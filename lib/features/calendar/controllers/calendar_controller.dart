import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/models/calendar_event_model.dart';
import '../../../core/models/task_model.dart';
import '../../../core/providers/providers.dart';
import '../../../services/conflict_detector.dart';
import '../../../services/calendar_sync_service.dart';

class CalendarController extends StateNotifier<List<CalendarEvent>> {
  Box<CalendarEvent>? _box;
  final ConflictDetector _conflictDetector;
  final CalendarSyncService _syncService;

  CalendarController({
    required ConflictDetector conflictDetector,
    required CalendarSyncService syncService,
  }) : _conflictDetector = conflictDetector,
       _syncService = syncService,
       super([]) {
    // Box is pre-opened in main() before runApp — grab it synchronously.
    _box = Hive.box<CalendarEvent>('calendarBox');
    _refreshState();
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return state.where((event) {
      return event.startTime.year == day.year &&
          event.startTime.month == day.month &&
          event.startTime.day == day.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// All overlapping-time conflict pairs across all events.
  List<ConflictPair> get conflicts =>
      _conflictDetector.detectTimeOverlaps(state);

  /// All events that have a sync conflict with the remote provider.
  List<CalendarEvent> get syncConflicts =>
      _conflictDetector.detectSyncConflicts(state);

  /// Resolve a sync conflict by accepting the local version and pushing it.
  Future<void> resolveConflictKeepLocal(CalendarEvent event) async {
    if (_box == null) return;
    event
      ..syncStatus = 'pending_push'
      ..save();
    _refreshState();
    try {
      await _syncService.pushEvent(event);
    } catch (e) {
      if (kDebugMode) debugPrint('resolveConflictKeepLocal: push failed: $e');
      // Revert to synced so the conflict badge clears — re-sync will pick it up.
      event
        ..syncStatus = 'sync_error'
        ..save();
    }
    _refreshState();
  }

  /// Resolve a sync conflict by discarding the local version (re-pull happens
  /// on next sync).  Simply mark as synced so the UI badge clears.
  void resolveConflictKeepRemote(CalendarEvent event) {
    if (_box == null) return;
    event
      ..syncStatus = 'synced'
      ..save();
    _refreshState();
  }

  List<CalendarEvent> getUpcomingEvents({int days = 7}) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return state.where((event) {
      return event.startTime.isAfter(now) && event.startTime.isBefore(cutoff);
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void addEvent(CalendarEvent event) {
    if (_box == null) return;
    _box!.put(event.id, event);
    _refreshState();
  }

  void updateEvent(CalendarEvent event) {
    if (_box == null) return;
    _box!.put(event.id, event);
    _refreshState();
  }

  void deleteEvent(String id) {
    if (_box == null) return;
    _box!.delete(id);
    _refreshState();
  }

  /// Sync tasks to calendar as events (full rebuild — retained for batch imports).
  void syncTasksToCalendar(List<TaskItem> tasks) {
    if (_box == null) return;

    // Remove old task-linked events
    final taskEventIds = state
        .where((e) => e.linkedTaskId != null)
        .map((e) => e.id)
        .toList();
    for (final id in taskEventIds) {
      _box!.delete(id);
    }

    // Add current tasks as events
    for (final task in tasks) {
      _box!.put('task_${task.id}', _taskToEvent(task));
    }

    _refreshState();
  }

  /// Insert or update a single task's calendar mirror — O(1) Hive writes.
  void upsertTaskEvent(TaskItem task) {
    if (_box == null) return;
    _box!.put('task_${task.id}', _taskToEvent(task));
    _refreshState();
  }

  /// Remove a single task's calendar mirror — O(1) Hive writes.
  void removeTaskEvent(String taskId) {
    if (_box == null) return;
    _box!.delete('task_$taskId');
    _refreshState();
  }

  CalendarEvent _taskToEvent(TaskItem task) => CalendarEvent(
    id: 'task_${task.id}',
    title: task.isCompleted ? '✓ ${task.title}' : task.title,
    description: task.note,
    startTime: task.startTime,
    endTime: task.endTime ?? task.startTime.add(const Duration(hours: 1)),
    source: 'local',
    linkedTaskId: task.id,
    colorValue: task.isCompleted ? 0xFF9E9E9E : _priorityToColor(task.priority),
  );

  int _priorityToColor(int priority) {
    switch (priority) {
      case 0:
        return 0xFF9E9E9E;
      case 1:
        return 0xFF00D4AA;
      case 2:
        return 0xFFFF6B6B;
      case 3:
        return 0xFFFF4444;
      default:
        return 0xFF6C63FF;
    }
  }

  void _refreshState() {
    state = _box!.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}

final calendarControllerProvider =
    StateNotifierProvider<CalendarController, List<CalendarEvent>>(
      (ref) => CalendarController(
        conflictDetector: ref.read(conflictDetectorProvider),
        syncService: ref.read(calendarSyncServiceProvider),
      ),
    );
