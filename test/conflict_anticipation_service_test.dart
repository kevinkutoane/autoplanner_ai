import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/services/conflict_anticipation_service.dart';

void main() {
  late ConflictAnticipationService service;

  setUp(() {
    service = ConflictAnticipationService();
  });

  group('ConflictAnticipationService Temporal Diagnostics', () {
    test('detects direct overlap between two tasks as critical', () {
      final taskA = TaskItem(
        id: 'task_a',
        title: 'Team Sync',
        startTime: DateTime(2099, 6, 15, 10, 0),
        endTime: DateTime(2099, 6, 15, 11, 0),
      );
      final taskB = TaskItem(
        id: 'task_b',
        title: 'Interview Candidate',
        startTime: DateTime(2099, 6, 15, 10, 30),
        endTime: DateTime(2099, 6, 15, 11, 30),
      );

      final conflicts = service.evaluateSchedule(
        tasks: [taskA, taskB],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(conflicts, isNotEmpty);
      final overlap = conflicts.firstWhere((c) => c.type == ConflictType.directOverlap);
      expect(overlap.severity, ConflictSeverity.critical);
      expect(overlap.affectedTaskIds, containsAll(['task_a', 'task_b']));
      expect(overlap.resolutionAction.actionType, 'auto_ripple');
    });

    test('detects overlap between task and external calendar event', () {
      final task = TaskItem(
        id: 'task_c',
        title: 'Code Review',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 15, 0),
      );
      final event = CalendarEvent(
        id: 'evt_1',
        title: 'All-Hands Meeting',
        startTime: DateTime(2099, 6, 15, 14, 30),
        endTime: DateTime(2099, 6, 15, 15, 30),
      );

      final conflicts = service.evaluateSchedule(
        tasks: [task],
        calendarEvents: [event],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      final overlap = conflicts.firstWhere((c) => c.type == ConflictType.directOverlap);
      expect(overlap.severity, ConflictSeverity.critical);
      expect(overlap.affectedTaskIds, contains('task_c'));
      expect(overlap.affectedEventIds, contains('evt_1'));
    });

    test('detects transit buffer compression between consecutive external events', () {
      final event1 = CalendarEvent(
        id: 'client_lunch',
        title: 'Client Lunch (Downtown)',
        startTime: DateTime(2099, 6, 15, 12, 0),
        endTime: DateTime(2099, 6, 15, 13, 0),
      );
      final event2 = CalendarEvent(
        id: 'site_visit',
        title: 'Site Visit (Uptown)',
        startTime: DateTime(2099, 6, 15, 13, 5), // Only 5 min gap!
        endTime: DateTime(2099, 6, 15, 14, 30),
      );

      final conflicts = service.evaluateSchedule(
        tasks: [],
        calendarEvents: [event1, event2],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      final transit = conflicts.firstWhere((c) => c.type == ConflictType.transitBufferCompression);
      expect(transit.severity, ConflictSeverity.warning);
      expect(transit.description, contains('5 min gap'));
      expect(transit.resolutionAction.actionType, 'insert_buffer');
    });

    test('detects deadline breach and deadline tight margin', () {
      final deadlineBreachedTask = TaskItem(
        id: 'task_deadline_breach',
        title: 'Urgent Filing',
        startTime: DateTime(2099, 6, 15, 16, 0),
        endTime: DateTime(2099, 6, 15, 17, 0),
        deadline: DateTime(2099, 6, 15, 16, 30), // finishes 30m past deadline
      );
      final deadlineTightTask = TaskItem(
        id: 'task_deadline_tight',
        title: 'Grant Proposal',
        startTime: DateTime(2099, 6, 15, 10, 0),
        endTime: DateTime(2099, 6, 15, 11, 45),
        deadline: DateTime(2099, 6, 15, 12, 0), // 15m margin (< 30m)
      );

      final conflicts = service.evaluateSchedule(
        tasks: [deadlineBreachedTask, deadlineTightTask],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      final breach = conflicts.firstWhere((c) => c.id == 'deadline_breach_task_deadline_breach');
      expect(breach.severity, ConflictSeverity.critical);
      expect(breach.title, contains('Deadline Breach'));

      final tight = conflicts.firstWhere((c) => c.id == 'deadline_tight_task_deadline_tight');
      expect(tight.severity, ConflictSeverity.warning);
      expect(tight.title, contains('Tight Deadline Margin'));
    });

    test('detects circadian focus mismatch when deep work placed in recovery dip', () {
      final deepWorkInDip = TaskItem(
        id: 'deep_slump',
        title: 'Complex Math Proof',
        startTime: DateTime(2099, 6, 15, 14, 0), // Early Bird post-lunch dip
        endTime: DateTime(2099, 6, 15, 15, 30),
        tags: ['coding', 'complex'],
      );

      final conflicts = service.evaluateSchedule(
        tasks: [deepWorkInDip],
        currentTime: DateTime(2099, 6, 15, 8, 0),
        chronotypeId: 'early_bird',
      );

      final mismatch = conflicts.firstWhere((c) => c.type == ConflictType.circadianMismatch);
      expect(mismatch.severity, ConflictSeverity.advisory);
      expect(mismatch.description, contains('Lion'));
      expect(mismatch.resolutionAction.label, contains('Align to Focus Zenith'));
    });
  });

  group('ConflictAnticipationService Automated Resolutions', () {
    test('applies insert_buffer resolution smoothly', () {
      final task1 = TaskItem(
        id: 't1',
        title: 'Meeting 1',
        startTime: DateTime(2099, 6, 15, 10, 0),
        endTime: DateTime(2099, 6, 15, 11, 0),
      );
      final task2 = TaskItem(
        id: 't2',
        title: 'Meeting 2',
        startTime: DateTime(2099, 6, 15, 11, 0),
        endTime: DateTime(2099, 6, 15, 12, 0),
      );

      final action = ConflictResolutionAction(
        actionType: 'insert_buffer',
        label: 'Insert 15m Buffer',
        description: 'Test buffer insertion',
        params: {'taskId': 't2', 'bufferMinutes': 15},
      );

      final result = service.applyResolution(
        action,
        tasks: [task1, task2],
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      expect(result.isSuccess, isTrue);
      final shifted = result.updatedTasks.firstWhere((t) => t.id == 't2');
      expect(shifted.startTime, DateTime(2099, 6, 15, 11, 15));
      expect(shifted.endTime, DateTime(2099, 6, 15, 12, 15));
    });

    test('applies auto_ripple resolution to a future overlap', () {
      final task1 = TaskItem(
        id: 't1',
        title: 'First Task',
        startTime: DateTime(2099, 6, 15, 9, 0),
        endTime: DateTime(2099, 6, 15, 10, 0),
      );
      final task2 = TaskItem(
        id: 't2',
        title: 'Overlapping Task',
        startTime: DateTime(2099, 6, 15, 9, 30),
        endTime: DateTime(2099, 6, 15, 10, 30),
      );

      final action = const ConflictResolutionAction(
        actionType: 'auto_ripple',
        label: 'Auto-Ripple',
        description: 'Ripple schedule',
      );

      final result = service.applyResolution(
        action,
        tasks: [task1, task2],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isTrue);
      expect(result.updatedTasks, isNotEmpty);
      expect(result.summary, contains('rippled'));

      final byId = {
        for (final t in [task1, task2]) t.id: t,
        for (final t in result.updatedTasks) t.id: t,
      };
      final a = byId['t1']!;
      final b = byId['t2']!;
      final noOverlap = !a.startTime.isBefore(b.endTime!) ||
          !b.startTime.isBefore(a.endTime!);
      expect(noOverlap, isTrue);
    });

    test('auto_ripple reports no change when nothing overlaps', () {
      final task1 = TaskItem(
        id: 't1',
        title: 'Only Task',
        startTime: DateTime(2099, 6, 15, 9, 0),
        endTime: DateTime(2099, 6, 15, 10, 0),
      );
      final result = service.applyResolution(
        const ConflictResolutionAction(
          actionType: 'auto_ripple',
          label: 'Auto-Ripple',
          description: 'Ripple schedule',
        ),
        tasks: [task1],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      expect(result.updatedTasks, isEmpty);
    });

    test('auto_ripple shifts target task past colliding task and cascades downstream tasks', () {
      final taskA = TaskItem(
        id: 'task_a',
        title: 'Team Sync',
        startTime: DateTime(2099, 6, 15, 10, 0),
        endTime: DateTime(2099, 6, 15, 11, 0),
      );
      final taskB = TaskItem(
        id: 'task_b',
        title: 'Design Review',
        startTime: DateTime(2099, 6, 15, 10, 30),
        endTime: DateTime(2099, 6, 15, 11, 30),
      );
      final taskC = TaskItem(
        id: 'task_c',
        title: 'Deep Focus Coding',
        startTime: DateTime(2099, 6, 15, 11, 15),
        endTime: DateTime(2099, 6, 15, 12, 15),
      );

      final action = const ConflictResolutionAction(
        actionType: 'auto_ripple',
        label: 'Auto-Ripple Downstream',
        description: 'Ripple',
        params: {
          'taskId': 'task_b',
          'conflictTaskId': 'task_a',
          'conflictId': 'overlap_task_task_a_task_b',
        },
      );

      final result = service.applyResolution(
        action,
        tasks: [taskA, taskB, taskC],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isTrue);
      final updatedB = result.updatedTasks.firstWhere((t) => t.id == 'task_b');
      final updatedC = result.updatedTasks.firstWhere((t) => t.id == 'task_c');

      // task_b moved after task_a ends (11:00)
      expect(updatedB.startTime.isBefore(taskA.endTime!), isFalse);
      // task_c moved after task_b ends
      expect(updatedC.startTime.isBefore(updatedB.endTime!), isFalse);
    });

    test('auto_ripple shifts task cleanly around an external calendar event', () {
      final task = TaskItem(
        id: 'task_x',
        title: 'Budget Analysis',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 15, 0),
      );
      final meeting = CalendarEvent(
        id: 'cal_meeting',
        title: 'Client Demo',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 15, 30),
      );

      final action = const ConflictResolutionAction(
        actionType: 'auto_ripple',
        label: 'Shift Around Meeting',
        description: 'Shift around meeting',
        params: {
          'taskId': 'task_x',
          'conflictEventId': 'cal_meeting',
          'conflictId': 'overlap_event_task_x_cal_meeting',
        },
      );

      final result = service.applyResolution(
        action,
        tasks: [task],
        calendarEvents: [meeting],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isTrue);
      final updatedX = result.updatedTasks.firstWhere((t) => t.id == 'task_x');
      expect(updatedX.startTime.isBefore(meeting.endTime), isFalse);
    });

    test('insert_buffer acknowledges and dismisses calendar-only buffer shortage from evaluateSchedule', () {
      final event1 = CalendarEvent(
        id: 'lunch',
        title: 'Lunch',
        startTime: DateTime(2099, 6, 15, 12, 0),
        endTime: DateTime(2099, 6, 15, 13, 0),
      );
      final event2 = CalendarEvent(
        id: 'meeting',
        title: 'Meeting',
        startTime: DateTime(2099, 6, 15, 13, 5),
        endTime: DateTime(2099, 6, 15, 14, 0),
      );

      final conflictsBefore = service.evaluateSchedule(
        tasks: [],
        calendarEvents: [event1, event2],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      expect(conflictsBefore.length, 1);
      final transitConflict = conflictsBefore.first;

      final result = service.applyResolution(
        transitConflict.resolutionAction,
        tasks: [],
        calendarEvents: [event1, event2],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isTrue);
      expect(result.summary, contains('acknowledged'));

      // Re-evaluating schedule should omit the dismissed conflict
      final conflictsAfter = service.evaluateSchedule(
        tasks: [],
        calendarEvents: [event1, event2],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      expect(conflictsAfter, isEmpty);
    });
  });
}
