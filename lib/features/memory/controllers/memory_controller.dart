import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/models/memory_entry_model.dart';

class MemoryController extends StateNotifier<List<MemoryEntry>> {
  Box<MemoryEntry>? _box;

  MemoryController() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<MemoryEntry>('memoryBox');
    _refreshState();
  }

  List<MemoryEntry> get recentMemories => state.take(20).toList();

  List<String> get allTags {
    final tags = <String>{};
    for (final m in state) {
      tags.addAll(m.tags);
    }
    return tags.toList()..sort();
  }

  Map<String, int> get tagCounts {
    final counts = <String, int>{};
    for (final m in state) {
      for (final tag in m.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<MemoryEntry> searchMemories(String query) {
    final q = query.toLowerCase();
    return state.where((m) {
      return m.content.toLowerCase().contains(q) ||
          m.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  List<MemoryEntry> getByTag(String tag) {
    return state
        .where((m) => m.tags.any((t) => t.toLowerCase() == tag.toLowerCase()))
        .toList();
  }

  List<MemoryEntry> getBySourceType(String sourceType) {
    return state.where((m) => m.sourceType == sourceType).toList();
  }

  void addMemory(MemoryEntry entry) {
    if (_box == null) return;
    _box!.put(entry.id, entry);
    _refreshState();
  }

  void deleteMemory(String id) {
    if (_box == null) return;
    _box!.delete(id);
    _refreshState();
  }

  void clearAll() {
    if (_box == null) return;
    _box!.clear();
    state = [];
  }

  void _refreshState() {
    state = _box!.values.toList()
      ..sort((a, b) {
        // Primary: highest relevance score first.
        final scoreDiff = b.relevanceScore.compareTo(a.relevanceScore);
        if (scoreDiff != 0) return scoreDiff;
        // Secondary: most recent first as tiebreaker.
        return b.createdAt.compareTo(a.createdAt);
      });
  }
}

final memoryControllerProvider =
    StateNotifierProvider<MemoryController, List<MemoryEntry>>(
      (ref) => MemoryController(),
    );
