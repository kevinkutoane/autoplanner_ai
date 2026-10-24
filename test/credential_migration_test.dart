import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';
import 'package:autoplanner_ai/services/secure_key_service.dart';

class FakeFailingSecureStorageClient implements SecureStorageClient {
  final Map<String, String> values;
  bool failWrite;
  bool failRead;
  bool failDelete;
  bool failReadAfterWrite;
  String? readOverride;
  int writeCount = 0;

  FakeFailingSecureStorageClient({
    Map<String, String>? initialValues,
    this.failWrite = false,
    this.failRead = false,
    this.failDelete = false,
    this.failReadAfterWrite = false,
    this.readOverride,
  }) : values = initialValues != null ? Map.from(initialValues) : {};

  @override
  Future<String?> read({required String key}) async {
    if (failRead) throw Exception('Simulated secure storage read failure');
    if (failReadAfterWrite && writeCount > 0) {
      throw Exception('Simulated read-back verification failure after write');
    }
    if (readOverride != null) return readOverride;
    return values[key];
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    if (failWrite) throw Exception('Simulated secure storage write failure');
    writeCount++;
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

  setUpAll(() {
    appConfig = const EnvConfig();
  });

  setUp(() async {
    SecureKeyService.resetStorageForTesting();
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('credential_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    SecureKeyService.resetStorageForTesting();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 1A: Credential Persistence & Safe Migration', () {
    test('8. Gemini keys are never emitted by ordinary AppSettings serialization (toMap)', () {
      final settings = AppSettings.defaults().copyWith(
        geminiApiKey: 'sensitive-gemini-key-9999',
        userName: 'Kevin',
        cloudGatewayUrl: 'https://gateway.example.com',
      );

      final serializedMap = settings.toMap();

      // Must NOT contain the credential key in the serialized map
      expect(serializedMap.containsKey(AppSettings.kGeminiApiKey), isFalse);
      expect(serializedMap[AppSettings.kGeminiApiKey], isNull);

      // Regular settings must still be present
      expect(serializedMap[AppSettings.kUserName], 'Kevin');
      expect(
        serializedMap[AppSettings.kCloudGatewayUrl],
        'https://gateway.example.com',
      );
    });

    test('7a. Legacy settings in Hive safely migrate to SecureKeyService and clean up Hive copy', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      // Simulate legacy version having written the API key into Hive
      await box.put(AppSettings.kUserName, 'Alice');
      await box.put(AppSettings.kGeminiApiKey, 'legacy-stored-secret-key-456');
      await box.put(AppSettings.kAiConnectionMode, 'direct_gemini');

      // Verify key is in Hive and NOT in SecureKeyService yet
      expect(
        box.get(AppSettings.kGeminiApiKey),
        'legacy-stored-secret-key-456',
      );
      expect(await SecureKeyService.getGeminiApiKey(), isNull);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // 1. Controller state must have the key loaded
      expect(ctrl.state.geminiApiKey, 'legacy-stored-secret-key-456');

      // 2. Key must now be securely stored in SecureKeyService
      final migratedKey = await SecureKeyService.getGeminiApiKey();
      expect(migratedKey, 'legacy-stored-secret-key-456');

      // 3. Key must be deleted from ordinary Hive box
      expect(box.get(AppSettings.kGeminiApiKey), isNull);

      // 4. Other preferences must be preserved intact
      expect(ctrl.state.userName, 'Alice');
      expect(box.get(AppSettings.kUserName), 'Alice');
    });

    test('7b. Legacy cloud_gateway with dead localhost URL migrates to direct_gemini safely', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kAiConnectionMode, 'cloud_gateway');
      await box.put(AppSettings.kCloudGatewayUrl, 'http://127.0.0.1:8000');
      await box.put(AppSettings.kUserName, 'Bob');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // Should migrate to direct_gemini and clear the dead localhost URL
      expect(ctrl.state.aiConnectionMode, 'direct_gemini');
      expect(ctrl.state.cloudGatewayUrl, '');
      expect(box.get(AppSettings.kCloudGatewayUrl), '');
      expect(box.get(AppSettings.kAiConnectionMode), 'direct_gemini');
      expect(ctrl.state.userName, 'Bob');
    });

    test('7c. Deliberately configured custom remote gateway URL is preserved during migration', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kAiConnectionMode, 'cloud_gateway');
      await box.put(
        AppSettings.kCloudGatewayUrl,
        'https://my-custom-gateway.cloudrun.app',
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // Must NOT overwrite custom remote URL
      expect(ctrl.state.aiConnectionMode, 'cloud_gateway');
      expect(
        ctrl.state.cloudGatewayUrl,
        'https://my-custom-gateway.cloudrun.app',
      );
      expect(
        box.get(AppSettings.kCloudGatewayUrl),
        'https://my-custom-gateway.cloudrun.app',
      );
    });

    test('updateGeminiApiKey updates SecureKeyService and never writes to Hive box', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      await ctrl.updateGeminiApiKey('new-user-entered-key-789');

      expect(ctrl.state.geminiApiKey, 'new-user-entered-key-789');
      expect(
        await SecureKeyService.getGeminiApiKey(),
        'new-user-entered-key-789',
      );
      // Hive box must NOT have the key
      expect(box.get(AppSettings.kGeminiApiKey), isNull);

      // Deleting the key
      await ctrl.updateGeminiApiKey('');
      expect(ctrl.state.geminiApiKey, '');
      expect(await SecureKeyService.getGeminiApiKey(), isNull);
      expect(box.get(AppSettings.kGeminiApiKey), isNull);
    });

