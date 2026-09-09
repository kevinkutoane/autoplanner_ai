import 'package:clock/clock.dart';
import '../core/models/task_model.dart';
import '../core/models/calendar_event_model.dart';
import '../core/models/schedule_result.dart';
import 'dependency_graph_service.dart';

/// Intelligent, constraint-based deterministic day-scheduling engine.
///
/// Features:
/// - Directed Acyclic Graph (DAG) task dependency resolution with cycle safety.
/// - Task splitting: decomposes long splittable tasks across focus sessions with restorative breaks.
/// - Multi-factor planning score: optimizes priority, deadlines, energy levels, preferred time of day, and context switching.
/// - Immovable anchors: completed tasks and fixed tasks ([TaskItem.isFixed]) schedule around existing times.
/// - Explainability: outputs [TaskPlacementRationale] per task explaining slot assignment.
class SchedulerService {
  static const _bufferMinutes = 10;
  static const _defaultDurationMinutes = 60;
  static const _minValidDurationMinutes = 15;
  static const _slotRoundingMinutes = 15;

  final DependencyGraphService _dependencyGraphService;

  SchedulerService({DependencyGraphService? dependencyGraphService})
    : _dependencyGraphService =
          dependencyGraphService ?? DependencyGraphService();

  /// Assigns start/end times to all *pending* tasks in [tasks].
  ///
  /// Backwards-compatible convenience wrapper returning a flattened, sorted list of tasks.
  List<TaskItem> scheduleDay({
    required List<TaskItem> tasks,
    required DateTime day,
    required int workStartHour,
    required int workHoursPerDay,
    List<CalendarEvent> calendarBlocks = const [],
  }) {
    return scheduleDayWithDetails(
      tasks: tasks,
      day: day,
      workStartHour: workStartHour,
      workHoursPerDay: workHoursPerDay,
      calendarBlocks: calendarBlocks,
    ).scheduledTasks;
  }

