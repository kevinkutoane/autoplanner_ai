import 'package:clock/clock.dart';

import '../core/models/calendar_event_model.dart';
import '../core/models/circadian_rhythm.dart';
import '../core/models/task_model.dart';
import 'schedule_drift_service.dart';
import 'scheduler_service.dart';

/// Categories of anticipated schedule conflicts detected by the engine.
enum ConflictType {
  /// Simultaneous commitments scheduled at overlapping times.
  directOverlap,

  /// Consecutive meetings or external appointments with insufficient travel/switch buffer (< 15 min).
  transitBufferCompression,

  /// High-priority commitments dangerously close (< 30 min) or past their hard deadline.
  deadlineCompression,

  /// High-cognitive deep work scheduled during biological recovery dip or rest phase.
  circadianMismatch,
}

/// Urgency / impact severity of an anticipated conflict.
enum ConflictSeverity {
  critical,
  warning,
  advisory,
}

/// Automated resolution actions that can be triggered in 1 tap to resolve an anticipated conflict.
class ConflictResolutionAction {
  final String actionType;
  final String label;
  final String description;
  final Map<String, dynamic> params;

  const ConflictResolutionAction({
    required this.actionType,
    required this.label,
    required this.description,
    this.params = const {},
  });
}

/// Represents an anticipated schedule friction point with diagnostic metadata and 1-tap healing action.
class AnticipatedConflict {
  final String id;
  final ConflictType type;
  final ConflictSeverity severity;
  final String title;
  final String description;
  final List<String> affectedTaskIds;
  final List<String> affectedEventIds;
  final DateTime anticipatedAt;
  final ConflictResolutionAction resolutionAction;

  const AnticipatedConflict({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.affectedTaskIds = const [],
    this.affectedEventIds = const [],
    required this.anticipatedAt,
    required this.resolutionAction,
  });
}

/// Result of executing an automated conflict resolution action.
class ConflictResolutionResult {
  final List<TaskItem> updatedTasks;
  final String summary;
  final bool isSuccess;

  const ConflictResolutionResult({
    required this.updatedTasks,
    required this.summary,
    this.isSuccess = true,
  });
}

/// Autonomous temporal diagnostic engine that predicts conflicts, transit buffer shortages,
/// deadline risks, and circadian mismatches before they cause schedule breakdown.
class ConflictAnticipationService {
  final SchedulerService _scheduler;
  final ScheduleDriftService _driftService;

  static const int minTransitBufferMinutes = 15;
  static const int deadlineWarningThresholdMinutes = 30;

  ConflictAnticipationService({
    SchedulerService? scheduler,
    ScheduleDriftService? driftService,
  })  : _scheduler = scheduler ?? SchedulerService(),
        _driftService = driftService ?? ScheduleDriftService(scheduler: scheduler);

