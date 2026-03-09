import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/memory_entry_model.dart';
import '../../../core/providers/providers.dart';
import '../../../services/ai_service.dart';
import '../../../services/notification_service.dart';
import '../../memory/controllers/memory_controller.dart';
import '../../calendar/controllers/calendar_controller.dart';

const _uuid = Uuid();

class TaskController extends StateNotifier<List<TaskItem>> {
  Box<TaskItem>? _box;
  final AIService _aiService;
  final MemoryController _memoryCtrl;
  final CalendarController _calendarCtrl;
  final NotificationService _notifications;

  TaskController({
    required AIService aiService,
    required MemoryController memoryCtrl,
    required CalendarController calendarCtrl,
    required NotificationService notifications,
  }) : _aiService = aiService,
       _memoryCtrl = memoryCtrl,
       _calendarCtrl = calendarCtrl,
       _notifications = notifications,
       super([]) {
    // Box is pre-opened in main() before runApp — grab it synchronously.
    _box = Hive.box<TaskItem>('tasksBox');
    _refreshState();
  }

  List<TaskItem> get todayTasks {
    final now = DateTime.now();
    return state.where((task) {
      return task.startTime.year == now.year &&
          task.startTime.month == now.month &&
          task.startTime.day == now.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<TaskItem> get completedTasks =>
      state.where((t) => t.isCompleted).toList();

  List<TaskItem> get pendingTasks =>
      state.where((t) => !t.isCompleted).toList();

  double get completionRate {
    if (todayTasks.isEmpty) return 0;
    return todayTasks.where((t) => t.isCompleted).length / todayTasks.length;
  }

  void addTask(TaskItem task) {
    if (_box == null) return;
    _box!.put(task.id, task);
    _refreshState();
    _calendarCtrl.upsertTaskEvent(task);
    _createTaskMemory(task, 'created');
    _notifications.scheduleTaskReminder(task);
  }

  void removeTask(String id) {
    if (_box == null) return;
    _box!.delete(id);
    _refreshState();
    _calendarCtrl.removeTaskEvent(id);
    _notifications.cancelTaskReminder(id);
  }

  void updateTask(TaskItem task) {
    if (_box == null) return;
    final oldTask = _box!.get(task.id);
    _box!.put(task.id, task);
    _refreshState();
    _calendarCtrl.upsertTaskEvent(task);
    if (oldTask != null && !oldTask.isCompleted && task.isCompleted) {
      _createTaskMemory(task, 'completed');
      _notifications.cancelTaskReminder(task.id);
    } else if (!task.isCompleted) {
      _notifications.scheduleTaskReminder(task);
    }
  }

  void toggleComplete(String taskId) {
    final task = state.firstWhere((t) => t.id == taskId);
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    updateTask(updated);
    // Spawn next occurrence if task has a recurrence and is being completed.
    if (updated.isCompleted && task.recurrence != null) {
      _spawnNextRecurrence(task);
    }
  }

  /// Calculates the next occurrence date for a recurring task and creates it.
  void _spawnNextRecurrence(TaskItem completed) {
    final next = _nextOccurrenceDate(completed);
    if (next == null) return;
    final duration = completed.endTime != null
        ? completed.endTime!.difference(completed.startTime)
        : const Duration(hours: 1);
    final nextEnd = next.add(duration);
    final newTask = TaskItem(
      id: _uuid.v4(),
      title: completed.title,
      startTime: next,
      endTime: nextEnd,
      note: completed.note,
      priority: completed.priority,
      tags: List.from(completed.tags),
      linkedNoteIds: List.from(completed.linkedNoteIds),
      recurrence: completed.recurrence,
      recurrenceDays: List.from(completed.recurrenceDays),
    );
    addTask(newTask);
  }

  DateTime? _nextOccurrenceDate(TaskItem task) {
    final base = task.startTime;
    switch (task.recurrence) {
      case 'daily':
        return base.add(const Duration(days: 1));
      case 'weekly':
        return base.add(const Duration(days: 7));
      case 'weekdays':
        var next = base.add(const Duration(days: 1));
        while (next.weekday == DateTime.saturday ||
            next.weekday == DateTime.sunday) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      case 'custom':
        if (task.recurrenceDays.isEmpty) return null;
        var candidate = base.add(const Duration(days: 1));
        for (var i = 0; i < 14; i++) {
          if (task.recurrenceDays.contains(candidate.weekday)) return candidate;
          candidate = candidate.add(const Duration(days: 1));
        }
        return null;
      default:
        return null;
    }
  }

  void clearAll() {
    if (_box == null) return;
    _box!.clear();
    state = [];
  }

  /// Links a note ID to this task (bidirectional — caller should also call
  /// NoteController.linkTask on the note side).
  void linkNote(String taskId, String noteId) {
    final matches = state.where((t) => t.id == taskId);
    if (matches.isEmpty) return;
    final task = matches.first;
    if (task.linkedNoteIds.contains(noteId)) return;
    updateTask(task.copyWith(linkedNoteIds: [...task.linkedNoteIds, noteId]));
  }

  void unlinkNote(String taskId, String noteId) {
    final matches = state.where((t) => t.id == taskId);
    if (matches.isEmpty) return;
    final task = matches.first;
    updateTask(
      task.copyWith(
        linkedNoteIds: task.linkedNoteIds.where((id) => id != noteId).toList(),
      ),
    );
  }

  /// Saves a reordered list of tasks in-place without triggering AI memory extraction.
  void reorderTasks(List<TaskItem> tasks) {
    if (_box == null) return;
    _box!.clear();
    for (final task in tasks) {
      _box!.put(task.id, task);
    }
    _refreshState();
    _calendarCtrl.syncTasksToCalendar(state);
  }

  void _refreshState() {
    state = _box!.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void _createTaskMemory(TaskItem task, String action) async {
    try {
      final ctx =
          'Task "$action": "${task.title}" at ${task.startTime.hour}:${task.startTime.minute.toString().padLeft(2, '0')} [${task.priorityLabel}] tags: ${task.tags.join(', ')}';
      final memoryContent = await _aiService.extractMemoryFromContext(
        ctx,
        'task',
      );
      if (memoryContent != null) {
        _memoryCtrl.addMemory(
          MemoryEntry(
            id: _uuid.v4(),
            content: memoryContent,
            sourceType: 'task',
            sourceId: task.id,
            tags: task.tags,
            createdAt: DateTime.now(),
            relevanceScore: task.priority / 3.0,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Memory creation failed: $e');
    }
  }
}

final taskControllerProvider =
    StateNotifierProvider<TaskController, List<TaskItem>>((ref) {
      return TaskController(
        aiService: ref.watch(aiServiceProvider),
        memoryCtrl: ref.watch(memoryControllerProvider.notifier),
        calendarCtrl: ref.watch(calendarControllerProvider.notifier),
        notifications: ref.watch(notificationServiceProvider),
      );
    });
