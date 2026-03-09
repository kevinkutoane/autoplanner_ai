import '../core/models/task_model.dart';

/// Deterministic, AI-free day-scheduling engine.
///
/// Sorts pending tasks by priority (urgent → low) then greedily packs each
/// into the earliest free slot within the configured work window.
/// Completed tasks are never moved — their existing times are treated as
/// occupied blocks that new tasks schedule around.
class SchedulerService {
  static const _bufferMinutes = 10;
  static const _defaultDurationMinutes = 60;
  static const _minValidDurationMinutes = 15;
  static const _slotRoundingMinutes = 15;

  /// Assigns start/end times to all *pending* tasks in [tasks].
  ///
  /// * [tasks]           – mixed completed/pending list for a single day.
  /// * [day]             – the calendar day to schedule (time components ignored).
  /// * [workStartHour]   – e.g. 9  → work starts 09:00.
  /// * [workHoursPerDay] – e.g. 8  → work ends 17:00.
  ///
  /// Returns a new sorted list; the original list is not mutated.
  List<TaskItem> scheduleDay({
    required List<TaskItem> tasks,
    required DateTime day,
    required int workStartHour,
    required int workHoursPerDay,
  }) {
    final workStart = DateTime(day.year, day.month, day.day, workStartHour);
    final workEnd = workStart.add(Duration(hours: workHoursPerDay));

    final completed = tasks.where((t) => t.isCompleted).toList();
    final pending = List<TaskItem>.from(tasks.where((t) => !t.isCompleted))
      ..sort((a, b) => b.priority.compareTo(a.priority)); // urgent first

    // Occupied intervals from completed tasks — these are untouchable.
    final occupied = <_Interval>[
      for (final t in completed)
        _Interval(
          t.startTime,
          t.endTime ?? t.startTime.add(const Duration(hours: 1)),
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    var cursor = _initialCursor(workStart, day);

    final scheduled = <TaskItem>[];
    for (final task in pending) {
      final dur = _duration(task);
      cursor = _findFreeSlot(cursor, dur, occupied, workEnd);
      final slotEnd = cursor.add(dur);

      if (slotEnd.isAfter(workEnd)) break; // Day is full — stop.

      scheduled.add(task.copyWith(startTime: cursor, endTime: slotEnd));
      occupied
        ..add(_Interval(cursor, slotEnd))
        ..sort((a, b) => a.start.compareTo(b.start));
      cursor = slotEnd.add(const Duration(minutes: _bufferMinutes));
    }

    return [...completed, ...scheduled]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// When scheduling today and we are past work start, begin from the next
  /// rounded quarter-hour so tasks don't land in the past.
  DateTime _initialCursor(DateTime workStart, DateTime day) {
    final now = DateTime.now();
    final isToday =
        now.year == day.year && now.month == day.month && now.day == day.day;
    if (isToday && now.isAfter(workStart)) {
      final rem = now.minute % _slotRoundingMinutes;
      final pad = rem == 0 ? 0 : _slotRoundingMinutes - rem;
      return now
          .add(Duration(minutes: pad + 2)) // 2-min breathing room
          .copyWith(second: 0, millisecond: 0, microsecond: 0);
    }
    return workStart;
  }

  /// Returns the task duration, falling back to 1 hour if none is encoded.
  Duration _duration(TaskItem task) {
    if (task.endTime != null) {
      final d = task.endTime!.difference(task.startTime);
      if (d.inMinutes >= _minValidDurationMinutes) return d;
    }
    return const Duration(minutes: _defaultDurationMinutes);
  }

  /// Advances [cursor] forward until a slot of [needed] width is free.
  DateTime _findFreeSlot(
    DateTime cursor,
    Duration needed,
    List<_Interval> occupied,
    DateTime workEnd,
  ) {
    var candidate = cursor;
    // Guard against degenerate inputs; 200 iterations >> realistic task count.
    for (var i = 0; i < 200; i++) {
      if (candidate.add(needed).isAfter(workEnd)) return workEnd;
      final clash = _firstOverlap(candidate, candidate.add(needed), occupied);
      if (clash == null) return candidate;
      // Jump to end of clashing block + buffer and try again.
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
