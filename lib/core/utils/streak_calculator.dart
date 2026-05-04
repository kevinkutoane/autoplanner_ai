import '../models/task_model.dart';

/// Calculates the current streak of consecutive days with at least one
/// completed task.
///
/// If today already has completions, today is counted and the streak extends
/// backwards from today. Otherwise the streak starts from yesterday so an
/// early-morning check doesn't reset a legitimate streak to zero.
///
/// Uses calendar-day arithmetic (not Duration subtraction) to avoid
/// DST/timezone edge cases where subtracting 24h crosses a clock change.
///
/// [maxLookback] controls how many days to scan (default 60).
int calculateStreak(List<TaskItem> tasks, {int maxLookback = 60}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final todayHasCompleted = tasks.any(
    (t) =>
        t.isCompleted &&
        t.startTime.year == today.year &&
        t.startTime.month == today.month &&
        t.startTime.day == today.day,
  );

  int streak = 0;
  final startOffset = todayHasCompleted ? 0 : 1;

  for (var i = startOffset; i < maxLookback; i++) {
    // Calendar-day subtraction: always produces midnight of the target day.
    final d = DateTime(today.year, today.month, today.day - i);
    final hasCompleted = tasks.any(
      (t) =>
          t.isCompleted &&
          t.startTime.year == d.year &&
          t.startTime.month == d.month &&
          t.startTime.day == d.day,
    );
    if (!hasCompleted) break;
    streak++;
  }
  return streak;
}

/// Returns the longest streak ever achieved across all historical data.
int calculateLongestStreak(List<TaskItem> tasks) {
  if (tasks.isEmpty) return 0;

  // Collect unique days with at least one completion.
  final completedDays = <DateTime>{};
  for (final t in tasks) {
    if (t.isCompleted) {
      completedDays.add(DateTime(
        t.startTime.year,
        t.startTime.month,
        t.startTime.day,
      ));
    }
  }
  if (completedDays.isEmpty) return 0;

  final sorted = completedDays.toList()..sort();
  int longest = 1;
  int current = 1;
  for (var i = 1; i < sorted.length; i++) {
    final diff = sorted[i].difference(sorted[i - 1]).inDays;
    if (diff == 1) {
      current++;
      if (current > longest) longest = current;
    } else if (diff > 1) {
      current = 1;
    }
    // diff == 0 means duplicate day, skip
  }
  return longest;
}
