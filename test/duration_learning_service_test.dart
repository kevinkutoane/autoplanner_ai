import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/services/duration_learning_service.dart';

void main() {
  late DurationLearningService service;
  final baseTime = DateTime(2026, 3, 12, 10, 0);

  setUp(() {
    service = DurationLearningService();
  });

  group('DurationLearningService - Multiplier Calculations', () {
    test('computeTaskMultiplier returns null for uncompleted task or missing actuals', () {
      final uncompleted = TaskItem(
        id: '1',
        title: 'Draft PR',
        startTime: baseTime,
        endTime: baseTime.add(const Duration(minutes: 30)),
        isCompleted: false,
      );
      expect(service.computeTaskMultiplier(uncompleted), isNull);

      final completedWithoutActual = uncompleted.copyWith(
        isCompleted: true,
        actualDurationMinutes: null,
      );
      expect(service.computeTaskMultiplier(completedWithoutActual), isNull);
    });

    test('computeTaskMultiplier computes accurate ratio and clamps bounds', () {
      final task45m = TaskItem(
        id: '2',
        title: 'Code review',
        startTime: baseTime,
        endTime: baseTime.add(const Duration(minutes: 30)),
        isCompleted: true,
        actualDurationMinutes: 45, // 1.5x
      );
      expect(service.computeTaskMultiplier(task45m), equals(1.5));

      // Test upper clamp (max 2.5x)
      final hugeTask = task45m.copyWith(actualDurationMinutes: 300); // 10x
      expect(service.computeTaskMultiplier(hugeTask), equals(2.5));

      // Test lower clamp (min 0.5x)
      final tinyTask = task45m.copyWith(actualDurationMinutes: 5); // 0.16x
      expect(service.computeTaskMultiplier(tinyTask), equals(0.5));
    });
  });

  group('DurationLearningService - Category Analysis', () {
    test('analyzeCategories groups multipliers and computes accuracy', () {
      final tasks = [
        TaskItem(
          id: '1',
          title: 'Implement feature',
          startTime: baseTime,
          endTime: baseTime.add(const Duration(minutes: 60)),
          isCompleted: true,
          actualDurationMinutes: 90, // 1.5x
          tags: ['dev', 'flutter'],
        ),
        TaskItem(
          id: '2',
          title: 'Fix bug',
          startTime: baseTime,
          endTime: baseTime.add(const Duration(minutes: 30)),
          isCompleted: true,
          actualDurationMinutes: 45, // 1.5x
          tags: ['dev'],
        ),
        TaskItem(
          id: '3',
          title: 'Team check-in',
          startTime: baseTime,
          endTime: baseTime.add(const Duration(minutes: 30)),
          isCompleted: true,
          actualDurationMinutes: 30, // 1.0x (accurate)
          tags: ['meeting'],
        ),
      ];

      final results = service.analyzeCategories(tasks);
      expect(results.containsKey('dev'), isTrue);
      expect(results['dev']!.sampleCount, equals(2));
      expect(results['dev']!.averageMultiplier, equals(1.5));
      expect(results['dev']!.percentageDelta, equals(50));
      expect(results['dev']!.deltaDisplay, equals('+50%'));

      expect(results['meeting']!.sampleCount, equals(1));
      expect(results['meeting']!.averageMultiplier, equals(1.0));
      expect(results['meeting']!.accuracyRate, equals(1.0));
    });
  });

  group('DurationLearningService - Calibration Application', () {
    test('getCalibratedDuration adjusts task duration based on learned tag multiplier', () {
      final calibrations = {
        'dev': const CategoryCalibration(
          tag: 'dev',
          sampleCount: 3,
          averageMultiplier: 1.4, // +40%
          accuracyRate: 0.33,
        ),
      };

      final task = TaskItem(
        id: 't-test',
        title: 'Build API client',
        startTime: baseTime,
        endTime: baseTime.add(const Duration(minutes: 60)),
        tags: ['dev'],
      );

      final calibrated = service.getCalibratedDuration(task, calibrations);
      expect(calibrated, equals(84)); // 60 * 1.4
    });

    test('getCalibratedDuration leaves unlearned tags unchanged', () {
      final calibrations = {
        'dev': const CategoryCalibration(
          tag: 'dev',
          sampleCount: 1, // below min confidence of 2
          averageMultiplier: 1.5,
          accuracyRate: 0.0,
        ),
      };

      final task = TaskItem(
        id: 't-test',
        title: 'General task',
        startTime: baseTime,
        endTime: baseTime.add(const Duration(minutes: 40)),
        tags: ['dev'],
      );

      final calibrated = service.getCalibratedDuration(task, calibrations);
      expect(calibrated, equals(40)); // unchanged
    });
  });

  group('DurationLearningService - Metrics', () {
    test('computeAccuracyIndex calculates percentage within +/- 25%', () {
      final tasks = [
        TaskItem(
          id: '1',
          title: 'Accurate task',
          startTime: baseTime,
          endTime: baseTime.add(const Duration(minutes: 60)),
          isCompleted: true,
          actualDurationMinutes: 65, // within 25%
        ),
        TaskItem(
          id: '2',
          title: 'Overdue task',
          startTime: baseTime,
          endTime: baseTime.add(const Duration(minutes: 30)),
          isCompleted: true,
          actualDurationMinutes: 60, // 2x, not within 25%
        ),
      ];

      final index = service.computeAccuracyIndex(tasks);
      expect(index, equals(50.0));
    });

    test('computePlanningDebt tallies past-due uncompleted task minutes', () {
      final now = DateTime(2026, 3, 12, 16, 0);

      final pastUncompleted = TaskItem(
        id: '1',
        title: 'Morning review',
        startTime: DateTime(2026, 3, 12, 9, 0),
        endTime: DateTime(2026, 3, 12, 10, 0), // 60 min, ended at 10:00
        isCompleted: false,
      );

      final pastCompleted = TaskItem(
        id: '2',
        title: 'Done task',
        startTime: DateTime(2026, 3, 12, 11, 0),
        endTime: DateTime(2026, 3, 12, 12, 0),
        isCompleted: true,
      );

      final futureTask = TaskItem(
        id: '3',
        title: 'Evening workout',
        startTime: DateTime(2026, 3, 12, 18, 0),
        endTime: DateTime(2026, 3, 12, 19, 0),
        isCompleted: false,
      );

      final debt = service.computePlanningDebt([
        pastUncompleted,
        pastCompleted,
        futureTask,
      ], now);
      expect(debt, equals(60));
    });
  });
}
