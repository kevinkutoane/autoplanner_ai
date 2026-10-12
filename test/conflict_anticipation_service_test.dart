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
      final overlap = conflicts.firstWhere(
        (c) => c.type == ConflictType.directOverlap,
      );
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

      final overlap = conflicts.firstWhere(
        (c) => c.type == ConflictType.directOverlap,
      );
      expect(overlap.severity, ConflictSeverity.critical);
      expect(overlap.affectedTaskIds, contains('task_c'));
      expect(overlap.affectedEventIds, contains('evt_1'));
    });

    test(
      'detects transit buffer compression between consecutive external events',
      () {
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

        final transit = conflicts.firstWhere(
          (c) => c.type == ConflictType.transitBufferCompression,
        );
        expect(transit.severity, ConflictSeverity.warning);
        expect(transit.description, contains('5 min gap'));
        expect(transit.resolutionAction.actionType, 'insert_buffer');
      },
    );

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

      final breach = conflicts.firstWhere(
        (c) => c.id == 'deadline_breach_task_deadline_breach',
      );
      expect(breach.severity, ConflictSeverity.critical);
      expect(breach.title, contains('Deadline Breach'));

      final tight = conflicts.firstWhere(
        (c) => c.id == 'deadline_tight_task_deadline_tight',
      );
      expect(tight.severity, ConflictSeverity.warning);
      expect(tight.title, contains('Tight Deadline Margin'));
    });

    test(
      'detects circadian focus mismatch when deep work placed in recovery dip',
      () {
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

        final mismatch = conflicts.firstWhere(
          (c) => c.type == ConflictType.circadianMismatch,
        );
        expect(mismatch.severity, ConflictSeverity.advisory);
        expect(mismatch.description, contains('Lion'));
        expect(
          mismatch.resolutionAction.label,
          contains('Align to Focus Zenith'),
        );
      },
    );
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
      final noOverlap =
          !a.startTime.isBefore(b.endTime!) ||
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

    test(
      'auto_ripple shifts task cleanly around an external calendar event',
      () {
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
        final updatedX = result.updatedTasks.firstWhere(
          (t) => t.id == 'task_x',
        );
        expect(updatedX.startTime.isBefore(meeting.endTime), isFalse);
      },
    );

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

    test('auto_ripple preserves earlier tasks while moving selected task and cascading downstream', () {
      final earlierTask = TaskItem(
        id: 'task_earlier',
        title: 'Morning Routine',
        startTime: DateTime(2099, 6, 15, 8, 30),
        endTime: DateTime(2099, 6, 15, 9, 30),
      );
      final taskA = TaskItem(
        id: 'task_a',
        title: 'Team Sync',
        startTime: DateTime(2099, 6, 15, 10, 0),
        endTime: DateTime(2099, 6, 15, 11, 0),
      );
      final taskB = TaskItem(
        id: 'task_b',
        title: 'Interview',
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
        tasks: [earlierTask, taskA, taskB, taskC],
        workStartHour: 8,
        workHoursPerDay: 9,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isTrue);

      // Earlier task must not be in updatedTasks and must remain completely untouched
      expect(result.updatedTasks.any((t) => t.id == 'task_earlier'), isFalse);
      expect(result.updatedTasks.any((t) => t.id == 'task_a'), isFalse);

      final updatedB = result.updatedTasks.firstWhere((t) => t.id == 'task_b');
      final updatedC = result.updatedTasks.firstWhere((t) => t.id == 'task_c');

      // Assert exact expected start and end times
      expect(updatedB.startTime, DateTime(2099, 6, 15, 11, 0));
      expect(updatedB.endTime, DateTime(2099, 6, 15, 12, 0));
      expect(updatedC.startTime, DateTime(2099, 6, 15, 12, 0));
      expect(updatedC.endTime, DateTime(2099, 6, 15, 13, 0));
    });

    test('auto_ripple treats fixed commitments as immovable obstacles', () {
      final taskA = TaskItem(
        id: 'task_a',
        title: 'Standup',
        startTime: DateTime(2099, 6, 15, 10, 0),
        endTime: DateTime(2099, 6, 15, 10, 30),
      );
      final taskB = TaskItem(
        id: 'task_b',
        title: 'Design Review',
        startTime: DateTime(2099, 6, 15, 10, 15),
        endTime: DateTime(2099, 6, 15, 11, 15),
      );
      final fixedTask = TaskItem(
        id: 'fixed_task',
        title: 'Client Contract Review (Fixed)',
        startTime: DateTime(2099, 6, 15, 10, 30),
        endTime: DateTime(2099, 6, 15, 11, 30),
        isFixed: true,
      );
      final downstream = TaskItem(
        id: 'downstream_task',
        title: 'Documentation',
        startTime: DateTime(2099, 6, 15, 11, 30),
        endTime: DateTime(2099, 6, 15, 12, 30),
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
        tasks: [taskA, taskB, fixedTask, downstream],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isTrue);
      // Fixed task must not be modified
      expect(result.updatedTasks.any((t) => t.id == 'fixed_task'), isFalse);

      final updatedB = result.updatedTasks.firstWhere((t) => t.id == 'task_b');
      final updatedDownstream = result.updatedTasks.firstWhere(
        (t) => t.id == 'downstream_task',
      );

      // task_b jumps past the fixed commitment (ends at 11:30)
      expect(updatedB.startTime, DateTime(2099, 6, 15, 11, 30));
      expect(updatedB.endTime, DateTime(2099, 6, 15, 12, 30));
      // downstream cascades past task_b
      expect(updatedDownstream.startTime, DateTime(2099, 6, 15, 12, 30));
      expect(updatedDownstream.endTime, DateTime(2099, 6, 15, 13, 30));
    });

    test('auto_ripple returns explicit failure when remaining schedule capacity is insufficient', () {
      final taskA = TaskItem(
        id: 'task_late_a',
        title: 'Closing Sprint',
        startTime: DateTime(2099, 6, 15, 16, 0),
        endTime: DateTime(2099, 6, 15, 17, 0),
      );
      final taskB = TaskItem(
        id: 'task_late_b',
        title: 'Urgent Deploy',
        startTime: DateTime(2099, 6, 15, 16, 30),
        endTime: DateTime(2099, 6, 15, 17, 30),
      );

      final action = const ConflictResolutionAction(
        actionType: 'auto_ripple',
        label: 'Auto-Ripple',
        description: 'Ripple',
        params: {
          'taskId': 'task_late_b',
          'conflictTaskId': 'task_late_a',
          'conflictId': 'overlap_late',
        },
      );

      // Work window ends at 17:00 (9:00 + 8 hours = 17:00)
      final result = service.applyResolution(
        action,
        tasks: [taskA, taskB],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isFalse);
      expect(result.updatedTasks, isEmpty);
      expect(
        result.summary,
        contains('Insufficient remaining schedule capacity to ripple tasks.'),
      );
    });

    test('failed resolution leaves conflict available in evaluateSchedule', () {
      final taskA = TaskItem(
        id: 'task_end_a',
        title: 'Late Meeting',
        startTime: DateTime(2099, 6, 15, 16, 0),
        endTime: DateTime(2099, 6, 15, 17, 0),
      );
      final taskB = TaskItem(
        id: 'task_end_b',
        title: 'Late Sync',
        startTime: DateTime(2099, 6, 15, 16, 30),
        endTime: DateTime(2099, 6, 15, 17, 30),
      );

      final initialConflicts = service.evaluateSchedule(
        tasks: [taskA, taskB],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      expect(initialConflicts, isNotEmpty);
      final conflict = initialConflicts.firstWhere(
        (c) => c.type == ConflictType.directOverlap,
      );

      // Attempt resolution with tight capacity limit -> fails
      final result = service.applyResolution(
        conflict.resolutionAction,
        tasks: [taskA, taskB],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isFalse);

      // Since resolution failed, conflict must still be detected and available
      final postFailureConflicts = service.evaluateSchedule(
        tasks: [taskA, taskB],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      expect(postFailureConflicts.any((c) => c.id == conflict.id), isTrue);
    });

    test('successful resolution dismisses conflict from evaluateSchedule', () {
      final taskA = TaskItem(
        id: 'sync_a',
        title: 'Morning Sync',
        startTime: DateTime(2099, 6, 15, 10, 0),
        endTime: DateTime(2099, 6, 15, 11, 0),
      );
      final taskB = TaskItem(
        id: 'sync_b',
        title: 'Design Review',
        startTime: DateTime(2099, 6, 15, 10, 30),
        endTime: DateTime(2099, 6, 15, 11, 30),
      );

      final initialConflicts = service.evaluateSchedule(
        tasks: [taskA, taskB],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      final conflict = initialConflicts.firstWhere(
        (c) => c.type == ConflictType.directOverlap,
      );

      final result = service.applyResolution(
        conflict.resolutionAction,
        tasks: [taskA, taskB],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isTrue);

      // Conflict must be dismissed
      final postSuccessConflicts = service.evaluateSchedule(
        tasks: [taskA, taskB],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      expect(postSuccessConflicts.any((c) => c.id == conflict.id), isFalse);
    });

    test('insert_buffer before meeting reschedules task earlier and guarantees >= 15m buffer without colliding with meeting', () {
      final deepTask = TaskItem(
        id: 'task_deep',
        title: 'Deep Focus Work',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 14, 55),
        priority: 2,
      );
      final meeting = CalendarEvent(
        id: 'client_meeting',
        title: 'Client Stakeholder Review',
        startTime: DateTime(2099, 6, 15, 15, 0),
        endTime: DateTime(2099, 6, 15, 16, 0),
      );

      final conflicts = service.evaluateSchedule(
        tasks: [deepTask],
        calendarEvents: [meeting],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      final transitConflict = conflicts.firstWhere(
        (c) => c.type == ConflictType.transitBufferCompression,
      );
      expect(
        transitConflict.resolutionAction.label,
        'Re-Schedule Before Meeting',
      );

      final result = service.applyResolution(
        transitConflict.resolutionAction,
        tasks: [deepTask],
        calendarEvents: [meeting],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isTrue);
      expect(result.updatedTasks.length, 1);
      final updated = result.updatedTasks.first;

      // Must finish at least 15 min before the meeting (14:45 finish, 13:50 start)
      expect(updated.startTime, DateTime(2099, 6, 15, 13, 50));
      expect(updated.endTime, DateTime(2099, 6, 15, 14, 45));
      expect(
        meeting.startTime.difference(updated.endTime!).inMinutes,
        greaterThanOrEqualTo(15),
      );
      expect(updated.endTime!.isBefore(meeting.startTime), isTrue);

      // Re-evaluating schedule should confirm transit conflict is dismissed
      final postConflicts = service.evaluateSchedule(
        tasks: [updated],
        calendarEvents: [meeting],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      expect(postConflicts.any((c) => c.id == transitConflict.id), isFalse);
    });

    test('insert_buffer before meeting searches and finds alternative earlier slot when immediate slot is occupied, preserving minimum buffers', () {
      final fixedTask = TaskItem(
        id: 'fixed_prep',
        title: 'Executive Briefing',
        startTime: DateTime(2099, 6, 15, 13, 0),
        endTime: DateTime(2099, 6, 15, 14, 0),
        isFixed: true,
      );
      final deepTask = TaskItem(
        id: 'task_deep',
        title: 'Deep Architecture Plan',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 14, 55),
        priority: 2,
      );
      final meeting = CalendarEvent(
        id: 'board_meeting',
        title: 'Board Meeting',
        startTime: DateTime(2099, 6, 15, 15, 0),
        endTime: DateTime(2099, 6, 15, 16, 0),
      );

      final conflicts = service.evaluateSchedule(
        tasks: [fixedTask, deepTask],
        calendarEvents: [meeting],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      final transitConflict = conflicts.firstWhere(
        (c) => c.type == ConflictType.transitBufferCompression,
      );

      final result = service.applyResolution(
        transitConflict.resolutionAction,
        tasks: [fixedTask, deepTask],
        calendarEvents: [meeting],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      // Immediate slot 13:50-14:45 clashes with fixedTask (13:00-14:00).
      // Multi-slot search finds alternative slot 11:55-12:50 before fixedTask!
      expect(result.isSuccess, isTrue);
      expect(result.updatedTasks.length, 1);
      final updated = result.updatedTasks.first;

      expect(updated.startTime, DateTime(2099, 6, 15, 11, 55));
      expect(updated.endTime, DateTime(2099, 6, 15, 12, 50));

      // Preserves >= 10m buffer before fixedTask (12:50 to 13:00 = 10 min)
      expect(
        fixedTask.startTime.difference(updated.endTime!).inMinutes,
        greaterThanOrEqualTo(ConflictAnticipationService.minTaskBufferMinutes),
      );

      // Preserves >= 15m buffer before meeting
      expect(
        meeting.startTime.difference(updated.endTime!).inMinutes,
        greaterThanOrEqualTo(15),
      );

      // Fixed task remains unchanged
      expect(fixedTask.startTime, DateTime(2099, 6, 15, 13, 0));
      expect(fixedTask.endTime, DateTime(2099, 6, 15, 14, 0));
    });

    test('insert_buffer before meeting fails cleanly and preserves fixed commitments when all earlier slots are occupied', () {
      final morningBlock = TaskItem(
        id: 'morning_block',
        title: 'Morning Operations Block',
        startTime: DateTime(2099, 6, 15, 9, 0),
        endTime: DateTime(2099, 6, 15, 13, 0),
        isFixed: true,
      );
      final fixedTask = TaskItem(
        id: 'fixed_prep',
        title: 'Executive Briefing',
        startTime: DateTime(2099, 6, 15, 13, 0),
        endTime: DateTime(2099, 6, 15, 14, 0),
        isFixed: true,
      );
      final deepTask = TaskItem(
        id: 'task_deep',
        title: 'Deep Architecture Plan',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 14, 55),
        priority: 2,
      );
      final meeting = CalendarEvent(
        id: 'board_meeting',
        title: 'Board Meeting',
        startTime: DateTime(2099, 6, 15, 15, 0),
        endTime: DateTime(2099, 6, 15, 16, 0),
      );

      final conflicts = service.evaluateSchedule(
        tasks: [morningBlock, fixedTask, deepTask],
        calendarEvents: [meeting],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      final transitConflict = conflicts.firstWhere(
        (c) => c.type == ConflictType.transitBufferCompression,
      );

      final result = service.applyResolution(
        transitConflict.resolutionAction,
        tasks: [morningBlock, fixedTask, deepTask],
        calendarEvents: [meeting],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      // All feasible earlier slots (09:00-14:00) are occupied by fixed commitments
      expect(result.isSuccess, isFalse);
      expect(result.updatedTasks, isEmpty);
      expect(result.summary, contains('Insufficient time'));

      // Commitments remain completely unchanged
      expect(morningBlock.startTime, DateTime(2099, 6, 15, 9, 0));
      expect(fixedTask.startTime, DateTime(2099, 6, 15, 13, 0));
      expect(deepTask.startTime, DateTime(2099, 6, 15, 14, 0));

      // Conflict is not dismissed and remains visible in evaluateSchedule
      final postConflicts = service.evaluateSchedule(
        tasks: [morningBlock, fixedTask, deepTask],
        calendarEvents: [meeting],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      expect(postConflicts.any((c) => c.id == transitConflict.id), isTrue);
    });

    test('insert_buffer before meeting fails cleanly and does not reschedule already-started task', () {
      final deepTask = TaskItem(
        id: 'task_started',
        title: 'Active Coding Session',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 14, 55),
        priority: 2,
      );
      final meeting = CalendarEvent(
        id: 'team_meeting',
        title: 'Team Sync',
        startTime: DateTime(2099, 6, 15, 15, 0),
        endTime: DateTime(2099, 6, 15, 16, 0),
      );

      final action = ConflictResolutionAction(
        actionType: 'insert_buffer',
        label: 'Re-Schedule Before Meeting',
        description: 'Allocate restorative break before meeting starts.',
        params: {
          'taskId': deepTask.id,
          'conflictEventId': meeting.id,
          'bufferMinutes': 15,
          'conflictId': 'transit_task_event_task_started_team_meeting',
        },
      );

      // Current time is 14:10 - task already started at 14:00!
      final result = service.applyResolution(
        action,
        tasks: [deepTask],
        calendarEvents: [meeting],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 14, 10),
      );

      expect(result.isSuccess, isFalse);
      expect(result.summary, contains('already started'));
      expect(result.updatedTasks, isEmpty);

      // Task remains untouched
      expect(deepTask.startTime, DateTime(2099, 6, 15, 14, 0));
      expect(deepTask.endTime, DateTime(2099, 6, 15, 14, 55));
    });

    test('insert_buffer before meeting fails cleanly when candidate slot would fall in the past relative to currentTime', () {
      final deepTask = TaskItem(
        id: 'task_upcoming',
        title: 'Quick Review',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 14, 50),
        priority: 2,
      );
      final meeting = CalendarEvent(
        id: 'board_sync',
        title: 'Board Sync',
        startTime: DateTime(2099, 6, 15, 15, 0),
        endTime: DateTime(2099, 6, 15, 16, 0),
      );

      final action = ConflictResolutionAction(
        actionType: 'insert_buffer',
        label: 'Re-Schedule Before Meeting',
        description: 'Allocate restorative break before meeting starts.',
        params: {
          'taskId': deepTask.id,
          'conflictEventId': meeting.id,
          'bufferMinutes': 15,
          'conflictId': 'transit_task_event_task_upcoming_board_sync',
        },
      );

      // Current time is 13:58 (task starts at 14:00, not started yet).
      // Candidate slot needed is 13:55-14:45.
      // But 13:55 is in the past (< 13:58)!
      // Earlier slots would also be in the past.
      final result = service.applyResolution(
        action,
        tasks: [deepTask],
        calendarEvents: [meeting],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 13, 58),
      );

      expect(result.isSuccess, isFalse);
      expect(result.updatedTasks, isEmpty);
      expect(result.summary, contains('Insufficient time'));
    });

    test('insert_buffer before meeting enforces minimum 10m buffer between adjacent tasks', () {
      final prevTask = TaskItem(
        id: 'task_prev',
        title: 'Morning Catchup',
        startTime: DateTime(2099, 6, 15, 13, 0),
        endTime: DateTime(2099, 6, 15, 13, 45), // Finishes at 13:45
      );
      final deepTask = TaskItem(
        id: 'task_deep',
        title: 'Focused Writing',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 14, 55), // 55m duration
        priority: 2,
      );
      final meeting = CalendarEvent(
        id: 'meeting',
        title: 'Client Demo',
        startTime: DateTime(2099, 6, 15, 15, 0),
        endTime: DateTime(2099, 6, 15, 16, 0),
      );

      final conflicts = service.evaluateSchedule(
        tasks: [prevTask, deepTask],
        calendarEvents: [meeting],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      final transitConflict = conflicts.firstWhere(
        (c) => c.type == ConflictType.transitBufferCompression,
      );

      final result = service.applyResolution(
        transitConflict.resolutionAction,
        tasks: [prevTask, deepTask],
        calendarEvents: [meeting],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      // Slot 13:50-14:45 leaves only a 5m gap with prevTask (13:45).
      // Since minimum task buffer is 10m, it must reject 13:50 and step earlier before prevTask!
      expect(result.isSuccess, isTrue);
      expect(result.updatedTasks.length, 1);
      final updated = result.updatedTasks.first;

      // Positioned before prevTask (13:00 - 10m = 12:50 end, 11:55 start)
      expect(updated.startTime, DateTime(2099, 6, 15, 11, 55));
      expect(updated.endTime, DateTime(2099, 6, 15, 12, 50));
      expect(
        prevTask.startTime.difference(updated.endTime!).inMinutes,
        greaterThanOrEqualTo(10),
      );
    });

    test('evaluateSchedule detects transit buffer compression for tasks with 10-14 min gap under 15m threshold', () {
      final deepTask = TaskItem(
        id: 'task_tight_buffer',
        title: 'Deep Engineering Audit',
        startTime: DateTime(2099, 6, 15, 14, 0),
        endTime: DateTime(2099, 6, 15, 14, 48), // 12 min gap to 15:00 meeting!
        priority: 2,
      );
      final meeting = CalendarEvent(
        id: 'investor_meeting',
        title: 'Investor Review',
        startTime: DateTime(2099, 6, 15, 15, 0),
        endTime: DateTime(2099, 6, 15, 16, 0),
      );

      // Gap is 12 minutes (previously missed by < 10m check, now caught by < 15m policy)
      final conflicts = service.evaluateSchedule(
        tasks: [deepTask],
        calendarEvents: [meeting],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      final transitConflict = conflicts.firstWhere(
        (c) => c.type == ConflictType.transitBufferCompression,
      );
      expect(transitConflict.description, contains('12 min before meeting'));
      expect(transitConflict.resolutionAction.actionType, 'insert_buffer');

      final result = service.applyResolution(
        transitConflict.resolutionAction,
        tasks: [deepTask],
        calendarEvents: [meeting],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isTrue);
      final updated = result.updatedTasks.first;

      // Finishes at 14:45, providing the required 15m buffer before 15:00 meeting
      expect(updated.endTime, DateTime(2099, 6, 15, 14, 45));
      expect(
        meeting.startTime.difference(updated.endTime!).inMinutes,
        greaterThanOrEqualTo(15),
      );
    });

    test('insert_buffer before meeting fails cleanly when shifting earlier breaches workStartHour', () {
      final morningTask = TaskItem(
        id: 'morning_task',
        title: 'Briefing Doc',
        startTime: DateTime(2099, 6, 15, 8, 45),
        endTime: DateTime(2099, 6, 15, 9, 5),
        priority: 2,
      );
      final meeting = CalendarEvent(
        id: 'early_meeting',
        title: 'Early Sync',
        startTime: DateTime(2099, 6, 15, 9, 10),
        endTime: DateTime(2099, 6, 15, 9, 45),
      );

      final conflicts = service.evaluateSchedule(
        tasks: [morningTask],
        calendarEvents: [meeting],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      final transitConflict = conflicts.firstWhere(
        (c) => c.type == ConflictType.transitBufferCompression,
      );

      // Shifting 20 min task before 09:10 with 15m buffer needs 08:35 start, before 09:00 workStartHour
      final result = service.applyResolution(
        transitConflict.resolutionAction,
        tasks: [morningTask],
        calendarEvents: [meeting],
        workStartHour: 9,
        workHoursPerDay: 8,
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );

      expect(result.isSuccess, isFalse);
      expect(result.updatedTasks, isEmpty);

      final postConflicts = service.evaluateSchedule(
        tasks: [morningTask],
        calendarEvents: [meeting],
        currentTime: DateTime(2099, 6, 15, 8, 0),
      );
      expect(postConflicts.any((c) => c.id == transitConflict.id), isTrue);
    });
  });
}
