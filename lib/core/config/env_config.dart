import 'package:flutter_dotenv/flutter_dotenv.dart';

// Application environment configuration.
// Reads from .env at runtime via flutter_dotenv.
enum Environment { dev, staging, prod }

class EnvConfig {
  final Environment environment;
  final String geminiApiKey;
  final String appName;
  final bool enableAILogging;
  final bool enableTokenTracking;
  final int maxTokensPerDay;
  final bool useMockAI;

  const EnvConfig._({
    required this.environment,
    required this.geminiApiKey,
    required this.appName,
    required this.enableAILogging,
    required this.enableTokenTracking,
    required this.maxTokensPerDay,

    required this.useMockAI,
  });

  bool get isDev => environment == Environment.dev;
  bool get isProd => environment == Environment.prod;
  bool get isStaging => environment == Environment.staging;

  // Reads all values from .env loaded by flutter_dotenv.
  // Call after dotenv.load() completes in main().
  static EnvConfig fromDotEnv() {
    final envName = dotenv.get('ENV', fallback: 'dev');
    final env = switch (envName) {
      'prod' => Environment.prod,
      'staging' => Environment.staging,
      _ => Environment.dev,
    };

    final appName = switch (env) {
      Environment.prod => 'AutoPlanner AI',
      Environment.staging => 'AutoPlanner AI [STAGING]',
      Environment.dev => 'AutoPlanner AI [DEV]',
    };

    return EnvConfig._(
      environment: env,
      geminiApiKey: dotenv.get('GEMINI_API_KEY', fallback: ''),
      appName: appName,
      enableAILogging:
          dotenv.get('ENABLE_AI_LOGGING', fallback: 'true') == 'true',
      enableTokenTracking:
          dotenv.get('ENABLE_TOKEN_TRACKING', fallback: 'true') == 'true',
      maxTokensPerDay:
          int.tryParse(dotenv.get('MAX_TOKENS_PER_DAY', fallback: '100000')) ??
          100000,
      useMockAI: dotenv.get('USE_MOCK_AI', fallback: 'false') == 'true',
    );
  }
}

/// Global singleton — initialized once in main.dart after dotenv.load()
late final EnvConfig appConfig;
