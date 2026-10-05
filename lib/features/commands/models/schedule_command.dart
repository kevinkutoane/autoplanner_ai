import '../../../core/models/task_model.dart';

/// Supported types of schedule commands in the AI Omnibar.
enum ScheduleCommandType {
  /// Shift/delay or advance tasks after a certain time by [minutes].
  shift,

  /// Clear a specific time window by moving conflicting tasks out.
  clearWindow,

  /// Quickly parse and insert a new task with schedule parameters.
  quickAdd,

  /// Find pending tasks that fit into an available duration.
  findFit,

  /// Launch an immersive focus session on a specified or recommended task.
  startFocus,

  /// Protect/reserve an uninterrupted focus window against meetings or shallow tasks.
  protectFocus,

  /// Trigger autonomous schedule drift healing and circadian peak re-alignment.
  autoReschedule,

  /// Automatically resolve anticipated schedule conflicts.
  resolveConflicts,

  /// Link a task to a goal, project, or note.
  linkContext,

  /// Multi-day weekly capacity planning across 5-7 days.
  planWeek,

  /// Mid-week adaptive recovery pass for slipped tasks.
  replanWeek,

  /// Backlog planning debt diagnostics and zombie task detection.
  planningDebt,

  /// Unrecognized or conversational query.
  unknown,
}

/// Represents a parsed actionable instruction for the AutoPlanner schedule.
class ScheduleCommand {
  final ScheduleCommandType type;
  final int? minutes;
  final DateTime? afterTime;
  final DateTime? fromTime;
  final DateTime? toTime;
  final DateTime? targetDate;
  final String? taskTitle;
  final int? priority;
  final List<String> tags;
  final String explanation;
  final Map<String, dynamic> rawParams;

  const ScheduleCommand({
    required this.type,
    this.minutes,
    this.afterTime,
    this.fromTime,
    this.toTime,
    this.targetDate,
    this.taskTitle,
    this.priority,
    this.tags = const [],
    required this.explanation,
    this.rawParams = const {},
  });

  factory ScheduleCommand.unknown({
    String explanation = 'Could not understand command.',
  }) {
    return ScheduleCommand(
      type: ScheduleCommandType.unknown,
      explanation: explanation,
    );
  }

