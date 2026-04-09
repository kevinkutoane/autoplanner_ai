import 'package:hive/hive.dart';

part 'project_model.g.dart';

@HiveType(typeId: 5)
class ProjectItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  /// Optional ID of the parent [GoalItem] this project belongs to.
  @HiveField(3)
  String? parentGoalId;

  @HiveField(4)
  bool isCompleted;

  /// IDs of [TaskItem]s linked to this project.
  @HiveField(5)
  List<String> linkedTaskIds;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  ProjectItem({
    required this.id,
    required this.title,
    this.description = '',
    this.parentGoalId,
    this.isCompleted = false,
    this.linkedTaskIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  ProjectItem copyWith({
    String? id,
    String? title,
    String? description,
    String? parentGoalId,
    bool? isCompleted,
    List<String>? linkedTaskIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      parentGoalId: parentGoalId ?? this.parentGoalId,
      isCompleted: isCompleted ?? this.isCompleted,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
