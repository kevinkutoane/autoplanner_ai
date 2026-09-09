import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/utils/streak_calculator.dart';

/// Helper to create a completed task on a specific date.
TaskItem _completedOn(DateTime date) => TaskItem(
  id: 'task_${date.millisecondsSinceEpoch}',
  title: 'Task on ${date.toIso8601String().substring(0, 10)}',
  startTime: date,
  isCompleted: true,
);

/// Helper to create an incomplete task on a specific date.
TaskItem _incompletedOn(DateTime date) => TaskItem(
  id: 'task_${date.millisecondsSinceEpoch}_inc',
  title: 'Incomplete on ${date.toIso8601String().substring(0, 10)}',
  startTime: date,
  isCompleted: false,
);

void main() {
  group('calculateStreak', () {
    test('returns 0 for empty task list', () {
      expect(calculateStreak([]), equals(0));
    });

    test('returns 0 when no tasks are completed', () {
      final now = DateTime.now();
      final tasks = [
        _incompletedOn(now),
        _incompletedOn(now.subtract(const Duration(days: 1))),
      ];
      expect(calculateStreak(tasks), equals(0));
    });

    test('returns 1 when only today has a completed task', () {
      final now = DateTime.now();
      final tasks = [_completedOn(now)];
      expect(calculateStreak(tasks), equals(1));
    });

    test('counts consecutive days backwards from today', () {
      final now = DateTime.now();
      final tasks = [
        _completedOn(now),
        _completedOn(now.subtract(const Duration(days: 1))),
        _completedOn(now.subtract(const Duration(days: 2))),
      ];
      expect(calculateStreak(tasks), equals(3));
    });

    test('streak breaks on a gap day', () {
      final now = DateTime.now();
      final tasks = [
        _completedOn(now),
        _completedOn(now.subtract(const Duration(days: 1))),
        // Day 2 missing
        _completedOn(now.subtract(const Duration(days: 3))),
      ];
      expect(calculateStreak(tasks), equals(2));
    });

    test('starts from yesterday when today has no completions', () {
      final now = DateTime.now();
      final tasks = [
        _incompletedOn(now), // today incomplete
        _completedOn(now.subtract(const Duration(days: 1))),
        _completedOn(now.subtract(const Duration(days: 2))),
        _completedOn(now.subtract(const Duration(days: 3))),
      ];
      expect(calculateStreak(tasks), equals(3));
    });

    test('returns 0 when yesterday also has no completions', () {
      final now = DateTime.now();
      final tasks = [
        _incompletedOn(now),
        _incompletedOn(now.subtract(const Duration(days: 1))),
        _completedOn(now.subtract(const Duration(days: 2))),
      ];
      expect(calculateStreak(tasks), equals(0));
    });

    test('respects maxLookback parameter', () {
      // Use noon today to avoid any day-boundary edge cases with Duration subtraction
      final now = DateTime.now();
      final todayNoon = DateTime(now.year, now.month, now.day, 12, 0, 0);
      final tasks = <TaskItem>[];
      // 100-day streak using noon each day
      for (var i = 0; i < 100; i++) {
        tasks.add(_completedOn(todayNoon.subtract(Duration(days: i))));
      }
      // Default lookback (60) should cap the count
      expect(calculateStreak(tasks), equals(60));
      // Custom lookback
      expect(calculateStreak(tasks, maxLookback: 30), equals(30));
      expect(calculateStreak(tasks, maxLookback: 100), equals(100));
    });

    test('multiple completed tasks on same day count as one day', () {
      final now = DateTime.now();
      final tasks = [
        _completedOn(now),
        _completedOn(now), // duplicate day
        _completedOn(now.subtract(const Duration(days: 1))),
      ];
      expect(calculateStreak(tasks), equals(2));
    });
  });

  group('calculateLongestStreak', () {
    test('returns 0 for empty task list', () {
      expect(calculateLongestStreak([]), equals(0));
    });

    test('returns 0 when no tasks are completed', () {
      final now = DateTime.now();
      final tasks = [_incompletedOn(now)];
      expect(calculateLongestStreak(tasks), equals(0));
    });

    test('returns 1 for a single completed task', () {
      final now = DateTime.now();
      final tasks = [_completedOn(now)];
      expect(calculateLongestStreak(tasks), equals(1));
    });

    test('calculates longest streak across multiple streaks', () {
      final now = DateTime.now();
      final tasks = [
        // Streak 1: 3 days (most recent)
        _completedOn(now),
        _completedOn(now.subtract(const Duration(days: 1))),
        _completedOn(now.subtract(const Duration(days: 2))),
        // Gap at day 3
        // Streak 2: 5 days (longer, older)
        _completedOn(now.subtract(const Duration(days: 10))),
        _completedOn(now.subtract(const Duration(days: 11))),
        _completedOn(now.subtract(const Duration(days: 12))),
        _completedOn(now.subtract(const Duration(days: 13))),
        _completedOn(now.subtract(const Duration(days: 14))),
      ];
      expect(calculateLongestStreak(tasks), equals(5));
    });

    test('handles single-day streaks scattered across time', () {
      final now = DateTime.now();
      final tasks = [
        _completedOn(now),
        _completedOn(now.subtract(const Duration(days: 5))),
        _completedOn(now.subtract(const Duration(days: 10))),
      ];
      expect(calculateLongestStreak(tasks), equals(1));
    });

    test('handles duplicate completions on same day', () {
      final now = DateTime.now();
      final tasks = [
        _completedOn(now),
        _completedOn(now), // same day
        _completedOn(now.subtract(const Duration(days: 1))),
        _completedOn(now.subtract(const Duration(days: 1))), // same day
      ];
      expect(calculateLongestStreak(tasks), equals(2));
    });

    test('ignores incomplete tasks', () {
      final now = DateTime.now();
      final tasks = [
        _completedOn(now),
        _incompletedOn(now.subtract(const Duration(days: 1))),
        _completedOn(now.subtract(const Duration(days: 2))),
      ];
      // The incomplete day breaks the streak
      expect(calculateLongestStreak(tasks), equals(1));
    });
  });
}
