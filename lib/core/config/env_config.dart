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
  final String sentryDsn;

  /// Whether to print each AI prompt/response to the debug console.
  final bool enableAILogging;

  /// Whether per-call token usage is written to the `aiLogsBox`.
  final bool enableTokenTracking;

  /// Maximum combined tokens (prompt + completion) allowed per calendar day.
  final int maxTokensPerDay;

  /// When true, [MockAIProvider] is used instead of the real Gemini model.
  final bool useMockAI;

  /// Safe defaults used when `.env` fails to load.
  const EnvConfig({
    this.environment = Environment.dev,
    this.geminiApiKey = '',
    this.appName = 'AutoPlanner AI [DEV]',
    this.sentryDsn = '',
    this.enableAILogging = true,
    this.enableTokenTracking = true,
    this.maxTokensPerDay = 100000,
    this.useMockAI = false,
  });

  const EnvConfig._({
    required this.environment,
    required this.geminiApiKey,
    required this.appName,
    required this.sentryDsn,
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
      sentryDsn: dotenv.get('SENTRY_DSN', fallback: ''),
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

  /// Returns non-blocking startup warnings for incomplete release config.
  List<String> validate() {
    final warnings = <String>[];

    if (geminiApiKey.isEmpty) {
      warnings.add(
        'GEMINI_API_KEY is not set. AI features will require a user key in Settings.',
      );
    }
    if (environment != Environment.dev && sentryDsn.isEmpty) {
      warnings.add(
        'SENTRY_DSN is not set. Production crash reporting is disabled.',
      );
    }
    if (useMockAI && environment == Environment.prod) {
      warnings.add('USE_MOCK_AI is enabled in production.');
    }

    return warnings;
  }
}

/// Global singleton — initialized once in main.dart after dotenv.load()
late final EnvConfig appConfig;
