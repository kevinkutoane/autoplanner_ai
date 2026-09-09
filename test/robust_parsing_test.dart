import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/services/ai_service.dart';
import 'package:autoplanner_ai/services/app_monitor_service.dart';
import 'package:autoplanner_ai/core/ai/ai_provider.dart';
import 'package:autoplanner_ai/core/ai/token_tracker.dart';

class FakeAIProvider extends AIProvider {
  String responseText = '';
  @override
  Future<AIResponse> complete(String prompt) async => AIResponse(
    text: responseText,
    promptTokens: 0,
    completionTokens: 0,
    model: 'fake',
  );
  @override
  Stream<String> streamComplete(String prompt) async* {
    yield responseText;
  }

  @override
  String get modelName => 'fake';
}

class FakeTokenTracker extends TokenTracker {
  @override
  Future<void> log({
    required String action,
    required AIResponse response,
    bool success = true,
  }) async {}
  @override
  void guardRateLimit() {}
}

class FakeAppMonitorService extends AppMonitorService {
  String? lastAction;
  String? lastMessage;
  String? lastDetail;
  int logCount = 0;

  @override
  Future<void> logAIError({
    required String action,
    required String message,
    String? detail,
  }) async {
    lastAction = action;
    lastMessage = message;
    lastDetail = detail;
    logCount++;
  }
}

void main() {
  late FakeAIProvider fakeProvider;
  late FakeTokenTracker fakeTracker;
  late FakeAppMonitorService fakeMonitor;
  late AIService aiService;

  setUp(() {
    fakeProvider = FakeAIProvider();
    fakeTracker = FakeTokenTracker();
    fakeMonitor = FakeAppMonitorService();
    aiService = AIService(
      provider: fakeProvider,
      tracker: fakeTracker,
      monitor: fakeMonitor,
    );
  });

  group('AIService Robustness (Manual Mocks)', () {
    test('logs AI error when output is not a JSON array', () async {
      fakeProvider.responseText = 'Not JSON';
      await aiService.parseTasks('input');

      expect(fakeMonitor.logCount, 1);
      expect(fakeMonitor.lastAction, 'parseTasks');
      expect(fakeMonitor.lastMessage, contains('No JSON array found'));
    });

    test('logs AI error when JSON decoding fails', () async {
      fakeProvider.responseText =
          '[{"title": "incomplete"}]'; // Valid wrap, but I want invalid JSON
      // Actually, to trigger JSON decoding failure, _extractJsonArray must succeed but jsonDecode fail.
      // _extractJsonArray returns everything between the first [ and last ].
      fakeProvider.responseText =
          'Some text [{"title": "bad" } broken ] more text';
      await aiService.parseTasks('input');

      expect(fakeMonitor.logCount, 1);
      expect(fakeMonitor.lastMessage, contains('JSON decoding failed'));
    });

    test(
      'skips malformed items (invalid types) within a valid JSON array',
      () async {
        // In _parseTasksFromJson, timeParts splitting an int would throw.
        fakeProvider.responseText = '[{"title": "good", "startTime": "09:00"}, {"title": "bad", "startTime": 123}]';
        final tasks = await aiService.parseTasks('input');

        expect(tasks.length, 1);
        expect(tasks.first.title, 'good');
      },
    );
  });
}
