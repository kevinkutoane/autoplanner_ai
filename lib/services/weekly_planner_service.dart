import 'dart:math' as math;
import 'package:clock/clock.dart';

import '../core/models/calendar_event_model.dart';
import '../core/models/circadian_rhythm.dart';
import '../core/models/task_model.dart';
import 'dependency_graph_service.dart';
import 'scheduler_service.dart';

/// Capacity status classification for a single planning day.
enum DailyCapacityStatus {
  underloaded, // < 50%
  optimal, // 50% - 85%
  nearCapacity, // 85% - 100%
  overloaded, // > 100%
}

/// Diagnostic capacity summary for a single day within a multi-day planning horizon.
class DailyCapacitySummary {
  final DateTime date;
  final int totalCapacityMinutes;
  final int calendarEventsMinutes;
  final int scheduledTasksMinutes;
  final int deepWorkMinutes;
  final int shallowMinutes;
  final int meetingCount;

  const DailyCapacitySummary({
    required this.date,
    required this.totalCapacityMinutes,
    required this.calendarEventsMinutes,
    required this.scheduledTasksMinutes,
    this.deepWorkMinutes = 0,
    this.shallowMinutes = 0,
    this.meetingCount = 0,
  });

  int get totalAllocatedMinutes =>
      calendarEventsMinutes + scheduledTasksMinutes;

  int get freeMinutes =>
      math.max(0, totalCapacityMinutes - totalAllocatedMinutes);

  double get capacityRatio => totalCapacityMinutes > 0
      ? (totalAllocatedMinutes / totalCapacityMinutes)
      : 0.0;

  DailyCapacityStatus get status {
    if (capacityRatio > 1.0) return DailyCapacityStatus.overloaded;
    if (capacityRatio >= 0.85) return DailyCapacityStatus.nearCapacity;
    if (capacityRatio >= 0.50) return DailyCapacityStatus.optimal;
    return DailyCapacityStatus.underloaded;
  }

  bool get isMeetingHeavy =>
      totalCapacityMinutes > 0 &&
      (calendarEventsMinutes / totalCapacityMinutes) >= 0.40;
}

/// Notice or advisory generated during multi-day capacity balancing.
class WeeklyPlanningNotice {
  final String type;
  final String message;
  final DateTime? date;
  final String? suggestedAction;

  const WeeklyPlanningNotice({
    required this.type,
    required this.message,
    this.date,
    this.suggestedAction,
  });
}

/// Complete output of a multi-day weekly planning or replanning operation.
class WeeklyScheduleResult {
  final Map<DateTime, List<TaskItem>> dayAllocations;
  final List<TaskItem> allScheduledTasks;
  final List<TaskItem> unplacedTasks;
  final List<WeeklyPlanningNotice> notices;
  final List<DailyCapacitySummary> dailySummaries;
  final double balanceScore; // 0.0 - 100.0

  const WeeklyScheduleResult({
    required this.dayAllocations,
    required this.allScheduledTasks,
    required this.unplacedTasks,
    required this.notices,
    required this.dailySummaries,
    required this.balanceScore,
  });
}

/// Backlog diagnostic report measuring accumulated planning debt and stale commitments.
class PlanningDebtReport {
  final double debtIndex; // 0.0 - 100.0
  final List<TaskItem> zombieTasks;
  final List<TaskItem> overdueTasks;
  final List<String> recommendations;

  const PlanningDebtReport({
    required this.debtIndex,
    required this.zombieTasks,
    required this.overdueTasks,
    required this.recommendations,
  });
}

/// Autonomous multi-day capacity allocation and weekly workload balancing engine.
class WeeklyPlannerService {
  final SchedulerService _scheduler;
  final DependencyGraphService _dependencyGraphService;

  WeeklyPlannerService({
    SchedulerService? scheduler,
    DependencyGraphService? dependencyGraphService,
  })  : _scheduler = scheduler ?? SchedulerService(),
        _dependencyGraphService =
            dependencyGraphService ?? DependencyGraphService();

