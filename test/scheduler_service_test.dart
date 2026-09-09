import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/services/scheduler_service.dart';

void main() {
  late SchedulerService scheduler;

  // Use a future date to avoid "isToday" cursor adjustment.
  final day = DateTime(2099, 1, 15);

  TaskItem _task({
    required String id,
    String title = 'Task',
    int priority = 1,
    bool isCompleted = false,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return TaskItem(
      id: id,
      title: title,
      priority: priority,
      isCompleted: isCompleted,
      startTime: startTime ?? day,
      endTime: endTime,
    );
  }

  setUp(() {
    scheduler = SchedulerService();
  });

  group('SchedulerService.scheduleDay', () {
    test('returns empty list when no tasks provided', () {
      final result = scheduler.scheduleDay(
        tasks: [],
        day: day,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      expect(result, isEmpty);
    });

    test('schedules a single task at work start', () {
      final result = scheduler.scheduleDay(
        tasks: [_task(id: '1')],
        day: day,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      expect(result, hasLength(1));
      expect(result.first.startTime.hour, 9);
      expect(result.first.startTime.minute, 0);
      expect(result.first.endTime, isNotNull);
    });

    test('sorts by priority — urgent before low', () {
      final tasks = [
        _task(id: 'low', priority: 0),
        _task(id: 'urgent', priority: 3),
        _task(id: 'medium', priority: 1),
      ];
      final result = scheduler.scheduleDay(
        tasks: tasks,
        day: day,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      // Urgent should be scheduled earliest.
      final urgentTask = result.firstWhere((t) => t.id == 'urgent');
      final lowTask = result.firstWhere((t) => t.id == 'low');
      expect(urgentTask.startTime.isBefore(lowTask.startTime), isTrue);
    });

    test('does not move completed tasks', () {
      final completedStart = DateTime(2099, 1, 15, 10, 0);
      final completedEnd = DateTime(2099, 1, 15, 11, 0);
      final tasks = [
        _task(
          id: 'done',
          isCompleted: true,
          startTime: completedStart,
          endTime: completedEnd,
        ),
        _task(id: 'pending', priority: 2),
      ];
      final result = scheduler.scheduleDay(
        tasks: tasks,
        day: day,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      final done = result.firstWhere((t) => t.id == 'done');
      expect(done.startTime, completedStart);
      expect(done.endTime, completedEnd);
    });

    test('adds buffer between tasks', () {
      final tasks = [_task(id: '1', priority: 2), _task(id: '2', priority: 1)];
      final result = scheduler.scheduleDay(
        tasks: tasks,
        day: day,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      final first = result.firstWhere((t) => t.id == '1');
      final second = result.firstWhere((t) => t.id == '2');
      final gap = second.startTime.difference(first.endTime!);
      // Buffer is 10 minutes.
      expect(gap.inMinutes, greaterThanOrEqualTo(10));
    });

    test('schedules around occupied (completed) blocks', () {
      // 09:00–10:00 is occupied by a completed task.
      final tasks = [
        _task(
          id: 'blocker',
          isCompleted: true,
          startTime: DateTime(2099, 1, 15, 9, 0),
          endTime: DateTime(2099, 1, 15, 10, 0),
        ),
        _task(id: 'pending', priority: 2),
      ];
      final result = scheduler.scheduleDay(
        tasks: tasks,
        day: day,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      final pending = result.firstWhere((t) => t.id == 'pending');
      // Should start at 10:00 + 10-min buffer = 10:10.
      expect(pending.startTime.hour, 10);
      expect(pending.startTime.minute, 10);
    });

    test('stops scheduling when work window is full', () {
      // Fill 8 hours with 1-hour tasks (8 tasks) + 10-min buffers.
      // Expect some tasks to be dropped when they overflow.
      final tasks = List.generate(12, (i) => _task(id: '$i', priority: 2));
      final result = scheduler.scheduleDay(
        tasks: tasks,
        day: day,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      // Each task = 60 min + 10 min buffer = 70 min per slot.
      // 8 hours = 480 min → floor(480 / 70) = 6, last task has no buffer
      // so we can fit ~7 tasks max.
      expect(result.length, lessThan(12));
      for (final t in result) {
        expect(
          t.endTime!.isBefore(
            DateTime(2099, 1, 15, 17, 1), // work end + 1 min leeway
          ),
          isTrue,
          reason: 'Task ${t.id} should not extend beyond work window',
        );
      }
    });

    test('respects explicit task durations', () {
      final tasks = [
        _task(
          id: 'short',
          priority: 2,
          startTime: day,
          endTime: day.add(const Duration(minutes: 30)),
        ),
      ];
      final result = scheduler.scheduleDay(
        tasks: tasks,
        day: day,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      final task = result.first;
      expect(task.endTime!.difference(task.startTime).inMinutes, 30);
    });
  });

  group('SchedulerService Clock abstraction & behavioural tests', () {
    final testDate = DateTime(2026, 6, 15);

    test(
      'morning scheduling: when scheduling before work start, starts at work start',
      () {
        final morningTime = DateTime(2026, 6, 15, 7, 30);
        withClock(Clock.fixed(morningTime), () {
          final result = scheduler.scheduleDay(
            tasks: [_task(id: 't1')],
            day: testDate,
            workStartHour: 9,
            workHoursPerDay: 8,
          );
          expect(result, hasLength(1));
          expect(result.first.startTime, DateTime(2026, 6, 15, 9, 0));
        });
      },
    );

    test('mid-day scheduling: tasks are placed in future, not in the past', () {
      final midDayTime = DateTime(2026, 6, 15, 11, 15);
      withClock(Clock.fixed(midDayTime), () {
        final result = scheduler.scheduleDay(
          tasks: [_task(id: 't1', startTime: DateTime(2026, 6, 15, 8, 0))],
          day: testDate,
          workStartHour: 9,
          workHoursPerDay: 8,
        );
        expect(result, hasLength(1));
        expect(result.first.startTime.isAfter(midDayTime), isTrue);
      });
    });

    test(
      'near end-of-day scheduling: task is not scheduled if it overflows work end',
      () {
        // Work ends at 17:00. At 16:45, a 60-min task cannot fit before 17:00.
        final nearEndTime = DateTime(2026, 6, 15, 16, 45);
        withClock(Clock.fixed(nearEndTime), () {
          final result = scheduler.scheduleDay(
            tasks: [_task(id: 't1')],
            day: testDate,
            workStartHour: 9,
            workHoursPerDay: 8,
          );
          expect(result, isEmpty);
        });
      },
    );

    test(
      'post work-hours scheduling: extends work window to 23:59 for today',
      () {
        // Work normally ends at 17:00. At 18:30 today, workEnd extends to 23:59.
        final eveningTime = DateTime(2026, 6, 15, 18, 30);
        withClock(Clock.fixed(eveningTime), () {
          final result = scheduler.scheduleDay(
            tasks: [_task(id: 't1')],
            day: testDate,
            workStartHour: 9,
            workHoursPerDay: 8,
          );
          expect(result, hasLength(1));
          expect(result.first.startTime.isAfter(eveningTime), isTrue);
          expect(
            result.first.endTime!.isBefore(DateTime(2026, 6, 15, 23, 59, 1)),
            isTrue,
          );
        });
      },
    );

    test(
      'no available time: when window is completely blocked by calendar, no pending tasks fit',
      () {
        final morningTime = DateTime(2026, 6, 15, 8, 0);
        withClock(Clock.fixed(morningTime), () {
          final busyCalendar = CalendarEvent(
            id: 'busy_all_day',
            title: 'All Day Workshop',
            startTime: DateTime(2026, 6, 15, 9, 0),
            endTime: DateTime(2026, 6, 15, 17, 0),
          );
          final result = scheduler.scheduleDay(
            tasks: [_task(id: 't1')],
            day: testDate,
            workStartHour: 9,
            workHoursPerDay: 8,
            calendarBlocks: [busyCalendar],
          );
          expect(result, isEmpty);
        });
      },
    );

    test(
      'occupied blocks: schedules around external calendar events and adds buffer',
      () {
        final morningTime = DateTime(2026, 6, 15, 8, 0);
        withClock(Clock.fixed(morningTime), () {
          final calMeeting = CalendarEvent(
            id: 'meeting',
            title: 'Team Sync',
            startTime: DateTime(2026, 6, 15, 10, 0),
            endTime: DateTime(2026, 6, 15, 11, 0),
          );
          final result = scheduler.scheduleDay(
            tasks: [
              _task(id: 't1'),
              _task(id: 't2'),
            ],
            day: testDate,
            workStartHour: 9,
            workHoursPerDay: 8,
            calendarBlocks: [calMeeting],
          );
          expect(result, hasLength(2));
          // t1 gets 09:00 - 10:00
          expect(result[0].startTime, DateTime(2026, 6, 15, 9, 0));
          expect(result[0].endTime, DateTime(2026, 6, 15, 10, 0));
          // t2 gets scheduled after meeting (11:00) + 10 min buffer = 11:10
          expect(result[1].startTime, DateTime(2026, 6, 15, 11, 10));
          expect(result[1].endTime, DateTime(2026, 6, 15, 12, 10));
        });
      },
    );

    test(
      'deterministic repeated execution: identical tasks and clock yield identical schedule',
      () {
        final fixedNow = DateTime(2026, 6, 15, 10, 20);
        final tasks = [
          _task(id: 't1', priority: 3),
          _task(id: 't2', priority: 1),
          _task(id: 't3', priority: 2),
        ];
        final calEvents = [
          CalendarEvent(
            id: 'cal1',
            title: 'Lunch',
            startTime: DateTime(2026, 6, 15, 12, 0),
            endTime: DateTime(2026, 6, 15, 13, 0),
          ),
        ];

        List<TaskItem> run1 = [];
        List<TaskItem> run2 = [];

        withClock(Clock.fixed(fixedNow), () {
          run1 = scheduler.scheduleDay(
            tasks: tasks,
            day: testDate,
            workStartHour: 9,
            workHoursPerDay: 8,
            calendarBlocks: calEvents,
          );
        });

        withClock(Clock.fixed(fixedNow), () {
          run2 = scheduler.scheduleDay(
            tasks: tasks,
            day: testDate,
            workStartHour: 9,
            workHoursPerDay: 8,
            calendarBlocks: calEvents,
          );
        });

        expect(run1.length, run2.length);
        for (var i = 0; i < run1.length; i++) {
          expect(run1[i].id, run2[i].id);
          expect(run1[i].startTime, run2[i].startTime);
          expect(run1[i].endTime, run2[i].endTime);
        }
      },
    );

    test('freeSlots respects clock when requesting slots for today', () {
      final fixedNow = DateTime(2026, 6, 15, 13, 0);
      withClock(Clock.fixed(fixedNow), () {
        final slots = scheduler.freeSlots(
          day: testDate,
          workStartHour: 9,
          workHoursPerDay: 8,
          slotDuration: const Duration(minutes: 60),
          count: 2,
        );
        expect(slots, isNotEmpty);
        for (final slot in slots) {
          expect(slot.isAfter(fixedNow), isTrue);
        }
      });
    });
  });
}
