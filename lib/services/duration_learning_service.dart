import 'dart:math';

import 'package:autoplanner_ai/core/models/task_model.dart';

/// Represents learning statistics for a specific category or tag.
class CategoryCalibration {
  final String tag;
  final int sampleCount;
  final double averageMultiplier;
  final double accuracyRate; // Fraction within +/- 25% of estimate

  const CategoryCalibration({
    required this.tag,
    required this.sampleCount,
    required this.averageMultiplier,
    required this.accuracyRate,
  });

  /// Percentage adjustment, e.g. +35% or -15%.
  int get percentageDelta => ((averageMultiplier - 1.0) * 100).round();

  String get deltaDisplay {
    final d = percentageDelta;
    if (d > 0) return '+$d%';
    if (d < 0) return '$d%';
    return '0%';
  }
}

/// Personal intelligence service that tracks historical estimation variance
/// between planned duration and actual execution time, calibrating future schedules.
class DurationLearningService {
  /// Minimum samples required before a category multiplier is applied automatically.
  static const int minSamplesForConfidence = 2;

  /// Clamps multipliers to prevent extreme distortions (e.g. 50% to 250%).
  static const double minMultiplier = 0.5;
  static const double maxMultiplier = 2.5;

  /// Calculates the estimation multiplier for a single completed task.
  ///
  /// Returns null if the task was not completed with a recorded actual duration.
  double? computeTaskMultiplier(TaskItem task) {
    if (!task.isCompleted ||
        task.actualDurationMinutes == null ||
        task.actualDurationMinutes! <= 0) {
      return null;
    }

    final scheduled = task.durationMinutes;
    if (scheduled <= 0) return 1.0;

    final ratio = task.actualDurationMinutes! / scheduled;
    return ratio.clamp(minMultiplier, maxMultiplier);
  }

  /// Calculates calibration profiles across all tags from [completedTasks].
  Map<String, CategoryCalibration> analyzeCategories(
    List<TaskItem> completedTasks,
  ) {
    final Map<String, List<double>> tagRatios = {};
    final Map<String, int> tagAccurateCounts = {};

    for (final task in completedTasks) {
      final ratio = computeTaskMultiplier(task);
      if (ratio == null) continue;

      final isAccurate = ratio >= 0.75 && ratio <= 1.25;

      for (final tag in task.tags) {
        final normTag = tag.trim().toLowerCase();
        if (normTag.isEmpty) continue;

        tagRatios.putIfAbsent(normTag, () => []).add(ratio);
        if (isAccurate) {
          tagAccurateCounts[normTag] = (tagAccurateCounts[normTag] ?? 0) + 1;
        }
      }
    }

    final Map<String, CategoryCalibration> results = {};
    for (final entry in tagRatios.entries) {
      final tag = entry.key;
      final ratios = entry.value;
      if (ratios.isEmpty) continue;

      final avg = ratios.reduce((a, b) => a + b) / ratios.length;
      final accurateCount = tagAccurateCounts[tag] ?? 0;

      results[tag] = CategoryCalibration(
        tag: tag,
        sampleCount: ratios.length,
        averageMultiplier: double.parse(avg.toStringAsFixed(2)),
        accuracyRate: accurateCount / ratios.length,
      );
    }

    return results;
  }

  /// Returns the calibrated duration in minutes for [task] based on learned tag multipliers.
  ///
  /// If [task] has multiple tags, uses the tag with the highest sample confidence.
  int getCalibratedDuration(
    TaskItem task,
    Map<String, CategoryCalibration> calibrations,
  ) {
    final baseDuration = task.durationMinutes;
    if (task.tags.isEmpty || calibrations.isEmpty) {
      return baseDuration;
    }

    CategoryCalibration? bestMatch;
    for (final tag in task.tags) {
      final norm = tag.trim().toLowerCase();
      final cal = calibrations[norm];
      if (cal != null && cal.sampleCount >= minSamplesForConfidence) {
        if (bestMatch == null || cal.sampleCount > bestMatch.sampleCount) {
          bestMatch = cal;
        }
      }
    }

    if (bestMatch == null) return baseDuration;

    final adjusted = (baseDuration * bestMatch.averageMultiplier).round();
    // Keep within reasonable bounds (minimum 15m, maximum 480m)
    return max(15, min(adjusted, 480));
  }

  /// Calculates Schedule Accuracy Index: percentage of completed tasks (with actuals)
  /// finished within +/- 25% of their planned estimate.
  double computeAccuracyIndex(List<TaskItem> tasks) {
    final withActuals = tasks
        .where(
          (t) =>
              t.isCompleted &&
              t.actualDurationMinutes != null &&
              t.actualDurationMinutes! > 0,
        )
        .toList();

    if (withActuals.isEmpty) return 100.0;

    int accurateCount = 0;
    for (final t in withActuals) {
      final ratio = t.actualDurationMinutes! / t.durationMinutes;
      if (ratio >= 0.75 && ratio <= 1.25) {
        accurateCount++;
      }
    }

    return (accurateCount / withActuals.length) * 100.0;
  }

  /// Calculates Planning Debt in minutes: accumulated uncompleted minutes
  /// from scheduled tasks whose finish time has already passed.
  int computePlanningDebt(List<TaskItem> tasks, DateTime now) {
    int debtMinutes = 0;
    for (final task in tasks) {
      if (task.isCompleted) continue;
      final end =
          task.endTime ??
          task.startTime.add(Duration(minutes: task.durationMinutes));

      if (end.isBefore(now)) {
        debtMinutes += task.durationMinutes;
      }
    }
    return debtMinutes;
  }
}
