import '../core/models/task_model.dart';
import '../core/models/calendar_event_model.dart';
import '../core/models/memory_entry_model.dart';
import '../core/models/goal_model.dart';
import '../features/settings/models/app_settings_model.dart';
import 'ai_service.dart';
import 'scheduler_service.dart';

/// The result of a proactive reschedule check.
class RescheduleSuggestion {
  final TaskItem task;
  final DateTime proposedTime;

  const RescheduleSuggestion({required this.task, required this.proposedTime});

  /// The proposed end time, preserving original task duration.
  DateTime get proposedEndTime => proposedTime.add(_duration(task));

  Duration _duration(TaskItem t) {
    if (t.endTime != null) {
      final d = t.endTime!.difference(t.startTime);
      if (d.inMinutes >= 15) return d;
    }
    return const Duration(hours: 1);
  }
}

/// Orchestrates the proactive re-scheduling flow:
///   1. Finds overdue uncompleted tasks (past startTime by > [gracePeriod]).
///   2. Takes the highest-priority one.
///   3. Computes free calendar slots for today.
///   4. Asks Gemini to pick the best slot.
///   5. Returns a [RescheduleSuggestion] or null when nothing is overdue.
class RescheduleService {
  static const _gracePeriod = Duration(minutes: 5);
  static const _slotCount = 6;

  final AIService _ai;
  final SchedulerService _scheduler;

  RescheduleService({required this._ai, required this._scheduler});

  /// Checks whether any of [tasks] are overdue today and, if so, proposes an
  /// AI-selected reschedule slot.
  ///
  /// Steps:
  /// 1. Filters today's uncompleted tasks whose [TaskItem.startTime] is more
  ///    than 5 minutes in the past.
  /// 2. Selects the single highest-priority overdue task.
  /// 3. Asks [SchedulerService.freeSlots] for up to 6 free windows.
  /// 4. Passes those windows to [AIService.suggestReschedule] for ranking.
  ///
  /// Returns `null` when no overdue tasks exist or no free slots are available.
  /// Finds the highest-priority overdue task for today and picks the best
  /// available free slot using AI.
  ///
  /// Returns `null` when no uncompleted tasks have passed their [_gracePeriod].
  /// The returned [RescheduleSuggestion] preserves the original task duration.
  Future<RescheduleSuggestion?> checkOverdue({
    required List<TaskItem> tasks,
    required List<CalendarEvent> calendarEvents,
    required List<MemoryEntry> memories,
    required AppSettings settings,
    List<GoalItem> goals = const [],
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter: today's tasks that are uncompleted and overdue by > grace period.
    final overdue = tasks.where((t) {
      final isToday =
          t.startTime.year == today.year &&
          t.startTime.month == today.month &&
          t.startTime.day == today.day;
      return isToday &&
          !t.isCompleted &&
          now.difference(t.startTime) > _gracePeriod;
    }).toList();

    if (overdue.isEmpty) return null;

    // Take the single highest-priority overdue task (priority desc, earliest first).
    overdue.sort((a, b) {
      final pc = b.priority.compareTo(a.priority);
      return pc != 0 ? pc : a.startTime.compareTo(b.startTime);
    });
    final task = overdue.first;

    // Compute free slots for today, blocking all tasks + calendar events.
    final todayCalendar = calendarEvents.where((e) {
      return e.startTime.year == today.year &&
          e.startTime.month == today.month &&
          e.startTime.day == today.day;
    }).toList();

    final todayTasks = tasks.where((t) {
      return t.startTime.year == today.year &&
          t.startTime.month == today.month &&
          t.startTime.day == today.day &&
          t.id != task.id; // exclude the overdue task itself
    }).toList();

    final duration = task.endTime != null
        ? task.endTime!.difference(task.startTime)
        : const Duration(hours: 1);

    final slots = _scheduler.freeSlots(
      day: today,
      workStartHour: settings.workStartHour,
      workHoursPerDay: settings.workHoursPerDay,
      slotDuration: duration,
      busyTasks: todayTasks,
      calendarBlocks: todayCalendar,
      count: _slotCount,
    );

    if (slots.isEmpty) return null;

    // Look up the linked goal (if any) so the AI can factor in its deadline.
    final linkedGoal = task.linkedGoalId != null
        ? goals.cast<GoalItem?>().firstWhere(
            (g) => g!.id == task.linkedGoalId,
            orElse: () => null,
          )
        : null;

    final proposed = await _ai.suggestReschedule(
      task: task,
      slots: slots,
      memories: memories,
      linkedGoal: linkedGoal,
    );

    if (proposed == null) return null;
    return RescheduleSuggestion(task: task, proposedTime: proposed);
  }
}
