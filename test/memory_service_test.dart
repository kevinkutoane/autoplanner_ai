import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:autoplanner_ai/services/memory_service.dart';
import 'package:autoplanner_ai/core/models/memory_entry_model.dart';

// ── Test helpers ─────────────────────────────────────────────────────────────

MemoryEntry _entry({
  required String id,
  String content = 'Test memory content',
  String sourceType = 'user',
  List<String> tags = const [],
  double relevanceScore = 0.5,
  int accessCount = 0,
  DateTime? createdAt,
}) => MemoryEntry(
  id: id,
  content: content,
  sourceType: sourceType,
  tags: tags,
  createdAt: createdAt ?? DateTime.now(),
  relevanceScore: relevanceScore,
  accessCount: accessCount,
);

// ── Suite ─────────────────────────────────────────────────────────────────────

void main() {
  late Directory tempDir;
  late MemoryService service;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('memory_service_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(MemoryEntryAdapter());
    }
  });

  setUp(() async {
    service = MemoryService();
    await service.init(); // open 'memoryBox' without encryption
  });

  tearDown(() async {
    if (Hive.isBoxOpen('memoryBox')) {
      await Hive.box<MemoryEntry>('memoryBox').clear();
      await Hive.box<MemoryEntry>('memoryBox').close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // ── addMemory / allMemories ──────────────────────────────────────────────

  group('MemoryService.addMemory / allMemories', () {
    test('addMemory persists an entry', () async {
      await service.addMemory(
        _entry(id: 'm1', content: 'Deep work prefers mornings'),
      );
      expect(service.allMemories, hasLength(1));
      expect(
        service.allMemories.first.content,
        equals('Deep work prefers mornings'),
      );
    });

    test('allMemories sorts newest createdAt first', () async {
      final old = _entry(id: 'm1', createdAt: DateTime(2024, 1, 1));
      final recent = _entry(id: 'm2', createdAt: DateTime(2025, 6, 1));
      await service.addMemory(old);
      await service.addMemory(recent);
      expect(service.allMemories.first.id, equals('m2'));
      expect(service.allMemories.last.id, equals('m1'));
    });

    test('allMemories returns all persisted entries', () async {
      for (var i = 0; i < 5; i++) {
        await service.addMemory(_entry(id: 'm$i'));
      }
      expect(service.allMemories, hasLength(5));
    });

    test('allMemories returns empty list when nothing added', () {
      expect(service.allMemories, isEmpty);
    });
  });

  // ── recentMemories ───────────────────────────────────────────────────────

  group('MemoryService.recentMemories', () {
    test('returns at most 20 entries from the most recent', () async {
      for (var i = 0; i < 25; i++) {
        await service.addMemory(_entry(id: 'm$i'));
      }
      expect(service.recentMemories.length, lessThanOrEqualTo(20));
    });

    test('returns all entries when fewer than 20 exist', () async {
      for (var i = 0; i < 5; i++) {
        await service.addMemory(_entry(id: 'm$i'));
      }
      expect(service.recentMemories.length, equals(5));
    });
  });

  // ── contextMemories ──────────────────────────────────────────────────────

  group('MemoryService.contextMemories', () {
    test('respects the limit parameter', () async {
      for (var i = 0; i < 20; i++) {
        await service.addMemory(_entry(id: 'm$i', relevanceScore: 0.5));
      }
      expect(service.contextMemories(limit: 5).length, lessThanOrEqualTo(5));
    });

    test('higher-relevance-score entries rank first', () async {
      await service.addMemory(_entry(id: 'low', relevanceScore: 0.1));
      await service.addMemory(_entry(id: 'high', relevanceScore: 0.9));
      expect(service.contextMemories(limit: 10).first.id, equals('high'));
    });

    test('returns empty list when nothing stored', () {
      expect(service.contextMemories(), isEmpty);
    });
  });

  // ── searchMemories ───────────────────────────────────────────────────────

  group('MemoryService.searchMemories', () {
    setUp(() async {
      await service.addMemory(
        _entry(id: 'm1', content: 'User prefers morning deep work'),
      );
      await service.addMemory(
        _entry(id: 'm2', content: 'Evening gym sessions work best'),
      );
      await service.addMemory(
        _entry(
          id: 'm3',
          content: 'Weekly planning on Mondays',
          tags: ['planning'],
        ),
      );
    });

    test('finds entry by content keyword', () {
      final results = service.searchMemories('morning');
      expect(results, hasLength(1));
      expect(results.first.id, equals('m1'));
    });

    test('search is case-insensitive', () {
      expect(service.searchMemories('MORNING'), hasLength(1));
      expect(service.searchMemories('morning'), hasLength(1));
    });

    test('returns empty list when no match found', () {
      expect(service.searchMemories('dentist'), isEmpty);
    });

    test('finds entry by tag keyword', () {
      final results = service.searchMemories('planning');
      expect(results.any((m) => m.id == 'm3'), isTrue);
    });

    test('matches partial content substring', () {
      expect(service.searchMemories('gym'), hasLength(1));
    });
  });

  // ── getByTag ─────────────────────────────────────────────────────────────

  group('MemoryService.getByTag', () {
    setUp(() async {
      await service.addMemory(_entry(id: 'm1', tags: const ['work', 'focus']));
      await service.addMemory(_entry(id: 'm2', tags: const ['personal']));
      await service.addMemory(_entry(id: 'm3', tags: const ['work']));
    });

    test('returns entries with matching tag', () {
      final results = service.getByTag('work');
      expect(results.length, equals(2));
      expect(results.map((m) => m.id).toSet(), containsAll(['m1', 'm3']));
    });

    test('tag matching is case-insensitive', () {
      expect(service.getByTag('WORK'), hasLength(2));
    });

    test('returns empty list when no entry has the tag', () {
      expect(service.getByTag('health'), isEmpty);
    });

    test('finds entry by one of multiple tags', () {
      final results = service.getByTag('focus');
      expect(results, hasLength(1));
      expect(results.first.id, equals('m1'));
    });
  });

  // ── getBySourceType ──────────────────────────────────────────────────────

  group('MemoryService.getBySourceType', () {
    setUp(() async {
      await service.addMemory(_entry(id: 'm1', sourceType: 'task'));
      await service.addMemory(_entry(id: 'm2', sourceType: 'note'));
      await service.addMemory(_entry(id: 'm3', sourceType: 'task'));
    });

    test('returns all entries with matching sourceType', () {
      expect(service.getBySourceType('task'), hasLength(2));
    });

    test('returns empty list when sourceType not found', () {
      expect(service.getBySourceType('calendar'), isEmpty);
    });

    test('returns exact single match', () {
      expect(service.getBySourceType('note'), hasLength(1));
    });
  });

  // ── reinforceMemory ──────────────────────────────────────────────────────

  group('MemoryService.reinforceMemory', () {
    test('boosts the relevance score by the given amount', () async {
      await service.addMemory(_entry(id: 'm1', relevanceScore: 0.5));
      await service.reinforceMemory('m1', boost: 0.2);
      final updated = service.allMemories.firstWhere((m) => m.id == 'm1');
      expect(updated.relevanceScore, closeTo(0.7, 0.001));
    });

    test('relevance score is clamped to 1.0 on overflow', () async {
      await service.addMemory(_entry(id: 'm1', relevanceScore: 0.9));
      await service.reinforceMemory('m1', boost: 0.5);
      final updated = service.allMemories.firstWhere((m) => m.id == 'm1');
      expect(updated.relevanceScore, lessThanOrEqualTo(1.0));
    });

    test('uses default boost value (0.1) when not specified', () async {
      await service.addMemory(_entry(id: 'm1', relevanceScore: 0.5));
      await service.reinforceMemory('m1');
      final updated = service.allMemories.firstWhere((m) => m.id == 'm1');
      expect(updated.relevanceScore, closeTo(0.6, 0.001));
    });

    test('is a no-op for a non-existent id (no exception)', () async {
      await service.addMemory(_entry(id: 'm1', relevanceScore: 0.5));
      await expectLater(
        service.reinforceMemory('does-not-exist', boost: 0.2),
        completes,
      );
      // Original unreinforced.
      expect(service.allMemories.first.relevanceScore, closeTo(0.5, 0.001));
    });
  });

  // ── markAccessed ─────────────────────────────────────────────────────────

  group('MemoryService.markAccessed', () {
    test('increments accessCount for every provided entry', () async {
      await service.addMemory(_entry(id: 'm1', accessCount: 0));
      await service.addMemory(_entry(id: 'm2', accessCount: 2));
      final entries = service.allMemories;
      await service.markAccessed(entries);
      final updated = service.allMemories;
      expect(updated.firstWhere((m) => m.id == 'm1').accessCount, equals(1));
      expect(updated.firstWhere((m) => m.id == 'm2').accessCount, equals(3));
    });

    test('is a no-op for an empty list (no exception)', () async {
      await expectLater(service.markAccessed([]), completes);
    });
  });

  // ── decayStaleMemories ───────────────────────────────────────────────────

  group('MemoryService.decayStaleMemories', () {
    test('removes old never-accessed low-score entries', () async {
      final stale = _entry(
        id: 'stale',
        createdAt: DateTime(2020, 1, 1), // well past 90 days
        relevanceScore: 0.01,
        accessCount: 0,
      );
      final fresh = _entry(id: 'fresh'); // today — not stale
      await service.addMemory(stale);
      await service.addMemory(fresh);

      final removed = await service.decayStaleMemories(
        thresholdDays: 90,
        threshold: 0.05,
      );

      expect(removed, equals(1));
      expect(service.allMemories.any((m) => m.id == 'stale'), isFalse);
      expect(service.allMemories.any((m) => m.id == 'fresh'), isTrue);
    });

    test('does not remove an entry that has been accessed', () async {
      final accessed = _entry(
        id: 'accessed',
        createdAt: DateTime(2020, 1, 1),
        relevanceScore: 0.01,
        accessCount: 3, // accessed — exempt from decay
      );
      await service.addMemory(accessed);
      final removed = await service.decayStaleMemories();
      expect(removed, equals(0));
      expect(service.allMemories, hasLength(1));
    });

    test('does not remove fresh entries even with low score', () async {
      final fresh = _entry(
        id: 'fresh',
        createdAt: DateTime.now(),
        relevanceScore: 0.01,
        accessCount: 0,
      );
      await service.addMemory(fresh);
      final removed = await service.decayStaleMemories();
      expect(removed, equals(0));
    });
  });

  // ── allTags ──────────────────────────────────────────────────────────────

  group('MemoryService.allTags', () {
    test('returns unique, sorted tags across all entries', () async {
      await service.addMemory(_entry(id: 'm1', tags: const ['work', 'focus']));
      await service.addMemory(
        _entry(id: 'm2', tags: const ['personal', 'work']),
      );

      final tags = service.allTags;
      expect(tags.toSet(), equals({'work', 'focus', 'personal'}));
      // Must be sorted.
      final sorted = List<String>.from(tags)..sort();
      expect(tags, equals(sorted));
    });

    test('returns empty list when no entries exist', () {
      expect(service.allTags, isEmpty);
    });
  });

  // ── clearAll ─────────────────────────────────────────────────────────────

  group('MemoryService.clearAll', () {
    test('removes all persisted entries', () async {
      await service.addMemory(_entry(id: 'm1'));
      await service.addMemory(_entry(id: 'm2'));
      await service.clearAll();
      expect(service.allMemories, isEmpty);
    });

    test('is safe to call on an empty store (no exception)', () async {
      await expectLater(service.clearAll(), completes);
    });
  });

  // ── deleteMemory ─────────────────────────────────────────────────────────

  group('MemoryService.deleteMemory', () {
    test('removes the entry with the given id', () async {
      await service.addMemory(_entry(id: 'm1'));
      await service.addMemory(_entry(id: 'm2'));
      await service.deleteMemory('m1');
      expect(service.allMemories.any((m) => m.id == 'm1'), isFalse);
      expect(service.allMemories.any((m) => m.id == 'm2'), isTrue);
    });

    test('is a no-op when id does not exist', () async {
      await service.addMemory(_entry(id: 'm1'));
      await expectLater(service.deleteMemory('nonexistent'), completes);
      expect(service.allMemories, hasLength(1));
    });
  });
}
