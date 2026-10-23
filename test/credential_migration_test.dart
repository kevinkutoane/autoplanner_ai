import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';
import 'package:autoplanner_ai/services/secure_key_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    appConfig = const EnvConfig();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('credential_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
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
  });
}
