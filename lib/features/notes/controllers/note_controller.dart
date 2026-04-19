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
      return b.createdAt.compareTo(a.createdAt);
    });
    state = all;
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  void addNote(NoteItem note) {
    _box.put(note.id, note);
    _refreshState();
    _scheduleNotifications(note);
  }

  /// Creates a new note with auto-generated id and timestamps.
  void createNote({
    required String title,
    required String content,
    List<String> tags = const [],
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

    // Cancel any previously scheduled notifications, then re-evaluate.
    _cancelNotifications(updated.id);
    _scheduleNotifications(updated);

    // Fire an urgent alert if urgency was just turned on.
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
      // No active notification to cancel for urgent (it was immediate), but
      // cancel the reminder if one was pending.
      _cancelNotifications(id);
      _scheduleNotifications(updated);
    }
  }

  // ── Notification helpers ──────────────────────────────────────────────────

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

final notesControllerProvider =
    StateNotifierProvider<NoteController, List<NoteItem>>(
  (ref) => NoteController(notifications: ref.read(notificationServiceProvider)),
);
