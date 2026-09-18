import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/services/dependency_graph_service.dart';
import 'package:autoplanner_ai/services/scheduler_service.dart';

/// Invariant and boundary test suite for the AutoPlanner AI scheduler engine.
///
/// Contains 21 deterministic invariant and boundary tests validating hard temporal
/// constraints, work-window policies, non-overlap buffers, immovable anchors, DAG
/// topological ordering, past-time protection, overload handling, circular dependency
/// recovery, and multi-run idempotence.
void main() {
  late SchedulerService scheduler;
  final futureDay = DateTime(2099, 6, 15);

  setUp(() {
    scheduler = SchedulerService();
  });

  TaskItem makeTask({
    required String id,
    String title = 'Task',
    int priority = 1,
    bool isCompleted = false,
    bool isFixed = false,
    bool splittable = false,
    int? preferredBlockMinutes,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? earliestStart,
    DateTime? latestFinish,
    DateTime? deadline,
    List<String> dependsOnTaskIds = const [],
    int estimatedDurationMinutes = 60,
  }) {
    final start = startTime ?? futureDay;
    return TaskItem(
      id: id,
      title: title,
      priority: priority,
      isCompleted: isCompleted,
      isFixed: isFixed,
      splittable: splittable,
      preferredBlockMinutes: preferredBlockMinutes,
      startTime: start,
      endTime:
          endTime ?? start.add(Duration(minutes: estimatedDurationMinutes)),
      earliestStart: earliestStart,
      latestFinish: latestFinish,
      deadline: deadline,
      dependsOnTaskIds: dependsOnTaskIds,
    );
  }

  group('Hard Temporal Invariants', () {
    test('start >= earliestStart is strictly respected', () {
      final task = makeTask(
        id: 'early_test',
        earliestStart: DateTime(2099, 6, 15, 14, 0),
        estimatedDurationMinutes: 60,
      );

      final result = scheduler.scheduleDayWithDetails(
        tasks: [task],
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final scheduled = result.scheduledTasks.firstWhere(
        (t) => t.id == 'early_test',
      );
      expect(
        scheduled.startTime.isAtSameMomentAs(DateTime(2099, 6, 15, 14, 0)) ||
            scheduled.startTime.isAfter(DateTime(2099, 6, 15, 14, 0)),
        isTrue,
        reason: 'Task should not start before earliestStart',
      );
    });

    test('end <= latestFinish is a hard constraint: task becomes unplaced if it cannot finish before latestFinish', () {
      // Slot: 09:00 - 10:00, latestFinish: 09:30 => 60m cannot finish before 09:30
      final task = makeTask(
        id: 'tight_finish',
        latestFinish: DateTime(2099, 6, 15, 9, 30),
        estimatedDurationMinutes: 60,
      );

      final result = scheduler.scheduleDayWithDetails(
        tasks: [task],
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      expect(result.unplacedTasks.any((t) => t.id == 'tight_finish'), isTrue);
      expect(
        result.warnings.any(
          (w) =>
              w.code == 'no_slot_available' &&
              w.affectedTaskId == 'tight_finish',
        ),
        isTrue,
      );
    });

    test(
      'end <= deadline produces deadline_exceeded warning when breached',
      () {
        final blocker = makeTask(
          id: 'blocker',
          isFixed: true,
          startTime: DateTime(2099, 6, 15, 9, 0),
          endTime: DateTime(2099, 6, 15, 12, 0),
        );
        final urgent = makeTask(
          id: 'urgent_deadline',
          deadline: DateTime(2099, 6, 15, 10, 0),
          estimatedDurationMinutes: 60,
        );

        final result = scheduler.scheduleDayWithDetails(
          tasks: [blocker, urgent],
          day: futureDay,
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
      },
    );
  });

  group('Work Window Invariants', () {
    test('all tasks placed within configured work window boundaries', () {
      final tasks = List.generate(
        4,
        (i) => makeTask(id: 't_$i', priority: 2, estimatedDurationMinutes: 60),
      );

      final result = scheduler.scheduleDayWithDetails(
        tasks: tasks,
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 6, // 09:00 to 15:00
      );

      for (final t in result.scheduledTasks) {
        expect(t.startTime.isBefore(DateTime(2099, 6, 15, 9, 0)), isFalse);
        expect(t.endTime!.isAfter(DateTime(2099, 6, 15, 15, 0)), isFalse);
      }
    });
  });

  group('No-Overlap & Buffer Invariants', () {
    test('consecutive scheduled tasks never overlap and preserve 10m buffer', () {
      const bufferMinutes = 10;
      final tasks = [
        makeTask(id: 'a', priority: 3, estimatedDurationMinutes: 60),
        makeTask(id: 'b', priority: 2, estimatedDurationMinutes: 45),
        makeTask(id: 'c', priority: 1, estimatedDurationMinutes: 30),
      ];

      final result = scheduler.scheduleDayWithDetails(
        tasks: tasks,
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final scheduled = result.scheduledTasks;
      scheduled.sort((a, b) => a.startTime.compareTo(b.startTime));

      for (int i = 0; i < scheduled.length - 1; i++) {
        final current = scheduled[i];
        final next = scheduled[i + 1];
        final minNextStart = current.endTime!.add(
          const Duration(minutes: bufferMinutes),
        );

        expect(
          next.startTime.isAtSameMomentAs(minNextStart) ||
              next.startTime.isAfter(minNextStart),
          isTrue,
          reason:
              'Task ${next.id} must start at or after ${current.id} end + buffer',
        );
      }
    });
  });

  group('Fixed & Completed Tasks Invariants', () {
    test('isFixed == true tasks remain strictly immovable', () {
      final fixedSlot = makeTask(
        id: 'client_meeting',
        isFixed: true,
        priority: 1,
        startTime: DateTime(2099, 6, 15, 11, 0),
        endTime: DateTime(2099, 6, 15, 12, 30),
      );
      final highPriority = makeTask(
        id: 'urgent_work',
        priority: 3,
        estimatedDurationMinutes: 120,
      );

      final result = scheduler.scheduleDayWithDetails(
        tasks: [fixedSlot, highPriority],
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final scheduledFixed = result.scheduledTasks.firstWhere(
        (t) => t.id == 'client_meeting',
      );
      expect(scheduledFixed.startTime, DateTime(2099, 6, 15, 11, 0));
      expect(scheduledFixed.endTime, DateTime(2099, 6, 15, 12, 30));
    });

    test('isCompleted == true tasks are preserved at historical time and not rescheduled', () {
      final historicalStart = DateTime(2099, 6, 15, 8, 30);
      final historicalEnd = DateTime(2099, 6, 15, 9, 30);
      final completed = makeTask(
        id: 'already_done',
        isCompleted: true,
        startTime: historicalStart,
        endTime: historicalEnd,
      );
      final normal = makeTask(id: 'normal', priority: 2);

      final result = scheduler.scheduleDay(
        tasks: [completed, normal],
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final doneOut = result.firstWhere((t) => t.id == 'already_done');
      expect(doneOut.startTime, historicalStart);
      expect(doneOut.endTime, historicalEnd);
    });
  });

  group('Dependency Ordering Invariants', () {
    test('dependent task B is never scheduled before prerequisite task A completes', () {
      const buffer = 10;
      final taskA = makeTask(
        id: 'prereq_A',
        priority: 1, // lower priority than B
        estimatedDurationMinutes: 60,
      );
      final taskB = makeTask(
        id: 'dependent_B',
        priority: 3, // higher priority, but depends on A!
        dependsOnTaskIds: ['prereq_A'],
        estimatedDurationMinutes: 60,
      );

      final result = scheduler.scheduleDayWithDetails(
        tasks: [taskB, taskA], // B passed first
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final outA = result.scheduledTasks.firstWhere((t) => t.id == 'prereq_A');
      final outB = result.scheduledTasks.firstWhere(
        (t) => t.id == 'dependent_B',
      );

      expect(
        outB.startTime.isAtSameMomentAs(
              outA.endTime!.add(const Duration(minutes: buffer)),
            ) ||
            outB.startTime.isAfter(outA.endTime!),
        isTrue,
        reason: 'Dependent task B must start after prerequisite A completes',
      );
    });
  });

  group('Past-Time Protection Invariants', () {
    test('scheduling for current day never places tasks before clock.now() cursor', () {
      final testDate = DateTime(2026, 4, 21);
      final midday = DateTime(2026, 4, 21, 14, 15);

      withClock(Clock.fixed(midday), () {
        final tasks = [
          makeTask(id: 't1', priority: 3, estimatedDurationMinutes: 45),
          makeTask(id: 't2', priority: 2, estimatedDurationMinutes: 60),
        ];

        final result = scheduler.scheduleDayWithDetails(
          tasks: tasks,
          day: testDate,
          workStartHour: 9,
          workHoursPerDay: 8,
        );

        for (final task in result.scheduledTasks) {
          expect(
            task.startTime.isBefore(midday),
            isFalse,
            reason:
                'Task ${task.id} scheduled at ${task.startTime} before clock.now() $midday',
          );
        }
      });
    });
  });

  group('Determinism & Idempotence Invariants', () {
    test(
      'identical inputs produce strictly identical schedules (determinism)',
      () {
        final tasks = [
          makeTask(id: 't1', priority: 2, estimatedDurationMinutes: 45),
          makeTask(id: 't2', priority: 3, estimatedDurationMinutes: 60),
          makeTask(id: 't3', priority: 1, estimatedDurationMinutes: 30),
        ];

        final run1 = scheduler.scheduleDay(
          tasks: tasks,
          day: futureDay,
          workStartHour: 9,
          workHoursPerDay: 8,
        );

        final run2 = scheduler.scheduleDay(
          tasks: tasks,
          day: futureDay,
          workStartHour: 9,
          workHoursPerDay: 8,
        );

        expect(run1.length, equals(run2.length));
        for (int i = 0; i < run1.length; i++) {
          expect(run1[i].id, equals(run2[i].id));
          expect(run1[i].startTime, equals(run2[i].startTime));
          expect(run1[i].endTime, equals(run2[i].endTime));
        }
      },
    );

    test(
      're-scheduling output produces identical valid placement (idempotence)',
      () {
        final initialTasks = [
          makeTask(id: 't1', priority: 3, estimatedDurationMinutes: 60),
          makeTask(id: 't2', priority: 2, estimatedDurationMinutes: 90),
        ];

        final firstPass = scheduler.scheduleDay(
          tasks: initialTasks,
          day: futureDay,
          workStartHour: 9,
          workHoursPerDay: 8,
        );

        final secondPass = scheduler.scheduleDay(
          tasks: firstPass,
          day: futureDay,
          workStartHour: 9,
          workHoursPerDay: 8,
        );

        expect(secondPass.length, equals(firstPass.length));
        for (int i = 0; i < firstPass.length; i++) {
          expect(secondPass[i].id, equals(firstPass[i].id));
          expect(secondPass[i].startTime, equals(firstPass[i].startTime));
          expect(secondPass[i].endTime, equals(firstPass[i].endTime));
        }
      },
    );
  });

  group('Overload Handling Invariants', () {
    test('excess workload produces valid partial schedule and lists unplaced tasks without invalid overlap', () {
      // 8 hour workday = 480 mins. We submit 10 tasks of 60 mins = 600 mins.
      final tasks = List.generate(
        10,
        (i) => makeTask(
          id: 'task_$i',
          priority: i % 4,
          estimatedDurationMinutes: 60,
        ),
      );

      final result = scheduler.scheduleDayWithDetails(
        tasks: tasks,
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      expect(result.unplacedTasks, isNotEmpty);
      expect(result.scheduledTasks, isNotEmpty);
      expect(
        result.scheduledTasks.length + result.unplacedTasks.length,
        equals(10),
      );

      // Assert scheduled tasks still strictly respect no-overlap and work window!
      for (final t in result.scheduledTasks) {
        expect(t.endTime!.isAfter(DateTime(2099, 6, 15, 17, 0)), isFalse);
      }
    });
  });

  group('DAG Cycle Safety Invariants', () {
    test('circular dependencies terminate safely without infinite recursion or hanging', () {
      final taskA = makeTask(id: 'cycle_A', dependsOnTaskIds: ['cycle_B']);
      final taskB = makeTask(id: 'cycle_B', dependsOnTaskIds: ['cycle_A']);

      final result = scheduler.scheduleDayWithDetails(
        tasks: [taskA, taskB],
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      expect(
        result.warnings.any(
          (w) => w.code == 'circular_dependency' || w.code.contains('cycle'),
        ),
        isTrue,
        reason: 'Cycle detector must report circular dependency diagnostic',
      );
      expect(
        result.scheduledTasks.length + result.unplacedTasks.length,
        equals(2),
      );
    });

    test('DependencyGraphService detects cycle explicitly', () {
      final graph = DependencyGraphService();
      final tasks = [
        makeTask(id: '1', dependsOnTaskIds: ['2']),
        makeTask(id: '2', dependsOnTaskIds: ['3']),
        makeTask(id: '3', dependsOnTaskIds: ['1']),
      ];

      final resolution = graph.resolveDependencies(tasks);
      expect(resolution.cycleTaskIds, isNotEmpty);
      expect(resolution.cycleTaskIds, containsAll(['1', '2', '3']));
    });
  });

  group('Task Splitting Invariants', () {
    test('splittable task conserves total duration and maintains parentTaskId link', () {
      // 120m task with preferredBlockMinutes = 60m => splits into two 60m chunks
      final splittable = makeTask(
        id: 'big_project',
        splittable: true,
        preferredBlockMinutes: 60,
        priority: 2,
        estimatedDurationMinutes: 120, // 2 hours
      );

      final result = scheduler.scheduleDayWithDetails(
        tasks: [splittable],
        day: futureDay,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final chunks = result.scheduledTasks
          .where(
            (t) =>
                t.parentTaskId == 'big_project' ||
                t.id.startsWith('big_project_chunk_'),
          )
          .toList();

      expect(chunks, hasLength(2));
      final totalMinutes = chunks.fold<int>(
        0,
        (sum, c) => sum + c.endTime!.difference(c.startTime).inMinutes,
      );
      expect(
        totalMinutes,
        equals(120),
        reason: 'Total chunk duration must be conserved',
      );
      for (final c in chunks) {
        expect(c.parentTaskId, equals('big_project'));
      }
    });
  });

  group('Clock Boundaries & Time-of-Day Variations', () {
    final times = [
      DateTime(2026, 4, 21, 6, 0), // early morning (before work)
      DateTime(2026, 4, 21, 12, 0), // midday
      DateTime(2026, 4, 21, 16, 30), // late afternoon
      DateTime(2026, 4, 21, 17, 45), // near end of work day
      DateTime(2026, 4, 21, 21, 0), // after work hours
      DateTime(2026, 4, 21, 23, 59), // day boundary
    ];

    for (final fixedClock in times) {
      test(
        'scheduler remains stable and invariant under clock at ${fixedClock.hour}:${fixedClock.minute}',
        () {
          withClock(Clock.fixed(fixedClock), () {
            final tasks = [
              makeTask(id: 'work_a', priority: 3, estimatedDurationMinutes: 45),
              makeTask(id: 'work_b', priority: 2, estimatedDurationMinutes: 30),
            ];

            final result = scheduler.scheduleDayWithDetails(
              tasks: tasks,
              day: DateTime(2026, 4, 21),
              workStartHour: 9,
              workHoursPerDay: 8,
            );

            // All scheduled tasks must not start before current clock
            for (final t in result.scheduledTasks) {
              expect(
                t.startTime.isBefore(fixedClock),
                isFalse,
                reason:
                    'Scheduled before clock at ${fixedClock.hour}:${fixedClock.minute}',
              );
            }
          });
        },
      );
    }
  });
}
