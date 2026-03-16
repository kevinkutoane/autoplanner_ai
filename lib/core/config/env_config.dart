import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application environment: controls AI logging, token limits, and mock mode.
enum Environment { dev, staging, prod }

/// Typed, immutable snapshot of all values read from the `.env` file.
///
/// Initialised once in `main()` via [EnvConfig.fromDotEnv] after
/// `dotenv.load()` completes, then stored in the [appConfig] global singleton.
/// Feature code reads `appConfig.*` directly — no BuildContext required.
class EnvConfig {
  final Environment environment;
  final String geminiApiKey;
  final String appName;

  /// Whether to print each AI prompt/response to the debug console.
  final bool enableAILogging;

  /// Whether per-call token usage is written to the `aiLogsBox`.
  final bool enableTokenTracking;

  /// Maximum combined tokens (prompt + completion) allowed per calendar day.
  final int maxTokensPerDay;

  /// When true, [MockAIProvider] is used instead of the real Gemini model.
  final bool useMockAI;

  /// Azure App Registration client ID for Microsoft MSAL sign-in.
  final String azureClientId;

  const EnvConfig._({
    required this.environment,
    required this.geminiApiKey,
    required this.appName,
    required this.enableAILogging,
    required this.enableTokenTracking,
    required this.maxTokensPerDay,
    required this.useMockAI,
    required this.azureClientId,
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
      azureClientId: dotenv.get('AZURE_CLIENT_ID', fallback: ''),
    );
  }
}

/// Global singleton — initialized once in main.dart after dotenv.load()
late final EnvConfig appConfig;