  /// Advanced constraint-based scheduler returning full [ScheduleResult] with
  /// explainability rationale, unplaced tasks, and constraint warnings.
  ScheduleResult scheduleDayWithDetails({
    required List<TaskItem> tasks,
    required DateTime day,
    required int workStartHour,
    required int workHoursPerDay,
    List<CalendarEvent> calendarBlocks = const [],
  }) {
    final workStart = DateTime(day.year, day.month, day.day, workStartHour);
    var workEnd = workStart.add(Duration(hours: workHoursPerDay));

    // When scheduling "today" after the normal work window has closed,
    // extend the end-of-day to 23:59 so tasks can still be placed.
    final now = clock.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    if (isToday && now.isAfter(workEnd)) {
      workEnd = DateTime(day.year, day.month, day.day, 23, 59);
    }

    final warnings = <ScheduleWarning>[];

    // 1. Partition tasks
    final completed = tasks.where((t) => t.isCompleted).toList();
    final fixed = tasks.where((t) => !t.isCompleted && t.isFixed).toList();
    final unfixedPending = tasks
        .where((t) => !t.isCompleted && !t.isFixed)
        .toList();

    // 2. Task Splitting
    final expandedPending = <TaskItem>[];
    for (final task in unfixedPending) {
      final dur = _duration(task);
      final preferredChunk =
          task.preferredBlockMinutes ?? _defaultDurationMinutes;

      if (task.splittable &&
          dur.inMinutes > preferredChunk &&
          preferredChunk >= _minValidDurationMinutes) {
        final totalMins = dur.inMinutes;
        final numChunks = (totalMins / preferredChunk).ceil();

        var allocatedMins = 0;
        for (var k = 0; k < numChunks; k++) {
          final isLast = k == numChunks - 1;
          final remaining = totalMins - allocatedMins;
          final chunkMins = isLast ? remaining : preferredChunk;
          allocatedMins += chunkMins;

          final chunkId = '${task.id}_chunk_${k + 1}';
          final prereqs = k == 0
              ? List<String>.from(task.dependsOnTaskIds)
              : ['${task.id}_chunk_$k'];

          expandedPending.add(
            task.copyWith(
              id: chunkId,
              title: '${task.title} (Part ${k + 1}/$numChunks)',
              startTime: task.startTime,
              endTime: task.startTime.add(Duration(minutes: chunkMins)),
              parentTaskId: task.id,
              dependsOnTaskIds: prereqs,
              splittable: false,
            ),
          );
        }
      } else {
        expandedPending.add(task);
      }
    }

    // 3. Resolve Dependencies & Cycle Detection
    final depResult = _dependencyGraphService.resolveDependencies(
      expandedPending,
    );
    for (final warnMsg in depResult.warnings) {
      warnings.add(ScheduleWarning(code: 'cycle_detected', message: warnMsg));
    }

    // 4. Immovable occupied intervals: completed tasks + fixed tasks + external calendar events
    final occupied = <_Interval>[
      for (final t in completed)
        _Interval(
          t.startTime,
          t.endTime ?? t.startTime.add(const Duration(hours: 1)),
        ),
      for (final t in fixed)
        _Interval(
          t.startTime,
          t.endTime ?? t.startTime.add(const Duration(hours: 1)),
        ),
      for (final e in calendarBlocks)
        if (!e.isAllDay) _Interval(e.startTime, e.endTime),
    ]..sort((a, b) => a.start.compareTo(b.start));

    // Map of placed tasks for prerequisite end-time lookup
    final placedMap = <String, TaskItem>{
      for (final t in completed) t.id: t,
      for (final t in fixed) t.id: t,
    };

    final scheduled = <TaskItem>[];
    final unplaced = <TaskItem>[];
    final explanations = <String, TaskPlacementRationale>{};

    TaskItem? lastScheduled;

    // 5. Intelligent Multi-Factor Constraint-Based Placement
    for (final task in depResult.sortedTasks) {
      final dur = _duration(task);

      // Prerequisite constraint
      final prereqTime = _dependencyGraphService.getPrerequisiteConstraintTime(
        task: task,
        scheduledOrCompletedTasks: placedMap,
        bufferMinutes: _bufferMinutes,
      );

      // Earliest permissible start
      var earliestAllowed = _initialCursor(workStart, day);
      if (prereqTime != null && prereqTime.isAfter(earliestAllowed)) {
        earliestAllowed = prereqTime;
      }
      if (task.earliestStart != null &&
          task.earliestStart!.isAfter(earliestAllowed)) {
        earliestAllowed = task.earliestStart!;
      }

      // Find candidate free slots that fit the duration
      final candidates = _findCandidateSlots(
        cursor: earliestAllowed,
        needed: dur,
        occupied: occupied,
        workEnd: workEnd,
        latestFinish: task.latestFinish,
        maxCandidates: 4,
      );

      if (candidates.isEmpty) {
        unplaced.add(task);
        warnings.add(
          ScheduleWarning(
            code: 'no_slot_available',
            message:
                'Unable to schedule "${task.title}" within work window constraints.',
            affectedTaskId: task.id,
          ),
        );
        continue;
      }

      // Evaluate candidate slots using Multi-Factor Score
      _CandidateEvaluation? bestCandidate;

      for (final candidateSlot in candidates) {
        final eval = _scoreSlot(
          task: task,
          slot: candidateSlot,
          workStart: workStart,
          workEnd: workEnd,
          lastScheduled: lastScheduled,
          prereqTime: prereqTime,
        );

        if (bestCandidate == null || eval.score > bestCandidate.score) {
          bestCandidate = eval;
        }
      }

      final chosenSlot = bestCandidate!.slot;
      final placedTask = task.copyWith(
        startTime: chosenSlot.start,
        endTime: chosenSlot.end,
      );

      scheduled.add(placedTask);
      placedMap[task.id] = placedTask;
      lastScheduled = placedTask;

      occupied
        ..add(_Interval(chosenSlot.start, chosenSlot.end))
        ..sort((a, b) => a.start.compareTo(b.start));

      explanations[task.id] = TaskPlacementRationale(
        taskId: task.id,
        assignedStart: chosenSlot.start,
        assignedEnd: chosenSlot.end,
        score: bestCandidate.score,
        factors: bestCandidate.factors,
      );

      // Deadline warning check
      if (task.deadline != null && chosenSlot.end.isAfter(task.deadline!)) {
        warnings.add(
          ScheduleWarning(
            code: 'deadline_exceeded',
            message:
                'Task "${task.title}" finishes after its deadline (${task.deadline}).',
            affectedTaskId: task.id,
          ),
        );
      }
    }

    final allScheduled = [...completed, ...fixed, ...scheduled]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return ScheduleResult(
      scheduledTasks: allScheduled,
      unplacedTasks: unplaced,
      explanations: explanations,
      warnings: warnings,
    );
  }

