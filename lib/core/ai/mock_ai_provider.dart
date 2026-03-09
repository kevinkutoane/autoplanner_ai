import 'ai_provider.dart';

/// Mock AI provider for testing and offline development.
///
/// Returns canned responses so UI can be developed without
/// burning real API tokens.
class MockAIProvider implements AIProvider {
  @override
  final String modelName = 'mock-ai-v1';

  @override
  Future<AIResponse> complete(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final lower = prompt.toLowerCase();

    String text;
    if (lower.contains('task') ||
        lower.contains('plan') ||
        lower.contains('schedule') ||
        lower.contains('enrich')) {
      text = '''[
  {"id": null, "title": "Morning review", "startTime": "08:00", "estimatedMinutes": 30, "priority": 1, "tags": ["work"]},
  {"id": null, "title": "Deep work block", "startTime": "09:00", "estimatedMinutes": 120, "priority": 2, "tags": ["focus"]},
  {"id": null, "title": "Lunch break", "startTime": "12:00", "estimatedMinutes": 60, "priority": 0, "tags": ["personal"]}
]''';
    } else if (lower.contains('summarize') || lower.contains('summary')) {
      text =
          'This note covers key project decisions and action items from the team sync.';
    } else if (lower.contains('tag')) {
      text = '["productivity", "planning", "ai"]';
    } else if (lower.contains('insight') || lower.contains('daily')) {
      text =
          'You tend to be most productive in the morning. Try scheduling your hardest task before 10am.';
    } else if (lower.contains('memory') || lower.contains('extract')) {
      text = 'User prefers morning schedules and blocks deep work before noon.';
    } else {
      text =
          'Mock AI response for: ${prompt.substring(0, prompt.length.clamp(0, 50))}';
    }

    return AIResponse(
      text: text,
      promptTokens: (prompt.length / 4).ceil(),
      completionTokens: (text.length / 4).ceil(),
      latencyMs: 300,
      model: modelName,
    );
  }

  /// Emit in small chunks with a tiny delay —
  /// gives a realistic streaming feel during development.
  @override
  Stream<String> streamComplete(String prompt) async* {
    final response = await complete(prompt);
    const chunkSize = 4;
    final text = response.text;
    for (var i = 0; i < text.length; i += chunkSize) {
      yield text.substring(i, (i + chunkSize).clamp(0, text.length));
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  @override
  void dispose() {}
}
