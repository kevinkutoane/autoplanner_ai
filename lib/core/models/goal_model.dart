import 'package:hive/hive.dart';

part 'goal_model.g.dart';

@HiveType(typeId: 4)
class GoalItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  /// Free-text notes / description for the goal.
  @HiveField(2)
  String description;

  @HiveField(3)
  String emoji;

  @HiveField(4)
  DateTime? deadline;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  bool isArchived;

  /// Stored as `Color.value` (ARGB int).
  @HiveField(7)
  int color;

  /// IDs of [TaskItem]s linked to this goal.
  @HiveField(8)
  List<String> linkedTaskIds;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  GoalItem({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '🎯',
    this.deadline,
    this.isCompleted = false,
    this.isArchived = false,
    this.color = 0xFF6C63FF,
    this.linkedTaskIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  GoalItem copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    DateTime? deadline,
    bool? isCompleted,
    bool? isArchived,
    int? color,
    List<String>? linkedTaskIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GoalItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived,
      color: color ?? this.color,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
