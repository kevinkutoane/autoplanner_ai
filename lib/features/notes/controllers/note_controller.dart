import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/note_model.dart';
import '../../../core/providers/providers.dart';
import '../../../services/notification_service.dart';

const _uuid = Uuid();

/// Riverpod [StateNotifier] that owns all [NoteItem] CRUD and notification wiring.
///
/// State is a flat list of every note in the local Hive box. Pinned notes are
/// sorted to the top, followed by creation-date descending.
class NoteController extends StateNotifier<List<NoteItem>> {
  late final Box<NoteItem> _box;
  final NotificationService _notifications;

  NoteController({required NotificationService notifications})
      : _notifications = notifications,
        super([]) {
    _box = Hive.box<NoteItem>('notesBox');
    _refreshState();
  }

  void _refreshState() {
    final all = _box.values.toList();
    all.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    state = all;
  }

  List<NoteItem> get pinnedNotes => state.where((n) => n.isPinned).toList();

  List<NoteItem> get unpinnedNotes => state.where((n) => !n.isPinned).toList();

  List<NoteItem> search(String query) {
    if (query.isEmpty) return state;
    final q = query.toLowerCase();
    return state.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  List<NoteItem> byTag(String tag) {
    final t = tag.toLowerCase();
    return state.where((n) => n.tags.any((nt) => nt.toLowerCase() == t)).toList();
  }

  List<String> get allTags {
    final tags = <String>{};
    for (final n in state) {
      tags.addAll(n.tags);
    }
    return tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void addNote(NoteItem note) {
    _box.put(note.id, note);
    _refreshState();
    _scheduleNotifications(note);
  }

  void createNote({
    required String title,
    String content = '',
    List<String> tags = const [],
    List<String> linkedTaskIds = const [],
    bool isPinned = false,
    bool isUrgent = false,
    DateTime? reminderAt,
  }) {
    final now = DateTime.now();
    final note = NoteItem(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags,
      linkedTaskIds: linkedTaskIds,
      createdAt: now,
      updatedAt: now,
      isPinned: isPinned,
      isUrgent: isUrgent,
      reminderAt: reminderAt,
    );
    _box.put(note.id, note);
    _refreshState();
    _scheduleNotifications(note);
  }

  void updateNote(NoteItem updated) {
    final existing = _box.get(updated.id);
    _box.put(updated.id, updated.copyWith(updatedAt: DateTime.now()));
    _refreshState();

    _cancelNotifications(updated.id);
    _scheduleNotifications(updated);

    final wasUrgent = existing?.isUrgent ?? false;
    if (updated.isUrgent && !wasUrgent) {
      _notifications.scheduleUrgentAlert(
        id: 'note_${updated.id}',
        title: updated.title,
        body: 'Note marked as Urgent.',
      );
    }
  }

  void removeNote(String id) {
    _box.delete(id);
    _refreshState();
    _cancelNotifications(id);
  }

  void togglePin(String id) {
    final note = _box.get(id);
    if (note == null) return;
    _box.put(id, note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now()));
    _refreshState();
  }

  void toggleUrgent(String id) {
    final note = _box.get(id);
    if (note == null) return;
    final updated = note.copyWith(isUrgent: !note.isUrgent, updatedAt: DateTime.now());
    _box.put(id, updated);
    _refreshState();
    if (updated.isUrgent) {
      _notifications.scheduleUrgentAlert(
        id: 'note_${updated.id}',
        title: updated.title,
        body: 'Note marked as Urgent.',
      );
    } else {
      _cancelNotifications(id);
      _scheduleNotifications(updated);
    }
  }

  void addTag(String noteId, String tag) {
    final note = _box.get(noteId);
    if (note == null) return;
    if (note.tags.contains(tag)) return;
    _box.put(
      noteId,
      note.copyWith(tags: [...note.tags, tag], updatedAt: DateTime.now()),
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

  void _scheduleNotifications(NoteItem note) {
    if (note.isUrgent) {
      _notifications.scheduleUrgentAlert(
        id: 'note_${note.id}',
        title: note.title,
        body: 'Urgent note requires your attention.',
      );
    }
    if (note.reminderAt != null) {
      _notifications.scheduleNoteReminder(note);
    }
  }

  void _cancelNotifications(String noteId) {
    _notifications.cancelNoteReminder(noteId);
  }
}

final noteControllerProvider =
    StateNotifierProvider<NoteController, List<NoteItem>>(
  (ref) => NoteController(notifications: ref.read(notificationServiceProvider)),
);

/// Alias for backward compatibility — screens that still reference the old name.
final notesControllerProvider = noteControllerProvider;