  factory ScheduleCommand.fromJson(
    Map<String, dynamic> json, {
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();
    final actionStr = (json['action'] as String? ?? 'unknown').toLowerCase();
    final minutes = json['minutes'] as int?;
    final title = json['taskTitle'] as String?;
    final priority = json['priority'] as int?;
    final tags =
        (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
    final explanation = json['explanation'] as String? ?? '';

    DateTime? parseTimeStr(String? timeStr, DateTime baseDate) {
      if (timeStr == null || timeStr.isEmpty) return null;
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? baseDate.hour;
        final m = int.tryParse(parts[1]) ?? 0;
        return DateTime(baseDate.year, baseDate.month, baseDate.day, h, m);
      }
      return null;
    }

    final baseDate = json['targetDate'] != null
        ? DateTime.tryParse(json['targetDate'].toString()) ?? now
        : now;

    final afterTime = parseTimeStr(json['afterTime'] as String?, baseDate);
    final fromTime = parseTimeStr(json['fromTime'] as String?, baseDate);
    final toTime = parseTimeStr(json['toTime'] as String?, baseDate);

    ScheduleCommandType type;
    switch (actionStr) {
      case 'shift':
        type = ScheduleCommandType.shift;
        break;
      case 'clear_window':
      case 'clear':
        type = ScheduleCommandType.clearWindow;
        break;
      case 'quick_add':
      case 'add':
        type = ScheduleCommandType.quickAdd;
        break;
      case 'find_fit':
      case 'fit':
        type = ScheduleCommandType.findFit;
        break;
      case 'start_focus':
      case 'focus':
        type = ScheduleCommandType.startFocus;
        break;
      case 'protect':
      case 'protect_focus':
      case 'protect_window':
        type = ScheduleCommandType.protectFocus;
        break;
      case 'reschedule':
      case 'auto_reschedule':
      case 'rebalance':
      case 'ripple':
        type = ScheduleCommandType.autoReschedule;
        break;
      case 'resolve':
      case 'resolve_conflicts':
      case 'fix_conflicts':
        type = ScheduleCommandType.resolveConflicts;
        break;
      case 'link':
      case 'link_context':
        type = ScheduleCommandType.linkContext;
        break;
      case 'plan_week':
      case 'weekly_plan':
      case 'planweek':
        type = ScheduleCommandType.planWeek;
        break;
      case 'replan_week':
      case 'midweek_recovery':
      case 'replanweek':
        type = ScheduleCommandType.replanWeek;
        break;
      case 'debt':
      case 'planning_debt':
        type = ScheduleCommandType.planningDebt;
        break;
      default:
        type = ScheduleCommandType.unknown;
    }

    return ScheduleCommand(
      type: type,
      minutes: minutes,
      afterTime: afterTime,
      fromTime: fromTime,
      toTime: toTime,
      targetDate: baseDate,
      taskTitle: title,
      priority: priority,
      tags: tags,
      explanation: explanation.isNotEmpty
          ? explanation
          : _defaultExplanation(type, minutes, title),
      rawParams: json,
    );
  }

  /// Parses client-side slash commands or plain shortcuts directly without round-trips.
  factory ScheduleCommand.fromRawText(String text, {DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();

    if (lower == '/plan-week' || lower == 'plan week' || lower == '/planweek' || lower == 'plan-week') {
      return ScheduleCommand(
        type: ScheduleCommandType.planWeek,
        explanation: 'Balance weekly capacity and distribute tasks across 7 days.',
        targetDate: now,
      );
    }

    if (lower == '/replan-week' || lower == 'replan week' || lower == '/replanweek' || lower == 'replan-week') {
      return ScheduleCommand(
        type: ScheduleCommandType.replanWeek,
        explanation: 'Mid-week adaptive recovery: roll uncompleted slipped tasks into open capacity.',
        targetDate: now,
      );
    }

    if (lower == '/debt' || lower == 'planning debt' || lower == '/planning-debt' || lower == 'debt') {
      return ScheduleCommand(
        type: ScheduleCommandType.planningDebt,
        explanation: 'Audit planning debt, overdue commitments, and stale tasks.',
        targetDate: now,
      );
    }

    if (lower == '/reschedule' || lower == 'reschedule' || lower == '/rebalance' || lower == 'rebalance') {
      return ScheduleCommand(
        type: ScheduleCommandType.autoReschedule,
        explanation: 'Autonomous schedule drift healing and circadian peak alignment.',
        targetDate: now,
      );
    }

    if (lower == '/resolve' || lower == 'resolve' || lower == '/resolve-conflicts' || lower == 'fix conflicts') {
      return ScheduleCommand(
        type: ScheduleCommandType.resolveConflicts,
        explanation: 'Proactively resolve anticipated schedule collisions, transit shortages, and deadline risks.',
        targetDate: now,
      );
    }

    if (lower.startsWith('/protect') || lower.startsWith('protect ')) {
      // e.g. /protect afternoon, /protect morning
      if (lower.contains('morning')) {
        final from = DateTime(now.year, now.month, now.day, 9, 0);
        final to = DateTime(now.year, now.month, now.day, 12, 0);
        return ScheduleCommand(
          type: ScheduleCommandType.protectFocus,
          fromTime: from,
          toTime: to,
          minutes: 180,
          targetDate: now,
          explanation: 'Protect morning focus window (09:00 - 12:00) against shallow work and drift.',
        );
      } else if (lower.contains('afternoon')) {
        final from = DateTime(now.year, now.month, now.day, 13, 0);
        final to = DateTime(now.year, now.month, now.day, 17, 0);
        return ScheduleCommand(
          type: ScheduleCommandType.protectFocus,
          fromTime: from,
          toTime: to,
          minutes: 240,
          targetDate: now,
          explanation: 'Protect afternoon deep work window (13:00 - 17:00).',
        );
      } else {
        // default 2-hour protection starting now or next round hour
        final from = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
        final to = from.add(const Duration(hours: 2));
        return ScheduleCommand(
          type: ScheduleCommandType.protectFocus,
          fromTime: from,
          toTime: to,
          minutes: 120,
          targetDate: now,
          explanation: 'Protect 2-hour uninterrupted focus block from ${from.hour}:00 to ${to.hour}:00.',
        );
      }
    }

    return ScheduleCommand.unknown(explanation: 'Command not recognized: $text');
  }

  static String _defaultExplanation(
    ScheduleCommandType type,
    int? minutes,
    String? title,
  ) {
    switch (type) {
      case ScheduleCommandType.planWeek:
        return 'Balance multi-day task capacity across 7 days.';
      case ScheduleCommandType.replanWeek:
        return 'Mid-week recovery: rebalance slipped tasks into open capacity.';
      case ScheduleCommandType.planningDebt:
        return 'Analyze backlog planning debt index and stale tasks.';
      case ScheduleCommandType.shift:
        return 'Shift upcoming tasks by ${minutes ?? 30} minutes.';
      case ScheduleCommandType.clearWindow:
        return 'Clear schedule window and push conflicting tasks.';
      case ScheduleCommandType.quickAdd:
        return 'Add new task "${title ?? 'New Task'}".';
      case ScheduleCommandType.findFit:
        return 'Find tasks that fit in ${minutes ?? 30} minutes.';
      case ScheduleCommandType.startFocus:
        return 'Start focus session${title != null ? ' for $title' : ''}.';
      case ScheduleCommandType.protectFocus:
        return 'Protect focus window for uninterrupted deep work.';
      case ScheduleCommandType.autoReschedule:
        return 'Autonomous schedule drift healing and circadian alignment.';
      case ScheduleCommandType.resolveConflicts:
        return 'Resolve anticipated schedule conflicts and transit shortages.';
      case ScheduleCommandType.linkContext:
        return 'Link task to associated goal or project.';
      case ScheduleCommandType.unknown:
        return 'Unknown command.';
    }
  }
}

/// Visual preview of a task being shifted in time.
class TaskShiftPreview {
  final TaskItem task;
  final DateTime originalStart;
  final DateTime? originalEnd;
  final DateTime newStart;
  final DateTime? newEnd;

  const TaskShiftPreview({
    required this.task,
    required this.originalStart,
    this.originalEnd,
    required this.newStart,
    this.newEnd,
  });

  Duration get shiftDuration => newStart.difference(originalStart);
}

/// Aggregated preview of changes to be reviewed before confirmation.
class CommandPreview {
  final ScheduleCommand command;
  final String summary;
  final List<TaskShiftPreview> shifts;
  final TaskItem? newTask;
  final List<TaskItem> fittingTasks;
  final TaskItem? focusTask;

  const CommandPreview({
    required this.command,
    required this.summary,
    this.shifts = const [],
    this.newTask,
    this.fittingTasks = const [],
    this.focusTask,
  });

  bool get hasActionableChanges =>
      shifts.isNotEmpty ||
      newTask != null ||
      focusTask != null ||
      fittingTasks.isNotEmpty;
}

/// Outcome of executing a schedule command.
class CommandExecutionResult {
  final bool success;
  final String message;
  final int affectedTasksCount;
  final TaskItem? createdTask;
  final TaskItem? focusTask;

  const CommandExecutionResult({
    required this.success,
    required this.message,
    this.affectedTasksCount = 0,
    this.createdTask,
    this.focusTask,
  });
}
