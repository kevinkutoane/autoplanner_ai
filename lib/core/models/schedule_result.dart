import 'task_model.dart';

/// Structured explanation of why a task was placed into a specific slot.
class TaskPlacementRationale {
  /// The task this rationale applies to.
  final String taskId;

  /// The assigned start time.
  final DateTime assignedStart;

  /// The assigned end time.
  final DateTime assignedEnd;

  /// Calculated multi-factor planning score.
  final double score;

  /// Human-readable factors explaining this placement (e.g. "Matched morning energy preference").
  final List<String> factors;

  const TaskPlacementRationale({
    required this.taskId,
    required this.assignedStart,
    required this.assignedEnd,
    required this.score,
    required this.factors,
  });
}

/// Warning generated during constraint solving or dependency resolution.
class ScheduleWarning {
  /// Machine-readable code (e.g. 'cycle_detected', 'deadline_exceeded', 'day_full').
  final String code;

  /// Human-readable description.
  final String message;

  /// The task affected, if applicable.
  final String? affectedTaskId;

  const ScheduleWarning({
    required this.code,
    required this.message,
    this.affectedTaskId,
  });
}

/// Comprehensive result of an intelligent constraint-based day scheduling run.
class ScheduleResult {
  /// Successfully scheduled tasks (sorted chronologically).
  final List<TaskItem> scheduledTasks;

  /// Tasks that could not be fitted within the work window or hard deadlines.
  final List<TaskItem> unplacedTasks;

  /// Rationale for each scheduled pending task.
  final Map<String, TaskPlacementRationale> explanations;

  /// Warnings raised during planning (e.g. broken dependency cycles, deadline overruns).
  final List<ScheduleWarning> warnings;

  const ScheduleResult({
    required this.scheduledTasks,
    this.unplacedTasks = const [],
    this.explanations = const {},
    this.warnings = const [],
  });
}
