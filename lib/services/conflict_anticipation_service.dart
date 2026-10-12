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
enum ConflictSeverity { critical, warning, advisory }

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
  // ignore: unused_field
  final ScheduleDriftService _driftService;

  static const int minTransitBufferMinutes = 15;
  static const int deadlineWarningThresholdMinutes = 30;

  final Set<String> _dismissedConflictIds = {};

  ConflictAnticipationService({
    SchedulerService? scheduler,
    ScheduleDriftService? driftService,
  }) : _scheduler = scheduler ?? SchedulerService(),
       _driftService =
           driftService ?? ScheduleDriftService(scheduler: scheduler);

  /// Manually dismisses an anticipated conflict so it will not reappear.
  void dismissConflict(String conflictId) =>
      _dismissedConflictIds.add(conflictId);

  /// Clears all dismissed conflicts, re-enabling them on evaluation.
  void resetDismissedConflicts() => _dismissedConflictIds.clear();

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
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    final timedEvents = calendarEvents.where((e) {
      if (e.isAllDay) return false;
      return e.startTime.year == now.year &&
          e.startTime.month == now.month &&
          e.startTime.day == now.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    // 1. Detect Direct Overlaps between tasks or task-event pairs
    _detectDirectOverlaps(activeTasks, timedEvents, conflicts);

    // 2. Detect Transit Buffer Compression (< 15 min gap between external/off-site events)
    _detectTransitBufferCompression(activeTasks, timedEvents, conflicts);

    // 3. Detect Deadline Compression (< 30 min margin or deadline breach)
    _detectDeadlineCompression(activeTasks, conflicts);

    // 4. Detect Circadian Energy Mismatches (Deep work in recovery dip)
    _detectCircadianMismatches(activeTasks, chronotypeId, conflicts);

    // Filter out user-acknowledged / dismissed conflicts
    conflicts.removeWhere((c) => _dismissedConflictIds.contains(c.id));

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
    final conflictId = action.params['conflictId'] as String?;

    ConflictResolutionResult result;

    switch (action.actionType) {
      case 'ripple_schedule':
      case 'auto_ripple':
        result = _applyAutoRipple(
          action: action,
          tasks: tasks,
          workStartHour: workStartHour,
          workHoursPerDay: workHoursPerDay,
          calendarEvents: calendarEvents,
        );
        break;

      case 'insert_buffer':
        final taskId = action.params['taskId'] as String?;
        final conflictEventId = action.params['conflictEventId'] as String?;
        final bufferMins =
            action.params['bufferMinutes'] as int? ?? minTransitBufferMinutes;

        // If no task specified (e.g. buffer warning between two calendar events), acknowledge and dismiss
        if (taskId == null) {
          result = ConflictResolutionResult(
            updatedTasks: const [],
            summary:
                'Transit buffer alert acknowledged ($bufferMins min travel buffer recommended).',
            isSuccess: true,
          );
          break;
        }

        final targetTask = tasks.where((t) => t.id == taskId).firstOrNull;
        if (targetTask == null ||
            targetTask.isFixed ||
            targetTask.isCompleted) {
          result = const ConflictResolutionResult(
            updatedTasks: [],
            summary: 'Cannot insert buffer on target task.',
            isSuccess: false,
          );
          break;
        }

        if (conflictEventId != null) {
          // Task-before-meeting branch: protect meeting boundary as a hard immovable constraint
          final conflictEvent = calendarEvents
              .where((e) => e.id == conflictEventId)
              .firstOrNull;
          if (conflictEvent == null) {
            result = const ConflictResolutionResult(
              updatedTasks: [],
              summary: 'Conflicting calendar event not found.',
              isSuccess: false,
            );
            break;
          }

          final targetDur = targetTask.endTime != null
              ? targetTask.endTime!.difference(targetTask.startTime)
              : Duration(
                  minutes: targetTask.durationMinutes > 0
                      ? targetTask.durationMinutes
                      : 60,
                );

          // Shift target task earlier so it finishes at least bufferMins before meeting
          final newEnd = conflictEvent.startTime.subtract(
            Duration(minutes: bufferMins),
          );
          final newStart = newEnd.subtract(targetDur);

          final taskDay = conflictEvent.startTime;
          final workStart = DateTime(
            taskDay.year,
            taskDay.month,
            taskDay.day,
            workStartHour,
          );

          var hasCollision = false;

          // Check workday capacity boundary
          if (newStart.isBefore(workStart)) {
            hasCollision = true;
          }

          // Check collisions with other calendar events on that day
          if (!hasCollision) {
            for (final ev in calendarEvents) {
              if (ev.id == conflictEvent.id || ev.isAllDay) continue;
              if (ev.startTime.year != taskDay.year ||
                  ev.startTime.month != taskDay.month ||
                  ev.startTime.day != taskDay.day) {
                continue;
              }
              if (newStart.isBefore(ev.endTime) &&
                  ev.startTime.isBefore(newEnd)) {
                hasCollision = true;
                break;
              }
            }
          }

          // Check collisions with other tasks on that day
          if (!hasCollision) {
            for (final t in tasks) {
              if (t.id == targetTask.id) continue;
              if (t.startTime.year != taskDay.year ||
                  t.startTime.month != taskDay.month ||
                  t.startTime.day != taskDay.day) {
                continue;
              }
              final tDur = t.endTime != null
                  ? t.endTime!.difference(t.startTime)
                  : Duration(
                      minutes: t.durationMinutes > 0 ? t.durationMinutes : 60,
                    );
              final tEnd = t.endTime ?? t.startTime.add(tDur);

              if (newStart.isBefore(tEnd) && t.startTime.isBefore(newEnd)) {
                hasCollision = true;
                break;
              }
            }
          }

          if (hasCollision) {
            result = ConflictResolutionResult(
              updatedTasks: const [],
              summary:
                  'Insufficient time before "${conflictEvent.title}" to allocate a $bufferMins min travel buffer.',
              isSuccess: false,
            );
            break;
          }

          final updatedTarget = targetTask.copyWith(
            startTime: newStart,
            endTime: newEnd,
          );
          result = ConflictResolutionResult(
            updatedTasks: [updatedTarget],
            summary:
                'Rescheduled "${targetTask.title}" before "${conflictEvent.title}" with a $bufferMins min travel buffer.',
            isSuccess: true,
          );
        } else {
          // Standard downstream buffer insertion for task-to-task gaps
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
          result = ConflictResolutionResult(
            updatedTasks: updated,
            summary:
                'Inserted $bufferMins min buffer and adjusted downstream tasks.',
            isSuccess: updated.isNotEmpty,
          );
        }
        break;

      case 'reschedule_task':
        final taskId = action.params['taskId'] as String?;
        final newStartStr = action.params['newStartTime'] as String?;
        if (taskId != null && newStartStr != null) {
          final newStart = DateTime.parse(newStartStr);
          final updated = tasks
              .map((t) {
                if (t.id == taskId) {
                  final dur = t.endTime != null
                      ? t.endTime!.difference(t.startTime)
                      : Duration(
                          minutes: t.durationMinutes > 0
                              ? t.durationMinutes
                              : 60,
                        );
                  return t.copyWith(
                    startTime: newStart,
                    endTime: newStart.add(dur),
                  );
                }
                return t;
              })
              .where((t) => t.id == taskId)
              .toList();
          result = ConflictResolutionResult(
            updatedTasks: updated,
            summary: 'Task rescheduled to $newStart.',
            isSuccess: updated.isNotEmpty,
          );
        } else {
          result = const ConflictResolutionResult(
            updatedTasks: [],
            summary: 'No valid task or start time specified.',
            isSuccess: false,
          );
        }
        break;

      case 'realign_circadian':
      case 'reschedule_day':
        final taskId = action.params['taskId'] as String?;
        TaskItem? targetTask;
        if (taskId != null) {
          for (final t in tasks) {
            if (t.id == taskId) {
              targetTask = t;
              break;
            }
          }
        }
        final targetDay = targetTask != null
            ? DateTime(
                targetTask.startTime.year,
                targetTask.startTime.month,
                targetTask.startTime.day,
              )
            : DateTime(now.year, now.month, now.day);

        final dayTasks = tasks
            .where(
              (t) =>
                  t.startTime.year == targetDay.year &&
                  t.startTime.month == targetDay.month &&
                  t.startTime.day == targetDay.day,
            )
            .toList();

        final scheduleResult = _scheduler.scheduleDayWithDetails(
          tasks: dayTasks.isNotEmpty ? dayTasks : tasks,
          day: targetDay,
          workStartHour: workStartHour,
          workHoursPerDay: workHoursPerDay,
          calendarBlocks: calendarEvents,
          chronotype: chronotypeId,
        );
        final originals = {for (final t in tasks) t.id: t};
        final changed = scheduleResult.scheduledTasks.where((t) {
          final o = originals[t.id];
          return o != null &&
              (o.startTime != t.startTime || o.endTime != t.endTime);
        }).toList();

        result = ConflictResolutionResult(
          updatedTasks: changed,
          summary: changed.isNotEmpty
              ? 'Schedule realigned to your ${Chronotype.fromId(chronotypeId).label} circadian peak focus windows.'
              : 'Tasks already aligned with your circadian peak windows.',
          isSuccess: true,
        );
        break;

      case 'dismiss_conflict':
        result = const ConflictResolutionResult(
          updatedTasks: [],
          summary: 'Conflict notification acknowledged.',
          isSuccess: true,
        );
        break;

      default:
        result = const ConflictResolutionResult(
          updatedTasks: [],
          summary: 'Unknown action type.',
          isSuccess: false,
        );
    }

    if (result.isSuccess && conflictId != null) {
      _dismissedConflictIds.add(conflictId);
    }

    return result;
  }

  ConflictResolutionResult _applyAutoRipple({
    required ConflictResolutionAction action,
    required List<TaskItem> tasks,
    required int workStartHour,
    required int workHoursPerDay,
    required List<CalendarEvent> calendarEvents,
  }) {
    final targetTaskId = action.params['taskId'] as String?;
    final conflictTaskId = action.params['conflictTaskId'] as String?;
    final conflictEventId = action.params['conflictEventId'] as String?;

    // 1. Identify target task to shift
    TaskItem? targetTask;
    if (targetTaskId != null) {
      for (final t in tasks) {
        if (t.id == targetTaskId) {
          targetTask = t;
          break;
        }
      }
    }

    // Fallback: search for any clashing task
    if (targetTask == null) {
      for (var i = 0; i < tasks.length; i++) {
        final a = tasks[i];
        if (a.isCompleted) continue;
        final aEnd =
            a.endTime ??
            a.startTime.add(
              Duration(minutes: a.durationMinutes > 0 ? a.durationMinutes : 60),
            );
        for (var j = i + 1; j < tasks.length; j++) {
          final b = tasks[j];
          if (b.isCompleted) continue;
          final bEnd =
              b.endTime ??
              b.startTime.add(
                Duration(
                  minutes: b.durationMinutes > 0 ? b.durationMinutes : 60,
                ),
              );
          if (a.startTime.isBefore(bEnd) && b.startTime.isBefore(aEnd)) {
            targetTask = b;
            break;
          }
        }
        if (targetTask != null) break;
        for (final ev in calendarEvents) {
          if (ev.isAllDay) continue;
          if (a.startTime.isBefore(ev.endTime) && ev.startTime.isBefore(aEnd)) {
            targetTask = a;
            break;
          }
        }
        if (targetTask != null) break;
      }
    }

    if (targetTask == null) {
      return const ConflictResolutionResult(
        updatedTasks: [],
        summary: 'No overlapping tasks to ripple.',
        isSuccess: false,
      );
    }

    if (targetTask.isFixed) {
      return ConflictResolutionResult(
        updatedTasks: const [],
        summary: 'Cannot ripple fixed task "${targetTask.title}".',
        isSuccess: false,
      );
    }

    final originalTargetStart = targetTask.startTime;
    final taskDay = originalTargetStart;

    // 2. Determine target start boundary past the colliding block
    DateTime targetStart = originalTargetStart;
    if (conflictTaskId != null) {
      for (final t in tasks) {
        if (t.id == conflictTaskId) {
          final cEnd =
              t.endTime ??
              t.startTime.add(
                Duration(
                  minutes: t.durationMinutes > 0 ? t.durationMinutes : 60,
                ),
              );
          if (cEnd.isAfter(targetStart)) targetStart = cEnd;
          break;
        }
      }
    } else if (conflictEventId != null) {
      for (final ev in calendarEvents) {
        if (ev.id == conflictEventId) {
          if (ev.endTime.isAfter(targetStart)) targetStart = ev.endTime;
          break;
        }
      }
    } else {
      // Find any collision with targetTask
      final curEnd =
          targetTask.endTime ??
          targetTask.startTime.add(
            Duration(
              minutes: targetTask.durationMinutes > 0
                  ? targetTask.durationMinutes
                  : 60,
            ),
          );
      for (final t in tasks) {
        if (t.id == targetTask.id || t.isCompleted) continue;
        final tEnd =
            t.endTime ??
            t.startTime.add(
              Duration(minutes: t.durationMinutes > 0 ? t.durationMinutes : 60),
            );
        if (targetTask.startTime.isBefore(tEnd) &&
            t.startTime.isBefore(curEnd)) {
          if (tEnd.isAfter(targetStart)) targetStart = tEnd;
        }
      }
      for (final ev in calendarEvents) {
        if (ev.isAllDay) continue;
        if (targetTask.startTime.isBefore(ev.endTime) &&
            ev.startTime.isBefore(curEnd)) {
          if (ev.endTime.isAfter(targetStart)) targetStart = ev.endTime;
        }
      }
    }

    if (targetStart == originalTargetStart) {
      targetStart = originalTargetStart.add(const Duration(minutes: 30));
    }

    // Capacity window for the day
    final workStart = DateTime(
      taskDay.year,
      taskDay.month,
      taskDay.day,
      workStartHour,
    );
    final workEnd = workStart.add(Duration(hours: workHoursPerDay));
    final eod = DateTime(taskDay.year, taskDay.month, taskDay.day, 23, 59);
    final effectiveLimit = originalTargetStart.isBefore(workEnd)
        ? workEnd
        : eod;

    // Same-day active tasks and events
    final sameDayTasks =
        tasks
            .where(
              (t) =>
                  !t.isCompleted &&
                  t.startTime.year == taskDay.year &&
                  t.startTime.month == taskDay.month &&
                  t.startTime.day == taskDay.day,
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final sameDayEvents =
        calendarEvents
            .where(
              (e) =>
                  !e.isAllDay &&
                  e.startTime.year == taskDay.year &&
                  e.startTime.month == taskDay.month &&
                  e.startTime.day == taskDay.day,
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Immovable obstacles:
    // 1. External calendar events
    // 2. Fixed tasks on that day
    // 3. Tasks scheduled BEFORE originalTargetStart (must remain untouched!)
    final immovableObstacles = <_TimeBlock>[
      for (final ev in sameDayEvents) _TimeBlock(ev.startTime, ev.endTime),
      for (final t in sameDayTasks)
        if (t.id != targetTask.id &&
            (t.isFixed || t.startTime.isBefore(originalTargetStart)))
          _TimeBlock(
            t.startTime,
            t.endTime ??
                t.startTime.add(
                  Duration(
                    minutes: t.durationMinutes > 0 ? t.durationMinutes : 60,
                  ),
                ),
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    // Helper: find next slot not overlapping any immovable obstacle
    DateTime avoidObstacles(DateTime start, Duration dur) {
      var cur = start;
      var shifted = true;
      while (shifted) {
        shifted = false;
        final end = cur.add(dur);
        for (final obs in immovableObstacles) {
          if (cur.isBefore(obs.end) && obs.start.isBefore(end)) {
            cur = obs.end;
            shifted = true;
          }
        }
      }
      return cur;
    }

    final targetDur = targetTask.endTime != null
        ? targetTask.endTime!.difference(targetTask.startTime)
        : Duration(
            minutes: targetTask.durationMinutes > 0
                ? targetTask.durationMinutes
                : 60,
          );

    final adjustedStart = avoidObstacles(targetStart, targetDur);
    final adjustedEnd = adjustedStart.add(targetDur);

    // Verify target task fits within remaining schedule capacity
    if (adjustedEnd.isAfter(effectiveLimit)) {
      return const ConflictResolutionResult(
        updatedTasks: [],
        summary: 'Insufficient remaining schedule capacity to ripple tasks.',
        isSuccess: false,
      );
    }

    final updatedMap = <String, TaskItem>{};
    final updatedTarget = targetTask.copyWith(
      startTime: adjustedStart,
      endTime: adjustedEnd,
    );
    updatedMap[updatedTarget.id] = updatedTarget;

    // 4. Cascade ONLY affected downstream tasks:
    // Downstream tasks are non-fixed tasks scheduled at or after originalTargetStart
    final downstreamTasks =
        sameDayTasks
            .where(
              (t) =>
                  t.id != targetTask!.id &&
                  !t.isFixed &&
                  !t.startTime.isBefore(originalTargetStart),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    var cursor = adjustedEnd;
    for (final t in downstreamTasks) {
      final tDur = t.endTime != null
          ? t.endTime!.difference(t.startTime)
          : Duration(minutes: t.durationMinutes > 0 ? t.durationMinutes : 60);

      if (t.startTime.isBefore(cursor)) {
        final newStart = avoidObstacles(cursor, tDur);
        final newEnd = newStart.add(tDur);

        if (newEnd.isAfter(effectiveLimit)) {
          return const ConflictResolutionResult(
            updatedTasks: [],
            summary:
                'Insufficient remaining schedule capacity to ripple tasks.',
            isSuccess: false,
          );
        }

        final moved = t.copyWith(startTime: newStart, endTime: newEnd);
        updatedMap[moved.id] = moved;
        cursor = newEnd;
      } else {
        final clearStart = avoidObstacles(t.startTime, tDur);
        final clearEnd = clearStart.add(tDur);

        if (clearEnd.isAfter(effectiveLimit)) {
          return const ConflictResolutionResult(
            updatedTasks: [],
            summary:
                'Insufficient remaining schedule capacity to ripple tasks.',
            isSuccess: false,
          );
        }

        if (clearStart != t.startTime) {
          final moved = t.copyWith(startTime: clearStart, endTime: clearEnd);
          updatedMap[moved.id] = moved;
          cursor = clearEnd;
        } else {
          final tEnd = t.endTime ?? t.startTime.add(tDur);
          if (tEnd.isAfter(cursor)) cursor = tEnd;
        }
      }
    }

    final changedTasks = updatedMap.values.toList();
    return ConflictResolutionResult(
      updatedTasks: changedTasks,
      summary:
          'Schedule autonomously rippled. ${changedTasks.length} task${changedTasks.length == 1 ? '' : 's'} smoothly repositioned.',
      isSuccess: changedTasks.isNotEmpty,
    );
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
        final aEnd =
            a.endTime ?? a.startTime.add(Duration(minutes: a.durationMinutes));
        final bEnd =
            b.endTime ?? b.startTime.add(Duration(minutes: b.durationMinutes));

        if (a.startTime.isBefore(bEnd) && b.startTime.isBefore(aEnd)) {
          outConflicts.add(
            AnticipatedConflict(
              id: 'overlap_task_${a.id}_${b.id}',
              type: ConflictType.directOverlap,
              severity: ConflictSeverity.critical,
              title: 'Schedule Collision',
              description:
                  '"${a.title}" overlaps with "${b.title}". Both demand your attention at the same time.',
              affectedTaskIds: [a.id, b.id],
              anticipatedAt: a.startTime,
              resolutionAction: ConflictResolutionAction(
                actionType: 'auto_ripple',
                label: 'Auto-Ripple Downstream',
                description: 'Smoothly ripple overlapping tasks forward into adjacent available slots.',
                params: {
                  'taskId': b.id,
                  'conflictTaskId': a.id,
                  'conflictId': 'overlap_task_${a.id}_${b.id}',
                },
              ),
            ),
          );
        }
      }

      // Task-to-event overlaps
      final a = tasks[i];
      final aEnd =
          a.endTime ?? a.startTime.add(Duration(minutes: a.durationMinutes));
      for (final event in events) {
        if (a.startTime.isBefore(event.endTime) &&
            event.startTime.isBefore(aEnd)) {
          outConflicts.add(
            AnticipatedConflict(
              id: 'overlap_event_${a.id}_${event.id}',
              type: ConflictType.directOverlap,
              severity: ConflictSeverity.critical,
              title: 'External Meeting Collision',
              description:
                  'Task "${a.title}" clashes with calendar event "${event.title}".',
              affectedTaskIds: [a.id],
              affectedEventIds: [event.id],
              anticipatedAt: a.startTime,
              resolutionAction: ConflictResolutionAction(
                actionType: 'auto_ripple',
                label: 'Shift Around Meeting',
                description: 'Preserve fixed calendar meeting and ripple task to next open opening.',
                params: {
                  'taskId': a.id,
                  'conflictEventId': event.id,
                  'conflictId': 'overlap_event_${a.id}_${event.id}',
                },
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
            description:
                'Only $gapMinutes min gap between "${first.title}" and "${second.title}". High risk of late arrival.',
            affectedEventIds: [first.id, second.id],
            anticipatedAt: first.endTime,
            resolutionAction: ConflictResolutionAction(
              actionType: 'insert_buffer',
              label: 'Guard 15m Travel Buffer',
              description:
                  'Shield travel and decompression buffer before "${second.title}".',
              params: {
                'bufferMinutes': minTransitBufferMinutes,
                'conflictId': 'transit_${first.id}_${second.id}',
              },
            ),
          ),
        );
      }
    }

    // Check task right before an external calendar event
    for (final task in tasks) {
      final taskEnd =
          task.endTime ??
          task.startTime.add(Duration(minutes: task.durationMinutes));
      for (final event in events) {
        final gapMinutes = event.startTime.difference(taskEnd).inMinutes;
        if (gapMinutes >= 0 &&
            gapMinutes < 10 &&
            (task.tags.contains('deep_work') || task.priority >= 2)) {
          outConflicts.add(
            AnticipatedConflict(
              id: 'transit_task_event_${task.id}_${event.id}',
              type: ConflictType.transitBufferCompression,
              severity: ConflictSeverity.warning,
              title: 'Context Switch Warning',
              description:
                  'Intense task "${task.title}" finishes only $gapMinutes min before meeting "${event.title}".',
              affectedTaskIds: [task.id],
              affectedEventIds: [event.id],
              anticipatedAt: taskEnd,
              resolutionAction: ConflictResolutionAction(
                actionType: 'insert_buffer',
                label: 'Re-Schedule Before Meeting',
                description:
                    'Allocate restorative break before meeting starts.',
                params: {
                  'taskId': task.id,
                  'conflictEventId': event.id,
                  'bufferMinutes': minTransitBufferMinutes,
                  'conflictId': 'transit_task_event_${task.id}_${event.id}',
                },
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
      final finishTime =
          task.endTime ??
          task.startTime.add(Duration(minutes: task.durationMinutes));
      final marginMinutes = task.deadline!.difference(finishTime).inMinutes;

      if (marginMinutes < 0) {
        // Deadline breached!
        outConflicts.add(
          AnticipatedConflict(
            id: 'deadline_breach_${task.id}',
            type: ConflictType.deadlineCompression,
            severity: ConflictSeverity.critical,
            title: 'Deadline Breach Projected',
            description:
                '"${task.title}" is scheduled to complete at ${finishTime.hour}:${finishTime.minute.toString().padLeft(2, '0')}, which is ${-marginMinutes} min past deadline.',
            affectedTaskIds: [task.id],
            anticipatedAt: finishTime,
            resolutionAction: ConflictResolutionAction(
              actionType: 'realign_circadian',
              label: 'Priority Emergency Reschedule',
              description: 'Re-prioritize and slot task into the earliest available morning/focus block.',
              params: {
                'taskId': task.id,
                'conflictId': 'deadline_breach_${task.id}',
              },
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
            description:
                '"${task.title}" finishes with only $marginMinutes min safety margin before its deadline (${task.deadline}).',
            affectedTaskIds: [task.id],
            anticipatedAt: finishTime,
            resolutionAction: ConflictResolutionAction(
              actionType: 'realign_circadian',
              label: 'Advance Task Earlier',
              description: 'Advance task earlier in the schedule to safeguard against overrun.',
              params: {
                'taskId': task.id,
                'conflictId': 'deadline_tight_${task.id}',
              },
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

      final taskEnd =
          task.endTime ??
          task.startTime.add(Duration(minutes: task.durationMinutes));
      final midPoint = task.startTime.add(
        taskEnd.difference(task.startTime) ~/ 2,
      );
      final capacity = CircadianRhythm.energyCapacityAt(
        midPoint,
        chronotypeId: chronotypeId,
      );
      final phase = CircadianPhase.fromCapacity(capacity);

      if (phase == CircadianPhase.recoveryDip ||
          phase == CircadianPhase.windDown) {
        final percentStr = '${(capacity * 100).round()}%';
        outConflicts.add(
          AnticipatedConflict(
            id: 'circadian_mismatch_${task.id}',
            type: ConflictType.circadianMismatch,
            severity: ConflictSeverity.advisory,
            title: 'Circadian Focus Inefficiency',
            description:
                'Deep work task "${task.title}" is slotted during ${chronotype.label} ${phase.label} ($percentStr capacity). You will likely experience sluggish progress.',
            affectedTaskIds: [task.id],
            anticipatedAt: task.startTime,
            resolutionAction: ConflictResolutionAction(
              actionType: 'realign_circadian',
              label: 'Align to Focus Zenith',
              description:
                  'Move "${task.title}" into your peak biological focus window.',
              params: {
                'taskId': task.id,
                'conflictId': 'circadian_mismatch_${task.id}',
              },
            ),
          ),
        );
      }
    }
  }
}

class _TimeBlock {
  final DateTime start;
  final DateTime end;

  const _TimeBlock(this.start, this.end);
}
