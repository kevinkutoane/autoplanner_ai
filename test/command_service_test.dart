import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/ai/mock_ai_provider.dart';
import 'package:autoplanner_ai/core/ai/token_tracker.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/features/commands/models/schedule_command.dart';
import 'package:autoplanner_ai/features/commands/services/command_executor_service.dart';
import 'package:autoplanner_ai/services/ai_service.dart';

void main() {
  late AIService aiService;
  late CommandExecutorService executorService;
  final referenceTime = DateTime(2026, 3, 12, 11, 0);

  setUp(() {
    aiService = AIService(
      provider: MockAIProvider(),
      tracker: TokenTracker(),
    );
    executorService = CommandExecutorService();
  });

  group('AIService - Schedule Command Parsing', () {
    test('parses "push afternoon by 30 mins" via instant heuristic', () async {
      final command = await aiService.parseScheduleCommand(
        query: 'push afternoon by 30 mins',
        currentTasks: [],
        referenceTime: referenceTime,
      );

      expect(command.type, equals(ScheduleCommandType.shift));
      expect(command.minutes, equals(30));
      expect(command.afterTime?.hour, equals(12));
    });

    test('parses "delay tasks by 45m" via instant heuristic', () async {
      final command = await aiService.parseScheduleCommand(
        query: 'delay tasks by 45m',
        currentTasks: [],
        referenceTime: referenceTime,
      );

      expect(command.type, equals(ScheduleCommandType.shift));
      expect(command.minutes, equals(45));
      expect(command.afterTime, equals(referenceTime));
    });

    test('parses "what can i do in 20 mins" via instant heuristic', () async {
      final command = await aiService.parseScheduleCommand(
        query: 'what can i do in 20 mins',
        currentTasks: [],
        referenceTime: referenceTime,
      );

      expect(command.type, equals(ScheduleCommandType.findFit));
      expect(command.minutes, equals(20));
    });

    test('parses "focus on Architecture Review" via instant heuristic', () async {
      final command = await aiService.parseScheduleCommand(
        query: 'focus on Architecture Review',
        currentTasks: [],
        referenceTime: referenceTime,
      );

      expect(command.type, equals(ScheduleCommandType.startFocus));
      expect(command.taskTitle, equals('Architecture Review'));
    });

    test('parses "clear afternoon" via instant heuristic', () async {
      final command = await aiService.parseScheduleCommand(
        query: 'clear afternoon',
        currentTasks: [],
        referenceTime: referenceTime,
      );

      expect(command.type, equals(ScheduleCommandType.clearWindow));
      expect(command.fromTime?.hour, equals(12));
      expect(command.toTime?.hour, equals(17));
    });

    test('parses "clear 2pm to 4pm" via instant heuristic', () async {
      final command = await aiService.parseScheduleCommand(
        query: 'clear 2pm to 4pm',
        currentTasks: [],
        referenceTime: referenceTime,
      );

      expect(command.type, equals(ScheduleCommandType.clearWindow));
      expect(command.fromTime?.hour, equals(14));
      expect(command.toTime?.hour, equals(16));
    });

    test('parses "add Team Sync at 3pm" via instant heuristic', () async {
      final command = await aiService.parseScheduleCommand(
        query: 'add Team Sync at 3pm',
        currentTasks: [],
        referenceTime: referenceTime,
      );

      expect(command.type, equals(ScheduleCommandType.quickAdd));
      expect(command.taskTitle, equals('Team Sync'));
      expect(command.fromTime?.hour, equals(15));
    });
  });

  group('CommandExecutorService - Preview Generation', () {
    test('generatePreview for shift calculates accurate new task times', () {
      final t1 = TaskItem(
        id: 't1',
        title: 'Morning Standup',
        startTime: DateTime(2026, 3, 12, 9, 30),
        endTime: DateTime(2026, 3, 12, 10, 0),
        isCompleted: false,
      );
      final t2 = TaskItem(
        id: 't2',
        title: 'Afternoon Deep Work',
        startTime: DateTime(2026, 3, 12, 13, 0),
        endTime: DateTime(2026, 3, 12, 14, 30),
        isCompleted: false,
      );
      final t3 = TaskItem(
        id: 't3',
        title: 'Evening Sync',
        startTime: DateTime(2026, 3, 12, 16, 0),
        endTime: DateTime(2026, 3, 12, 16, 30),
        isCompleted: false,
      );

      final command = ScheduleCommand(
        type: ScheduleCommandType.shift,
        minutes: 30,
        afterTime: DateTime(2026, 3, 12, 12, 0),
        targetDate: referenceTime,
        explanation: 'Shift afternoon tasks by 30 mins',
      );

      final preview = executorService.generatePreview(
        command,
        [t1, t2, t3],
        now: referenceTime,
      );

      // t1 is morning, so only t2 and t3 should be shifted
      expect(preview.shifts.length, equals(2));
      expect(preview.shifts[0].task.id, equals('t2'));
      expect(preview.shifts[0].newStart, equals(DateTime(2026, 3, 12, 13, 30)));
      expect(preview.shifts[0].newEnd, equals(DateTime(2026, 3, 12, 15, 0)));

      expect(preview.shifts[1].task.id, equals('t3'));
      expect(preview.shifts[1].newStart, equals(DateTime(2026, 3, 12, 16, 30)));
      expect(preview.shifts[1].newEnd, equals(DateTime(2026, 3, 12, 17, 0)));
    });

    test('generatePreview for clearWindow moves overlapping tasks out of window', () {
      final conflict = TaskItem(
        id: 'c1',
        title: 'Client Call',
        startTime: DateTime(2026, 3, 12, 14, 0),
        endTime: DateTime(2026, 3, 12, 15, 0),
        isCompleted: false,
      );
      final outside = TaskItem(
        id: 'o1',
        title: 'Morning Yoga',
        startTime: DateTime(2026, 3, 12, 7, 0),
        endTime: DateTime(2026, 3, 12, 8, 0),
        isCompleted: false,
      );

      final command = ScheduleCommand(
        type: ScheduleCommandType.clearWindow,
        fromTime: DateTime(2026, 3, 12, 13, 30),
        toTime: DateTime(2026, 3, 12, 15, 30),
        targetDate: referenceTime,
        explanation: 'Clear 1:30 PM to 3:30 PM',
      );

      final preview = executorService.generatePreview(
        command,
        [conflict, outside],
        now: referenceTime,
      );

      expect(preview.shifts.length, equals(1));
      expect(preview.shifts[0].task.id, equals('c1'));
      // Moved to start at or after window end (15:30)
      expect(preview.shifts[0].newStart, equals(DateTime(2026, 3, 12, 15, 30)));
      expect(preview.shifts[0].newEnd, equals(DateTime(2026, 3, 12, 16, 30)));
    });

    test('generatePreview for findFit returns tasks matching duration limit sorted by priority', () {
      final tShortLow = TaskItem(
        id: '1',
        title: 'Quick inbox check',
        startTime: referenceTime,
        endTime: referenceTime.add(const Duration(minutes: 15)),
        priority: 0,
        isCompleted: false,
      );
      final tShortHigh = TaskItem(
        id: '2',
        title: 'Approve urgent invoice',
        startTime: referenceTime,
        endTime: referenceTime.add(const Duration(minutes: 15)),
        priority: 3,
        isCompleted: false,
      );
      final tLong = TaskItem(
        id: '3',
        title: 'Write technical spec',
        startTime: referenceTime,
        endTime: referenceTime.add(const Duration(minutes: 90)),
        priority: 2,
        isCompleted: false,
      );

      final command = const ScheduleCommand(
        type: ScheduleCommandType.findFit,
        minutes: 20,
        explanation: 'Find tasks under 20m',
      );

      final preview = executorService.generatePreview(
        command,
        [tShortLow, tShortHigh, tLong],
        now: referenceTime,
      );

      expect(preview.fittingTasks.length, equals(2));
      // Urgent priority first
      expect(preview.fittingTasks[0].id, equals('2'));
      expect(preview.fittingTasks[1].id, equals('1'));
    });
  });
}
