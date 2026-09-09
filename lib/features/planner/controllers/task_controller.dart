import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/task_model.dart';
import '../../../core/models/memory_entry_model.dart';
import '../../../core/providers/providers.dart';
import '../../../services/ai_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/home_widget_service.dart';
import '../../../services/smart_notification_scheduler.dart';
import '../../../features/settings/models/app_settings_model.dart';
import '../../memory/controllers/memory_controller.dart';
import '../../calendar/controllers/calendar_controller.dart';

const _uuid = Uuid();

/// Riverpod [Notifier] that owns all [TaskItem] CRUD, scheduling,
/// recurrence, and AI-enrichment logic.
///
/// State is a flat list of every task in the local Hive box. The box is
/// opened synchronously in the constructor (Hive must be initialised first
/// in `main()`). Mutations go through dedicated methods that update both
/// the Hive box and Riverpod state atomically.
class TaskController extends Notifier<List<TaskItem>> {
  Box<TaskItem>? _box;
  late final AIService _aiService;
  late final MemoryController _memoryCtrl;
  late final CalendarController _calendarCtrl;
  late final NotificationService _notifications;

  @override
  List<TaskItem> build() {
    _aiService = ref.read(aiServiceProvider);
    _memoryCtrl = ref.read(memoryControllerProvider.notifier);
    _calendarCtrl = ref.read(calendarControllerProvider.notifier);
    _notifications = ref.read(notificationServiceProvider);

    _box = Hive.box<TaskItem>('tasksBox');

    Future.microtask(() {
      _seedMissingRecurrences();
      _refreshState();
    });

    return _getSortedTasks();
  }

  List<TaskItem> _getSortedTasks() {
    if (_box == null) return [];
    return _box!.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
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
    if (task.priority == 3) {
      _notifications.scheduleUrgentAlert(
        id: task.id,
        title: task.title,
        body: 'Urgent task added to your planner.',
      );
    }
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

    // Handle recurrence change → refresh future calendar occurrences.
    if (oldTask != null && oldTask.recurrence != task.recurrence) {
      if (oldTask.recurrence != null) {
        _removeFutureRecurrences(oldTask.title, oldTask.recurrence, task.id);
      }
      if (task.recurrence != null) {
        _populateFutureRecurrences(task);
      }
    }

    if (oldTask != null && !oldTask.isCompleted && task.isCompleted) {
      _createTaskMemory(task, 'completed');
      _notifications.cancelTaskReminder(task.id);
    } else if (!task.isCompleted) {
      _notifications.scheduleTaskReminder(task);
      // Fire an immediate alert when priority rises to Urgent.
      final wasUrgent = oldTask?.priority == 3;
      if (task.priority == 3 && !wasUrgent) {
        _notifications.scheduleUrgentAlert(
          id: task.id,
          title: task.title,
          body: 'Task marked as Urgent.',
        );
      }
    }
  }

  void toggleComplete(String taskId) {
    final matches = state.where((t) => t.id == taskId);
    if (matches.isEmpty) return;
    final task = matches.first;
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    updateTask(updated);
    // Spawn next occurrence if task has a recurrence and is being completed.
    if (updated.isCompleted && task.recurrence != null) {
      _spawnNextRecurrence(task);
    }
    // Reinforce memories whose tags overlap with this completed task —
    // they likely contributed context when the task was created or planned.
    if (updated.isCompleted && task.tags.isNotEmpty) {
      _reinforceRelatedMemories(task.tags);
    }
  }

  void _reinforceRelatedMemories(List<String> taskTags) {
    final tagSet = taskTags.map((t) => t.toLowerCase()).toSet();
    final related = _memoryCtrl.state
        .where((m) => m.tags.any((t) => tagSet.contains(t.toLowerCase())))
        .take(3)
        .toList();
    for (final m in related) {
      _memoryCtrl.reinforceMemory(m.id);
    }
  }

