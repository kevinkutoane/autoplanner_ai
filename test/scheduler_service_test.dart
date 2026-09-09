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

  group('Phase 1.2 Smart Scheduling Engine Tests', () {
    final fixedDate = DateTime(2099, 1, 15);

    test(
      'scheduleDayWithDetails returns ScheduleResult with explainability',
      () {
        final task = _task(id: 't1', priority: 2);
        final result = scheduler.scheduleDayWithDetails(
          tasks: [task],
          day: fixedDate,
          workStartHour: 9,
          workHoursPerDay: 8,
        );

        expect(result.scheduledTasks, hasLength(1));
        expect(result.unplacedTasks, isEmpty);
        expect(result.explanations.containsKey('t1'), isTrue);

        final rationale = result.explanations['t1']!;
        expect(rationale.taskId, equals('t1'));
        expect(rationale.score, greaterThan(0));
        expect(rationale.factors, isNotEmpty);
        expect(rationale.factors.any((f) => f.contains('priority')), isTrue);
      },
    );

    test('task dependencies enforce temporal ordering', () {
      // Task B depends on Task A. Even if Task B is Urgent (priority 3) and A is Low (priority 0),
      // Task A must be scheduled first and Task B must start after Task A ends + buffer.
      final taskA = _task(id: 'taskA', priority: 0);
      final taskB = TaskItem(
        id: 'taskB',
        title: 'Task B',
        priority: 3,
        startTime: fixedDate,
        dependsOnTaskIds: ['taskA'],
      );

      final result = scheduler.scheduleDayWithDetails(
        tasks: [taskB, taskA],
        day: fixedDate,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final scheduledA = result.scheduledTasks.firstWhere(
        (t) => t.id == 'taskA',
      );
      final scheduledB = result.scheduledTasks.firstWhere(
        (t) => t.id == 'taskB',
      );

      expect(scheduledA.startTime, DateTime(2099, 1, 15, 9, 0));
      // Task A: 09:00 - 10:00. Buffer: 10m. Task B must start at or after 10:10.
      expect(scheduledB.startTime.isAfter(scheduledA.endTime!), isTrue);
      expect(
        scheduledB.startTime.difference(scheduledA.endTime!).inMinutes,
        greaterThanOrEqualTo(10),
      );
    });

    test(
      'task splitting decomposes long tasks into linked sub-tasks with buffer',
      () {
        // 120-minute task with splittable: true and preferredBlockMinutes: 60
        final bigTask = TaskItem(
          id: 'big1',
          title: 'Deep Research',
          priority: 2,
          startTime: fixedDate,
          endTime: fixedDate.add(const Duration(minutes: 120)),
          splittable: true,
          preferredBlockMinutes: 60,
        );

        final result = scheduler.scheduleDayWithDetails(
          tasks: [bigTask],
          day: fixedDate,
          workStartHour: 9,
          workHoursPerDay: 8,
        );

        // Should be split into 2 chunks of 60m
        expect(result.scheduledTasks, hasLength(2));
        final chunk1 = result.scheduledTasks[0];
        final chunk2 = result.scheduledTasks[1];

        expect(chunk1.id, 'big1_chunk_1');
        expect(chunk1.title, contains('Part 1/2'));
        expect(chunk1.endTime!.difference(chunk1.startTime).inMinutes, 60);

        expect(chunk2.id, 'big1_chunk_2');
        expect(chunk2.title, contains('Part 2/2'));
        expect(chunk2.endTime!.difference(chunk2.startTime).inMinutes, 60);

        // Chunk 2 must start after chunk 1 + buffer
        expect(
          chunk2.startTime.difference(chunk1.endTime!).inMinutes,
          greaterThanOrEqualTo(10),
        );
      },
    );

    test('immovable fixed tasks (isFixed: true) anchor their time slot', () {
      final fixedTask = TaskItem(
        id: 'fixed1',
        title: 'Team Standup',
        priority: 1,
        isFixed: true,
        startTime: DateTime(2099, 1, 15, 10, 0),
        endTime: DateTime(2099, 1, 15, 10, 30),
      );
      final normalTask = _task(id: 'normal', priority: 2);

      final result = scheduler.scheduleDayWithDetails(
        tasks: [normalTask, fixedTask],
        day: fixedDate,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final fixedOut = result.scheduledTasks.firstWhere(
        (t) => t.id == 'fixed1',
      );
      final normalOut = result.scheduledTasks.firstWhere(
        (t) => t.id == 'normal',
      );

      // Fixed task must not have moved
      expect(fixedOut.startTime, DateTime(2099, 1, 15, 10, 0));
      expect(fixedOut.endTime, DateTime(2099, 1, 15, 10, 30));

      // Normal task starts at 09:00 - 10:00 (fits right before fixed task)
      expect(normalOut.startTime, DateTime(2099, 1, 15, 9, 0));
      expect(normalOut.endTime, DateTime(2099, 1, 15, 10, 0));
    });

    test(
      'earliestStart constraint prevents scheduling before specified time',
      () {
        final task = TaskItem(
          id: 't_early',
          title: 'Wait for call',
          priority: 3,
          startTime: fixedDate,
          earliestStart: DateTime(2099, 1, 15, 13, 0),
        );

        final result = scheduler.scheduleDayWithDetails(
          tasks: [task],
          day: fixedDate,
          workStartHour: 9,
          workHoursPerDay: 8,
        );

        final scheduled = result.scheduledTasks.firstWhere(
          (t) => t.id == 't_early',
        );
        expect(scheduled.startTime, isNot(DateTime(2099, 1, 15, 9, 0)));
        expect(
          scheduled.startTime.isAtSameMomentAs(DateTime(2099, 1, 15, 13, 0)) ||
              scheduled.startTime.isAfter(DateTime(2099, 1, 15, 13, 0)),
          isTrue,
        );
      },
    );

    test('deadline exceeded produces a warning', () {
      // 09:00 - 10:30 blocker
      final blocker = TaskItem(
        id: 'blocker',
        title: 'Morning blocker',
        priority: 2,
        isFixed: true,
        startTime: DateTime(2099, 1, 15, 9, 0),
        endTime: DateTime(2099, 1, 15, 10, 30),
      );
      // Deadline was 10:00, but can only be scheduled after 10:30 + 10m = 10:40
      final taskWithDeadline = TaskItem(
        id: 'urgent_deadline',
        title: 'Missed deadline task',
        priority: 3,
        startTime: fixedDate,
        deadline: DateTime(2099, 1, 15, 10, 0),
      );

      final result = scheduler.scheduleDayWithDetails(
        tasks: [blocker, taskWithDeadline],
        day: fixedDate,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      expect(
        result.warnings.any(
          (w) =>
              w.code == 'deadline_exceeded' &&
              w.affectedTaskId == 'urgent_deadline',
        ),
        isTrue,
      );
    });
  });
}
