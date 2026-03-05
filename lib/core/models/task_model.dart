import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 0)
class TaskItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime startTime;

  @HiveField(3)
  DateTime? endTime;

  @HiveField(4)
  String? note;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  int priority; // 0=low, 1=medium, 2=high, 3=urgent

  @HiveField(7)
  List<String> tags;

  @HiveField(8)
  List<String> linkedNoteIds;

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
    );
  }

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
