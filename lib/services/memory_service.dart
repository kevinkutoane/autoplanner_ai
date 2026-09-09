import 'dart:math' show exp;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../core/models/memory_entry_model.dart';

/// Local memory store backed by a Hive box.
///
/// Provides ranked retrieval (time-decayed relevance scoring), tag/source
/// filtering, keyword search, and automatic decay of stale entries. Call
/// [init] once at app startup after Hive is initialised.
class MemoryService {
  Box<MemoryEntry>? _box;

  Future<void> init({HiveAesCipher? cipher}) async {
    _box = await Hive.openBox<MemoryEntry>(
      'memoryBox',
      encryptionCipher: cipher,
    );
  }

  /// All stored memory entries, sorted by [MemoryEntry.createdAt] descending
  /// (most recent first). Returns an empty list before [init] is called.
  List<MemoryEntry> get allMemories {
    final entries = _box?.values.toList() ?? [];
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  /// The 20 most recently created memory entries. Useful for populating
  /// short AI context windows without relevance-ranking overhead.
  List<MemoryEntry> get recentMemories {
    return allMemories.take(20).toList();
  }

  /// Returns the top [limit] memories ranked by time-decayed relevance score.
  /// Formula: base_score × e^(-0.007 × days_old) + 0.05 × access_count
  /// This means a memory with score 0.8 created 100 days ago ranks lower than
  /// a score 0.5 memory from last week — keeping context fresh and useful.
  List<MemoryEntry> contextMemories({int limit = 10}) {
    final entries = _box?.values.toList() ?? [];
    entries.sort((a, b) => _adjustedScore(b).compareTo(_adjustedScore(a)));
    return entries.take(limit).toList();
  }

  /// Time-decayed relevance score for memory prioritisation.
  double _adjustedScore(MemoryEntry m) {
    final days = DateTime.now().difference(m.createdAt).inDays.clamp(0, 365);
    return m.relevanceScore * exp(-0.007 * days.toDouble()) +
        0.05 * m.accessCount.clamp(0, 10);
  }

  /// Deletes memories that haven't been accessed and whose adjusted score
  /// has decayed below [threshold]. Returns the count removed.
  Future<int> decayStaleMemories({
    int thresholdDays = 90,
    double threshold = 0.05,
  }) async {
    final stale =
        _box?.values
            .where(
              (m) =>
                  m.accessCount == 0 &&
                  DateTime.now().difference(m.createdAt).inDays >
                      thresholdDays &&
                  _adjustedScore(m) < threshold,
            )
            .toList() ??
        [];
    for (final m in stale) {
      await _box?.delete(m.id);
    }
    if (kDebugMode && stale.isNotEmpty) {
      debugPrint('🧠 Decayed ${stale.length} stale memories');
    }
    return stale.length;
  }

  /// Increments the access count for context-injected memories.
  Future<void> markAccessed(List<MemoryEntry> memories) async {
    for (final m in memories) {
      m.accessCount += 1;
      await m.save();
    }
  }

  /// Boosts relevance when a memory contributed to a successful outcome.
  /// Clamped at 1.0 so scores stay normalised.
  Future<void> reinforceMemory(String id, {double boost = 0.1}) async {
    final m = _box?.get(id);
    if (m == null) return;
    m.relevanceScore = (m.relevanceScore + boost).clamp(0.0, 1.0);
    await m.save();
  }

  /// Persists a new [MemoryEntry] to the memory box.
  /// Use [reinforceMemory] later to boost its relevance when it proves useful.
  Future<void> addMemory(MemoryEntry entry) async {
    await _box?.put(entry.id, entry);
    if (kDebugMode) debugPrint('MemoryService: saved — ${entry.content}');
  }

  /// Permanently removes the memory entry with the given [id].
  Future<void> deleteMemory(String id) async {
    await _box?.delete(id);
  }

  /// Returns all memories whose [MemoryEntry.content] or [MemoryEntry.tags]
  /// contain [query] as a case-insensitive substring.
  List<MemoryEntry> searchMemories(String query) {
    final queryLower = query.toLowerCase();
    return allMemories.where((m) {
      return m.content.toLowerCase().contains(queryLower) ||
          m.tags.any((tag) => tag.toLowerCase().contains(queryLower));
    }).toList();
  }

  /// Returns all memories whose [MemoryEntry.sourceType] matches [sourceType]
  /// exactly (e.g. `'task'`, `'note'`, `'ai'`, `'user'`).
  List<MemoryEntry> getBySourceType(String sourceType) {
    return allMemories.where((m) => m.sourceType == sourceType).toList();
  }

  /// Get memories by tag
  List<MemoryEntry> getByTag(String tag) {
    final tagLower = tag.toLowerCase();
    return allMemories
        .where((m) => m.tags.any((t) => t.toLowerCase() == tagLower))
        .toList();
  }

  /// Sorted list of all unique tag strings across every stored memory entry.
  List<String> get allTags {
    final tags = <String>{};
    for (final m in allMemories) {
      tags.addAll(m.tags);
    }
    final tagList = tags.toList()..sort();
    return tagList;
  }

  /// Removes all entries from the memory box.
  /// Useful for full data wipe (e.g. settings reset).
  Future<void> clearAll() async {
    await _box?.clear();
  }
}
