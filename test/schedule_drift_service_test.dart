import 'package:flutter_test/flutter_test.dart';
import 'package:clock/clock.dart';

import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/services/schedule_drift_service.dart';

void main() {
  group('ScheduleDriftService — Self-Healing Schedule Drift', () {
    late ScheduleDriftService driftService;
    final fixedNow = DateTime(2026, 10, 2, 10, 30); // 10:30 AM

    setUp(() {
      driftService = ScheduleDriftService();
    });

    test('detects zero drift when tasks are in the future or completed', () {
      final tasks = [
        TaskItem(
          id: 't-1',
          title: 'Morning Sync',
          startTime: DateTime(2026, 10, 2, 9, 0),
          endTime: DateTime(2026, 10, 2, 9, 30),
          isCompleted: true,
        ),
        TaskItem(
          id: 't-2',
          title: 'Deep Work',
          startTime: DateTime(2026, 10, 2, 11, 0),
          endTime: DateTime(2026, 10, 2, 12, 0),
          isCompleted: false,
        ),
      ];

      final drift = driftService.detectDrift(
        tasks: tasks,
        currentTime: fixedNow,
        graceMinutes: 10,
      );

      expect(drift.hasDrift, isFalse);
      expect(drift.driftMinutes, equals(0));
      expect(drift.overdueTasks, isEmpty);
    });

    test('detects negative drift when uncompleted task is past its grace period', () {
      final tasks = [
        TaskItem(
          id: 't-1',
          title: 'Architecture Review',
          startTime: DateTime(2026, 10, 2, 10, 0), // Planned at 10:00, now is 10:30 (30m late)
          endTime: DateTime(2026, 10, 2, 10, 45),
          isCompleted: false,
        ),
        TaskItem(
          id: 't-2',
          title: 'Sprint Planning',
          startTime: DateTime(2026, 10, 2, 11, 0),
          endTime: DateTime(2026, 10, 2, 12, 0),
          isCompleted: false,
        ),
      ];

      final drift = driftService.detectDrift(
        tasks: tasks,
        currentTime: fixedNow,
        graceMinutes: 10,
      );

      expect(drift.hasDrift, isTrue);
      expect(drift.driftMinutes, equals(30));
      expect(drift.overdueTasks.length, equals(1));
      expect(drift.overdueTasks.first.id, equals('t-1'));
      expect(drift.impactedTasks.length, equals(1));
      expect(drift.impactedTasks.first.id, equals('t-2'));
      expect(drift.summary, contains('30 min behind'));
    });

    test('ignores fixed anchor tasks during overdue calculation', () {
      final tasks = [
        TaskItem(
          id: 't-anchor',
          title: 'Fixed All-Hands Meeting',
          startTime: DateTime(2026, 10, 2, 9, 30),
          endTime: DateTime(2026, 10, 2, 10, 30),
          isFixed: true, // Anchor task
          isCompleted: false,
        ),
      ];

      final drift = driftService.detectDrift(
        tasks: tasks,
        currentTime: fixedNow,
        graceMinutes: 10,
      );

      expect(drift.hasDrift, isFalse);
      expect(drift.overdueTasks, isEmpty);
    });

    test('rippleReschedule heals overdue tasks forward past current time', () {
      withClock(Clock.fixed(fixedNow), () {
        final tasks = [
          TaskItem(
            id: 't-1',
            title: 'Draft RFC',
            startTime: DateTime(2026, 10, 2, 9, 30), // Planned at 9:30 AM
            endTime: DateTime(2026, 10, 2, 10, 15),
            isCompleted: false,
          ),
          TaskItem(
            id: 't-2',
            title: 'Code Review',
            startTime: DateTime(2026, 10, 2, 10, 30),
            endTime: DateTime(2026, 10, 2, 11, 15),
            isCompleted: false,
          ),
        ];

        final result = driftService.rippleReschedule(
          allTasks: tasks,
          workStartHour: 9,
          workHoursPerDay: 8,
          currentTime: fixedNow,
        );

        expect(result.shiftedCount, greaterThanOrEqualTo(1));
        final healedT1 = result.healedTasks.firstWhere((t) => t.id == 't-1');
        // Must be scheduled at or after current clock time (10:30 AM)
        expect(healedT1.startTime.isBefore(fixedNow), isFalse);
        expect(result.resolvedDriftMinutes, equals(60));
        expect(result.rationale, contains('Self-healing ripple repositioned'));
      });
    });

    test('rippleReschedule preserves immovable calendar blocks during ripple', () {
      withClock(Clock.fixed(fixedNow), () {
        final tasks = [
          TaskItem(
            id: 't-1',
            title: 'Urgent Bugfix',
            startTime: DateTime(2026, 10, 2, 9, 0),
            endTime: DateTime(2026, 10, 2, 9, 45),
            isCompleted: false,
          ),
        ];

        final externalMeeting = CalendarEvent(
          id: 'cal-1',
          title: 'Executive Review',
          startTime: DateTime(2026, 10, 2, 10, 30),
          endTime: DateTime(2026, 10, 2, 11, 30),
        );

        final result = driftService.rippleReschedule(
          allTasks: tasks,
          workStartHour: 9,
          workHoursPerDay: 8,
          currentTime: fixedNow,
          calendarBlocks: [externalMeeting],
        );

        final healed = result.healedTasks.firstWhere((t) => t.id == 't-1');
        // Task must not overlap the 10:30–11:30 executive meeting
        expect(healed.startTime.isBefore(externalMeeting.endTime), isFalse);
      });
    });
  });
}
