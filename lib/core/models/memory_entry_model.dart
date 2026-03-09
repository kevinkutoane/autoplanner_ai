import 'package:hive/hive.dart';

part 'memory_entry_model.g.dart';

@HiveType(typeId: 3)
class MemoryEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String content;

  @HiveField(2)
  String sourceType; // 'task', 'note', 'calendar', 'ai', 'user'

  @HiveField(3)
  String? sourceId;

  @HiveField(4)
  List<String> tags;

  @HiveField(5)
  DateTime createdAt;

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
