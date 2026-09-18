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

  factory ScheduleCommand.unknown({String explanation = 'Could not understand command.'}) {
    return ScheduleCommand(
      type: ScheduleCommandType.unknown,
      explanation: explanation,
    );
  }

  factory ScheduleCommand.fromJson(Map<String, dynamic> json, {DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    final actionStr = (json['action'] as String? ?? 'unknown').toLowerCase();
    final minutes = json['minutes'] as int?;
    final title = json['taskTitle'] as String?;
    final priority = json['priority'] as int?;
    final tags = (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
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
      explanation: explanation.isNotEmpty ? explanation : _defaultExplanation(type, minutes, title),
      rawParams: json,
    );
  }

  static String _defaultExplanation(ScheduleCommandType type, int? minutes, String? title) {
    switch (type) {
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
      shifts.isNotEmpty || newTask != null || focusTask != null || fittingTasks.isNotEmpty;
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
