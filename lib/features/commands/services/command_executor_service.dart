import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/task_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../planner/controllers/task_controller.dart';
import '../models/schedule_command.dart';

class CommandExecutorService {
  static const _uuid = Uuid();

  /// Generates a preview of changes that will occur if [command] is executed.
  CommandPreview generatePreview(
    ScheduleCommand command,
    List<TaskItem> tasks, {
    DateTime? now,
  }) {
    final currentMoment = now ?? DateTime.now();
    final targetDay = command.targetDate ?? currentMoment;

    switch (command.type) {
      case ScheduleCommandType.shift:
        return _previewShift(command, tasks, targetDay, currentMoment);
      case ScheduleCommandType.clearWindow:
        return _previewClearWindow(command, tasks, targetDay, currentMoment);
      case ScheduleCommandType.quickAdd:
        return _previewQuickAdd(command, tasks, targetDay, currentMoment);
      case ScheduleCommandType.findFit:
        return _previewFindFit(command, tasks, currentMoment);
      case ScheduleCommandType.startFocus:
        return _previewStartFocus(command, tasks, currentMoment);
      case ScheduleCommandType.unknown:
        return CommandPreview(
          command: command,
          summary: command.explanation.isNotEmpty
              ? command.explanation
              : 'Command not recognized.',
        );
    }
  }

