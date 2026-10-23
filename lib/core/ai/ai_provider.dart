import 'ai_invocation.dart';

/// Model-agnostic AI provider abstraction.
///
/// All AI calls flow through [AIProvider]. Implementations can wrap
/// Gemini, OpenAI, Claude, local models, or a mock for testing.
/// This is the single point of control for model swapping, token
/// metering, and structured-output enforcement.
abstract class AIProvider {
  /// Human-readable name (e.g. "gemini-2.0-flash", "gpt-4o")
  String get modelName;

  /// Send a prompt (and optional semantic [invocation]) and receive raw text back.
  Future<AIResponse> complete(String prompt, {AIInvocation? invocation});

  /// Stream tokens as they arrive. Override for real streaming; the default
  /// implementation falls back to a single [complete] call.
  Stream<String> streamComplete(
    String prompt, {
    AIInvocation? invocation,
  }) async* {
    final response = await complete(prompt, invocation: invocation);
    yield response.text;
  }

  /// Dispose any cached resources.
  void dispose() {}
}

/// Structured response wrapper — every AI call returns this.
class AIResponse {
  /// The raw text returned by the model.
  final String text;

  /// Estimated token counts (input + output).
  final int promptTokens;
  final int completionTokens;

  int get totalTokens => promptTokens + completionTokens;

  /// Wall-clock latency in milliseconds.
  final int latencyMs;

  /// Which model produced this response.
  final String model;

  const AIResponse({
    required this.text,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.latencyMs = 0,
    this.model = 'unknown',
  });
}

/// Base exception for all AI provider and runtime failures.
abstract class AIException implements Exception {
  final String message;
  const AIException(this.message);

  @override
  String toString() => message;
}

/// Permanent configuration failure (e.g. missing Gemini API key, missing gateway URL,
/// unconfigured authentication).
/// Non-retryable: fails fast so the UI can explain the missing configuration.
class AIConfigurationException extends AIException {
  final String? code;
  const AIConfigurationException(super.message, {this.code});
}

/// Permanent authentication/authorization failure (e.g. invalid API key, 401/403).
/// Non-retryable: fails fast so the UI can prompt for re-authentication.
class AIAuthenticationException extends AIException {
  final int? statusCode;
  const AIAuthenticationException(super.message, {this.statusCode});
}

/// Rate limit exceeded (e.g. HTTP 429 or quota limit).
/// Retryable with bounded backoff.
class AIRateLimitException extends AIException {
  final Duration? retryAfter;
  const AIRateLimitException(super.message, {this.retryAfter});
}

/// Transient network or server failure (e.g. timeout, connection reset, 502/503/504).
/// Retryable with bounded backoff.
class AITransientException extends AIException {
  final int? statusCode;
  const AITransientException(super.message, {this.statusCode});
}

/// An [AIProvider] representing an unconfigured or unavailable AI engine.
///
/// Throws [AIConfigurationException] on any invocation with a clear, user-facing
/// explanation of why the provider cannot execute.
class UnconfiguredAIProvider implements AIProvider {
  final String reason;
  final String? configurationHelp;

  @override
  final String modelName;

  const UnconfiguredAIProvider({
    required this.reason,
    this.configurationHelp,
    this.modelName = 'unconfigured-ai',
  });

  @override
  Future<AIResponse> complete(String prompt, {AIInvocation? invocation}) async {
    final help = configurationHelp != null ? ' ($configurationHelp)' : '';
    throw AIConfigurationException('$reason$help');
  }

  @override
  Stream<String> streamComplete(
    String prompt, {
    AIInvocation? invocation,
  }) async* {
    final help = configurationHelp != null ? ' ($configurationHelp)' : '';
    throw AIConfigurationException('$reason$help');
  }

  @override
  void dispose() {}
}
