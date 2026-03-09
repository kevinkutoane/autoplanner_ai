import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/env_config.dart';
import 'ai_provider.dart';

/// Gemini implementation of [AIProvider].
class GeminiProvider implements AIProvider {
  late final GenerativeModel _model;

  @override
  final String modelName;

  GeminiProvider({String? apiKey, this.modelName = 'gemini-2.5-flash'}) {
    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey ?? appConfig.geminiApiKey,
    );
  }

  @override
  Future<AIResponse> complete(String prompt) async {
    final stopwatch = Stopwatch()..start();
    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);
    stopwatch.stop();

    final text = response.text ?? '';
    // Use real token counts from the API response when available;
    // fall back to the character-based heuristic only if metadata is absent.
    final promptTokens =
        response.usageMetadata?.promptTokenCount ?? (prompt.length / 4).ceil();
    final completionTokens =
        response.usageMetadata?.candidatesTokenCount ??
        (text.length / 4).ceil();

    return AIResponse(
      text: text,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      latencyMs: stopwatch.elapsedMilliseconds,
      model: modelName,
    );
  }

  @override
  Stream<String> streamComplete(String prompt) async* {
    final content = [Content.text(prompt)];
    final stream = _model.generateContentStream(content);
    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) yield text;
    }
  }

  @override
  void dispose() {}
}
