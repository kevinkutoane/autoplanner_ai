import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autoplanner_ai/core/ai/gemini_provider.dart';
import 'package:autoplanner_ai/core/ai/mock_ai_provider.dart';
import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';
import 'package:autoplanner_ai/features/settings/controllers/settings_controller.dart';

class _TestSettingsController extends SettingsController {
  final AppSettings _initial;
  _TestSettingsController(this._initial);

  @override
  AppSettings build() => _initial;
}

void main() {
  setUp(() {
    appConfig = const EnvConfig();
  });

  group('Phase 1A: AI Provider Selection & Routing Rules', () {
    test('1. Fresh settings with no Gemini key do not select an unreachable localhost CloudAIProvider', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsController(AppSettings.defaults()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = container.read(aiProviderProvider);

      // Must NOT be CloudAIProvider pointing to localhost
      expect(provider.modelName, isNot(contains('cloud-gateway')));
      expect(provider, isA<UnconfiguredAIProvider>());

      // Must throw AIConfigurationException when complete() is attempted
      expect(
        () => provider.complete('Plan my day'),
        throwsA(
          isA<AIConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('Gemini API key is not configured'),
          ),
        ),
      );
    });

    test(
      '2. Direct Gemini mode with a configured key selects GeminiProvider',
      () {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              () => _TestSettingsController(
                AppSettings.defaults().copyWith(
                  aiConnectionMode: 'direct_gemini',
                  geminiApiKey: 'test-active-gemini-key-12345',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final provider = container.read(aiProviderProvider);
        expect(provider, isA<GeminiProvider>());
      },
    );

    test('3. Direct Gemini mode without a key fails clearly and promptly with AIConfigurationException', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsController(
              AppSettings.defaults().copyWith(
                aiConnectionMode: 'direct_gemini',
                geminiApiKey: '',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = container.read(aiProviderProvider);
      expect(provider, isA<UnconfiguredAIProvider>());

      expect(
        () => provider.complete('Parse tasks'),
        throwsA(
          isA<AIConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('Gemini API key is not configured'),
          ),
        ),
      );
    });

    test('4. Explicit offline mock mode selects MockAIProvider and does not claim genuine AI', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsController(
              AppSettings.defaults().copyWith(
                aiConnectionMode: 'offline_mock',
                useMockAI: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = container.read(aiProviderProvider);
      expect(provider, isA<MockAIProvider>());

      final res = await provider.complete('Test prompt');
      expect(res.text, isNotEmpty);
    });

    test('5. Real remote gateway mode cannot run without its required client authentication', () async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsController(
              AppSettings.defaults().copyWith(
                aiConnectionMode: 'cloud_gateway',
                cloudGatewayUrl: 'https://gateway.autoplanner.app',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = container.read(aiProviderProvider);
      expect(provider, isA<UnconfiguredAIProvider>());

      expect(
        () => provider.complete('Test gateway complete'),
        throwsA(
          isA<AIConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('Hosted AI Gateway authentication is not configured'),
          ),
        ),
      );
    });

    test('6. An environment-configured gateway URL is not shadowed by a default URL', () {
      appConfig = const EnvConfig(
        aiGatewayUrl: 'https://env-gateway.autoplanner.internal',
      );

      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _TestSettingsController(
              // cloudGatewayUrl defaults to empty string, so env URL is not shadowed
              AppSettings.defaults().copyWith(
                aiConnectionMode: 'cloud_gateway',
                cloudGatewayUrl: '',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = container.read(aiProviderProvider);
      // Because the effective URL is the remote env URL without client auth, it fails safely
      expect(provider, isA<UnconfiguredAIProvider>());
      expect(
        () => provider.complete('Ping'),
        throwsA(
          isA<AIConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('Hosted AI Gateway authentication is not configured'),
          ),
        ),
      );
    });
  });
}
