import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/circadian_rhythm.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';

void main() {
  group('CircadianRhythm Chronotype Models', () {
    test('Early Bird (Lion) peaks in the morning and dips post-lunch', () {
      final morningPeak = CircadianRhythm.energyCapacityAtHour(9.0, chronotypeId: 'early_bird');
      final postLunchDip = CircadianRhythm.energyCapacityAtHour(14.0, chronotypeId: 'early_bird');
      final eveningWindDown = CircadianRhythm.energyCapacityAtHour(21.0, chronotypeId: 'early_bird');

      expect(morningPeak, greaterThan(0.85), reason: 'Lion peak at 9:00 AM should be >= 0.85');
      expect(postLunchDip, lessThan(0.55), reason: 'Lion post-lunch dip at 2:00 PM should be < 0.55');
      expect(eveningWindDown, lessThan(0.35), reason: 'Lion evening at 9:00 PM should be < 0.35');
      expect(morningPeak, greaterThan(postLunchDip));
      expect(morningPeak, greaterThan(eveningWindDown));
    });

    test('Balanced (Bear) has morning peak and afternoon resurgence', () {
      final morningPeak = CircadianRhythm.energyCapacityAtHour(10.5, chronotypeId: 'balanced');
      final slump = CircadianRhythm.energyCapacityAtHour(14.5, chronotypeId: 'balanced');
      final afternoonRebound = CircadianRhythm.energyCapacityAtHour(17.5, chronotypeId: 'balanced');

      expect(morningPeak, greaterThan(0.85), reason: 'Bear prime focus at 10:30 AM should be >= 0.85');
      expect(slump, lessThan(0.55), reason: 'Bear post-lunch slump at 2:30 PM should be < 0.55');
      expect(afternoonRebound, greaterThan(0.65), reason: 'Bear afternoon resurgence at 5:30 PM should be >= 0.65');
      expect(afternoonRebound, greaterThan(slump));
    });

    test('Night Owl (Wolf) has slow morning and evening golden hour', () {
      final morningInertia = CircadianRhythm.energyCapacityAtHour(8.5, chronotypeId: 'night_owl');
      final middayBase = CircadianRhythm.energyCapacityAtHour(14.0, chronotypeId: 'night_owl');
      final eveningGoldenHour = CircadianRhythm.energyCapacityAtHour(21.0, chronotypeId: 'night_owl');

      expect(morningInertia, lessThan(0.45), reason: 'Wolf morning at 8:30 AM should be < 0.45');
      expect(middayBase, greaterThan(morningInertia));
      expect(eveningGoldenHour, greaterThan(0.85), reason: 'Wolf golden hour at 9:00 PM should be >= 0.85');
      expect(eveningGoldenHour, greaterThan(morningInertia));
    });

    test('CircadianPhase maps accurately to capacity thresholds', () {
      expect(CircadianPhase.fromCapacity(0.92), CircadianPhase.peakFocus);
      expect(CircadianPhase.fromCapacity(0.68), CircadianPhase.steadyWork);
      expect(CircadianPhase.fromCapacity(0.45), CircadianPhase.recoveryDip);
      expect(CircadianPhase.fromCapacity(0.25), CircadianPhase.windDown);
      expect(CircadianPhase.fromCapacity(0.10), CircadianPhase.rest);
    });

    test('Chronotype.fromId handles fallback and case insensitivity', () {
      expect(Chronotype.fromId('EARLY_BIRD'), Chronotype.earlyBird);
      expect(Chronotype.fromId('balanced'), Chronotype.balanced);
      expect(Chronotype.fromId('night_owl'), Chronotype.nightOwl);
      expect(Chronotype.fromId('unknown_type'), Chronotype.earlyBird);
      expect(Chronotype.fromId(null), Chronotype.earlyBird);
    });
  });

  group('CognitiveDemand Inference', () {
    test('Infers deep work from tags', () {
      final task = TaskItem(
        id: '1',
        title: 'Refactor Architecture',
        startTime: DateTime(2026, 10, 2, 9, 0),
        tags: ['coding', 'architecture'],
      );
      expect(CircadianRhythm.inferCognitiveDemand(task), CognitiveDemand.deepWork);
    });

    test('Infers shallow / admin from tags', () {
      final task = TaskItem(
        id: '2',
        title: 'Clear Inbox & Reply to Emails',
        startTime: DateTime(2026, 10, 2, 14, 0),
        tags: ['email', 'admin'],
      );
      expect(CircadianRhythm.inferCognitiveDemand(task), CognitiveDemand.shallow);
    });

    test('Infers from energyLevel override', () {
      final highEnergyTask = TaskItem(
        id: '3',
        title: 'Team sync',
        startTime: DateTime(2026, 10, 2, 10, 0),
        energyLevel: 'high',
      );
      expect(CircadianRhythm.inferCognitiveDemand(highEnergyTask), CognitiveDemand.deepWork);

      final lowEnergyTask = TaskItem(
        id: '4',
        title: 'File receipts',
        startTime: DateTime(2026, 10, 2, 14, 0),
        energyLevel: 'low',
      );
      expect(CircadianRhythm.inferCognitiveDemand(lowEnergyTask), CognitiveDemand.shallow);
    });

    test('Infers deep work for high priority when unspecific', () {
      final highPriorityTask = TaskItem(
        id: '5',
        title: 'Important presentation draft',
        startTime: DateTime(2026, 10, 2, 10, 0),
        priority: 2,
      );
      expect(CircadianRhythm.inferCognitiveDemand(highPriorityTask), CognitiveDemand.deepWork);
    });
  });

  group('Circadian Fit Evaluation', () {
    test('Rewards deep work scheduled during Lion morning peak', () {
      final task = TaskItem(
        id: 'deep-1',
        title: 'Algorithm Design',
        startTime: DateTime(2026, 10, 2, 9, 0),
        tags: ['coding'],
      );

      final result = CircadianRhythm.evaluateFit(
        task: task,
        slotStart: DateTime(2026, 10, 2, 9, 0),
        slotEnd: DateTime(2026, 10, 2, 10, 30),
        chronotypeId: 'early_bird',
      );

      expect(result.score, greaterThan(10.0));
      expect(result.rationale, contains('peak focus'));
    });

    test('Rewards administrative work placed in recovery dip', () {
      final task = TaskItem(
        id: 'admin-1',
        title: 'Expense Reports',
        startTime: DateTime(2026, 10, 2, 14, 0),
        tags: ['admin'],
      );

      final result = CircadianRhythm.evaluateFit(
        task: task,
        slotStart: DateTime(2026, 10, 2, 14, 0),
        slotEnd: DateTime(2026, 10, 2, 15, 0),
        chronotypeId: 'early_bird',
      );

      expect(result.score, greaterThan(0.0));
      expect(result.rationale, contains('recovery dip'));
      expect(result.rationale, contains('preserves peak focus'));
    });

    test('Penalizes deep work scheduled during recovery dip', () {
      final task = TaskItem(
        id: 'deep-2',
        title: 'Deep System Architecture',
        startTime: DateTime(2026, 10, 2, 14, 0),
        tags: ['architecture'],
      );

      final result = CircadianRhythm.evaluateFit(
        task: task,
        slotStart: DateTime(2026, 10, 2, 14, 0),
        slotEnd: DateTime(2026, 10, 2, 15, 30),
        chronotypeId: 'early_bird',
      );

      expect(result.score, lessThan(0.0));
      expect(result.rationale, contains('recovery dip'));
    });
  });
}
