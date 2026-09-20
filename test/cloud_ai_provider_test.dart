import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:autoplanner_ai/core/ai/ai_invocation.dart';
import 'package:autoplanner_ai/core/ai/cloud_ai_provider.dart';

void main() {
  group('CloudAIProvider', () {
    test('sends correct headers and JSON payload on complete()', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'text': '[{"title": "Review PR"}]',
            'promptTokens': 45,
            'completionTokens': 18,
            'model': 'gateway-gemini-1.5-pro',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = CloudAIProvider(
        gatewayBaseUrl: Uri.parse('https://ai.autoplanner.app'),
        httpClient: mockClient,
        authTokenProvider: () async => 'test-bearer-token-123',
        clientVersion: '2.3.1',
      );

      final invocation = AIInvocation(
        id: 'req-abc-999',
        operation: AIOperation.parseTasks,
        input: {'text': 'Buy milk at 3pm'},
        context: {'workHours': 8},
      );

      final response = await provider.complete(
        'Prompt text',
        invocation: invocation,
      );

      expect(response.text, equals('[{"title": "Review PR"}]'));
      expect(response.promptTokens, equals(45));
      expect(response.completionTokens, equals(18));
      expect(response.model, equals('gateway-gemini-1.5-pro'));

      expect(capturedRequest, isNotNull);
      expect(
        capturedRequest!.url.toString(),
        equals('https://ai.autoplanner.app/v1/ai/complete'),
      );
      expect(
        capturedRequest!.headers['authorization'],
        equals('Bearer test-bearer-token-123'),
      );
      expect(capturedRequest!.headers['x-request-id'], equals('req-abc-999'));
      expect(capturedRequest!.headers['x-client-version'], equals('2.3.1'));

      final sentBody =
          jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(sentBody['operation'], equals('parse_tasks'));
      expect(sentBody['id'], equals('req-abc-999'));
      expect(sentBody['input']['text'], equals('Buy milk at 3pm'));
      expect(sentBody['input']['prompt'], equals('Prompt text'));
      expect(sentBody['context']['workHours'], equals(8));
      expect(sentBody['client']['appVersion'], equals('2.3.1'));
    });

    test('throws CloudGatewayException on HTTP 401 Unauthorized', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Unauthorized API token"}', 401);
      });

      final provider = CloudAIProvider(
        gatewayBaseUrl: Uri.parse('https://ai.autoplanner.app'),
        httpClient: mockClient,
      );

      expect(
        () => provider.complete('Hello world'),
        throwsA(
          isA<CloudGatewayException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.responseBody,
                'responseBody',
                contains('Unauthorized'),
              ),
        ),
      );
    });

    test('throws CloudGatewayException on HTTP 429 Rate Limited', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Rate limit exceeded"}', 429);
      });

      final provider = CloudAIProvider(
        gatewayBaseUrl: Uri.parse('https://ai.autoplanner.app'),
        httpClient: mockClient,
      );

      expect(
        () => provider.complete('Hello world'),
        throwsA(
          isA<CloudGatewayException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having(
                (e) => e.responseBody,
                'responseBody',
                contains('Rate limit'),
              ),
        ),
      );
    });

    test('throws CloudGatewayException on network error (status 0)', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final provider = CloudAIProvider(
        gatewayBaseUrl: Uri.parse('https://ai.autoplanner.app'),
        httpClient: mockClient,
      );

      expect(
        () => provider.complete('Hello world'),
        throwsA(
          isA<CloudGatewayException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having((e) => e.message, 'message', contains('Network error')),
        ),
      );
    });

    test('streamComplete yields text from successful completion', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'text': 'Streamed chunk response'}),
          200,
        );
      });

      final provider = CloudAIProvider(
        gatewayBaseUrl: Uri.parse('https://ai.autoplanner.app'),
        httpClient: mockClient,
      );

      final chunks = await provider.streamComplete('Test').toList();
      expect(chunks, equals(['Streamed chunk response']));
    });
  });
}
