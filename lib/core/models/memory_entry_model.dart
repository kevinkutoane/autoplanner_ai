import 'package:hive/hive.dart';

part 'memory_entry_model.g.dart';

/// A single entry in the AI long-term memory store.
///
/// Stored in the Hive `memoryBox` (typeId 3). Memories are ranked
/// by time-decayed relevance score and injected into AI prompts to
/// personalise responses based on the user's history and preferences.
@HiveType(typeId: 3)
class MemoryEntry extends HiveObject {
  /// Unique identifier (UUID v4).
  @HiveField(0)
  String id;

  /// The memory text injected verbatim into AI prompts.
  @HiveField(1)
  String content;

  /// Origin of this memory: `'task'`, `'note'`, `'calendar'`, `'ai'`, or `'user'`.
  @HiveField(2)
  String sourceType;

  /// Optional ID of the originating entity (e.g. a task or note ID).
  @HiveField(3)
  String? sourceId;

  /// User-defined labels; also searched by [MemoryService.searchMemories].
  @HiveField(4)
  List<String> tags;

  /// When this memory was created; used for time-decay ranking.
  @HiveField(5)
  DateTime createdAt;

  /// Base relevance weight in the range [0.0, 1.0].
  /// Boosted by [MemoryService.reinforceMemory] on positive outcomes.
  @HiveField(6)
  double relevanceScore;

  /// How many times this memory has been retrieved for AI context injection.
  @HiveField(7)
  int accessCount;

  MemoryEntry({
    required this.id,
    required this.content,
    required this.sourceType,
    this.sourceId,
    this.tags = const [],
    required this.createdAt,
    this.relevanceScore = 0.5,
    this.accessCount = 0,
  });

  /// Returns a new [MemoryEntry] with the given fields replaced.
  /// Fields not passed retain their current value.
  MemoryEntry copyWith({
    String? id,
    String? content,
    String? sourceType,
    String? sourceId,
    List<String>? tags,
    DateTime? createdAt,
    double? relevanceScore,
    int? accessCount,
  }) {
    return MemoryEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      relevanceScore: relevanceScore ?? this.relevanceScore,
      accessCount: accessCount ?? this.accessCount,
    );
  }
}