  /// Calculates the next occurrence date for a recurring task and creates it.
  void _spawnNextRecurrence(TaskItem completed) {
    final next = _nextOccurrenceDate(completed);
    if (next == null) return;

    // Skip if a pre-populated occurrence already exists on the next date.
    final nextDay = DateTime(next.year, next.month, next.day);
    if (_hasOccurrenceOnDay(completed.title, completed.recurrence, nextDay)) {
      return;
    }

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
      // ignore: deprecated_member_use_from_same_package
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
      case 'biweekly':
        return base.add(const Duration(days: 14));
      case 'monthly':
        // Same day next month; clamp to month-end for short months.
        final nextMonth = base.month == 12 ? 1 : base.month + 1;
        final nextYear = base.month == 12 ? base.year + 1 : base.year;
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final day = base.day > daysInNextMonth ? daysInNextMonth : base.day;
        return DateTime(nextYear, nextMonth, day, base.hour, base.minute);
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

  // ── Recurrence helpers ──────────────────────────────────────────────────

  /// Returns `true` when the Hive box already contains a task with the given
  /// [title] and [recurrence] on [day] (regardless of completion state).
  bool _hasOccurrenceOnDay(String title, String? recurrence, DateTime day) {
    if (_box == null) return false;
    return _box!.values.any(
      (t) =>
          t.title == title &&
          t.recurrence == recurrence &&
          t.startTime.year == day.year &&
          t.startTime.month == day.month &&
          t.startTime.day == day.day,
    );
  }

  /// Pre-creates task instances for the next 14 days so recurring tasks
  /// appear on the calendar immediately when the user sets a recurrence.
  void _populateFutureRecurrences(TaskItem template) {
    if (_box == null || template.recurrence == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: 14));

    final duration = template.endTime != null
        ? template.endTime!.difference(template.startTime)
        : const Duration(hours: 1);

    // Walk forward from the template, creating occurrences up to the horizon.
    var cursor = template;
    while (true) {
      final nextDate = _nextOccurrenceDate(cursor);
      if (nextDate == null) break;
      final nextDay = DateTime(nextDate.year, nextDate.month, nextDate.day);
      if (nextDay.isAfter(horizon)) break;

      if (!_hasOccurrenceOnDay(template.title, template.recurrence, nextDay)) {
        final newTask = TaskItem(
          id: _uuid.v4(),
          title: template.title,
          startTime: nextDate,
          endTime: nextDate.add(duration),
          note: template.note,
          priority: template.priority,
          tags: List.from(template.tags),
          // ignore: deprecated_member_use_from_same_package
          linkedNoteIds: List.from(template.linkedNoteIds),
          recurrence: template.recurrence,
          recurrenceDays: List.from(template.recurrenceDays),
          linkedGoalId: template.linkedGoalId,
        );
        _box!.put(newTask.id, newTask);
        _calendarCtrl.upsertTaskEvent(newTask);
        _notifications.scheduleTaskReminder(newTask);
      }

      // Advance cursor to compute the following occurrence.
      cursor = TaskItem(
        id: '',
        title: template.title,
        startTime: nextDate,
        recurrence: template.recurrence,
        recurrenceDays: List.from(template.recurrenceDays),
      );
    }
    _refreshState();
  }

  /// Removes all future pending occurrences that match [title]+[recurrence],
  /// skipping the task with [excludeId] (the one being edited).
  void _removeFutureRecurrences(
    String title,
    String? recurrence,
    String excludeId,
  ) {
    if (_box == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final toRemove = _box!.values.where((t) {
      if (t.id == excludeId) return false;
      if (t.title != title || t.recurrence != recurrence) return false;
      if (t.isCompleted) return false;
      final tDay = DateTime(
        t.startTime.year,
        t.startTime.month,
        t.startTime.day,
      );
      return tDay.isAfter(today);
    }).toList();

    for (final t in toRemove) {
      _box!.delete(t.id);
      _calendarCtrl.removeTaskEvent(t.id);
      _notifications.cancelTaskReminder(t.id);
    }
    _refreshState();
  }

  /// On startup, check each recurring task group and spawn a pending occurrence
  /// for today if the most recent completed instance has no future sibling yet.
  void _seedMissingRecurrences() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final recurring = state.where((t) => t.recurrence != null).toList();

    // Group by title+recurrence as the template key.
    final groups = <String, List<TaskItem>>{};
    for (final t in recurring) {
      groups.putIfAbsent('${t.title}|${t.recurrence}', () => []).add(t);
    }

    for (final group in groups.values) {
      group.sort((a, b) => b.startTime.compareTo(a.startTime));
      final latest = group.first;

      // Skip if there is already a pending (uncompleted) future occurrence.
      final hasPending = group.any(
        (t) =>
            !t.isCompleted &&
            !DateTime(
              t.startTime.year,
              t.startTime.month,
              t.startTime.day,
            ).isBefore(today),
      );
      if (hasPending) continue;

      // Only seed if the latest completed instance is overdue for a recurrence.
      if (!latest.isCompleted) continue;
      final next = _nextOccurrenceDate(latest);
      if (next == null) continue;
      final nextDay = DateTime(next.year, next.month, next.day);
      if (nextDay.isAfter(today)) continue;

      // Spawn using today's date but keep the original time-of-day.
      _spawnOccurrenceOnDay(latest, today);
    }
  }

