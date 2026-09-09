import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:autoplanner_ai/core/config/env_config.dart';

void main() {
  group('EnvConfig.fromDotEnv defaults', () {
    setUp(() async {
      // Load an isolated empty env so real .env values don't bleed in.
      dotenv.loadFromString(envString: '', isOptional: true);
    });

    test('environment defaults to dev', () {
      final config = EnvConfig.fromDotEnv();
      expect(config.environment, equals(Environment.dev));
    });

    test('isDev is true when ENV is omitted', () {
      expect(EnvConfig.fromDotEnv().isDev, isTrue);
    });

    test('isProd and isStaging are false when ENV is omitted', () {
      final config = EnvConfig.fromDotEnv();
      expect(config.isProd, isFalse);
      expect(config.isStaging, isFalse);
    });

    test('geminiApiKey falls back to empty string', () {
      expect(EnvConfig.fromDotEnv().geminiApiKey, equals(''));
    });

    test('sentryDsn falls back to empty string', () {
      expect(EnvConfig.fromDotEnv().sentryDsn, equals(''));
    });

    test('maxTokensPerDay falls back to 100000', () {
      expect(EnvConfig.fromDotEnv().maxTokensPerDay, equals(100000));
    });

    test('useMockAI falls back to false', () {
      expect(EnvConfig.fromDotEnv().useMockAI, isFalse);
    });

    test('enableAILogging falls back to true', () {
      expect(EnvConfig.fromDotEnv().enableAILogging, isTrue);
    });
  });

  group('EnvConfig.fromDotEnv with explicit values', () {
    test('recognises prod environment', () async {
      dotenv.loadFromString(envString: 'ENV=prod');
      final config = EnvConfig.fromDotEnv();
      expect(config.isProd, isTrue);
      expect(config.isDev, isFalse);
    });

    test('recognises staging environment', () async {
      dotenv.loadFromString(envString: 'ENV=staging');
      final config = EnvConfig.fromDotEnv();
      expect(config.isStaging, isTrue);
    });

    test('reads GEMINI_API_KEY', () async {
      dotenv.loadFromString(envString: 'GEMINI_API_KEY=test-key-123');
      expect(EnvConfig.fromDotEnv().geminiApiKey, equals('test-key-123'));
    });

    test('reads SENTRY_DSN', () async {
      dotenv.loadFromString(envString: 'SENTRY_DSN=https://dsn.example/123');
      expect(
        EnvConfig.fromDotEnv().sentryDsn,
        equals('https://dsn.example/123'),
      );
    });

    test('reads USE_MOCK_AI = true', () async {
      dotenv.loadFromString(envString: 'USE_MOCK_AI=true');
      expect(EnvConfig.fromDotEnv().useMockAI, isTrue);
    });

    test('reads MAX_TOKENS_PER_DAY', () async {
      dotenv.loadFromString(envString: 'MAX_TOKENS_PER_DAY=50000');
      expect(EnvConfig.fromDotEnv().maxTokensPerDay, equals(50000));
    });

    test('invalid MAX_TOKENS_PER_DAY falls back to 100000', () async {
      dotenv.loadFromString(envString: 'MAX_TOKENS_PER_DAY=not-a-number');
      expect(EnvConfig.fromDotEnv().maxTokensPerDay, equals(100000));
    });

    test('validate reports missing release monitoring config', () async {
      dotenv.loadFromString(envString: 'ENV=prod');
      expect(
        EnvConfig.fromDotEnv().validate(),
        contains(
          'SENTRY_DSN is not set. Production crash reporting is disabled.',
        ),
      );
    });
  });
}
