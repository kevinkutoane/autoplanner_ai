import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_invocation.dart';
import 'ai_provider.dart';

/// Exception thrown when the AutoPlanner AI Gateway returns an error.
class CloudGatewayException implements Exception {
  final int statusCode;
  final String message;
  final String? responseBody;

  const CloudGatewayException({
    required this.statusCode,
    required this.message,
    this.responseBody,
  });

  @override
  String toString() {
    final bodyStr = responseBody != null ? ' ($responseBody)' : '';
    return 'CloudGatewayException ($statusCode): $message$bodyStr';
  }
}

/// Cloud-ready implementation of [AIProvider] designed to communicate
/// with the server-side AutoPlanner AI Gateway (Cloud Run + FastAPI).
///
/// Sends structured [AIInvocation] payloads containing operation semantics,
/// request IDs, and context, allowing the cloud boundary to own prompt
/// templates, model routing, safety policies, and rate limits.
class CloudAIProvider implements AIProvider {
  final Uri gatewayBaseUrl;
  final http.Client _httpClient;
  final Future<String?> Function()? authTokenProvider;
  final String clientVersion;

  @override
  final String modelName;

  CloudAIProvider({
    required this.gatewayBaseUrl,
    http.Client? httpClient,
    this.authTokenProvider,
    this.modelName = 'autoplanner-cloud-gateway',
    this.clientVersion = '2.3.1+1',
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<AIResponse> complete(String prompt, {AIInvocation? invocation}) async {
    final effectiveInvocation =
        invocation ??
        AIInvocation(
          id: '',
          operation: AIOperation.parseTasks,
          input: {'prompt': prompt},
        );

    final payload = effectiveInvocation.toJson();
    final inputMap = Map<String, dynamic>.from(effectiveInvocation.input);
    if (!inputMap.containsKey('prompt')) {
      inputMap['prompt'] = prompt;
    }
    payload['input'] = inputMap;

    // Attach client version metadata
    final clientMap = Map<String, dynamic>.from(effectiveInvocation.client);
    clientMap['appVersion'] = clientVersion;
    payload['client'] = clientMap;

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'X-Client-Version': clientVersion,
      'X-Request-ID': effectiveInvocation.id,
    };

    if (authTokenProvider != null) {
      final token = await authTokenProvider!();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final endpoint = gatewayBaseUrl.resolve('/v1/ai/complete');
    final stopwatch = Stopwatch()..start();

    http.Response response;
    try {
      response = await _httpClient
          .post(endpoint, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      stopwatch.stop();
      throw CloudGatewayException(
        statusCode: 0,
        message: 'Network error contacting AI Gateway: $e',
      );
    }

    stopwatch.stop();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final text =
            decoded['text'] as String? ??
            decoded['content'] as String? ??
            response.body;
        final promptTokens = (decoded['promptTokens'] as num?)?.toInt() ?? 0;
        final completionTokens =
            (decoded['completionTokens'] as num?)?.toInt() ?? 0;
        final gatewayModel = decoded['model'] as String? ?? modelName;

        return AIResponse(
          text: text,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          latencyMs: stopwatch.elapsedMilliseconds,
          model: gatewayModel,
        );
      } catch (_) {
        // Plain string fallback
        return AIResponse(
          text: response.body,
          latencyMs: stopwatch.elapsedMilliseconds,
          model: modelName,
        );
      }
    }

    throw CloudGatewayException(
      statusCode: response.statusCode,
      message: 'AI Gateway request failed with HTTP ${response.statusCode}',
      responseBody: response.body,
    );
  }

  @override
  Stream<String> streamComplete(
    String prompt, {
    AIInvocation? invocation,
  }) async* {
    final res = await complete(prompt, invocation: invocation);
    yield res.text;
  }

  @override
  void dispose() {
    _httpClient.close();
  }
}
