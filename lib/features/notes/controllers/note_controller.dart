import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/note_model.dart';

const _uuid = Uuid();

// ── NoteController ──────────────────────────────────────────────────────────

/// Riverpod [StateNotifier] that owns all [NoteItem] CRUD operations.
///
/// State is a flat list of every note in the local Hive `notesBox`.
/// Pinned notes always sort first, then by [updatedAt] descending.
class NoteController extends StateNotifier<List<NoteItem>> {
  late final Box<NoteItem> _box;

  NoteController() : super([]) {
    _box = Hive.box<NoteItem>('notesBox');
    _refreshState();
  }

  void _refreshState() {
    final all = _box.values.toList();
    // Pinned first, then most-recently-updated first.
    all.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    state = all;
  }

  /// All pinned notes.
  List<NoteItem> get pinnedNotes => state.where((n) => n.isPinned).toList();

  /// All unpinned notes.
  List<NoteItem> get unpinnedNotes => state.where((n) => !n.isPinned).toList();

  /// Notes matching a search query (title, content, or tags).
  List<NoteItem> search(String query) {
    if (query.isEmpty) return state;
    final q = query.toLowerCase();
    return state.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  /// Notes filtered by a specific tag.
  List<NoteItem> byTag(String tag) {
    final t = tag.toLowerCase();
    return state.where((n) => n.tags.any((nt) => nt.toLowerCase() == t)).toList();
  }

  /// All unique tags across all notes, sorted alphabetically.
  List<String> get allTags {
    final tags = <String>{};
    for (final n in state) {
      tags.addAll(n.tags);
    }
    return tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void createNote({
    required String title,
    String content = '',
    List<String> tags = const [],
    List<String> linkedTaskIds = const [],
  }) {
    final now = DateTime.now();
    final note = NoteItem(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags,
      createdAt: now,
      updatedAt: now,
      linkedTaskIds: linkedTaskIds,
    );
    _box.put(note.id, note);
    _refreshState();
  }

  void addNote(NoteItem note) {
    _box.put(note.id, note);
    _refreshState();
  }

  void updateNote(NoteItem updated) {
    _box.put(updated.id, updated.copyWith(updatedAt: DateTime.now()));
    _refreshState();
  }

  void removeNote(String noteId) {
    _box.delete(noteId);
    _refreshState();
  }

  void togglePin(String noteId) {
    final note = _box.get(noteId);
    if (note == null) return;
    _box.put(
      noteId,
      note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now()),
    );
    _refreshState();
  }

  void addTag(String noteId, String tag) {
    final note = _box.get(noteId);
    if (note == null) return;
    if (note.tags.contains(tag)) return;
    _box.put(
      noteId,
      note.copyWith(
        tags: [...note.tags, tag],
        updatedAt: DateTime.now(),
      ),
    );
    _refreshState();
  }

  void removeTag(String noteId, String tag) {
    final note = _box.get(noteId);
    if (note == null) return;
    _box.put(
      noteId,
      note.copyWith(
        tags: note.tags.where((t) => t != tag).toList(),
        updatedAt: DateTime.now(),
      ),
    );
    _refreshState();
  }

  void linkTask(String noteId, String taskId) {
    final note = _box.get(noteId);
    if (note == null) return;
    if (note.linkedTaskIds.contains(taskId)) return;
    _box.put(
      noteId,
      note.copyWith(
        linkedTaskIds: [...note.linkedTaskIds, taskId],
        updatedAt: DateTime.now(),
      ),
    );
    _refreshState();
  }

  void unlinkTask(String noteId, String taskId) {
    final note = _box.get(noteId);
    if (note == null) return;
    _box.put(
      noteId,
      note.copyWith(
        linkedTaskIds: note.linkedTaskIds.where((id) => id != taskId).toList(),
        updatedAt: DateTime.now(),
      ),
    );
    _refreshState();
  }

  /// Sets the AI-generated summary for a note.
  void setSummary(String noteId, String summary) {
    final note = _box.get(noteId);
    if (note == null) return;
    _box.put(
      noteId,
      note.copyWith(summary: summary, updatedAt: DateTime.now()),
    );
    _refreshState();
  }

  void clearAll() {
    _box.clear();
    state = [];
  }
}

final noteControllerProvider =
    StateNotifierProvider<NoteController, List<NoteItem>>(
  (ref) => NoteController(),
);