  /// Spawns a new occurrence of [template] scheduled on [day], preserving
  /// the original time-of-day and duration.
  void _spawnOccurrenceOnDay(TaskItem template, DateTime day) {
    final orig = template.startTime;
    final newStart = DateTime(
      day.year,
      day.month,
      day.day,
      orig.hour,
      orig.minute,
    );
    final duration = template.endTime != null
        ? template.endTime!.difference(template.startTime)
        : const Duration(hours: 1);
    final newTask = TaskItem(
      id: _uuid.v4(),
      title: template.title,
      startTime: newStart,
      endTime: newStart.add(duration),
      note: template.note,
      priority: template.priority,
      tags: List.from(template.tags),
      // ignore: deprecated_member_use_from_same_package
      linkedNoteIds: List.from(template.linkedNoteIds),
      recurrence: template.recurrence,
      recurrenceDays: List.from(template.recurrenceDays),
    );
    addTask(newTask);
  }

  void clearAll() {
    if (_box == null) return;
    _box!.clear();
    state = [];
  }

  /// Links a goal ID to this task (bidirectional — caller should also call
  /// GoalController.linkTask on the goal side).
  void linkGoal(String taskId, String goalId) {
    final matches = state.where((t) => t.id == taskId);
    if (matches.isEmpty) return;
    final task = matches.first;
    updateTask(task.copyWith(linkedGoalId: goalId));
  }

  void unlinkGoal(String taskId) {
    final matches = state.where((t) => t.id == taskId);
    if (matches.isEmpty) return;
    final task = matches.first;
    updateTask(task.copyWith(linkedGoalId: null));
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
    if (_box == null) return;
    state = _getSortedTasks();
    // Push updated task data to the home screen widget.
    HomeWidgetService.update(state);
    // Recalculate smart morning briefing based on current tasks.
    _recalculateBriefing();
  }

  /// Fires the smart notification scheduler to adjust morning briefing
  /// timing based on tomorrow's first task.
  Future<void> _recalculateBriefing() async {
    try {
      final settingsBox = Hive.box('settingsBox');
      final enabled = settingsBox.get(
        'morningBriefingEnabled',
        defaultValue: false,
      ) as bool;
      if (!enabled) return;
      final hour =
          settingsBox.get('morningBriefingHour', defaultValue: 8) as int;
      final minute =
          settingsBox.get('morningBriefingMinute', defaultValue: 0) as int;
      final scheduler = SmartNotificationScheduler(_notifications);
      await scheduler.recalculate(
        tasks: state,
        settings: AppSettings.defaults().copyWith(
          morningBriefingEnabled: enabled,
          morningBriefingHour: hour,
          morningBriefingMinute: minute,
        ),
      );
    } catch (_) {
      // Non-critical — don't crash on scheduling failure.
    }
  }

  Future<void> _createTaskMemory(TaskItem task, String action) async {
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
      if (kDebugMode) debugPrint('TaskController: memory creation failed: $e');
    }
  }
}

final taskControllerProvider = NotifierProvider<TaskController, List<TaskItem>>(
  TaskController.new,
);
