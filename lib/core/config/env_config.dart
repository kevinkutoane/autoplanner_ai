/// Application environment configuration.
///
/// Provides dev/prod separation for API keys, base URLs,
/// feature flags, and diagnostic settings.
enum Environment { dev, staging, prod }

class EnvConfig {
  final Environment environment;
  final String geminiApiKey;
  final String appName;
  final bool enableAILogging;
  final bool enableTokenTracking;
  final int maxTokensPerDay;
  final String firestoreProjectId;
  final bool useMockAI;

  const EnvConfig._({
    required this.environment,
    required this.geminiApiKey,
    required this.appName,
    required this.enableAILogging,
    required this.enableTokenTracking,
    required this.maxTokensPerDay,
    required this.firestoreProjectId,
    required this.useMockAI,
  });

  /// Development configuration
  static const dev = EnvConfig._(
    environment: Environment.dev,
    geminiApiKey: String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: 'AIzaSyBSFhNWnsc2c8xFFXqmuR0RDsguTXX1cog',
    ),
    appName: 'AutoPlanner AI [DEV]',
    enableAILogging: true,
    enableTokenTracking: true,
    maxTokensPerDay: 100000,
    firestoreProjectId: 'autoplanner-ai-dev',
    useMockAI: false,
  );

  /// Staging configuration
  static const staging = EnvConfig._(
    environment: Environment.staging,
    geminiApiKey: String.fromEnvironment('GEMINI_API_KEY'),
    appName: 'AutoPlanner AI [STAGING]',
    enableAILogging: true,
    enableTokenTracking: true,
    maxTokensPerDay: 500000,
    firestoreProjectId: 'autoplanner-ai-staging',
    useMockAI: false,
  );

  /// Production configuration
  static const prod = EnvConfig._(
    environment: Environment.prod,
    geminiApiKey: String.fromEnvironment('GEMINI_API_KEY'),
    appName: 'AutoPlanner AI',
    enableAILogging: false,
    enableTokenTracking: true,
    maxTokensPerDay: 1000000,
    firestoreProjectId: 'autoplanner-ai-prod',
    useMockAI: false,
  );

  bool get isDev => environment == Environment.dev;
  bool get isProd => environment == Environment.prod;
  bool get isStaging => environment == Environment.staging;

  /// Resolve environment from build-time dart-define
  static EnvConfig fromEnvironment() {
    const envName = String.fromEnvironment('ENV', defaultValue: 'dev');
    switch (envName) {
      case 'prod':
        return EnvConfig.prod;
      case 'staging':
        return EnvConfig.staging;
      case 'dev':
      default:
        return EnvConfig.dev;
    }
  }
}

/// Global singleton — initialized once in main.dart
late final EnvConfig appConfig;
