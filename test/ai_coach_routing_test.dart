import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/ai/mock_ai_provider.dart';

void main() {
  group('MockAIProvider - Coach chat sanitization & routing', () {
    late MockAIProvider provider;

    setUp(() {
      provider = MockAIProvider();
    });

    test('coach queries asking for a plan return human coaching advice without raw JSON array', () async {
      final response = await provider.complete(
        'You are an executive productivity coach. User message: Can you help me plan my day?\nCoach:',
      );

      expect(response.text, isNotEmpty);
      expect(response.text.trim().startsWith('['), isFalse);
      expect(response.text.contains('Morning Anchor'), isTrue);
    });

    test(
      'coach queries asking for schedule return motivational actionable advice',
      () async {
        final response = await provider.complete(
          'You are AutoPlanner AI Coach. What schedule should I follow today?\nCoach:',
        );

        expect(response.text, isNotEmpty);
        expect(response.text.trim().startsWith('['), isFalse);
        expect(response.text.contains('Morning Anchor'), isTrue);
      },
    );

    test(
      'procrastination coach query returns 5-minute rule guidance',
      () async {
        final response = await provider.complete(
          'You are AutoPlanner AI Coach. I feel so stuck and keep procrastinating!\nCoach:',
        );

        expect(response.text, isNotEmpty);
        expect(response.text.trim().startsWith('['), isFalse);
        expect(response.text.contains('5-Minute Rule'), isTrue);
      },
    );

    test(
      'direct task parsing still returns structured JSON for planner',
      () async {
        final response = await provider.complete(
          'You are AutoPlanner AI. Convert user input into a structured task list: Buy milk, Write code',
        );

        expect(response.text.trim().startsWith('['), isTrue);
      },
    );
  });
}
