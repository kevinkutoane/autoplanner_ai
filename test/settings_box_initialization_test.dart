import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:autoplanner_ai/core/bootstrap/app_bootstrapper.dart';
import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';
import 'package:autoplanner_ai/features/settings/controllers/settings_controller.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';
import 'package:autoplanner_ai/services/secure_key_service.dart';

class _FakeSecureStorageClient implements SecureStorageClient {
  final Map<String, String> values = {};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  @override
  Future<String?> read({required String key}) async {
    if (failRead) throw Exception('Simulated secure storage read failure');
    return values[key];
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    if (failWrite) throw Exception('Simulated secure storage write failure');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    if (failDelete) throw Exception('Simulated secure storage delete failure');
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveAesCipher testCipher;
  late Uint8List testKeyBytes;
  late _FakeSecureStorageClient fakeStorage;

  setUpAll(() {
    appConfig = const EnvConfig();
  });

  setUp(() async {
    fakeStorage = _FakeSecureStorageClient();
    SecureKeyService.setStorageForTesting(fakeStorage);
    FlutterSecureStorage.setMockInitialValues({});

    tempDir = await Directory.systemTemp.createTemp('settings_init_test_');
    Hive.init(tempDir.path);

    testKeyBytes = Uint8List.fromList(List.generate(32, (i) => i + 10));
    testCipher = HiveAesCipher(testKeyBytes);

    // Reset settings box opener between tests
    SettingsController.resetBoxOpenerForTesting();
  });

  tearDown(() async {
    SettingsController.resetBoxOpenerForTesting();
    SecureKeyService.resetStorageForTesting();
    await Hive.close();
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  group('Phase 1B.2: Safe Settings-Box Initialization', () {
    test('1. Settings initialization reuses an already-open encrypted box without re-opening', () async {
      // Pre-open the settings box with encryption
      final encryptedBox = await AppBootstrapper.openBoxSafe<dynamic>(
        AppSettings.boxName,
        testCipher,
        customDir: tempDir.path,
      );
      await encryptedBox.put(AppSettings.kUserName, 'PreOpenedUser');
      await encryptedBox.put(AppSettings.kWorkHoursPerDay, 9);

      var openerCalled = false;
      SettingsController.boxOpener = () async {
        openerCalled = true;
        throw StateError(
          'Opener should NOT be called when box is already open',
        );
      };

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // Verify the controller state was populated from the open box
      expect(ctrl.state.userName, 'PreOpenedUser');
      expect(ctrl.state.workHoursPerDay, 9);
      // Verify boxOpener was never touched
      expect(openerCalled, isFalse);
    });

    test('2. When box is not open, SettingsController follows approved safe initialization path', () async {
      expect(Hive.isBoxOpen(AppSettings.boxName), isFalse);

      var openerCallCount = 0;
      SettingsController.boxOpener = () async {
        openerCallCount++;
        return await AppBootstrapper.openBoxSafe<dynamic>(
          AppSettings.boxName,
          testCipher,
          customDir: tempDir.path,
        );
      };

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      expect(openerCallCount, 1);
      expect(Hive.isBoxOpen(AppSettings.boxName), isTrue);

      // Verify mutation persists and updates state through safe box
      await ctrl.updateUserName('SafeInitializedUser');
      expect(ctrl.state.userName, 'SafeInitializedUser');
      expect(
        Hive.box<dynamic>(AppSettings.boxName).get(AppSettings.kUserName),
        'SafeInitializedUser',
      );
    });

    test('3. Initialization failure does not silently create an unencrypted replacement', () async {
      expect(Hive.isBoxOpen(AppSettings.boxName), isFalse);

      // No boxOpener registered, simulating unconfigured fallback
      SettingsController.resetBoxOpenerForTesting();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      // ensureInitialized completes safely (errors caught internally)
      await ctrl.ensureInitialized();

      // Hive box must remain NOT open
      expect(Hive.isBoxOpen(AppSettings.boxName), isFalse);

      // No unencrypted settings box file should exist on disk
      final hiveFile1 = File('${tempDir.path}/settingsbox.hive');
      final hiveFile2 = File('${tempDir.path}/${AppSettings.boxName}.hive');
      expect(hiveFile1.existsSync(), isFalse);
      expect(hiveFile2.existsSync(), isFalse);

      // Mutating via controller must fail closed (throws SecureStorageException)
      expect(
        () async => await ctrl.updateUserName('Hacker'),
        throwsA(isA<SecureStorageException>()),
      );
    });

    test('4. Delegate error during initialization does not delete existing encrypted data', () async {
      // 1. Create and write encrypted box on disk
      var encryptedBox = await AppBootstrapper.openBoxSafe<dynamic>(
        AppSettings.boxName,
        testCipher,
        customDir: tempDir.path,
      );
      await encryptedBox.put(AppSettings.kUserName, 'ImportantUserData');
      await encryptedBox.close();

      expect(Hive.isBoxOpen(AppSettings.boxName), isFalse);
      final hiveFile = File('${tempDir.path}/settingsbox.hive');
      expect(hiveFile.existsSync(), isTrue);
      final originalLength = hiveFile.lengthSync();
      expect(originalLength, greaterThan(0));

      // 2. Set boxOpener that throws an error
      SettingsController.boxOpener = () async {
        throw const SecureStorageException('Simulated keychain access failure');
      };

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // Original file MUST NOT have been deleted
      expect(hiveFile.existsSync(), isTrue);
      expect(hiveFile.lengthSync(), originalLength);
    });

    test('5. Repeated and concurrent ensureInitialized calls execute safe initialization exactly once', () async {
      expect(Hive.isBoxOpen(AppSettings.boxName), isFalse);

      var openerInvocationCount = 0;
      final openerCompleter = Completer<Box<dynamic>>();

      SettingsController.boxOpener = () async {
        openerInvocationCount++;
        // Simulate async opening latency
        await Future.delayed(const Duration(milliseconds: 20));
        final box = await AppBootstrapper.openBoxSafe<dynamic>(
          AppSettings.boxName,
          testCipher,
          customDir: tempDir.path,
        );
        openerCompleter.complete(box);
        return box;
      };

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);

      // Trigger 5 concurrent initialization calls
      final futures = [
        ctrl.ensureInitialized(),
        ctrl.ensureInitialized(),
        ctrl.ensureInitialized(),
        ctrl.ensureInitialized(),
        ctrl.ensureInitialized(),
      ];

      await Future.wait(futures);

      // Verify the box opener was invoked exactly once across all concurrent callers
      expect(openerInvocationCount, 1);
      expect(Hive.isBoxOpen(AppSettings.boxName), isTrue);

      // Verify subsequent repeated calls also do not re-invoke
      await ctrl.ensureInitialized();
      expect(openerInvocationCount, 1);
    });

    test('6. Credential migration and legacy setting migration remain intact with safe initialization', () async {
      // Pre-open encrypted box and inject legacy credentials and default localhost gateway
      final box = await AppBootstrapper.openBoxSafe<dynamic>(
        AppSettings.boxName,
        testCipher,
        customDir: tempDir.path,
      );
      await box.put(AppSettings.kGeminiApiKey, 'legacy-secret-api-key');
      await box.put(AppSettings.kAiConnectionMode, 'cloud_gateway');
      await box.put(AppSettings.kCloudGatewayUrl, 'http://127.0.0.1:8000');
      await box.put(AppSettings.kUserName, 'MigrationUser');

      // Secure storage starts empty
      expect(await SecureKeyService.getGeminiApiKey(), isNull);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // Credential migration verified:
      // 1. Controller state has key loaded
      expect(ctrl.state.geminiApiKey, 'legacy-secret-api-key');
      // 2. Authoritative secure storage has key
      expect(await SecureKeyService.getGeminiApiKey(), 'legacy-secret-api-key');
      // 3. Plain Hive key removed
      expect(box.get(AppSettings.kGeminiApiKey), isNull);

      // AI configuration migration verified:
      expect(ctrl.state.aiConnectionMode, 'direct_gemini');
      expect(ctrl.state.cloudGatewayUrl, '');
      expect(box.get(AppSettings.kCloudGatewayUrl), '');
      expect(box.get(AppSettings.kAiConnectionMode), 'direct_gemini');

      // Other settings intact:
      expect(ctrl.state.userName, 'MigrationUser');
      expect(box.get(AppSettings.kUserName), 'MigrationUser');
    });

    test('7. AppBootstrapper.openSettingsBoxSafe reuses open box and derives key when needed', () async {
      // Seed secure storage with hive encryption key
      await SecureKeyService.getOrCreateHiveEncryptionKey(
        hasExistingData: () async => false,
      );

      // 1. openSettingsBoxSafe opens with derived key
      final box1 = await AppBootstrapper.openSettingsBoxSafe(
        customDir: tempDir.path,
      );
      expect(box1.isOpen, isTrue);
      expect(box1.name, equalsIgnoringCase(AppSettings.boxName));
      await box1.put('testKey', 'value123');

      // 2. Calling openSettingsBoxSafe again reuses the already open instance
      final box2 = await AppBootstrapper.openSettingsBoxSafe(
        customDir: tempDir.path,
      );
      expect(identical(box1, box2), isTrue);
      expect(box2.get('testKey'), 'value123');
    });

    test('8. openSettingsBoxSafe with customDir fails safely and refuses to generate key when existing non-empty file is present', () async {
      // 1. Create a separate temporary custom data directory
      final customTempDir = await Directory.systemTemp.createTemp(
        'custom_dir_safety_test_',
      );
      addTearDown(() async {
        if (customTempDir.existsSync()) {
          try {
            await customTempDir.delete(recursive: true);
          } catch (_) {}
        }
      });

      // 2. Place a non-empty Hive database file inside the custom directory
      final existingDbFile = File(
        '${customTempDir.path}/some_existing_box.hive',
      );
      await existingDbFile.writeAsBytes(List<int>.generate(64, (i) => i));
      expect(existingDbFile.existsSync(), isTrue);
      final initialFileLength = existingDbFile.lengthSync();
      expect(initialFileLength, greaterThan(0));

      // 3. Confirm secure storage starts with NO stored Hive encryption key
      expect(fakeStorage.values.containsKey('hive_encryption_key'), isFalse);

      // 4. Calling openSettingsBoxSafe(customDir: customTempDir.path) must fail closed
      expect(
        () async => await AppBootstrapper.openSettingsBoxSafe(
          customDir: customTempDir.path,
        ),
        throwsA(
          isA<SecureStorageException>().having(
            (e) => e.message,
            'message',
            contains('Refusing to generate new Hive encryption key'),
          ),
        ),
      );

      // 5. Confirm no replacement key was written to secure storage
      expect(fakeStorage.values.containsKey('hive_encryption_key'), isFalse);

      // 6. Confirm the existing database file remains intact and untouched
      expect(existingDbFile.existsSync(), isTrue);
      expect(existingDbFile.lengthSync(), initialFileLength);
    });
  });
}