  CommandPreview _previewShift(
    ScheduleCommand command,
    List<TaskItem> tasks,
    DateTime targetDay,
    DateTime currentMoment,
  ) {
    final minutes = command.minutes ?? 30;
    final shiftDuration = Duration(minutes: minutes);
    final thresholdTime = command.afterTime ??
        (isSameDay(targetDay, currentMoment)
            ? currentMoment
            : DateTime(targetDay.year, targetDay.month, targetDay.day, 12, 0));

    // Find non-completed tasks on the target day starting at or after the threshold
    final candidateTasks = tasks.where((t) {
      if (t.isCompleted) return false;
      if (!isSameDay(t.startTime, targetDay)) return false;
      return !t.startTime.isBefore(thresholdTime);
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    final shifts = <TaskShiftPreview>[];
    for (final task in candidateTasks) {
      final newStart = task.startTime.add(shiftDuration);
      final newEnd = task.endTime?.add(shiftDuration);
      shifts.add(TaskShiftPreview(
        task: task,
        originalStart: task.startTime,
        originalEnd: task.endTime,
        newStart: newStart,
        newEnd: newEnd,
      ));
    }

    final timeLabel = DateFormat.jm().format(thresholdTime);
    final summary = shifts.isEmpty
        ? 'No upcoming tasks found after $timeLabel to shift.'
        : 'Shift ${shifts.length} task${shifts.length == 1 ? '' : 's'} after $timeLabel by $minutes min.';

    return CommandPreview(
      command: command,
      summary: summary,
      shifts: shifts,
    );
  }

  CommandPreview _previewClearWindow(
    ScheduleCommand command,
    List<TaskItem> tasks,
    DateTime targetDay,
    DateTime currentMoment,
  ) {
    final from = command.fromTime ??
        DateTime(targetDay.year, targetDay.month, targetDay.day, 13, 0);
    final to = command.toTime ??
        from.add(Duration(minutes: command.minutes ?? 120));

    // Find non-completed tasks on targetDay that overlap [from, to]
    final conflicting = tasks.where((t) {
      if (t.isCompleted) return false;
      if (!isSameDay(t.startTime, targetDay)) return false;
      final end = t.endTime ?? t.startTime.add(Duration(minutes: t.durationMinutes));
      return t.startTime.isBefore(to) && end.isAfter(from);
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    final shifts = <TaskShiftPreview>[];
    var nextAvailableTime = to;

    for (final task in conflicting) {
      final duration = Duration(minutes: task.durationMinutes);
      final newStart = nextAvailableTime;
      final newEnd = newStart.add(duration);
      shifts.add(TaskShiftPreview(
        task: task,
        originalStart: task.startTime,
        originalEnd: task.endTime,
        newStart: newStart,
        newEnd: newEnd,
      ));
      nextAvailableTime = newEnd.add(const Duration(minutes: 5)); // 5m breathing room
    }

    final fromStr = DateFormat.jm().format(from);
    final toStr = DateFormat.jm().format(to);
    final summary = shifts.isEmpty
        ? 'Window $fromStr – $toStr is already clear.'
        : 'Free window $fromStr – $toStr and shift ${shifts.length} conflicting task${shifts.length == 1 ? '' : 's'}.';

    return CommandPreview(
      command: command,
      summary: summary,
      shifts: shifts,
    );
  }

  CommandPreview _previewQuickAdd(
    ScheduleCommand command,
    List<TaskItem> tasks,
    DateTime targetDay,
    DateTime currentMoment,
  ) {
    final title = command.taskTitle ?? 'New Task';
    final durationMins = command.minutes ?? 30;
    
    // Choose start time: specified fromTime/afterTime, or next round 15-min slot
    DateTime start;
    if (command.fromTime != null) {
      start = command.fromTime!;
    } else if (command.afterTime != null) {
      start = command.afterTime!;
    } else {
      final base = isSameDay(targetDay, currentMoment) ? currentMoment : targetDay;
      final minuteRounded = ((base.minute / 15).ceil() * 15) % 60;
      final hourAdded = (base.minute >= 45) ? 1 : 0;
      start = DateTime(base.year, base.month, base.day, base.hour + hourAdded, minuteRounded);
    }

    final end = start.add(Duration(minutes: durationMins));
    final candidate = TaskItem(
      id: _uuid.v4(),
      title: title,
      startTime: start,
      endTime: end,
      priority: command.priority ?? 1,
      tags: command.tags,
      note: 'Added via AI Omnibar',
    );

    final summary = 'Add "${candidate.title}" at ${DateFormat.jm().format(start)} (${durationMins}m)';

    return CommandPreview(
      command: command,
      summary: summary,
      newTask: candidate,
    );
  }

  CommandPreview _previewFindFit(
    ScheduleCommand command,
    List<TaskItem> tasks,
    DateTime currentMoment,
  ) {
    final limitMins = command.minutes ?? 30;
    final fitting = tasks.where((t) {
      if (t.isCompleted) return false;
      return t.durationMinutes <= limitMins;
    }).toList()
      ..sort((a, b) {
        // Priority first desc, then shortest duration
        final p = b.priority.compareTo(a.priority);
        if (p != 0) return p;
        return a.durationMinutes.compareTo(b.durationMinutes);
      });

    final summary = fitting.isEmpty
        ? 'No tasks found that take $limitMins minutes or less.'
        : 'Found ${fitting.length} task${fitting.length == 1 ? '' : 's'} fitting in $limitMins min.';

    return CommandPreview(
      command: command,
      summary: summary,
      fittingTasks: fitting,
    );
  }

  CommandPreview _previewStartFocus(
    ScheduleCommand command,
    List<TaskItem> tasks,
    DateTime currentMoment,
  ) {
    final pending = tasks.where((t) => !t.isCompleted).toList();
    TaskItem? target;

    if (command.taskTitle != null && command.taskTitle!.trim().isNotEmpty) {
      final query = command.taskTitle!.trim().toLowerCase();
      target = pending.cast<TaskItem?>().firstWhere(
            (t) => t!.title.toLowerCase().contains(query),
            orElse: () => null,
          );
    }

    // Default to next scheduled task for today or first pending
    if (target == null && pending.isNotEmpty) {
      final todayPending = pending
          .where((t) => isSameDay(t.startTime, currentMoment))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      target = todayPending.isNotEmpty ? todayPending.first : pending.first;
    }

    final summary = target != null
        ? 'Ready to focus on "${target.title}" (${target.durationMinutes}m).'
        : 'No pending tasks available for focus session.';

    return CommandPreview(
      command: command,
      summary: summary,
      focusTask: target,
    );
  }

  /// Executes the command previewed against the controller.
  Future<CommandExecutionResult> execute({
    required CommandPreview preview,
    required TaskController taskController,
  }) async {
    final command = preview.command;

    switch (command.type) {
      case ScheduleCommandType.shift:
      case ScheduleCommandType.clearWindow:
        if (preview.shifts.isEmpty) {
          return const CommandExecutionResult(
            success: true,
            message: 'No tasks needed to be shifted.',
            affectedTasksCount: 0,
          );
        }
        final updatedTasks = preview.shifts.map((s) {
          return s.task.copyWith(
            startTime: s.newStart,
            endTime: s.newEnd,
          );
        }).toList();
        taskController.batchUpdateTasks(updatedTasks);
        return CommandExecutionResult(
          success: true,
          message: 'Updated ${updatedTasks.length} task schedule${updatedTasks.length == 1 ? '' : 's'}.',
          affectedTasksCount: updatedTasks.length,
        );

      case ScheduleCommandType.quickAdd:
        if (preview.newTask == null) {
          return const CommandExecutionResult(
            success: false,
            message: 'Failed to create task.',
          );
        }
        taskController.addTask(preview.newTask!);
        return CommandExecutionResult(
          success: true,
          message: 'Task "${preview.newTask!.title}" added to planner.',
          affectedTasksCount: 1,
          createdTask: preview.newTask,
        );

      case ScheduleCommandType.startFocus:
        return CommandExecutionResult(
          success: preview.focusTask != null,
          message: preview.focusTask != null
              ? 'Launching Focus Mode for "${preview.focusTask!.title}".'
              : 'No task selected for focus.',
          focusTask: preview.focusTask,
        );

      case ScheduleCommandType.findFit:
        return CommandExecutionResult(
          success: true,
          message: 'Found ${preview.fittingTasks.length} fitting tasks.',
          affectedTasksCount: preview.fittingTasks.length,
        );

      case ScheduleCommandType.unknown:
        return CommandExecutionResult(
          success: false,
          message: preview.summary,
        );
    }
  }
}