  /// Computes real-time capacity summaries across a multi-day window without altering tasks.
  List<DailyCapacitySummary> getWeeklyCapacitySummaries({
    required List<TaskItem> tasks,
    required DateTime weekStart,
    int daysCount = 7,
    required int workStartHour,
    required int workHoursPerDay,
    List<CalendarEvent> calendarEvents = const [],
  }) {
    final summaries = <DailyCapacitySummary>[];
    final totalCapMins = workHoursPerDay * 60;

    for (var i = 0; i < daysCount; i++) {
      final day = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      ).add(Duration(days: i));

      final dayTasks = tasks.where((t) {
        return t.startTime.year == day.year &&
            t.startTime.month == day.month &&
            t.startTime.day == day.day;
      }).toList();

      final dayEvents = calendarEvents.where((e) {
        if (e.isAllDay) return false;
        return e.startTime.year == day.year &&
            e.startTime.month == day.month &&
            e.startTime.day == day.day;
      }).toList();

      var taskMinutes = 0;
      var deepWorkMinutes = 0;
      var shallowMinutes = 0;

      for (final t in dayTasks) {
        final dur = t.durationMinutes > 0 ? t.durationMinutes : 60;
        taskMinutes += dur;
        final demand = _inferCognitiveDemand(t);
        if (demand == CognitiveDemand.deepWork) {
          deepWorkMinutes += dur;
        } else if (demand == CognitiveDemand.shallow) {
          shallowMinutes += dur;
        }
      }

      var eventMinutes = 0;
      for (final e in dayEvents) {
        final dur = e.endTime.difference(e.startTime).inMinutes;
        if (dur > 0) eventMinutes += dur;
      }

      summaries.add(
        DailyCapacitySummary(
          date: day,
          totalCapacityMinutes: totalCapMins,
          calendarEventsMinutes: eventMinutes,
          scheduledTasksMinutes: taskMinutes,
          deepWorkMinutes: deepWorkMinutes,
          shallowMinutes: shallowMinutes,
          meetingCount: dayEvents.length,
        ),
      );
    }

