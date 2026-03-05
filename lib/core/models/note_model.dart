import 'package:hive/hive.dart';

part 'note_model.g.dart';

@HiveType(typeId: 1)
class NoteItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  String? summary;

  @HiveField(4)
  List<String> tags;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  List<String> linkedTaskIds;

  @HiveField(8)
  bool isPinned;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    this.summary,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.linkedTaskIds = const [],
    this.isPinned = false,
  });

  NoteItem copyWith({
    String? id,
    String? title,
    String? content,
    String? summary,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? linkedTaskIds,
    bool? isPinned,
  }) {
    return NoteItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
