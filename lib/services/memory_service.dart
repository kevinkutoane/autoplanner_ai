import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../core/models/memory_entry_model.dart';

class MemoryService {
  Box<MemoryEntry>? _box;

  Future<void> init({HiveAesCipher? cipher}) async {
    _box = await Hive.openBox<MemoryEntry>(
      'memoryBox',
      encryptionCipher: cipher,
    );
  }

  List<MemoryEntry> get allMemories {
    final entries = _box?.values.toList() ?? [];
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  List<MemoryEntry> get recentMemories {
    return allMemories.take(20).toList();
  }

  /// Add a new memory entry
  Future<void> addMemory(MemoryEntry entry) async {
    await _box?.put(entry.id, entry);
    if (kDebugMode) {
      print("🧠 Memory saved: ${entry.content}");
    }
  }

  /// Delete a memory entry
  Future<void> deleteMemory(String id) async {
    await _box?.delete(id);
  }

  /// Search memories by content keywords
  List<MemoryEntry> searchMemories(String query) {
    final queryLower = query.toLowerCase();
    return allMemories.where((m) {
      return m.content.toLowerCase().contains(queryLower) ||
          m.tags.any((tag) => tag.toLowerCase().contains(queryLower));
    }).toList();
  }

  /// Get memories by source type
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

  /// Get all unique tags across all memories
  List<String> get allTags {
    final tags = <String>{};
    for (final m in allMemories) {
      tags.addAll(m.tags);
    }
    final tagList = tags.toList()..sort();
    return tagList;
  }

  /// Clear all memories
  Future<void> clearAll() async {
    await _box?.clear();
  }
}