    return summaries;
  }

  /// Distributes a pool of [tasks] across a 5–7 day planning window, solving multi-day
  /// capacity constraints, chronotype peak matching, meeting load balancing, and DAG dependencies.
  WeeklyScheduleResult planWeek({
    required List<TaskItem> tasks,
    required DateTime weekStart,
    int daysCount = 7,
    required int workStartHour,
    required int workHoursPerDay,
    List<CalendarEvent> calendarEvents = const [],
    String chronotype = 'balanced',
    double targetDailyLoadRatio = 0.85,
    DateTime? currentTime,
  }) {
    final normalizedStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final days = List.generate(
      daysCount,
      (i) => normalizedStart.add(Duration(days: i)),
    );
    final totalDailyCap = workHoursPerDay * 60;
    final notices = <WeeklyPlanningNotice>[];

    // 1. Separate fixed / completed tasks anchored to specific days
    final dayAllocations = <DateTime, List<TaskItem>>{
      for (final d in days) d: <TaskItem>[],
    };
    final unplacedTasks = <TaskItem>[];

    // Compute external calendar event load per day
    final eventLoadPerDay = <DateTime, int>{};
    final dayEventsMap = <DateTime, List<CalendarEvent>>{};
    for (final d in days) {
      final events = calendarEvents.where((e) {
        if (e.isAllDay) return false;
        return e.startTime.year == d.year &&
            e.startTime.month == d.month &&
            e.startTime.day == d.day;
      }).toList();
      dayEventsMap[d] = events;
      var sum = 0;
      for (final e in events) {
        final dur = e.endTime.difference(e.startTime).inMinutes;
        if (dur > 0) sum += dur;
      }
      eventLoadPerDay[d] = sum;

      if (totalDailyCap > 0 && (sum / totalDailyCap) >= 0.40) {
        notices.add(
          WeeklyPlanningNotice(
            type: 'meeting_heavy',
            message:
                '${_formatDayName(d)} is meeting-heavy (${(sum / 60).toStringAsFixed(1)}h). Deep work will be routed to lighter days.',
            date: d,
          ),
        );
      }
    }

    // Identify fixed / already completed tasks that must remain on their assigned day
    final floatingTasks = <TaskItem>[];
    for (final task in tasks) {
      final taskDay = DateTime(
        task.startTime.year,
        task.startTime.month,
        task.startTime.day,
      );
      if (dayAllocations.containsKey(taskDay) && (task.isFixed || task.isCompleted)) {
        dayAllocations[taskDay]!.add(task);
      } else {
        floatingTasks.add(task);
      }
    }

    // 2. Resolve Topological Dependency Order for floating tasks
    final sortedTasks =
        _dependencyGraphService.resolveDependencies(floatingTasks).sortedTasks;

    // Track assigned day for DAG dependencies
    final taskAssignedDay = <String, DateTime>{};
    for (final entry in dayAllocations.entries) {
      for (final t in entry.value) {
        taskAssignedDay[t.id] = entry.key;
      }
    }

    // 3. Multi-Factor Day Assignment Constraint Solver
    for (final task in sortedTasks) {
      final taskDur = task.durationMinutes > 0 ? task.durationMinutes : 60;
      final demand = _inferCognitiveDemand(task);

      // Determine earliest allowable day based on prerequisite tasks
      DateTime minDay = normalizedStart;
      for (final depId in task.dependsOnTaskIds) {
        if (taskAssignedDay.containsKey(depId)) {
          final depDay = taskAssignedDay[depId]!;
          if (depDay.isAfter(minDay)) {
            minDay = depDay;
          }
        }
      }

      // Determine latest allowable day based on hard deadline
      DateTime maxDay = days.last;
      if (task.deadline != null) {
        final dlDay = DateTime(
          task.deadline!.year,
          task.deadline!.month,
          task.deadline!.day,
        );
        if (dlDay.isBefore(maxDay)) {
          maxDay = dlDay;
        }
      }

      // Filter valid candidate days within [minDay, maxDay]
      final candidateDays = days.where((d) {
        return !d.isBefore(minDay) && !d.isAfter(maxDay);
      }).toList();

      if (candidateDays.isEmpty) {
        unplacedTasks.add(task);
        notices.add(
          WeeklyPlanningNotice(
            type: 'deadline_risk',
            message:
                '"${task.title}" has a deadline before earliest allowable scheduling slot.',
            suggestedAction: 'Extend deadline or resolve prerequisite task.',
          ),
        );
        continue;
      }

      // Score candidate days
      DateTime? bestDay;
      var bestScore = -999999.0;

      for (final d in candidateDays) {
        final currentAllocated = (eventLoadPerDay[d] ?? 0) +
            dayAllocations[d]!.fold<int>(
              0,
              (sum, t) => sum + (t.durationMinutes > 0 ? t.durationMinutes : 60),
            );

        final projectedMinutes = currentAllocated + taskDur;
        final projectedRatio =
            totalDailyCap > 0 ? (projectedMinutes / totalDailyCap) : 1.0;

        // Skip days that would strictly breach 100% capacity if alternatives exist
        if (projectedRatio > 1.0 && candidateDays.length > 1) {
          continue;
        }

        var score = 100.0;

        // Load balancing penalty: lower score for days that have higher load ratio
        // This spreads tasks evenly across candidate days.
        score -= projectedRatio * 60.0;

        // Cognitive demand fit
        final isMeetingHeavy =
            totalDailyCap > 0 && ((eventLoadPerDay[d] ?? 0) / totalDailyCap) >= 0.40;
        if (demand == CognitiveDemand.deepWork) {
          if (isMeetingHeavy) {
            score -= 40.0; // Avoid deep work on meeting-heavy days
          } else {
            score += 25.0; // Boost deep work on clear days
          }
        } else if (demand == CognitiveDemand.shallow) {
          if (isMeetingHeavy) {
            score += 20.0; // Absorb shallow admin on meeting-heavy days
          }
        }

        // Deadline urgency incentive: if deadline is approaching, prefer earlier days
        if (task.deadline != null) {
          final daysUntilDeadline = task.deadline!.difference(d).inDays;
          if (daysUntilDeadline >= 0 && daysUntilDeadline <= 2) {
            score += (3 - daysUntilDeadline) * 15.0;
          }
        }

        if (score > bestScore) {
          bestScore = score;
          bestDay = d;
        }
      }

      // Fallback: if all candidate days are at capacity, pick day with lowest projected ratio
      if (bestDay == null) {
        candidateDays.sort((a, b) {
          final loadA = (eventLoadPerDay[a] ?? 0) +
              dayAllocations[a]!.fold<int>(0, (s, t) => s + (t.durationMinutes > 0 ? t.durationMinutes : 60));
          final loadB = (eventLoadPerDay[b] ?? 0) +
              dayAllocations[b]!.fold<int>(0, (s, t) => s + (t.durationMinutes > 0 ? t.durationMinutes : 60));
          return loadA.compareTo(loadB);
        });
        bestDay = candidateDays.first;
      }

      final taskDuration = task.endTime != null
          ? task.endTime!.difference(task.startTime)
          : Duration(minutes: task.durationMinutes > 0 ? task.durationMinutes : 60);
      final rebasedTask = task.copyWith(
        startTime: DateTime(
          bestDay.year,
          bestDay.month,
          bestDay.day,
          task.startTime.hour,
          task.startTime.minute,
        ),
        endTime: DateTime(
          bestDay.year,
          bestDay.month,
          bestDay.day,
          task.startTime.hour,
          task.startTime.minute,
        ).add(taskDuration),
      );

      dayAllocations[bestDay]!.add(rebasedTask);
      taskAssignedDay[task.id] = bestDay;
    }

    // 4. Run single-day SchedulerService on each day allocation to calculate exact slot times
    final allScheduledTasks = <TaskItem>[];
    for (final day in days) {
      final tasksForDay = dayAllocations[day]!;
      if (tasksForDay.isEmpty) continue;

      final scheduleResult = _scheduler.scheduleDayWithDetails(
        tasks: tasksForDay,
        day: day,
        workStartHour: workStartHour,
        workHoursPerDay: workHoursPerDay,
        calendarBlocks: dayEventsMap[day] ?? const [],
        chronotype: chronotype,
      );

      dayAllocations[day] = scheduleResult.scheduledTasks;
      allScheduledTasks.addAll(scheduleResult.scheduledTasks);
      unplacedTasks.addAll(scheduleResult.unplacedTasks);
    }

    // 5. Generate Daily Capacity Summaries
    final dailySummaries = getWeeklyCapacitySummaries(
      tasks: allScheduledTasks,
      weekStart: normalizedStart,
      daysCount: daysCount,
      workStartHour: workStartHour,
      workHoursPerDay: workHoursPerDay,
      calendarEvents: calendarEvents,
    );

    // 6. Calculate Balance Score (measures workload variance)
    final balanceScore = _calculateBalanceScore(dailySummaries);

    return WeeklyScheduleResult(
      dayAllocations: dayAllocations,
      allScheduledTasks: allScheduledTasks,
      unplacedTasks: unplacedTasks,
      notices: notices,
      dailySummaries: dailySummaries,
      balanceScore: balanceScore,
    );
  }

  /// Mid-week recovery pass that detects uncompleted or slipped tasks from past days
  /// of the week and smoothly rebalances them into remaining available days.
  WeeklyScheduleResult replanWeek({
    required List<TaskItem> allTasks,
    required DateTime currentDay,
    int daysCount = 7,
    required int workStartHour,
    required int workHoursPerDay,
    List<CalendarEvent> calendarEvents = const [],
    String chronotype = 'balanced',
  }) {
    final normalizedNow = DateTime(
      currentDay.year,
      currentDay.month,
      currentDay.day,
    );

    // Collect slipped/missed tasks from past days of the week that are not completed
    final slippedTasks = <TaskItem>[];
    final remainingTasks = <TaskItem>[];

    for (final task in allTasks) {
      final taskDay = DateTime(
        task.startTime.year,
        task.startTime.month,
        task.startTime.day,
      );

      if (taskDay.isBefore(normalizedNow)) {
        if (!task.isCompleted && !task.isFixed) {
          slippedTasks.add(task);
        }
      } else {
        remainingTasks.add(task);
      }
    }

    // Combine slipped tasks with remaining tasks and plan forward from currentDay
    final replanPool = [...slippedTasks, ...remainingTasks];

    final result = planWeek(
      tasks: replanPool,
      weekStart: normalizedNow,
      daysCount: daysCount,
      workStartHour: workStartHour,
      workHoursPerDay: workHoursPerDay,
      calendarEvents: calendarEvents,
      chronotype: chronotype,
    );

    if (slippedTasks.isNotEmpty) {
      result.notices.insert(
        0,
        WeeklyPlanningNotice(
          type: 'midweek_recovery',
          message:
              'Mid-week recovery: ${slippedTasks.length} slipped task${slippedTasks.length > 1 ? 's' : ''} rebalanced into remaining open days.',
          suggestedAction: 'Review rescheduled tasks.',
        ),
      );
    }

    return result;
  }

  /// Analyzes task backlog and completion history to measure accumulated planning debt.
  PlanningDebtReport calculatePlanningDebt({
    required List<TaskItem> tasks,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? clock.now();
    final overdue = <TaskItem>[];
    final zombies = <TaskItem>[];
    final recommendations = <String>[];

    var rawDebt = 0.0;

    for (final task in tasks) {
      if (task.isCompleted) continue;

      // Overdue check
      if (task.deadline != null && task.deadline!.isBefore(now)) {
        overdue.add(task);
        rawDebt += 18.0;
      }

      // Slipped / lingering check
      final daysSinceScheduled = now.difference(task.startTime).inDays;
      if (daysSinceScheduled > 7 && !task.isFixed) {
        zombies.add(task);
        rawDebt += 12.0;
      } else if (daysSinceScheduled > 3) {
        rawDebt += 4.0;
      }
    }

    final debtIndex = rawDebt.clamp(0.0, 100.0);

    if (overdue.isNotEmpty) {
      recommendations.add(
        '${overdue.length} overdue task${overdue.length > 1 ? 's' : ''} require immediate resolution or deadline extension.',
      );
    }

    if (zombies.isNotEmpty) {
      recommendations.add(
        'Archive or batch ${zombies.length} stagnant task${zombies.length > 1 ? 's' : ''} that have lingered over 7 days.',
      );
    }

    if (debtIndex < 20.0) {
      recommendations.add('Schedule is in optimal health with minimal planning debt.');
    } else if (debtIndex >= 70.0) {
      recommendations.add('High planning debt: consider a weekly reset pass with /replan-week.');
    }

    return PlanningDebtReport(
      debtIndex: debtIndex,
      zombieTasks: zombies,
      overdueTasks: overdue,
      recommendations: recommendations,
    );
  }

  // ── Helper Math & Classifiers ─────────────────────────────────────────────

  CognitiveDemand _inferCognitiveDemand(TaskItem task) {
    if (task.energyLevel == 'high' || task.priority >= 3) {
      return CognitiveDemand.deepWork;
    }
    if (task.energyLevel == 'low' || task.priority == 0) {
      return CognitiveDemand.shallow;
    }

    final title = task.title.toLowerCase();
    final tags = task.tags.map((t) => t.toLowerCase()).toList();

    const deepKeywords = [
      'code', 'coding', 'develop', 'architecture', 'design', 'write',
      'refactor', 'strategy', 'analysis', 'research', 'audit',
    ];
    const shallowKeywords = [
      'email', 'inbox', 'errand', 'groceries', 'admin', 'sync', 'quick',
      'call', 'receipt', 'clean', 'update',
    ];

    if (deepKeywords.any((k) => title.contains(k) || tags.contains(k))) {
      return CognitiveDemand.deepWork;
    }
    if (shallowKeywords.any((k) => title.contains(k) || tags.contains(k))) {
      return CognitiveDemand.shallow;
    }

    return CognitiveDemand.moderate;
  }

  double _calculateBalanceScore(List<DailyCapacitySummary> summaries) {
    if (summaries.isEmpty) return 100.0;
    final ratios = summaries.map((s) => s.capacityRatio).toList();
    final mean = ratios.reduce((a, b) => a + b) / ratios.length;

    var varianceSum = 0.0;
    for (final r in ratios) {
      varianceSum += math.pow(r - mean, 2);
    }
    final stdDev = math.sqrt(varianceSum / ratios.length);

    // Standard deviation of 0.0 -> score 100. stdDev of 0.50 -> score 50.
    final score = (1.0 - stdDev) * 100.0;
    return score.clamp(0.0, 100.0);
  }

  String _formatDayName(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(d.weekday - 1) % 7];
  }
}
