import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autoplanner_ai/core/ai/ai_invocation.dart';
import 'package:autoplanner_ai/core/ai/ai_provider.dart';
import 'package:autoplanner_ai/core/ai/cloud_ai_provider.dart';
import 'package:autoplanner_ai/core/ai/token_tracker.dart';
import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/services/ai_service.dart';

class _MockCallableAIProvider extends AIProvider {
  final Future<AIResponse> Function(String prompt, int callCount) handler;
  int callCount = 0;

  _MockCallableAIProvider(this.handler);

  @override
  String get modelName => 'mock-callable';

  @override
  Future<AIResponse> complete(String prompt, {AIInvocation? invocation}) {
    callCount++;
    return handler(prompt, callCount);
  }
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'ENABLE_TOKEN_TRACKING=false');
    appConfig = const EnvConfig();
  });

  group('Phase 1A: Failure-Aware AI Retries & Non-Retryable Handling', () {
    test('9a. Permanent AIConfigurationException fails fast without retrying (callCount == 1)', () async {
      late _MockCallableAIProvider provider;
      provider = _MockCallableAIProvider((prompt, count) async {
        throw const AIConfigurationException('Key missing');
      });

      final service = AIService(provider: provider, tracker: TokenTracker());

      expect(
        () => service.parseTasks('Buy groceries at 5pm'),
        throwsA(isA<AIConfigurationException>()),
      );

      // Crucial assertion: callCount must be exactly 1
      expect(provider.callCount, equals(1));
    });

    test('9b. Permanent AIAuthenticationException fails fast without retrying (callCount == 1)', () async {
      late _MockCallableAIProvider provider;
      provider = _MockCallableAIProvider((prompt, count) async {
        throw const AIAuthenticationException(
          'Invalid API Key',
          statusCode: 401,
        );
      });

      final service = AIService(provider: provider, tracker: TokenTracker());

      expect(
        () => service.chatWithCoach('How do I plan my day?', const []),
        throwsA(isA<AIAuthenticationException>()),
      );

      expect(provider.callCount, equals(1));
    });

    test('9c. Gateway HTTP 400, 401, 403, 404 client errors fail fast in 1 attempt', () async {
      for (final statusCode in [400, 401, 403, 404]) {
        late _MockCallableAIProvider provider;
        provider = _MockCallableAIProvider((prompt, count) async {
          throw CloudGatewayException(
            statusCode: statusCode,
            message: 'Client error $statusCode',
          );
        });

        final service = AIService(provider: provider, tracker: TokenTracker());

        expect(
          () => service.planDay(
            existingTasks: [],
            memories: const [],
            workStartHour: 9,
            workHoursPerDay: 8,
            additionalInput: 'Work on slides',
          ),
          throwsA(
            isA<CloudGatewayException>().having(
              (e) => e.statusCode,
              'statusCode',
              statusCode,
            ),
          ),
        );

        expect(
          provider.callCount,
          equals(1),
          reason: 'HTTP $statusCode must not be retried',
        );
      }
    });

    test(
      '10a. Transient network errors (status 0) use bounded retries',
      () async {
        late _MockCallableAIProvider provider;
        provider = _MockCallableAIProvider((prompt, count) async {
          if (count < 3) {
            throw const CloudGatewayException(
              statusCode: 0,
              message: 'Connection dropped',
            );
          }
          return const AIResponse(
            text: '[{"title": "Recovered Task", "startTime": "09:00", "estimatedMinutes": 30, "priority": 1, "tags": ["work"]}]',
          );
        });

        final service = AIService(provider: provider, tracker: TokenTracker());

        final result = await service.parseTasks('Do task');

        // Succeeded on 3rd attempt
        expect(provider.callCount, equals(3));
        expect(result, isNotEmpty);
        expect(result.first.title, 'Recovered Task');
      },
    );

    test('10b. HTTP 429 rate limit errors use bounded retries', () async {
      late _MockCallableAIProvider provider;
      provider = _MockCallableAIProvider((prompt, count) async {
        if (count < 2) {
          throw const CloudGatewayException(
            statusCode: 429,
            message: 'Too Many Requests',
          );
        }
        return const AIResponse(text: 'I am here to coach your productivity!');
      });

      final service = AIService(provider: provider, tracker: TokenTracker());

      final advice = await service.chatWithCoach('Hello coach', const []);

      expect(provider.callCount, equals(2));
      expect(advice, contains('coach your productivity'));
    });

    test('11. Real AI failures do NOT silently return canned mock tasks, goals, or notes', () async {
      late _MockCallableAIProvider provider;
      provider = _MockCallableAIProvider((prompt, count) async {
        throw const CloudGatewayException(
          statusCode: 500,
          message: 'Server error',
        );
      });

      final service = AIService(provider: provider, tracker: TokenTracker());

      // When brainDump fails, it must throw rather than silently returning canned data
      expect(
        () => service.brainDump('Need to finish quarterly budget'),
        throwsA(isA<CloudGatewayException>()),
      );

      // When parseTasks fails, it must throw rather than returning canned items
      expect(
        () => service.parseTasks('Buy groceries'),
        throwsA(isA<CloudGatewayException>()),
      );
    });
  });
}
