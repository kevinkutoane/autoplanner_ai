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
      linkedNoteIds: linkedNoteIds ?? this.linkedNoteIds,
      recurrence: recurrence == _sentinel
          ? this.recurrence
          : recurrence as String?,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      linkedGoalId: linkedGoalId == _sentinel
          ? this.linkedGoalId
          : linkedGoalId as String?,
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