  /// Evaluates current schedule and external events, returning all anticipated conflicts
  /// sorted by severity (critical first, then warning, then advisory).
  List<AnticipatedConflict> evaluateSchedule({
    required List<TaskItem> tasks,
    List<CalendarEvent> calendarEvents = const [],
    DateTime? currentTime,
    String chronotypeId = 'early_bird',
  }) {
    final now = currentTime ?? clock.now();
    final conflicts = <AnticipatedConflict>[];

    // Filter to today's active pending tasks
    final activeTasks = tasks.where((t) {
      if (t.isCompleted) return false;
      return t.startTime.year == now.year &&
          t.startTime.month == now.month &&
          t.startTime.day == now.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final timedEvents = calendarEvents.where((e) {
      if (e.isAllDay) return false;
      return e.startTime.year == now.year &&
          e.startTime.month == now.month &&
          e.startTime.day == now.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // 1. Detect Direct Overlaps between tasks or task-event pairs
    _detectDirectOverlaps(activeTasks, timedEvents, conflicts);

    // 2. Detect Transit Buffer Compression (< 15 min gap between external/off-site events)
    _detectTransitBufferCompression(activeTasks, timedEvents, conflicts);

    // 3. Detect Deadline Compression (< 30 min margin or deadline breach)
    _detectDeadlineCompression(activeTasks, conflicts);

    // 4. Detect Circadian Energy Mismatches (Deep work in recovery dip)
    _detectCircadianMismatches(activeTasks, chronotypeId, conflicts);

    // Sort: Critical -> Warning -> Advisory
    conflicts.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return conflicts;
  }

  /// Executes an automated resolution action, returning updated tasks.
  ConflictResolutionResult applyResolution(
    ConflictResolutionAction action, {
    required List<TaskItem> tasks,
    required int workStartHour,
    required int workHoursPerDay,
    List<CalendarEvent> calendarEvents = const [],
    String chronotypeId = 'early_bird',
    DateTime? currentTime,
  }) {
    final now = currentTime ?? clock.now();

    switch (action.actionType) {
      case 'ripple_schedule':
      case 'auto_ripple':
        final ripple = _driftService.rippleReschedule(
          allTasks: tasks,
          workStartHour: workStartHour,
          workHoursPerDay: workHoursPerDay,
          calendarBlocks: calendarEvents,
          currentTime: now,
          chronotype: chronotypeId,
        );
        return ConflictResolutionResult(
          updatedTasks: ripple.updatedTasks,
          summary: 'Schedule autonomously rippled. ${ripple.shiftedCount} task${ripple.shiftedCount == 1 ? '' : 's'} smoothly repositioned.',
        );

      case 'insert_buffer':
        final taskId = action.params['taskId'] as String? ?? (tasks.isNotEmpty ? tasks.first.id : null);
        final bufferMins = action.params['bufferMinutes'] as int? ?? minTransitBufferMinutes;
        if (taskId == null) {
          return const ConflictResolutionResult(updatedTasks: [], summary: 'No task specified for buffer insertion.', isSuccess: false);
        }

        final updated = <TaskItem>[];
        var found = false;
        for (final t in tasks) {
          if (t.id == taskId) {
            found = true;
            final newStart = t.startTime.add(Duration(minutes: bufferMins));
            final newEnd = t.endTime?.add(Duration(minutes: bufferMins));
            updated.add(t.copyWith(startTime: newStart, endTime: newEnd));
          } else if (found && !t.isCompleted && !t.isFixed) {
            final newStart = t.startTime.add(Duration(minutes: bufferMins));
            final newEnd = t.endTime?.add(Duration(minutes: bufferMins));
            updated.add(t.copyWith(startTime: newStart, endTime: newEnd));
          }
        }
        return ConflictResolutionResult(
          updatedTasks: updated,
          summary: 'Inserted $bufferMins min buffer and adjusted downstream tasks.',
        );

      case 'reschedule_task':
        final taskId = action.params['taskId'] as String?;
        final newStartStr = action.params['newStartTime'] as String?;
        if (taskId != null && newStartStr != null) {
          final newStart = DateTime.parse(newStartStr);
          final updated = tasks.map((t) {
            if (t.id == taskId) {
              final dur = t.endTime != null
                  ? t.endTime!.difference(t.startTime)
                  : Duration(minutes: t.durationMinutes > 0 ? t.durationMinutes : 60);
              return t.copyWith(startTime: newStart, endTime: newStart.add(dur));
            }
            return t;
          }).where((t) => t.id == taskId).toList();
          return ConflictResolutionResult(
            updatedTasks: updated,
            summary: 'Task rescheduled to $newStart.',
          );
        }
        return const ConflictResolutionResult(
          updatedTasks: [],
          summary: 'No valid task or start time specified.',
          isSuccess: false,
        );

      case 'realign_circadian':
      case 'reschedule_day':
        final scheduleResult = _scheduler.scheduleDayWithDetails(
          tasks: tasks,
          day: now,
          workStartHour: workStartHour,
          workHoursPerDay: workHoursPerDay,
          calendarBlocks: calendarEvents,
          chronotype: chronotypeId,
        );
        return ConflictResolutionResult(
          updatedTasks: scheduleResult.scheduledTasks,
          summary: 'Schedule realigned to your ${Chronotype.fromId(chronotypeId).label} circadian peak focus windows.',
        );

      default:
        return const ConflictResolutionResult(
          updatedTasks: [],
          summary: 'Unknown action type.',
          isSuccess: false,
        );
    }
  }

  // ── Diagnostic Evaluators ────────────────────────────────────────────────

  void _detectDirectOverlaps(
    List<TaskItem> tasks,
    List<CalendarEvent> events,
    List<AnticipatedConflict> outConflicts,
  ) {
    // Task-to-task overlaps
    for (var i = 0; i < tasks.length; i++) {
      for (var j = i + 1; j < tasks.length; j++) {
        final a = tasks[i];
        final b = tasks[j];
        final aEnd = a.endTime ?? a.startTime.add(Duration(minutes: a.durationMinutes));
        final bEnd = b.endTime ?? b.startTime.add(Duration(minutes: b.durationMinutes));

        if (a.startTime.isBefore(bEnd) && b.startTime.isBefore(aEnd)) {
          outConflicts.add(
            AnticipatedConflict(
              id: 'overlap_task_${a.id}_${b.id}',
              type: ConflictType.directOverlap,
              severity: ConflictSeverity.critical,
              title: 'Schedule Collision',
              description: '"${a.title}" overlaps with "${b.title}". Both demand your attention at the same time.',
              affectedTaskIds: [a.id, b.id],
              anticipatedAt: a.startTime,
              resolutionAction: ConflictResolutionAction(
                actionType: 'auto_ripple',
                label: 'Auto-Ripple Downstream',
                description: 'Smoothly ripple overlapping tasks forward into adjacent available slots.',
                params: {'taskId': b.id},
              ),
            ),
          );
        }
      }

      // Task-to-event overlaps
      final a = tasks[i];
      final aEnd = a.endTime ?? a.startTime.add(Duration(minutes: a.durationMinutes));
      for (final event in events) {
        if (a.startTime.isBefore(event.endTime) && event.startTime.isBefore(aEnd)) {
          outConflicts.add(
            AnticipatedConflict(
              id: 'overlap_event_${a.id}_${event.id}',
              type: ConflictType.directOverlap,
              severity: ConflictSeverity.critical,
              title: 'External Meeting Collision',
              description: 'Task "${a.title}" clashes with calendar event "${event.title}".',
              affectedTaskIds: [a.id],
              affectedEventIds: [event.id],
              anticipatedAt: a.startTime,
              resolutionAction: ConflictResolutionAction(
                actionType: 'auto_ripple',
                label: 'Shift Around Meeting',
                description: 'Preserve fixed calendar meeting and ripple task to next open opening.',
                params: {'taskId': a.id},
              ),
            ),
          );
        }
      }
    }
  }

  void _detectTransitBufferCompression(
    List<TaskItem> tasks,
    List<CalendarEvent> events,
    List<AnticipatedConflict> outConflicts,
  ) {
    // Check consecutive calendar events or meetings for buffer < 15m
    for (var i = 0; i < events.length - 1; i++) {
      final first = events[i];
      final second = events[i + 1];
      final gapMinutes = second.startTime.difference(first.endTime).inMinutes;

      if (gapMinutes >= 0 && gapMinutes < minTransitBufferMinutes) {
        outConflicts.add(
          AnticipatedConflict(
            id: 'transit_${first.id}_${second.id}',
            type: ConflictType.transitBufferCompression,
            severity: ConflictSeverity.warning,
            title: 'Transit Buffer Shortage ($gapMinutes min)',
            description: 'Only $gapMinutes min gap between "${first.title}" and "${second.title}". High risk of late arrival.',
            affectedEventIds: [first.id, second.id],
            anticipatedAt: first.endTime,
            resolutionAction: ConflictResolutionAction(
              actionType: 'insert_buffer',
              label: 'Guard 15m Travel Buffer',
              description: 'Shield travel and decompression buffer before "${second.title}".',
              params: {'bufferMinutes': minTransitBufferMinutes},
            ),
          ),
        );
      }
    }

    // Check task right before an external calendar event
    for (final task in tasks) {
      final taskEnd = task.endTime ?? task.startTime.add(Duration(minutes: task.durationMinutes));
      for (final event in events) {
        final gapMinutes = event.startTime.difference(taskEnd).inMinutes;
        if (gapMinutes >= 0 && gapMinutes < 10 && (task.tags.contains('deep_work') || task.priority >= 2)) {
          outConflicts.add(
            AnticipatedConflict(
              id: 'transit_task_event_${task.id}_${event.id}',
              type: ConflictType.transitBufferCompression,
              severity: ConflictSeverity.warning,
              title: 'Context Switch Warning',
              description: 'Intense task "${task.title}" finishes only $gapMinutes min before meeting "${event.title}".',
              affectedTaskIds: [task.id],
              affectedEventIds: [event.id],
              anticipatedAt: taskEnd,
              resolutionAction: ConflictResolutionAction(
                actionType: 'auto_ripple',
                label: 'Re-Schedule Before Meeting',
                description: 'Allocate restorative break before meeting starts.',
              ),
            ),
          );
        }
      }
    }
  }

  void _detectDeadlineCompression(
    List<TaskItem> tasks,
    List<AnticipatedConflict> outConflicts,
  ) {
    for (final task in tasks) {
      if (task.deadline == null) continue;
      final finishTime = task.endTime ?? task.startTime.add(Duration(minutes: task.durationMinutes));
      final marginMinutes = task.deadline!.difference(finishTime).inMinutes;

      if (marginMinutes < 0) {
        // Deadline breached!
        outConflicts.add(
          AnticipatedConflict(
            id: 'deadline_breach_${task.id}',
            type: ConflictType.deadlineCompression,
            severity: ConflictSeverity.critical,
            title: 'Deadline Breach Projected',
            description: '"${task.title}" is scheduled to complete at ${finishTime.hour}:${finishTime.minute.toString().padLeft(2, '0')}, which is ${-marginMinutes} min past deadline.',
            affectedTaskIds: [task.id],
            anticipatedAt: finishTime,
            resolutionAction: ConflictResolutionAction(
              actionType: 'realign_circadian',
              label: 'Priority Emergency Reschedule',
              description: 'Re-prioritize and slot task into the earliest available morning/focus block.',
              params: {'taskId': task.id},
            ),
          ),
        );
      } else if (marginMinutes < deadlineWarningThresholdMinutes) {
        // Dangerously narrow safety margin
        outConflicts.add(
          AnticipatedConflict(
            id: 'deadline_tight_${task.id}',
            type: ConflictType.deadlineCompression,
            severity: ConflictSeverity.warning,
            title: 'Tight Deadline Margin ($marginMinutes min)',
            description: '"${task.title}" finishes with only $marginMinutes min safety margin before its deadline (${task.deadline}).',
            affectedTaskIds: [task.id],
            anticipatedAt: finishTime,
            resolutionAction: ConflictResolutionAction(
              actionType: 'realign_circadian',
              label: 'Advance Task Earlier',
              description: 'Advance task earlier in the schedule to safeguard against overrun.',
              params: {'taskId': task.id},
            ),
          ),
        );
      }
    }
  }

  void _detectCircadianMismatches(
    List<TaskItem> tasks,
    String chronotypeId,
    List<AnticipatedConflict> outConflicts,
  ) {
    final chronotype = Chronotype.fromId(chronotypeId);

    for (final task in tasks) {
      final demand = CircadianRhythm.inferCognitiveDemand(task);
      if (demand != CognitiveDemand.deepWork) continue;

      final taskEnd = task.endTime ?? task.startTime.add(Duration(minutes: task.durationMinutes));
      final midPoint = task.startTime.add(taskEnd.difference(task.startTime) ~/ 2);
      final capacity = CircadianRhythm.energyCapacityAt(midPoint, chronotypeId: chronotypeId);
      final phase = CircadianPhase.fromCapacity(capacity);

      if (phase == CircadianPhase.recoveryDip || phase == CircadianPhase.windDown) {
        final percentStr = '${(capacity * 100).round()}%';
        outConflicts.add(
          AnticipatedConflict(
            id: 'circadian_mismatch_${task.id}',
            type: ConflictType.circadianMismatch,
            severity: ConflictSeverity.advisory,
            title: 'Circadian Focus Inefficiency',
            description: 'Deep work task "${task.title}" is slotted during ${chronotype.label} ${phase.label} ($percentStr capacity). You will likely experience sluggish progress.',
            affectedTaskIds: [task.id],
            anticipatedAt: task.startTime,
            resolutionAction: ConflictResolutionAction(
              actionType: 'realign_circadian',
              label: 'Align to Focus Zenith',
              description: 'Move "${task.title}" into your peak biological focus window.',
              params: {'taskId': task.id},
            ),
          ),
        );
      }
    }
  }
}
