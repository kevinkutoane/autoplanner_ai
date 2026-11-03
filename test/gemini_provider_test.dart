import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:autoplanner_ai/core/ai/ai_provider.dart';
import 'package:autoplanner_ai/core/ai/gemini_provider.dart';

http.Response _apiError(int code, String status, String message) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'status': status, 'message': message},
      }),
      code,
      headers: {'content-type': 'application/json'},
    );

GeminiProvider _provider(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 30),
}) => GeminiProvider(
  apiKey: 'test-key',
  requestTimeout: timeout,
  httpClient: MockClient(handler),
);

void main() {
  group('GeminiProvider error handling', () {
    test('stalled request times out as a retryable transient error', () async {
      final provider = _provider(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        provider.complete('Ping'),
        throwsA(isA<AITransientException>()),
      );
    });

    test('unknown model fails fast as a configuration error', () async {
      final provider = _provider(
        (_) async => _apiError(
          404,
          'NOT_FOUND',
          'models/gemini-x is not found for API version v1beta.',
        ),
      );

      await expectLater(
        provider.complete('Ping'),
        throwsA(isA<AIConfigurationException>()),
      );
    });

    test(
      'quota exhaustion maps to a rate limit error with retry hint',
      () async {
        final provider = _provider(
          (_) async => _apiError(
            429,
            'RESOURCE_EXHAUSTED',
            'You exceeded your current quota. Please retry in 5h3m54.6s.',
          ),
        );

        await expectLater(
          provider.complete('Ping'),
          throwsA(
            isA<AIRateLimitException>().having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(hours: 5, minutes: 3, milliseconds: 54600),
            ),
          ),
        );
      },
    );

    test('overloaded primary model falls back to the second model', () async {
      final requested = <String>[];
      final provider = _provider((req) async {
        requested.add(req.url.path);
        if (req.url.path.contains('/${GeminiProvider.defaultModel}:')) {
          return _apiError(
            503,
            'UNAVAILABLE',
            'This model is currently experiencing high demand.',
          );
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'pong'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final res = await provider.complete('Ping');

      expect(res.text, 'pong');
      expect(res.model, GeminiProvider.defaultFallbackModel);
      expect(requested, hasLength(2));
    });

    test('overload without a fallback surfaces a transient 503', () async {
      final provider = GeminiProvider(
        apiKey: 'test-key',
        fallbackModelName: '',
        httpClient: MockClient(
          (_) async => _apiError(503, 'UNAVAILABLE', 'High demand.'),
        ),
      );

      await expectLater(
        provider.complete('Ping'),
        throwsA(
          isA<AITransientException>().having(
            (e) => e.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });

    test('configuration errors do not trigger the fallback', () async {
      var calls = 0;
      final provider = _provider((_) async {
        calls++;
        return _apiError(404, 'NOT_FOUND', 'models/x is not found.');
      });

      await expectLater(
        provider.complete('Ping'),
        throwsA(isA<AIConfigurationException>()),
      );
      expect(calls, 1);
    });

    test('defaults to Flash-Lite with Flash fallback and 30s timeout', () {
      final provider = GeminiProvider(apiKey: 'test-key');
      expect(provider.modelName, 'gemini-3.5-flash-lite');
      expect(provider.fallbackModelName, 'gemini-3.8-flash');
      expect(provider.requestTimeout, const Duration(seconds: 30));
    });
  });
}
