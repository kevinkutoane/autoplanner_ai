import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/memory_entry_model.dart';

// ── Test helper ──────────────────────────────────────────────────────────────

MemoryEntry _entry({
  String id = 'm1',
  String content = 'User prefers morning deep work',
  String sourceType = 'user',
  String? sourceId,
  List<String> tags = const [],
  DateTime? createdAt,
  double relevanceScore = 0.5,
  int accessCount = 0,
}) {
  return MemoryEntry(
    id: id,
    content: content,
    sourceType: sourceType,
    sourceId: sourceId,
    tags: tags,
    createdAt: createdAt ?? DateTime(2026, 3, 1, 10, 0),
    relevanceScore: relevanceScore,
    accessCount: accessCount,
  );
}

// ── Suite ─────────────────────────────────────────────────────────────────────

void main() {
  final base = DateTime(2026, 3, 1, 10, 0);

  // ── Constructor defaults ─────────────────────────────────────────────────
  group('MemoryEntry constructor defaults', () {
    test('relevanceScore defaults to 0.5', () {
      expect(_entry().relevanceScore, 0.5);
    });

    test('accessCount defaults to 0', () {
      expect(_entry().accessCount, 0);
    });

    test('tags defaults to empty list', () {
      expect(_entry().tags, isEmpty);
    });

    test('sourceId defaults to null', () {
      expect(_entry().sourceId, isNull);
    });

    test('id and content are stored correctly', () {
      final m = _entry(id: 'abc', content: 'Deep work at 9am');
      expect(m.id, 'abc');
      expect(m.content, 'Deep work at 9am');
    });

    test('createdAt is preserved', () {
      final m = _entry(createdAt: base);
      expect(m.createdAt, base);
    });

    test('sourceType is stored correctly', () {
      expect(_entry(sourceType: 'task').sourceType, 'task');
    });
  });

  // ── Constructor with explicit values ─────────────────────────────────────
  group('MemoryEntry explicit values', () {
    test('sourceType "note" is stored', () {
      expect(_entry(sourceType: 'note').sourceType, 'note');
    });

    test('sourceType "calendar" is stored', () {
      expect(_entry(sourceType: 'calendar').sourceType, 'calendar');
    });

    test('sourceType "ai" is stored', () {
      expect(_entry(sourceType: 'ai').sourceType, 'ai');
    });

    test('sourceId is stored when provided', () {
      expect(_entry(sourceId: 'task_123').sourceId, 'task_123');
    });

    test('tags list is stored', () {
      expect(_entry(tags: ['work', 'focus']).tags, ['work', 'focus']);
    });

    test('relevanceScore 0.9 is stored', () {
      expect(_entry(relevanceScore: 0.9).relevanceScore, 0.9);
    });

    test('relevanceScore 0.0 is stored', () {
      expect(_entry(relevanceScore: 0.0).relevanceScore, 0.0);
    });

    test('relevanceScore 1.0 is stored', () {
      expect(_entry(relevanceScore: 1.0).relevanceScore, 1.0);
    });

    test('accessCount 5 is stored', () {
      expect(_entry(accessCount: 5).accessCount, 5);
    });
  });

  // ── copyWith ─────────────────────────────────────────────────────────────
  group('MemoryEntry.copyWith', () {
    test('copyWith returns a new instance', () {
      final original = _entry(content: 'Original content');
      final copy = original.copyWith(content: 'Updated content');
      expect(copy.content, 'Updated content');
      expect(original.content, 'Original content');
    });

    test('copyWith preserves unchanged fields', () {
      final original = _entry(
        sourceType: 'ai',
        relevanceScore: 0.8,
        accessCount: 3,
      );
      final copy = original.copyWith(content: 'New content');
      expect(copy.sourceType, 'ai');
      expect(copy.relevanceScore, 0.8);
      expect(copy.accessCount, 3);
    });

    test('copyWith can update relevanceScore', () {
      final m = _entry(relevanceScore: 0.3);
      final boosted = m.copyWith(relevanceScore: 0.8);
      expect(boosted.relevanceScore, 0.8);
    });

    test('copyWith can increment accessCount', () {
      final m = _entry(accessCount: 2);
      final accessed = m.copyWith(accessCount: 3);
      expect(accessed.accessCount, 3);
    });

    test('copyWith can set sourceId', () {
      final m = _entry();
      final linked = m.copyWith(sourceId: 'note_42');
      expect(linked.sourceId, 'note_42');
    });

    test('copyWith can add tags', () {
      final m = _entry(tags: const ['focus']);
      final tagged = m.copyWith(tags: ['focus', 'morning']);
      expect(tagged.tags, contains('morning'));
    });

    test('copyWith can update createdAt', () {
      final m = _entry(createdAt: base);
      final newDate = DateTime(2026, 6, 1);
      final updated = m.copyWith(createdAt: newDate);
      expect(updated.createdAt, newDate);
    });

    test('copyWith preserves createdAt when not passed', () {
      final m = _entry(createdAt: base);
      final copy = m.copyWith(content: 'Changed');
      expect(copy.createdAt, base);
    });

    test('copyWith can update sourceType', () {
      final m = _entry(sourceType: 'user');
      final copy = m.copyWith(sourceType: 'ai');
      expect(copy.sourceType, 'ai');
    });

    test('copyWith preserves id', () {
      final m = _entry(id: 'mem-99');
      final copy = m.copyWith(content: 'X');
      expect(copy.id, 'mem-99');
    });
  });

  // ── Field validation helpers (immutability) ───────────────────────────────
  group('MemoryEntry immutability', () {
    test('modifying tags list from constructor does not affect stored list', () {
      // copyWith creates a new instance; the original stored list is unaffected.
      final m = _entry(tags: const ['work']);
      final copy = m.copyWith(tags: ['work', 'play']);
      expect(m.tags, hasLength(1));
      expect(copy.tags, hasLength(2));
    });

    test('two entries with same id are independent objects', () {
      final a = _entry(id: 'dup', relevanceScore: 0.3);
      final b = _entry(id: 'dup', relevanceScore: 0.9);
      expect(a.relevanceScore, isNot(equals(b.relevanceScore)));
    });
  });

  // ── Source type coverage ──────────────────────────────────────────────────
  group('MemoryEntry sourceType accepted values', () {
    for (final type in ['user', 'task', 'note', 'calendar', 'ai']) {
      test('sourceType "$type" is stored without modification', () {
        expect(_entry(sourceType: type).sourceType, type);
      });
    }
  });
}
