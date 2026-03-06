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

    // Estimate tokens (~4 chars per token for English text)
    final promptTokens = (prompt.length / 4).ceil();
    final completionTokens = (text.length / 4).ceil();

    return AIResponse(
      text: text,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      latencyMs: stopwatch.elapsedMilliseconds,
      model: modelName,
    );
  }

  @override
  void dispose() {}
}
