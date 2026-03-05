/// Model-agnostic AI provider abstraction.
///
/// All AI calls flow through [AIProvider]. Implementations can wrap
/// Gemini, OpenAI, Claude, local models, or a mock for testing.
/// This is the single point of control for model swapping, token
/// metering, and structured-output enforcement.
abstract class AIProvider {
  /// Human-readable name (e.g. "gemini-2.0-flash", "gpt-4o")
  String get modelName;

  /// Send a prompt and receive raw text back.
  Future<AIResponse> complete(String prompt);

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
