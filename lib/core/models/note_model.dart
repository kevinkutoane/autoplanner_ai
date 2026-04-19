import 'package:hive/hive.dart';

part 'note_model.g.dart';

/// A user-created note that can be pinned, tagged, and linked to tasks.
///
/// Stored in the Hive `notesBox` (typeId 1). The model mirrors the
/// serialisation contract expected by [BackupService].
@HiveType(typeId: 1)
class NoteItem extends HiveObject {
  /// Unique identifier (UUID v4).
  @HiveField(0)
  String id;

  /// Short title shown in list views.
  @HiveField(1)
  String title;

  /// Full note body.
  @HiveField(2)
  String content;

  /// Optional AI-generated summary.
  @HiveField(3)
  String? summary;

  /// User-defined labels for filtering and search.
  @HiveField(4)
  List<String> tags;

  /// When the note was first created.
  @HiveField(5)
  DateTime createdAt;

  /// When the note was last modified.
  @HiveField(6)
  DateTime updatedAt;

  /// IDs of tasks linked to this note.
  @HiveField(7)
  List<String> linkedTaskIds;

  /// Whether the note is pinned to the top of lists.
  @HiveField(8)
  bool isPinned;

  /// When true, an immediate push notification fires to alert the user.
  @HiveField(9)
  bool isUrgent;

  /// Optional one-shot reminder time. When set, a scheduled notification
  /// fires at this datetime and is cancelled once it fires or is cleared.
  @HiveField(10)
  DateTime? reminderAt;

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
    this.isUrgent = false,
    this.reminderAt,
  });

  /// Returns a new [NoteItem] with the given fields replaced.
  /// Fields not passed retain their current value.
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
    bool? isUrgent,
    DateTime? reminderAt,
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
      isUrgent: isUrgent ?? this.isUrgent,
      reminderAt: reminderAt ?? this.reminderAt,
    );
  }
}