    test('P1.1: Secure save verifies read-back and cleans up legacy Hive credential', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kGeminiApiKey, 'legacy-hive-credential-123');

      final fakeStorage = FakeFailingSecureStorageClient();
      SecureKeyService.setStorageForTesting(fakeStorage);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // Call update with a new key
      await ctrl.updateGeminiApiKey('fresh-verified-key-456');

      // 1. Secure storage has the new key
      expect(
        await SecureKeyService.getGeminiApiKey(),
        'fresh-verified-key-456',
      );
      // 2. Controller state has the new key
      expect(ctrl.state.geminiApiKey, 'fresh-verified-key-456');
      // 3. Hive box has NO copy
      expect(box.get(AppSettings.kGeminiApiKey), isNull);
    });

    test('P1.2: Secure-storage write failure: does not delete recoverable Hive credential or report success', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kGeminiApiKey, 'recoverable-legacy-key-xyz');

      final fakeStorage = FakeFailingSecureStorageClient(failWrite: true);
      SecureKeyService.setStorageForTesting(fakeStorage);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // State holds the in-memory fallback from failed migration
      expect(ctrl.state.geminiApiKey, 'recoverable-legacy-key-xyz');

      // Attempting to save a new key fails fast and distinguishes error
      expect(
        () => ctrl.updateGeminiApiKey('unwritable-new-key'),
        throwsA(isA<SecureStorageException>()),
      );

      // 1. Recoverable Hive copy must NOT be deleted
      expect(box.get(AppSettings.kGeminiApiKey), 'recoverable-legacy-key-xyz');
      // 2. Controller state must NOT claim new key was saved
      expect(ctrl.state.geminiApiKey, isNot('unwritable-new-key'));
      // 3. Ordinary Hive box must NEVER contain the newly entered key
      expect(box.get(AppSettings.kGeminiApiKey), isNot('unwritable-new-key'));
    });

    test('P1.3: Read-back failure or mismatched value: preserves recoverable Hive credential and fails', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kGeminiApiKey, 'recoverable-legacy-key-abc');

      // Simulate mismatch on readback (e.g., storage corruption)
      final fakeStorage = FakeFailingSecureStorageClient(
        readOverride: 'corrupted-mismatched-key',
      );
      SecureKeyService.setStorageForTesting(fakeStorage);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      expect(
        () => ctrl.updateGeminiApiKey('intended-new-key'),
        throwsA(
          isA<SecureStorageException>().having(
            (e) => e.message,
            'message',
            contains('Verification failed'),
          ),
        ),
      );

      // 1. Recoverable Hive copy must NOT be deleted
      expect(box.get(AppSettings.kGeminiApiKey), 'recoverable-legacy-key-abc');
      // 2. Controller state must NOT claim new key was saved
      expect(ctrl.state.geminiApiKey, isNot('intended-new-key'));
    });

    test('P1.4: Secure-storage deletion failure: does not report success or delete recoverable copy', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kGeminiApiKey, 'legacy-key-fallback');

      final fakeStorage = FakeFailingSecureStorageClient(
        initialValues: {'gemini_api_key': 'active-secure-key'},
        failDelete: true,
      );
      SecureKeyService.setStorageForTesting(fakeStorage);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // Deletion fails in secure storage
      expect(
        () => ctrl.updateGeminiApiKey(''),
        throwsA(isA<SecureStorageException>()),
      );

      // 1. Recoverable Hive copy must NOT be deleted if secure deletion failed
      expect(box.get(AppSettings.kGeminiApiKey), 'legacy-key-fallback');
      // 2. Controller state must NOT report key as cleared
      expect(ctrl.state.geminiApiKey, isNotEmpty);
      // 3. Key in secure storage is still present
      expect(fakeStorage.values['gemini_api_key'], 'active-secure-key');
    });

    test('P1.5: Restart/reinitialization after failed legacy migration preserves recoverable credential and retries', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kGeminiApiKey, 'legacy-survivor-key-999');

      // First run: Secure storage write fails
      final failingStorage = FakeFailingSecureStorageClient(failWrite: true);
      SecureKeyService.setStorageForTesting(failingStorage);

      final container1 = ProviderContainer();
      final ctrl1 = container1.read(settingsProvider.notifier);
      await ctrl1.ensureInitialized();

      // Migration failed on first run, but key remains in Hive box
      expect(box.get(AppSettings.kGeminiApiKey), 'legacy-survivor-key-999');
      expect(ctrl1.state.geminiApiKey, 'legacy-survivor-key-999');
      container1.dispose();

      // Second run: Simulating app restart with secure storage recovered and working
      final workingStorage = FakeFailingSecureStorageClient();
      SecureKeyService.setStorageForTesting(workingStorage);

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      final ctrl2 = container2.read(settingsProvider.notifier);
      await ctrl2.ensureInitialized();

      // Migration on restart succeeds!
      expect(
        await SecureKeyService.getGeminiApiKey(),
        'legacy-survivor-key-999',
      );
      // Hive box copy is now cleanly deleted
      expect(box.get(AppSettings.kGeminiApiKey), isNull);
      // Controller state has migrated key
      expect(ctrl2.state.geminiApiKey, 'legacy-survivor-key-999');
    });

    test('P1.6: Exception during read-back verification step after saving a key preserves legacy credential and fails', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kGeminiApiKey, 'legacy-preserve-me-123');

      final fakeStorage = FakeFailingSecureStorageClient(
        failReadAfterWrite: true,
      );
      SecureKeyService.setStorageForTesting(fakeStorage);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // Read-back verification throws during update
      expect(
        () => ctrl.updateGeminiApiKey('new-key-verification-throws'),
        throwsA(
          isA<SecureStorageException>().having(
            (e) => e.message,
            'message',
            contains('Failed to read back Gemini API key'),
          ),
        ),
      );

      // 1. Legacy Hive credential is not deleted
      expect(box.get(AppSettings.kGeminiApiKey), 'legacy-preserve-me-123');
      // 2. Controller state does NOT claim new key was saved
      expect(ctrl.state.geminiApiKey, isNot('new-key-verification-throws'));
    });

    test('P1.7: Initial secure-storage read failure while legacy Hive credential exists does not overwrite secure storage', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kGeminiApiKey, 'stale-legacy-hive-key-456');

      final fakeStorage = FakeFailingSecureStorageClient(
        initialValues: {'gemini_api_key': 'newer-existing-secure-key-789'},
        failRead: true,
      );
      SecureKeyService.setStorageForTesting(fakeStorage);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      // 1. Secure storage was NOT overwritten by legacy Hive migration
      expect(fakeStorage.writeCount, equals(0));
      expect(
        fakeStorage.values['gemini_api_key'],
        'newer-existing-secure-key-789',
      );

      // 2. Legacy Hive copy is preserved in Hive box for recoverability
      expect(box.get(AppSettings.kGeminiApiKey), 'stale-legacy-hive-key-456');

      // 3. Controller state uses legacy key as session fallback
      expect(ctrl.state.geminiApiKey, 'stale-legacy-hive-key-456');
    });

    test('P1.8: Recovery after initial secure-storage read failure restores newer secure key without replacement by stale Hive key', () async {
      final box = await Hive.openBox<dynamic>(AppSettings.boxName);
      await box.put(AppSettings.kGeminiApiKey, 'stale-legacy-hive-key-456');

      final fakeStorage = FakeFailingSecureStorageClient(
        initialValues: {'gemini_api_key': 'newer-existing-secure-key-789'},
        failRead: true,
      );
      SecureKeyService.setStorageForTesting(fakeStorage);

      // Launch 1: Read fails
      final container1 = ProviderContainer();
      final ctrl1 = container1.read(settingsProvider.notifier);
      await ctrl1.ensureInitialized();
      container1.dispose();

      // Launch 2: Secure storage recovers
      fakeStorage.failRead = false;

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      final ctrl2 = container2.read(settingsProvider.notifier);
      await ctrl2.ensureInitialized();

      // 1. Controller state authoritative key is the newer secure key
      expect(ctrl2.state.geminiApiKey, 'newer-existing-secure-key-789');

      // 2. Secure storage was NEVER overwritten with stale legacy key
      expect(
        await SecureKeyService.getGeminiApiKey(),
        'newer-existing-secure-key-789',
      );
      expect(fakeStorage.writeCount, equals(0));
    });
  });
}
