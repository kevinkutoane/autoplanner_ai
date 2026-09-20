import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/ai/ai_guard.dart';
import 'package:autoplanner_ai/core/ai/ai_invocation.dart';
import 'package:autoplanner_ai/core/ai/ai_provider.dart';
import 'package:autoplanner_ai/core/ai/token_tracker.dart';
import 'package:autoplanner_ai/core/models/memory_entry_model.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/services/ai_service.dart';

class RecordingAIProvider implements AIProvider {
  AIInvocation? lastInvocation;
  String? lastPrompt;
  String responseText = '';

  @override
  String get modelName => 'recording-mock';

  @override
  Future<AIResponse> complete(String prompt, {AIInvocation? invocation}) async {
    lastPrompt = prompt;
    lastInvocation = invocation;
    return AIResponse(
      text: responseText,
      promptTokens: 10,
      completionTokens: 10,
      model: modelName,
    );
  }

  @override
  Stream<String> streamComplete(
    String prompt, {
    AIInvocation? invocation,
  }) async* {
    lastPrompt = prompt;
    lastInvocation = invocation;
    yield responseText;
  }

  @override
  void dispose() {}
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'ENABLE_TOKEN_TRACKING=false');
    appConfig = EnvConfig.fromDotEnv();
  });

  group('AIService AIInvocation routing', () {
    late RecordingAIProvider provider;
    late TokenTracker tracker;
    late AIService aiService;

    setUp(() {
      AIGuard.instance.resetFrequencyWindow();
      provider = RecordingAIProvider();
      tracker = TokenTracker();
      aiService = AIService(provider: provider, tracker: tracker);
    });

    test('parseTasks sets AIOperation.parseTasks', () async {
      provider.responseText = '[{"title":"Buy milk","startTime":"10:00","estimatedMinutes":30,"priority":1,"tags":["errands"]}]';
      await aiService.parseTasks('Buy milk at 10am');

      expect(provider.lastInvocation, isNotNull);
      expect(
        provider.lastInvocation!.operation,
        equals(AIOperation.parseTasks),
      );
      expect(
        provider.lastInvocation!.input['text'],
        equals('Buy milk at 10am'),
      );
    });

    test('chatWithCoach sets AIOperation.chatCoach', () async {
      provider.responseText = 'Keep pushing forward!';
      await aiService.chatWithCoach('How do I stop procrastinating?', []);

      expect(provider.lastInvocation, isNotNull);
      expect(provider.lastInvocation!.operation, equals(AIOperation.chatCoach));
      expect(
        provider.lastInvocation!.input['message'],
        contains('procrastinating'),
      );
    });

    test('planDay sets AIOperation.planDay', () async {
      provider.responseText = '[{"id":"t-1","title":"Task 1","estimatedMinutes":45,"priority":2,"tags":["work"]}]';
      final task = TaskItem(
        id: 't-1',
        title: 'Task 1',
        startTime: DateTime.now(),
        priority: 1,
      );

      await aiService.planDay(
        existingTasks: [task],
        memories: [],
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      expect(provider.lastInvocation, isNotNull);
      expect(provider.lastInvocation!.operation, equals(AIOperation.planDay));
      expect(provider.lastInvocation!.context['workStartHour'], equals(9));
      expect(provider.lastInvocation!.context['workHoursPerDay'], equals(8));
    });

    test('suggestReschedule sets AIOperation.suggestReschedule', () async {
      provider.responseText = '1';
      final task = TaskItem(
        id: 't-resched',
        title: 'Overdue Task',
        startTime: DateTime.now(),
        priority: 2,
      );
      final slot = DateTime.now().add(const Duration(hours: 2));

      await aiService.suggestReschedule(task: task, slots: [slot]);

      expect(provider.lastInvocation, isNotNull);
      expect(
        provider.lastInvocation!.operation,
        equals(AIOperation.suggestReschedule),
      );
      expect(
        provider.lastInvocation!.input['taskTitle'],
        equals('Overdue Task'),
      );
      expect(provider.lastInvocation!.context['slots'], isNotEmpty);
    });

    test('summarizeNote sets AIOperation.summarizeNote', () async {
      provider.responseText = 'A concise note summary.';
      final noteContent =
          'This is a long note that exceeds fifty characters to ensure it passes the length check.';

      await aiService.summarizeNote(noteContent);

      expect(provider.lastInvocation, isNotNull);
      expect(
        provider.lastInvocation!.operation,
        equals(AIOperation.summarizeNote),
      );
      expect(provider.lastInvocation!.input['content'], equals(noteContent));
    });

    test('generateTags sets AIOperation.generateTags', () async {
      provider.responseText = '["planning", "mobile"]';
      await aiService.generateTags(
        'Designing the future of mobile scheduling apps',
      );

      expect(provider.lastInvocation, isNotNull);
      expect(
        provider.lastInvocation!.operation,
        equals(AIOperation.generateTags),
      );
    });

    test('generateDailyInsight sets AIOperation.dailyInsight', () async {
      provider.responseText =
          'Great momentum today! Focus on your deep work blocks.';
      await aiService.generateDailyInsight([], []);

      expect(provider.lastInvocation, isNotNull);
      expect(
        provider.lastInvocation!.operation,
        equals(AIOperation.dailyInsight),
      );
    });

    test('extractMemoryFromContext sets AIOperation.extractMemory', () async {
      provider.responseText =
          'User thrives when doing complex tasks before noon.';
      await aiService.extractMemoryFromContext(
        'Morning deep work session completed early',
        'task',
      );

      expect(provider.lastInvocation, isNotNull);
      expect(
        provider.lastInvocation!.operation,
        equals(AIOperation.extractMemory),
      );
      expect(provider.lastInvocation!.input['sourceType'], equals('task'));
    });

    test('brainDump sets AIOperation.brainDump', () async {
      provider.responseText =
          '{"tasks":[],"notes":[],"goals":[],"memories":[]}';
      await aiService.brainDump('Need to write quarterly reports');

      expect(provider.lastInvocation, isNotNull);
      expect(provider.lastInvocation!.operation, equals(AIOperation.brainDump));
      expect(
        provider.lastInvocation!.input['text'],
        equals('Need to write quarterly reports'),
      );
    });

    test('extractPatterns sets AIOperation.extractPatterns', () async {
      provider.responseText = '[{"pattern":"Completes tasks before noon","confidence":0.8,"category":"time"}]';
      final tasks = List.generate(
        4,
        (i) => TaskItem(
          id: 'task-$i',
          title: 'Task $i',
          startTime: DateTime(2026, 9, 19, 9, 0),
          isCompleted: true,
        ),
      );

      await aiService.extractPatterns(tasks);

      expect(provider.lastInvocation, isNotNull);
      expect(
        provider.lastInvocation!.operation,
        equals(AIOperation.extractPatterns),
      );
      expect(provider.lastInvocation!.context['completedCount'], equals(4));
    });

    test('suggestTasks sets AIOperation.suggestTasks', () async {
      provider.responseText = '["Workout 30 min", "Review budget"]';
      await aiService.suggestTasks(
        memories: [
          MemoryEntry(
            id: 'm1',
            content: 'User exercises daily',
            sourceType: 'user',
            createdAt: DateTime.now(),
          ),
        ],
        date: DateTime(2026, 9, 21),
      );

      expect(provider.lastInvocation, isNotNull);
      expect(
        provider.lastInvocation!.operation,
        equals(AIOperation.suggestTasks),
      );
      expect(provider.lastInvocation!.input['dayName'], equals('Monday'));
    });

    test('generateWeeklyReview sets AIOperation.weeklyReview', () async {
      provider.responseText =
          '## Highlights\nYou accomplished all top priorities.';
      await aiService.generateWeeklyReview(
        weekTasks: [],
        weekGoals: [],
        memories: [],
      );

      expect(provider.lastInvocation, isNotNull);
      expect(
        provider.lastInvocation!.operation,
        equals(AIOperation.weeklyReview),
      );
    });

    test(
      'parseScheduleCommand sets AIOperation.parseScheduleCommand',
      () async {
        provider.responseText = '{"action":"shift","minutes":45,"explanation":"Shifting afternoon schedule"}';
        await aiService.parseScheduleCommand(
          query: 'delay schedule by 45 minutes',
          currentTasks: [],
        );

        expect(provider.lastInvocation, isNotNull);
        expect(
          provider.lastInvocation!.operation,
          equals(AIOperation.parseScheduleCommand),
        );
        expect(
          provider.lastInvocation!.input['query'],
          contains('delay schedule'),
        );
      },
    );
  });
}
