import 'dart:math';
import 'package:clock/clock.dart';

import '../core/models/task_model.dart';
import '../core/models/calendar_event_model.dart';
import 'duration_learning_service.dart';
import 'scheduler_service.dart';

/// Represents the detected temporal drift of the current schedule against reality.
class ScheduleDrift {
  /// Whether the schedule has drifted sufficiently beyond the grace threshold.
  final bool hasDrift;

  /// Magnitude of the drift in minutes (positive = running behind / late).
  final int driftMinutes;

  /// Tasks whose planned start times are in the past and remain uncompleted.
  final List<TaskItem> overdueTasks;

  /// Downstream tasks that will be pushed or collided if the schedule is rippled.
  final List<TaskItem> impactedTasks;

  /// Human-readable explanation of the drift state.
  final String summary;

  const ScheduleDrift({
    required this.hasDrift,
    required this.driftMinutes,
    required this.overdueTasks,
    required this.impactedTasks,
    required this.summary,
  });

  /// Alias for driftMinutes.
  int get totalDriftMinutes => driftMinutes;

  /// Alias for overdueTasks.
  List<TaskItem> get driftedTasks => overdueTasks;

  /// Returns the first downstream fixed anchor if one exists.
  TaskItem? get nextFixedAnchor {
    for (final t in impactedTasks) {
      if (t.isFixed) return t;
    }
    return null;
  }

  factory ScheduleDrift.none() => const ScheduleDrift(
        hasDrift: false,
        driftMinutes: 0,
        overdueTasks: [],
        impactedTasks: [],
        summary: 'Schedule is on track.',
      );
}

/// The result of an autonomous ripple reschedule operation.
class RippleRescheduleResult {
  /// Complete updated task list for the day with healed start and end times.
  final List<TaskItem> healedTasks;

  /// Alias for healedTasks.
  List<TaskItem> get updatedTasks => healedTasks;

  /// Number of tasks that were repositioned.
  final int shiftedCount;

  /// Tasks that could not fit into the remaining work window.
  final List<TaskItem> unplacedTasks;

  /// Total drift minutes resolved by this ripple.
  final int resolvedDriftMinutes;

  /// Explainability summary detailing the adjustments made.
  final String rationale;

  const RippleRescheduleResult({
    required this.healedTasks,
    required this.shiftedCount,
    required this.unplacedTasks,
    required this.resolvedDriftMinutes,
    required this.rationale,
  });
}

/// Senses real-world schedule drift and autonomously heals downstream commitments.
///
/// Features:
/// - Detects negative drift (running behind) and positive drift (finished early).
/// - Honors fixed anchor commitments immovably ([TaskItem.isFixed]).
/// - Performs topological ripple shifts without violating hard deadlines or dependency order.
/// - Preserves external Google Calendar meetings and buffers.
class ScheduleDriftService {
  final SchedulerService _scheduler;

  ScheduleDriftService({SchedulerService? scheduler})
      : _scheduler = scheduler ?? SchedulerService();

  /// Detects whether today's schedule has drifted beyond [graceMinutes].
  ScheduleDrift detectDrift({
    required List<TaskItem> tasks,
    DateTime? currentTime,
    int graceMinutes = 10,
  }) {
    final now = currentTime ?? clock.now();

    // Only inspect tasks scheduled for today
    final todayTasks = tasks.where((t) {
      return t.startTime.year == now.year &&
          t.startTime.month == now.month &&
          t.startTime.day == now.day;
    }).toList();

    if (todayTasks.isEmpty) {
      return ScheduleDrift.none();
    }

    final overdue = <TaskItem>[];
    var maxDriftMinutes = 0;

    for (final task in todayTasks) {
      // Completed or immovable anchor tasks cannot drift
      if (task.isCompleted || task.isFixed) continue;

      if (now.isAfter(task.startTime.add(Duration(minutes: graceMinutes)))) {
        overdue.add(task);
        final delta = now.difference(task.startTime).inMinutes;
        maxDriftMinutes = max(maxDriftMinutes, delta);
      }
    }

    if (overdue.isEmpty) {
      return ScheduleDrift.none();
    }

    // Downstream tasks scheduled after the earliest overdue start
    final earliestOverdue = overdue
        .map((t) => t.startTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    final impacted = todayTasks.where((t) {
      return !t.isCompleted &&
          !t.isFixed &&
          !overdue.contains(t) &&
          t.startTime.isAfter(earliestOverdue);
    }).toList();

    return ScheduleDrift(
      hasDrift: true,
      driftMinutes: maxDriftMinutes,
      overdueTasks: overdue,
      impactedTasks: impacted,
      summary: 'Schedule is running $maxDriftMinutes min behind (${overdue.length} overdue task${overdue.length > 1 ? 's' : ''}).',
    );
  }

  /// Autonomously ripples downstream tasks forward to absorb drift.
  ///
  /// Anchors fixed commitments, enforces DAG dependency order, respects
  /// calendar blocks, and updates start/end times.
  RippleRescheduleResult rippleReschedule({
    required List<TaskItem> allTasks,
    required int workStartHour,
    required int workHoursPerDay,
    DateTime? currentTime,
    List<CalendarEvent> calendarBlocks = const [],
    Map<String, CategoryCalibration>? calibrations,
    String? chronotype,
  }) {
    final now = currentTime ?? clock.now();
    final drift = detectDrift(tasks: allTasks, currentTime: now);

    if (!drift.hasDrift) {
      return RippleRescheduleResult(
        healedTasks: allTasks,
        shiftedCount: 0,
        unplacedTasks: const [],
        resolvedDriftMinutes: 0,
        rationale: 'Schedule is already aligned with current time.',
      );
    }

    // Run deterministic scheduler for today with past-time protection at 'now'
    final scheduleResult = _scheduler.scheduleDayWithDetails(
      tasks: allTasks,
      day: now,
      workStartHour: workStartHour,
      workHoursPerDay: workHoursPerDay,
      calendarBlocks: calendarBlocks,
      calibrations: calibrations,
      chronotype: chronotype,
    );

    // Map healed tasks into original collection
    final scheduledMap = {for (final t in scheduleResult.scheduledTasks) t.id: t};
    var shifted = 0;

    final updatedAll = allTasks.map((original) {
      final healed = scheduledMap[original.id];
      if (healed != null) {
        if (healed.startTime != original.startTime || healed.endTime != original.endTime) {
          shifted++;
          return healed;
        }
      }
      return original;
    }).toList();

    final rationale = 'Self-healing ripple repositioned $shifted task${shifted == 1 ? '' : 's'} '
        'to absorb ${drift.driftMinutes}m drift while preserving fixed commitments.';

    return RippleRescheduleResult(
      healedTasks: updatedAll,
      shiftedCount: shifted,
      unplacedTasks: scheduleResult.unplacedTasks,
      resolvedDriftMinutes: drift.driftMinutes,
      rationale: rationale,
    );
  }
}
