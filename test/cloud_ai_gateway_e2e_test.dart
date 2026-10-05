import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/ai/cloud_ai_provider.dart';
import 'package:autoplanner_ai/core/ai/token_tracker.dart';
import 'package:autoplanner_ai/services/ai_service.dart';
import 'package:autoplanner_ai/core/models/memory_entry_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    appConfig = const EnvConfig();
  });

  group('AIService + CloudAIProvider End-to-End Integration', () {
    test('successfully parses tasks through CloudAIProvider contract', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'id': 'test-gateway-invocation-123',
            'operation': 'parse_tasks',
            'text': jsonEncode([
              {
                'title': 'Team Sync',
                'startTime': '10:00',
                'estimatedMinutes': 45,
                'priority': 2,
                'tags': ['work', 'meeting'],
              },
              {
                'title': 'Review architecture PR',
                'startTime': '11:00',
                'estimatedMinutes': 60,
                'priority': 1,
                'tags': ['dev'],
              }
            ]),
            'promptTokens': 150,
            'completionTokens': 75,
            'model': 'gemini-2.5-flash',
            'latencyMs': 240,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final cloudProvider = CloudAIProvider(
        gatewayBaseUrl: Uri.parse('http://127.0.0.1:8000'),
        httpClient: mockClient,
        authTokenProvider: () async => 'dev-secret-token',
        clientVersion: '2.3.1+1',
      );

      final aiService = AIService(
        provider: cloudProvider,
        tracker: TokenTracker(),
      );

      final memories = [
        MemoryEntry(
          id: 'mem-1',
          content: 'User prefers deep work in mornings',
          sourceType: 'user',
          createdAt: DateTime.now(),
        ),
      ];

      final tasks = await aiService.parseTasks(
        'Team Sync at 10am and review PR at 11am',
        memories: memories,
      );

      // Verify returned tasks parsed into deterministic domain objects
      expect(tasks.length, equals(2));
      expect(tasks[0].title, equals('Team Sync'));
      expect(tasks[0].endTime!.difference(tasks[0].startTime).inMinutes, equals(45));
      expect(tasks[0].priority, equals(2));
      expect(tasks[0].tags, contains('meeting'));

      expect(tasks[1].title, equals('Review architecture PR'));
      expect(tasks[1].endTime!.difference(tasks[1].startTime).inMinutes, equals(60));
      expect(tasks[1].priority, equals(1));

      // Verify captured HTTP request matches Gateway contract
      expect(capturedRequest, isNotNull);
      expect(
        capturedRequest!.url.toString(),
        equals('http://127.0.0.1:8000/v1/ai/complete'),
      );
      expect(
        capturedRequest!.headers['authorization'],
        equals('Bearer dev-secret-token'),
      );
      expect(capturedRequest!.headers['x-client-version'], equals('2.3.1+1'));
      expect(capturedRequest!.headers['x-request-id'], isNotEmpty);

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['operation'], equals('parse_tasks'));
      expect(body['input']['text'], contains('Team Sync'));
      expect(body['context']['memories'], contains('User prefers deep work in mornings'));
    });

    test('propagates CloudGatewayException on Gateway 429 Rate Limit error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'RATE_LIMITED',
              'message': 'Rate limit exceeded: 60 requests per minute.',
              'requestId': 'req-rate-limit-1',
            }
          }),
          429,
          headers: {'content-type': 'application/json'},
        );
      });

      final cloudProvider = CloudAIProvider(
        gatewayBaseUrl: Uri.parse('http://127.0.0.1:8000'),
        httpClient: mockClient,
        authTokenProvider: () async => 'dev-secret-token',
      );

      final aiService = AIService(
        provider: cloudProvider,
        tracker: TokenTracker(),
      );

      expect(
        () => aiService.parseTasks('Buy groceries'),
        throwsA(isA<CloudGatewayException>()),
      );
    });
  });
}
