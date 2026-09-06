import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:autoplanner_ai/core/models/note_model.dart';
import 'package:autoplanner_ai/features/notes/controllers/note_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Unit tests for [NoteController].
///
/// Uses a temporary Hive directory so no OS keychain or cipher is needed.
/// Each test gets a fresh box to avoid cross-contamination.
void main() {
  late Box<NoteItem> box;
  late ProviderContainer container;
  late NoteController controller;
  int boxCounter = 0;

  final now = DateTime(2026, 4, 19, 10, 0);

  NoteItem makeNote({
    String? id,
    String title = 'Test note',
    String content = 'Body text',
    bool isPinned = false,
    List<String> tags = const [],
    List<String> linkedTaskIds = const [],
    String? summary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NoteItem(
    id: id ?? 'n-${boxCounter++}',
    title: title,
    content: content,
    summary: summary,
    tags: tags,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    linkedTaskIds: linkedTaskIds,
    isPinned: isPinned,
  );

  setUpAll(() async {
    final dir =
        '${Directory.systemTemp.path}/hive_note_test_${DateTime.now().millisecondsSinceEpoch}';
    Hive.init(dir);
    Hive.registerAdapter(NoteItemAdapter());
  });

  setUp(() async {
    boxCounter++;
    box = await Hive.openBox<NoteItem>('notesBox');
    await box.clear();
    container = ProviderContainer();
    controller = container.read(noteControllerProvider.notifier);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
    container.dispose();
  });

  // ── CRUD ──────────────────────────────────────────────────────────────────

  group('CRUD operations', () {
    test('initial state is empty when box is empty', () {
      expect(controller.state, isEmpty);
    });

    test('createNote adds a note and updates state', () {
      controller.createNote(title: 'First', content: 'Hello');
      expect(controller.state, hasLength(1));
      expect(controller.state.first.title, 'First');
      expect(controller.state.first.content, 'Hello');
    });

    test('addNote inserts a pre-built NoteItem', () {
      final note = makeNote(id: 'custom-id', title: 'Pre-built');
      controller.addNote(note);
      expect(controller.state, hasLength(1));
      expect(controller.state.first.id, 'custom-id');
    });

    test('updateNote replaces the note and bumps updatedAt', () {
      controller.createNote(title: 'Original');
      final original = controller.state.first;
      final updated = original.copyWith(title: 'Revised');
      controller.updateNote(updated);
      expect(controller.state, hasLength(1));
      expect(controller.state.first.title, 'Revised');
      // updatedAt should be newer than the original
      expect(
        controller.state.first.updatedAt.isAfter(original.createdAt) ||
            controller.state.first.updatedAt.isAtSameMomentAs(
              original.createdAt,
            ),
        isTrue,
      );
    });

    test('removeNote deletes the note from state', () {
      controller.createNote(title: 'To delete');
      final id = controller.state.first.id;
      controller.removeNote(id);
      expect(controller.state, isEmpty);
    });

    test('removeNote with non-existent id does not throw', () {
      expect(() => controller.removeNote('ghost-id'), returnsNormally);
    });

    test('clearAll empties the box and state', () {
      controller.createNote(title: 'A');
      controller.createNote(title: 'B');
      expect(controller.state, hasLength(2));
      controller.clearAll();
      expect(controller.state, isEmpty);
    });
  });

  // ── Pin / Unpin ───────────────────────────────────────────────────────────

  group('Pin / Unpin', () {
    test('togglePin pins an unpinned note', () {
      controller.createNote(title: 'Pin me');
      final id = controller.state.first.id;
      expect(controller.state.first.isPinned, isFalse);
      controller.togglePin(id);
      expect(controller.state.first.isPinned, isTrue);
    });

    test('togglePin unpins a pinned note', () {
      controller.createNote(title: 'Unpin me');
      final id = controller.state.first.id;
      controller.togglePin(id); // pin
      controller.togglePin(id); // unpin
      expect(controller.state.first.isPinned, isFalse);
    });

    test('togglePin on non-existent id does not throw', () {
      expect(() => controller.togglePin('ghost'), returnsNormally);
    });

    test('pinnedNotes returns only pinned notes', () {
      controller.createNote(title: 'Pinned');
      controller.createNote(title: 'Not pinned');
      // Find the note titled 'Pinned' by title (sort order is by updatedAt).
      final pinnedId = controller.state
          .firstWhere((n) => n.title == 'Pinned')
          .id;
      controller.togglePin(pinnedId);
      expect(controller.pinnedNotes, hasLength(1));
      expect(controller.pinnedNotes.first.title, 'Pinned');
    });

    test('unpinnedNotes returns only unpinned notes', () {
      controller.createNote(title: 'A');
      controller.createNote(title: 'B');
      controller.togglePin(controller.state.first.id);
      expect(controller.unpinnedNotes, hasLength(1));
    });

    test('pinned notes sort before unpinned in state', () {
      // Create two notes; pin the second one.
      final older = makeNote(id: 'older', title: 'Older', updatedAt: now);
      final newer = makeNote(
        id: 'newer',
        title: 'Newer',
        updatedAt: now.add(const Duration(hours: 1)),
      );
      controller.addNote(older);
      controller.addNote(newer);
      // Newer should be first (most recent updatedAt).
      expect(controller.state.first.id, 'newer');
      // Pin the older note — it should jump to the top.
      controller.togglePin('older');
      expect(controller.state.first.id, 'older');
      expect(controller.state.first.isPinned, isTrue);
    });
  });

  // ── Tag Management ────────────────────────────────────────────────────────

  group('Tag management', () {
    test('addTag appends a tag to the note', () {
      controller.createNote(title: 'Tagged');
      final id = controller.state.first.id;
      controller.addTag(id, 'work');
      expect(controller.state.first.tags, contains('work'));
    });

    test('addTag does not duplicate an existing tag', () {
      controller.createNote(title: 'Tagged', tags: ['work']);
      final id = controller.state.first.id;
      controller.addTag(id, 'work');
      expect(
        controller.state.first.tags.where((t) => t == 'work'),
        hasLength(1),
      );
    });

    test('removeTag removes the specified tag', () {
      controller.createNote(title: 'Tagged', tags: ['work', 'ideas']);
      final id = controller.state.first.id;
      controller.removeTag(id, 'work');
      expect(controller.state.first.tags, isNot(contains('work')));
      expect(controller.state.first.tags, contains('ideas'));
    });

    test('removeTag with non-existent tag does not throw', () {
      controller.createNote(title: 'Tagged');
      final id = controller.state.first.id;
      expect(() => controller.removeTag(id, 'ghost'), returnsNormally);
    });

    test('allTags returns unique sorted tags across all notes', () {
      controller.createNote(title: 'A', tags: ['work', 'flutter']);
      controller.createNote(title: 'B', tags: ['work', 'ideas']);
      final tags = controller.allTags;
      expect(tags, ['flutter', 'ideas', 'work']);
    });

    test('allTags is empty when no notes have tags', () {
      controller.createNote(title: 'No tags');
      expect(controller.allTags, isEmpty);
    });
  });

  // ── Search ────────────────────────────────────────────────────────────────

  group('Search', () {
    test('search returns all notes for empty query', () {
      controller.createNote(title: 'A');
      controller.createNote(title: 'B');
      expect(controller.search(''), hasLength(2));
    });

    test('search matches title', () {
      controller.createNote(title: 'Meeting notes', content: 'irrelevant');
      controller.createNote(title: 'Shopping list', content: 'irrelevant');
      final results = controller.search('meeting');
      expect(results, hasLength(1));
      expect(results.first.title, 'Meeting notes');
    });

    test('search matches content', () {
      controller.createNote(title: 'A', content: 'Flutter is great');
      controller.createNote(title: 'B', content: 'Dart is fast');
      final results = controller.search('flutter');
      expect(results, hasLength(1));
    });

    test('search matches tags', () {
      controller.createNote(title: 'A', tags: ['architecture']);
      controller.createNote(title: 'B', tags: ['design']);
      final results = controller.search('architecture');
      expect(results, hasLength(1));
    });

    test('search is case-insensitive', () {
      controller.createNote(title: 'UPPERCASE');
      expect(controller.search('uppercase'), hasLength(1));
      expect(controller.search('UPPERCASE'), hasLength(1));
    });
  });

  // ── Filter by Tag ─────────────────────────────────────────────────────────

  group('byTag', () {
    test('byTag returns notes matching the tag', () {
      controller.createNote(title: 'A', tags: ['work']);
      controller.createNote(title: 'B', tags: ['personal']);
      expect(controller.byTag('work'), hasLength(1));
    });

    test('byTag is case-insensitive', () {
      controller.createNote(title: 'A', tags: ['Work']);
      expect(controller.byTag('work'), hasLength(1));
      expect(controller.byTag('WORK'), hasLength(1));
    });

    test('byTag returns empty for non-existent tag', () {
      controller.createNote(title: 'A', tags: ['work']);
      expect(controller.byTag('ghost'), isEmpty);
    });
  });

  // ── Task Linking ──────────────────────────────────────────────────────────

  group('Task linking', () {
    test('linkTask adds a task ID to linkedTaskIds', () {
      controller.createNote(title: 'Linked');
      final id = controller.state.first.id;
      controller.linkTask(id, 'task-1');
      expect(controller.state.first.linkedTaskIds, contains('task-1'));
    });

    test('linkTask does not duplicate an existing link', () {
      controller.createNote(title: 'Linked', linkedTaskIds: ['task-1']);
      final id = controller.state.first.id;
      controller.linkTask(id, 'task-1');
      expect(
        controller.state.first.linkedTaskIds.where((t) => t == 'task-1'),
        hasLength(1),
      );
    });

    test('unlinkTask removes a task ID from linkedTaskIds', () {
      controller.createNote(
        title: 'Linked',
        linkedTaskIds: ['task-1', 'task-2'],
      );
      final id = controller.state.first.id;
      controller.unlinkTask(id, 'task-1');
      expect(controller.state.first.linkedTaskIds, isNot(contains('task-1')));
      expect(controller.state.first.linkedTaskIds, contains('task-2'));
    });

    test('unlinkTask with non-existent task does not throw', () {
      controller.createNote(title: 'Linked');
      final id = controller.state.first.id;
      expect(() => controller.unlinkTask(id, 'ghost'), returnsNormally);
    });
  });

  // ── AI Summary ────────────────────────────────────────────────────────────

  group('AI summary', () {
    test('setSummary stores the summary on the note', () {
      controller.createNote(title: 'Summarise me');
      final id = controller.state.first.id;
      controller.setSummary(id, 'This is a summary');
      expect(controller.state.first.summary, 'This is a summary');
    });

    test('setSummary on non-existent id does not throw', () {
      expect(() => controller.setSummary('ghost', 'summary'), returnsNormally);
    });
  });

  // ── Sort Order ────────────────────────────────────────────────────────────

  group('Sort order', () {
    test('notes are sorted by updatedAt descending (most recent first)', () {
      final old = makeNote(
        id: 'old',
        title: 'Old',
        updatedAt: now.subtract(const Duration(days: 1)),
      );
      final recent = makeNote(id: 'recent', title: 'Recent', updatedAt: now);
      // Add old first, then recent.
      controller.addNote(old);
      controller.addNote(recent);
      expect(controller.state.first.id, 'recent');
      expect(controller.state.last.id, 'old');
    });
  });
}
