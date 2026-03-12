import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/note_model.dart';

void main() {
  final now = DateTime(2026, 3, 12, 10, 0);

  NoteItem makeNote({
    String id = 'n1',
    String title = 'Test note',
    String content = 'Note content',
    bool isPinned = false,
    List<String> tags = const [],
    List<String> linkedTaskIds = const [],
    String? summary,
  }) => NoteItem(
    id: id,
    title: title,
    content: content,
    summary: summary,
    tags: tags,
    createdAt: now,
    updatedAt: now,
    linkedTaskIds: linkedTaskIds,
    isPinned: isPinned,
  );

  group('NoteItem constructor defaults', () {
    test('isPinned defaults to false', () {
      expect(makeNote().isPinned, isFalse);
    });

    test('tags defaults to empty list', () {
      expect(makeNote().tags, isEmpty);
    });

    test('linkedTaskIds defaults to empty list', () {
      expect(makeNote().linkedTaskIds, isEmpty);
    });

    test('summary defaults to null', () {
      expect(makeNote().summary, isNull);
    });

    test('createdAt and updatedAt are preserved', () {
      final note = makeNote();
      expect(note.createdAt, equals(now));
      expect(note.updatedAt, equals(now));
    });
  });

  group('NoteItem.copyWith', () {
    test('copyWith returns new instance with updated title', () {
      final original = makeNote(title: 'Original');
      final copy = original.copyWith(title: 'Updated');
      expect(copy.title, equals('Updated'));
      expect(original.title, equals('Original'));
    });

    test('copyWith preserves unchanged fields', () {
      final original = makeNote(content: 'Keep this');
      final copy = original.copyWith(title: 'New title');
      expect(copy.content, equals('Keep this'));
    });

    test('copyWith can pin a note', () {
      final note = makeNote(isPinned: false);
      final pinned = note.copyWith(isPinned: true);
      expect(pinned.isPinned, isTrue);
    });

    test('copyWith can set linkedTaskIds', () {
      final note = makeNote();
      final linked = note.copyWith(linkedTaskIds: ['t1', 't2']);
      expect(linked.linkedTaskIds, equals(['t1', 't2']));
    });

    test('copyWith can add tags', () {
      final note = makeNote();
      final tagged = note.copyWith(tags: ['work', 'ideas']);
      expect(tagged.tags, equals(['work', 'ideas']));
    });

    test('copyWith can set summary', () {
      final note = makeNote();
      final withSummary = note.copyWith(summary: 'A short summary');
      expect(withSummary.summary, equals('A short summary'));
    });

    test('copyWith preserves summary when not passed', () {
      final note = makeNote(summary: 'existing');
      final copy = note.copyWith(title: 'Updated');
      expect(copy.summary, equals('existing'));
    });
  });
}
