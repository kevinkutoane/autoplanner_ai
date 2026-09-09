import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';

void main() {
  final baseTime = DateTime(2026, 3, 12, 9, 0);

  TaskItem makeTask({
    String id = 't1',
    String title = 'Test task',
    int priority = 1,
    bool isCompleted = false,
    String? recurrence,
  }) => TaskItem(
    id: id,
    title: title,
    startTime: baseTime,
    priority: priority,
    isCompleted: isCompleted,
    recurrence: recurrence,
  );

  group('TaskItem constructor defaults', () {
    test('isCompleted defaults to false', () {
      expect(makeTask().isCompleted, isFalse);
    });

    test('priority defaults to 1 (medium)', () {
      expect(makeTask().priority, equals(1));
    });

    test('tags defaults to empty list', () {
      expect(makeTask().tags, isEmpty);
    });

    test('linkedNoteIds defaults to empty list', () {
      // ignore: deprecated_member_use_from_same_package
      expect(makeTask().linkedNoteIds, isEmpty);
    });

    test('recurrenceDays defaults to empty list', () {
      expect(makeTask().recurrenceDays, isEmpty);
    });

    test('endTime defaults to null', () {
      expect(makeTask().endTime, isNull);
    });

    test('note defaults to null', () {
      expect(makeTask().note, isNull);
    });

    test('recurrence defaults to null', () {
      expect(makeTask().recurrence, isNull);
    });

    test('deadline, earliestStart, latestFinish default to null', () {
      final task = makeTask();
      expect(task.deadline, isNull);
      expect(task.earliestStart, isNull);
      expect(task.latestFinish, isNull);
    });

    test('isFixed and splittable default to false', () {
      final task = makeTask();
      expect(task.isFixed, isFalse);
      expect(task.splittable, isFalse);
    });

    test('dependsOnTaskIds defaults to empty list', () {
      expect(makeTask().dependsOnTaskIds, isEmpty);
    });

    test('energyLevel and preferredTimeOfDay default to null', () {
      final task = makeTask();
      expect(task.energyLevel, isNull);
      expect(task.preferredTimeOfDay, isNull);
    });
  });

  group('TaskItem.copyWith', () {
    test('copyWith returns a new instance with updated fields', () {
      final original = makeTask(title: 'Original');
      final copy = original.copyWith(title: 'Updated');
      expect(copy.title, equals('Updated'));
      expect(original.title, equals('Original'));
    });

    test('copyWith preserves unchanged fields', () {
      final original = makeTask(priority: 3);
      final copy = original.copyWith(title: 'New title');
      expect(copy.priority, equals(3));
      expect(copy.startTime, equals(baseTime));
    });

    test('copyWith can null out recurrence using sentinel', () {
      final task = makeTask(recurrence: 'daily');
      final copy = task.copyWith(recurrence: null);
      expect(copy.recurrence, isNull);
    });

    test('copyWith preserves recurrence when not passed', () {
      final task = makeTask(recurrence: 'weekly');
      final copy = task.copyWith(title: 'Unchanged recurrence');
      expect(copy.recurrence, equals('weekly'));
    });

    test('copyWith can mark task completed', () {
      final task = makeTask(isCompleted: false);
      final done = task.copyWith(isCompleted: true);
      expect(done.isCompleted, isTrue);
    });

    test('copyWith can set and update constraints', () {
      final deadline = DateTime(2026, 3, 12, 18, 0);
      final task = makeTask().copyWith(
        deadline: deadline,
        isFixed: true,
        splittable: true,
        preferredBlockMinutes: 45,
        energyLevel: 'high',
        preferredTimeOfDay: 'morning',
        dependsOnTaskIds: ['t0'],
      );
      expect(task.deadline, equals(deadline));
      expect(task.isFixed, isTrue);
      expect(task.splittable, isTrue);
      expect(task.preferredBlockMinutes, equals(45));
      expect(task.energyLevel, equals('high'));
      expect(task.preferredTimeOfDay, equals('morning'));
      expect(task.dependsOnTaskIds, equals(['t0']));

      // Can clear deadline with sentinel
      final cleared = task.copyWith(deadline: null);
      expect(cleared.deadline, isNull);
    });
  });

  group('TaskItem.priorityLabel', () {
    test(
      '0 maps to Low',
      () => expect(makeTask(priority: 0).priorityLabel, 'Low'),
    );
    test(
      '1 maps to Medium',
      () => expect(makeTask(priority: 1).priorityLabel, 'Medium'),
    );
    test(
      '2 maps to High',
      () => expect(makeTask(priority: 2).priorityLabel, 'High'),
    );
    test(
      '3 maps to Urgent',
      () => expect(makeTask(priority: 3).priorityLabel, 'Urgent'),
    );
    test(
      'unknown maps to Medium',
      () => expect(makeTask(priority: 99).priorityLabel, 'Medium'),
    );
  });
}
