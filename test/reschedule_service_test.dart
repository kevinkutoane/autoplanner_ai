import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/services/scheduler_service.dart';
import 'package:autoplanner_ai/services/reschedule_service.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

TaskItem _task({
  required String id,
  required DateTime start,
  int durationMinutes = 60,
  int priority = 1,
  bool completed = false,
}) => TaskItem(
  id: id,
  title: 'Task $id',
  startTime: start,
  endTime: start.add(Duration(minutes: durationMinutes)),
  priority: priority,
  isCompleted: completed,
);

CalendarEvent _calEvent({
  required String id,
  required DateTime start,
  int durationMinutes = 60,
}) => CalendarEvent(
  id: id,
  title: 'Cal $id',
  startTime: start,
  endTime: start.add(Duration(minutes: durationMinutes)),
);

// ── SchedulerService.freeSlots ──────────────────────────────────────────────

void main() {
  final scheduler = SchedulerService();

  // Fixed base: today at 09:00 — used as relative reference.
  // Use a past date so "is today" logic doesn't shift the cursor.
  final baseDay = DateTime(2025, 6, 2); // Monday
  final workStart = DateTime(2025, 6, 2, 9, 0);

  group('SchedulerService.freeSlots', () {
    test('returns [count] slots when day is completely empty', () {
      final slots = scheduler.freeSlots(
        day: baseDay,
        workStartHour: 9,
        workHoursPerDay: 8,
        slotDuration: const Duration(hours: 1),
        count: 4,
      );
      expect(slots.length, 4);
      // First slot starts at work start (no busy blocks).
      expect(slots.first, workStart);
    });

    test('skips task-occupied block', () {
      // Task occupies 09:00–10:00.
      final busy = _task(id: 'a', start: workStart, durationMinutes: 60);
      final slots = scheduler.freeSlots(
        day: baseDay,
        workStartHour: 9,
        workHoursPerDay: 8,
        slotDuration: const Duration(hours: 1),
        busyTasks: [busy],
        count: 2,
      );
      // First free slot should be at or after 10:00 + buffer.
      expect(slots.first.isAfter(workStart.add(const Duration(minutes: 59))),
          isTrue);
    });

    test('skips calendar-event-occupied block', () {
      // Calendar event 09:00–10:30.
      final block = _calEvent(id: 'c1', start: workStart, durationMinutes: 90);
      final slots = scheduler.freeSlots(
        day: baseDay,
        workStartHour: 9,
        workHoursPerDay: 8,
        slotDuration: const Duration(hours: 1),
        calendarBlocks: [block],
        count: 1,
      );
      expect(slots.first.isAfter(workStart.add(const Duration(minutes: 89))),
          isTrue);
    });

    test('returns fewer slots than count when day is nearly full', () {
      // Fill 09:00–16:00 with 7 × 1-h tasks (leaving only 1 h free).
      final busy = List.generate(7, (i) {
        final s = workStart.add(Duration(hours: i));
        return _task(id: 'f$i', start: s, durationMinutes: 60);
      });
      final slots = scheduler.freeSlots(
        day: baseDay,
        workStartHour: 9,
        workHoursPerDay: 8,
        slotDuration: const Duration(hours: 1),
        busyTasks: busy,
        count: 4,
      );
      expect(slots.length, lessThan(4));
    });

    test('slots do not overlap each other', () {
      final slots = scheduler.freeSlots(
        day: baseDay,
        workStartHour: 9,
        workHoursPerDay: 8,
        slotDuration: const Duration(hours: 1),
        count: 5,
      );
      for (var i = 0; i < slots.length - 1; i++) {
        // Each next slot must start at or after previous slot + 1h.
        expect(slots[i + 1].isAfter(slots[i]), isTrue);
      }
    });
  });

  // ── RescheduleSuggestion duration helper ───────────────────────────────────

  group('RescheduleSuggestion', () {
    test('proposedEndTime uses task original duration', () {
      final task = _task(id: 't', start: workStart, durationMinutes: 90);
      final proposed = workStart.add(const Duration(hours: 2));
      final s = RescheduleSuggestion(task: task, proposedTime: proposed);
      expect(s.proposedEndTime, proposed.add(const Duration(minutes: 90)));
    });

    test('proposedEndTime falls back to 1h when endTime is null', () {
      final task = TaskItem(
        id: 'x',
        title: 'No end',
        startTime: workStart,
      );
      final proposed = workStart.add(const Duration(hours: 3));
      final s = RescheduleSuggestion(task: task, proposedTime: proposed);
      expect(s.proposedEndTime, proposed.add(const Duration(hours: 1)));
    });
  });
}
