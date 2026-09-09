import 'package:hive/hive.dart';

part 'task_model.g.dart';

// Sentinel object used by [TaskItem.copyWith] so callers can explicitly
// pass `null` to clear a nullable field (e.g. `recurrence: null`).
const _sentinel = Object();

/// A single scheduled task in the user's planner.
///
/// Stored in the Hive `tasksBox` (typeId 0). All list fields default to
/// empty so they are safe to read without null-checks.
@HiveType(typeId: 0)
class TaskItem extends HiveObject {
  /// Unique identifier (UUID v4).
  @HiveField(0)
  String id;

  /// Short, actionable task title shown in all list views.
  @HiveField(1)
  String title;

  /// Scheduled start time for the task.
  @HiveField(2)
  DateTime startTime;

  /// Scheduled end time; null until the scheduler assigns one.
  @HiveField(3)
  DateTime? endTime;

  /// Optional free-text note attached to the task.
  @HiveField(4)
  String? note;

  /// Whether the user has marked the task done.
  @HiveField(5)
  bool isCompleted;

  /// Priority level: 0 = Low, 1 = Medium, 2 = High, 3 = Urgent.
  @HiveField(6)
  int priority;

  /// User-defined labels for filtering and AI context.
  @HiveField(7)
  List<String> tags;

  /// Kept for Hive schema compatibility (field index 8).
  /// No longer used — goals use [linkedGoalId] instead.
  @Deprecated('No longer used. Hive field 8 reserved for schema compatibility.')
  @HiveField(8)
  List<String> linkedNoteIds;

  /// Recurrence pattern: null | 'daily' | 'weekly' | 'weekdays' | 'custom'
  @HiveField(9)
  String? recurrence;

  /// For 'custom': list of weekday indices (1=Mon … 7=Sun).
  @HiveField(10)
  List<int> recurrenceDays;

  /// ID of the [GoalItem] this task is linked to, if any.
  @HiveField(11)
  String? linkedGoalId;

  /// Hard deadline; scheduler flags warning if unable to fit before this time.
  @HiveField(12)
  DateTime? deadline;

  /// Earliest moment this task is permitted to start.
  @HiveField(13)
  DateTime? earliestStart;

  /// Latest moment this task must finish.
  @HiveField(14)
  DateTime? latestFinish;

  /// If true, startTime/endTime cannot be moved by auto-scheduler.
  @HiveField(15)
  bool isFixed;

  /// Energy requirement: 'low' | 'medium' | 'high'.
  @HiveField(16)
  String? energyLevel;

  /// Preferred time of day: 'morning' | 'afternoon' | 'evening'.
  @HiveField(17)
  String? preferredTimeOfDay;

  /// Whether long tasks can be split across multiple sessions.
  @HiveField(18)
  bool splittable;

  /// Target chunk size in minutes when split (e.g. 60m).
  @HiveField(19)
  int? preferredBlockMinutes;

  /// IDs of tasks that must complete before this task can start.
  @HiveField(20)
  List<String> dependsOnTaskIds;

  /// ID of the parent ProjectItem, if any.
  @HiveField(21)
  String? linkedProjectId;

  /// For split tasks: ID of the parent task this chunk belongs to.
  @HiveField(22)
  String? parentTaskId;

  TaskItem({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.note,
    this.isCompleted = false,
    this.priority = 1,
    this.tags = const [],
    this.linkedNoteIds = const [],
    this.recurrence,
    this.recurrenceDays = const [],
    this.linkedGoalId,
    this.deadline,
    this.earliestStart,
    this.latestFinish,
    this.isFixed = false,
    this.energyLevel,
    this.preferredTimeOfDay,
    this.splittable = false,
    this.preferredBlockMinutes,
    this.dependsOnTaskIds = const [],
    this.linkedProjectId,
    this.parentTaskId,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? note,
    bool? isCompleted,
    int? priority,
    List<String>? tags,
    List<String>? linkedNoteIds,
    Object? recurrence = _sentinel,
    List<int>? recurrenceDays,
    Object? linkedGoalId = _sentinel,
    Object? deadline = _sentinel,
    Object? earliestStart = _sentinel,
    Object? latestFinish = _sentinel,
    bool? isFixed,
    Object? energyLevel = _sentinel,
    Object? preferredTimeOfDay = _sentinel,
    bool? splittable,
    Object? preferredBlockMinutes = _sentinel,
    List<String>? dependsOnTaskIds,
    Object? linkedProjectId = _sentinel,
    Object? parentTaskId = _sentinel,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      // ignore: deprecated_member_use_from_same_package
      linkedNoteIds: linkedNoteIds ?? this.linkedNoteIds,
      recurrence: recurrence == _sentinel
          ? this.recurrence
          : recurrence as String?,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      linkedGoalId: linkedGoalId == _sentinel
          ? this.linkedGoalId
          : linkedGoalId as String?,
      deadline: deadline == _sentinel ? this.deadline : deadline as DateTime?,
      earliestStart: earliestStart == _sentinel
          ? this.earliestStart
          : earliestStart as DateTime?,
      latestFinish: latestFinish == _sentinel
          ? this.latestFinish
          : latestFinish as DateTime?,
      isFixed: isFixed ?? this.isFixed,
      energyLevel: energyLevel == _sentinel
          ? this.energyLevel
          : energyLevel as String?,
      preferredTimeOfDay: preferredTimeOfDay == _sentinel
          ? this.preferredTimeOfDay
          : preferredTimeOfDay as String?,
      splittable: splittable ?? this.splittable,
      preferredBlockMinutes: preferredBlockMinutes == _sentinel
          ? this.preferredBlockMinutes
          : preferredBlockMinutes as int?,
      dependsOnTaskIds: dependsOnTaskIds ?? this.dependsOnTaskIds,
      linkedProjectId: linkedProjectId == _sentinel
          ? this.linkedProjectId
          : linkedProjectId as String?,
      parentTaskId: parentTaskId == _sentinel
          ? this.parentTaskId
          : parentTaskId as String?,
    );
  }

  /// Human-readable label for [priority].
  ///
  /// Falls back to `'Medium'` for any unrecognised value so the UI
  /// never shows a raw integer.
  String get priorityLabel {
    switch (priority) {
      case 0:
        return 'Low';
      case 1:
        return 'Medium';
      case 2:
        return 'High';
      case 3:
        return 'Urgent';
      default:
        return 'Medium';
    }
  }
}
