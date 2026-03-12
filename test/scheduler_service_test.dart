import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
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
}
