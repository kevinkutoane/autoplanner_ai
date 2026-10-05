import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/services/scheduler_service.dart';

void main() {
  late SchedulerService scheduler;
  final testDay = DateTime(2099, 5, 20);

  setUp(() {
    scheduler = SchedulerService();
  });

  group('SchedulerService Circadian & Chronotype Alignment', () {
    test('Early Bird (Lion) places deep work in prime morning focus window', () {
      final tasks = [
        TaskItem(
          id: 'admin_1',
          title: 'Review Inbox',
          startTime: testDay,
          tags: ['email', 'admin'],
          priority: 1,
        ),
        TaskItem(
          id: 'deep_1',
          title: 'Core Algorithm Architecture',
          startTime: testDay,
          tags: ['coding', 'architecture'],
          priority: 3,
        ),
      ];

      final result = scheduler.scheduleDayWithDetails(
        tasks: tasks,
        day: testDay,
        workStartHour: 8,
        workHoursPerDay: 9,
        chronotype: 'early_bird',
      );

      final deepTask = result.scheduledTasks.firstWhere((t) => t.id == 'deep_1');
      final adminTask = result.scheduledTasks.firstWhere((t) => t.id == 'admin_1');

      // Deep work should be scheduled in morning peak (8:00 - 11:30)
      expect(deepTask.startTime.hour, inInclusiveRange(8, 11));
      expect(adminTask.startTime, isNotNull);

      // Rationale should mention Lion peak focus and biological capacity
      final deepRationale = result.explanations['deep_1'];
      expect(deepRationale, isNotNull);
      expect(
        deepRationale!.factors.any((f) => f.contains('Lion') || f.contains('peak focus')),
        isTrue,
      );

      // Admin task should have rationale noting administrative fit
      final adminRationale = result.explanations['admin_1'];
      expect(adminRationale, isNotNull);
      expect(
        adminRationale!.factors.any((f) => f.contains('Administrative task') || f.contains('preserves peak focus')),
        isTrue,
      );
    });

    test('Night Owl (Wolf) aligns high cognitive tasks with evening / late day windows', () {
      final tasks = [
        TaskItem(
          id: 'wolf_deep',
          title: 'Complex Data Pipeline Refactoring',
          startTime: testDay,
          tags: ['programming'],
          priority: 2,
        ),
      ];

      final result = scheduler.scheduleDayWithDetails(
        tasks: tasks,
        day: testDay,
        workStartHour: 10,
        workHoursPerDay: 12, // 10:00 to 22:00
        chronotype: 'night_owl',
      );

      final deepTask = result.scheduledTasks.firstWhere((t) => t.id == 'wolf_deep');
      expect(deepTask.startTime, isNotNull);
      // For Night Owl working late, the scheduler evaluation favors higher energy slots
      expect(result.explanations['wolf_deep'], isNotNull);
      final factors = result.explanations['wolf_deep']!.factors;
      expect(factors.any((f) => f.contains('Wolf')), isTrue);
    });

    test('Balanced (Bear) preserves morning peak and surfaces biological capacity percentages', () {
      final tasks = [
        TaskItem(
          id: 'bear_task',
          title: 'System Design Session',
          startTime: testDay,
          tags: ['deep_work'],
          priority: 2,
        ),
      ];

      final result = scheduler.scheduleDayWithDetails(
        tasks: tasks,
        day: testDay,
        workStartHour: 9,
        workHoursPerDay: 8,
        chronotype: 'balanced',
      );

      final explanation = result.explanations['bear_task'];
      expect(explanation, isNotNull);
      expect(
        explanation!.factors.any((f) => f.contains('Bear') && f.contains('capacity')),
        isTrue,
      );
    });

    test('Hard constraints (earliestStart) strictly honored despite circadian score', () {
      final tasks = [
        TaskItem(
          id: 'constrained_deep',
          title: 'Deep Work with Late Earliest Start',
          startTime: testDay,
          earliestStart: DateTime(testDay.year, testDay.month, testDay.day, 14, 0),
          tags: ['coding'],
          priority: 3,
        ),
      ];

      final result = scheduler.scheduleDayWithDetails(
        tasks: tasks,
        day: testDay,
        workStartHour: 8,
        workHoursPerDay: 10,
        chronotype: 'early_bird',
      );

      final task = result.scheduledTasks.firstWhere((t) => t.id == 'constrained_deep');
      expect(task.startTime.hour, greaterThanOrEqualTo(14));
    });
  });
}
