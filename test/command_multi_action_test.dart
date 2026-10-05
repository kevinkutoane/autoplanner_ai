import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/features/commands/models/schedule_command.dart';
import 'package:autoplanner_ai/features/commands/services/command_executor_service.dart';

void main() {
  late CommandExecutorService executor;
  final testDay = DateTime(2099, 7, 20);

  setUp(() {
    executor = CommandExecutorService();
  });

  group('ScheduleCommand.fromRawText Direct Parsing', () {
    test('parses /reschedule and /rebalance commands', () {
      final cmd = ScheduleCommand.fromRawText('/reschedule', referenceTime: testDay);
      expect(cmd.type, ScheduleCommandType.autoReschedule);
      expect(cmd.explanation, contains('Autonomous schedule drift healing'));

      final cmd2 = ScheduleCommand.fromRawText('rebalance', referenceTime: testDay);
      expect(cmd2.type, ScheduleCommandType.autoReschedule);
    });

    test('parses /resolve and fix conflicts commands', () {
      final cmd = ScheduleCommand.fromRawText('/resolve', referenceTime: testDay);
      expect(cmd.type, ScheduleCommandType.resolveConflicts);
      expect(cmd.explanation, contains('Proactively resolve'));
    });

    test('parses /protect morning and /protect afternoon commands', () {
      final morningCmd = ScheduleCommand.fromRawText('/protect morning', referenceTime: testDay);
      expect(morningCmd.type, ScheduleCommandType.protectFocus);
      expect(morningCmd.fromTime?.hour, 9);
      expect(morningCmd.toTime?.hour, 12);

      final afternoonCmd = ScheduleCommand.fromRawText('protect afternoon', referenceTime: testDay);
      expect(afternoonCmd.type, ScheduleCommandType.protectFocus);
      expect(afternoonCmd.fromTime?.hour, 13);
      expect(afternoonCmd.toTime?.hour, 17);
    });
  });

  group('CommandExecutorService Multi-Action Preview & Execution', () {
    test('protectFocus creates fixed focus block and moves conflicting tasks out', () {
      final command = ScheduleCommand(
        type: ScheduleCommandType.protectFocus,
        fromTime: DateTime(2099, 7, 20, 13, 0),
        toTime: DateTime(2099, 7, 20, 15, 0),
        targetDate: testDay,
        explanation: 'Protect 13:00 - 15:00',
      );

      final conflictingTask = TaskItem(
        id: 't_conflict',
        title: 'Review PRs',
        startTime: DateTime(2099, 7, 20, 13, 30),
        endTime: DateTime(2099, 7, 20, 14, 30),
      );

      final preview = executor.generatePreview(
        command,
        [conflictingTask],
        now: DateTime(2099, 7, 20, 8, 0),
      );

      expect(preview.newTask, isNotNull);
      expect(preview.newTask!.isFixed, isTrue);
      expect(preview.newTask!.title, contains('Focus Block'));
      expect(preview.newTask!.startTime, DateTime(2099, 7, 20, 13, 0));
      expect(preview.newTask!.endTime, DateTime(2099, 7, 20, 15, 0));

      expect(preview.shifts, hasLength(1));
      expect(preview.shifts.first.newStart, DateTime(2099, 7, 20, 15, 0));
      expect(preview.shifts.first.newEnd, DateTime(2099, 7, 20, 16, 0));
    });

    test('autoReschedule detects drift and previews non-destructive shifts', () {
      final fixedNow = DateTime(2099, 7, 20, 9, 45);
      withClock(Clock.fixed(fixedNow), () {
        final overdueTask = TaskItem(
          id: 'overdue_1',
          title: 'Overdue Strategy',
          startTime: DateTime(2099, 7, 20, 9, 0),
          endTime: DateTime(2099, 7, 20, 10, 0),
        );
        final downstreamTask = TaskItem(
          id: 'downstream_1',
          title: 'Next Item',
          startTime: DateTime(2099, 7, 20, 10, 10),
          endTime: DateTime(2099, 7, 20, 11, 10),
        );

        final command = ScheduleCommand(
          type: ScheduleCommandType.autoReschedule,
          targetDate: testDay,
          explanation: 'Heal drift',
        );

        final preview = executor.generatePreview(
          command,
          [overdueTask, downstreamTask],
          now: fixedNow,
        );

        expect(preview.summary, contains('drift'));
        expect(preview.shifts, isNotEmpty);
      });
    });

    test('resolveConflicts evaluates schedule and provides resolution preview', () {
      final taskA = TaskItem(
        id: 'ta',
        title: 'Collision A',
        startTime: DateTime(2099, 7, 20, 10, 0),
        endTime: DateTime(2099, 7, 20, 11, 0),
      );
      final taskB = TaskItem(
        id: 'tb',
        title: 'Collision B',
        startTime: DateTime(2099, 7, 20, 10, 0),
        endTime: DateTime(2099, 7, 20, 11, 0),
      );

      final command = ScheduleCommand(
        type: ScheduleCommandType.resolveConflicts,
        targetDate: testDay,
        explanation: 'Resolve conflicts',
      );

      final preview = executor.generatePreview(
        command,
        [taskA, taskB],
        now: DateTime(2099, 7, 20, 8, 0),
      );

      expect(preview.summary, contains('conflict'));
    });
  });
}