  /// Returns up to [count] available start times on [day] within the work
  /// window, skipping slots blocked by [busyTasks] and [calendarBlocks].
  List<DateTime> freeSlots({
    required DateTime day,
    required int workStartHour,
    required int workHoursPerDay,
    required Duration slotDuration,
    List<TaskItem> busyTasks = const [],
    List<CalendarEvent> calendarBlocks = const [],
    int count = 6,
  }) {
    final workStart = DateTime(day.year, day.month, day.day, workStartHour);
    var workEnd = workStart.add(Duration(hours: workHoursPerDay));

    final now = clock.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    if (isToday && now.isAfter(workEnd)) {
      workEnd = DateTime(day.year, day.month, day.day, 23, 59);
    }

    final occupied = <_Interval>[
      for (final t in busyTasks)
        _Interval(
          t.startTime,
          t.endTime ?? t.startTime.add(const Duration(hours: 1)),
        ),
      for (final e in calendarBlocks)
        if (!e.isAllDay) _Interval(e.startTime, e.endTime),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final results = <DateTime>[];
    var cursor = _initialCursor(workStart, day);

    while (results.length < count) {
      cursor = _findFreeSlot(cursor, slotDuration, occupied, workEnd);
      if (cursor.add(slotDuration).isAfter(workEnd)) break;
      results.add(cursor);
      cursor = cursor
          .add(slotDuration)
          .add(const Duration(minutes: _bufferMinutes));
    }
    return results;
  }

  // ── Scoring & Constraints Helper ──────────────────────────────────────────

  _CandidateEvaluation _scoreSlot({
    required TaskItem task,
    required _Interval slot,
    required DateTime workStart,
    required DateTime workEnd,
    required TaskItem? lastScheduled,
    required DateTime? prereqTime,
  }) {
    var score = 0.0;
    final factors = <String>[];

    // 1. Priority Weight (0 to 30)
    final priorityScore = task.priority * 10.0;
    score += priorityScore;
    factors.add('${task.priorityLabel} priority (+$priorityScore)');

    // 2. Deadline Urgency
    if (task.deadline != null) {
      if (slot.end.isBefore(task.deadline!)) {
        score += 20.0;
        factors.add('Satisfies deadline before ${task.deadline} (+20)');
      } else {
        score -= 30.0;
        factors.add('Violates deadline (-30)');
      }
    }

    // 3. Goal Alignment
    if (task.linkedGoalId != null) {
      score += 5.0;
      factors.add('Aligned with active goal (+5)');
    }

    // 4. Energy & Time of Day Matching
    final slotHour = slot.start.hour;
    if (slotHour < 12) {
      // Morning
      if (task.energyLevel == 'high') {
        score += 8.0;
        factors.add('High energy task in morning focus block (+8)');
      }
      if (task.preferredTimeOfDay == 'morning') {
        score += 10.0;
        factors.add('Matched morning preference (+10)');
      }
    } else if (slotHour < 17) {
      // Afternoon
      if (task.energyLevel == 'medium') {
        score += 5.0;
        factors.add('Medium energy task in afternoon (+5)');
      }
      if (task.preferredTimeOfDay == 'afternoon') {
        score += 10.0;
        factors.add('Matched afternoon preference (+10)');
      }
    } else {
      // Evening
      if (task.energyLevel == 'low') {
        score += 6.0;
        factors.add('Low energy task in evening (+6)');
      }
      if (task.preferredTimeOfDay == 'evening') {
        score += 10.0;
        factors.add('Matched evening preference (+10)');
      }
    }

    // 5. Context Continuity (Project & Tag coherence)
    if (lastScheduled != null) {
      if (task.linkedProjectId != null &&
          task.linkedProjectId == lastScheduled.linkedProjectId) {
        score += 5.0;
        factors.add('Coherent with previous project (+5)');
      }
      final sharedTags = task.tags.toSet().intersection(
        lastScheduled.tags.toSet(),
      );
      if (sharedTags.isNotEmpty) {
        score += 3.0;
        factors.add('Shared tag context: ${sharedTags.first} (+3)');
      }
    }

    // 6. Compactness: slight bonus for earlier placement to avoid fragmented schedules
    final totalDayMinutes = workEnd.difference(workStart).inMinutes;
    if (totalDayMinutes > 0) {
      final slotOffsetMinutes = slot.start.difference(workStart).inMinutes;
      final compactnessBonus =
          (1.0 - (slotOffsetMinutes / totalDayMinutes)) * 4.0;
      score += compactnessBonus;
    }

    if (prereqTime != null) {
      factors.add('Scheduled after prerequisite completion ($prereqTime)');
    }

    return _CandidateEvaluation(slot: slot, score: score, factors: factors);
  }

  List<_Interval> _findCandidateSlots({
    required DateTime cursor,
    required Duration needed,
    required List<_Interval> occupied,
    required DateTime workEnd,
    required DateTime? latestFinish,
    required int maxCandidates,
  }) {
    final results = <_Interval>[];
    var currentCursor = cursor;

    while (results.length < maxCandidates) {
      currentCursor = _findFreeSlot(currentCursor, needed, occupied, workEnd);
      final slotEnd = currentCursor.add(needed);

      if (slotEnd.isAfter(workEnd)) break;
      if (latestFinish != null && slotEnd.isAfter(latestFinish)) break;

      results.add(_Interval(currentCursor, slotEnd));
      currentCursor = slotEnd.add(const Duration(minutes: _bufferMinutes));
    }

    return results;
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  DateTime _initialCursor(DateTime workStart, DateTime day) {
    final now = clock.now();
    final isToday =
        now.year == day.year && now.month == day.month && now.day == day.day;
    if (isToday && now.isAfter(workStart)) {
      final rem = now.minute % _slotRoundingMinutes;
      final pad = rem == 0 ? 0 : _slotRoundingMinutes - rem;
      return now
          .add(Duration(minutes: pad + 2))
          .copyWith(second: 0, millisecond: 0, microsecond: 0);
    }
    return workStart;
  }

  Duration _duration(TaskItem task) {
    if (task.endTime != null) {
      final d = task.endTime!.difference(task.startTime);
      if (d.inMinutes >= _minValidDurationMinutes) return d;
    }
    return const Duration(minutes: _defaultDurationMinutes);
  }

  DateTime _findFreeSlot(
    DateTime cursor,
    Duration needed,
    List<_Interval> occupied,
    DateTime workEnd,
  ) {
    var candidate = cursor;
    for (var i = 0; i < 200; i++) {
      if (candidate.add(needed).isAfter(workEnd)) return workEnd;
      final clash = _firstOverlap(candidate, candidate.add(needed), occupied);
      if (clash == null) return candidate;
      candidate = clash.end.add(const Duration(minutes: _bufferMinutes));
    }
    return workEnd;
  }

  _Interval? _firstOverlap(
    DateTime start,
    DateTime end,
    List<_Interval> occupied,
  ) {
    for (final o in occupied) {
      if (o.start.isBefore(end) && o.end.isAfter(start)) return o;
    }
    return null;
  }
}

class _Interval {
  final DateTime start;
  final DateTime end;
  _Interval(this.start, this.end);
}

class _CandidateEvaluation {
  final _Interval slot;
  final double score;
  final List<String> factors;
  _CandidateEvaluation({
    required this.slot,
    required this.score,
    required this.factors,
  });
}
