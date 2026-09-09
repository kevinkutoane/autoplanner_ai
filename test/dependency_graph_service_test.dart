import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/services/dependency_graph_service.dart';

void main() {
  late DependencyGraphService service;
  final now = DateTime(2026, 6, 15, 9, 0);

  TaskItem _task({
    required String id,
    String title = 'Task',
    int priority = 1,
    List<String> dependsOn = const [],
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return TaskItem(
      id: id,
      title: title,
      priority: priority,
      startTime: startTime ?? now,
      endTime: endTime,
      dependsOnTaskIds: dependsOn,
    );
  }

  setUp(() {
    service = DependencyGraphService();
  });

  group('DependencyGraphService.resolveDependencies', () {
    test('returns empty sorted list when given empty input', () {
      final result = service.resolveDependencies([]);
      expect(result.sortedTasks, isEmpty);
      expect(result.cycleTaskIds, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('orders independent tasks by priority descending', () {
      final tasks = [
        _task(id: 'low', priority: 0),
        _task(id: 'urgent', priority: 3),
        _task(id: 'high', priority: 2),
      ];

      final result = service.resolveDependencies(tasks);
      expect(result.sortedTasks.map((t) => t.id).toList(), [
        'urgent',
        'high',
        'low',
      ]);
      expect(result.cycleTaskIds, isEmpty);
    });

    test('topologically orders a linear chain A -> B -> C', () {
      // C depends on B, B depends on A.
      // Even if C has higher priority than A, A must be evaluated first!
      final tasks = [
        _task(id: 'C', priority: 3, dependsOn: ['B']),
        _task(id: 'A', priority: 1),
        _task(id: 'B', priority: 2, dependsOn: ['A']),
      ];

      final result = service.resolveDependencies(tasks);
      final order = result.sortedTasks.map((t) => t.id).toList();

      expect(order.indexOf('A'), lessThan(order.indexOf('B')));
      expect(order.indexOf('B'), lessThan(order.indexOf('C')));
      expect(result.cycleTaskIds, isEmpty);
    });

    test('resolves diamond DAG correctly', () {
      // A -> B, A -> C, B -> D, C -> D
      final tasks = [
        _task(id: 'D', dependsOn: ['B', 'C']),
        _task(id: 'B', dependsOn: ['A']),
        _task(id: 'C', dependsOn: ['A']),
        _task(id: 'A'),
      ];

      final result = service.resolveDependencies(tasks);
      final order = result.sortedTasks.map((t) => t.id).toList();

      expect(order.indexOf('A'), equals(0));
      expect(order.indexOf('B'), greaterThan(order.indexOf('A')));
      expect(order.indexOf('C'), greaterThan(order.indexOf('A')));
      expect(order.indexOf('D'), greaterThan(order.indexOf('B')));
      expect(order.indexOf('D'), greaterThan(order.indexOf('C')));
      expect(result.cycleTaskIds, isEmpty);
    });

    test('detects circular dependency and breaks cycle gracefully', () {
      // A -> B -> A
      final tasks = [
        _task(id: 'A', dependsOn: ['B']),
        _task(id: 'B', dependsOn: ['A']),
      ];

      final result = service.resolveDependencies(tasks);
      expect(result.cycleTaskIds, containsAll(['A', 'B']));
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('Dependency cycle detected'));
      // All tasks are still preserved in output
      expect(result.sortedTasks, hasLength(2));
    });

    test('handles missing or external prerequisite without stalling', () {
      // Task depends on an ID that is not in the pending day list (e.g. external or already completed)
      final tasks = [
        _task(id: 'task1', dependsOn: ['external_or_past_task']),
      ];

      final result = service.resolveDependencies(tasks);
      expect(result.sortedTasks, hasLength(1));
      expect(result.sortedTasks.first.id, equals('task1'));
      expect(result.cycleTaskIds, isEmpty);
    });
  });

  group('DependencyGraphService.getPrerequisiteConstraintTime', () {
    test('returns null when task has no dependencies', () {
      final task = _task(id: 't1');
      final constraint = service.getPrerequisiteConstraintTime(
        task: task,
        scheduledOrCompletedTasks: {},
        bufferMinutes: 10,
      );
      expect(constraint, isNull);
    });

    test('returns prerequisite endTime + buffer', () {
      final prereq = _task(
        id: 'p1',
        startTime: DateTime(2026, 6, 15, 9, 0),
        endTime: DateTime(2026, 6, 15, 10, 0),
      );
      final task = _task(id: 't1', dependsOn: ['p1']);

      final constraint = service.getPrerequisiteConstraintTime(
        task: task,
        scheduledOrCompletedTasks: {'p1': prereq},
        bufferMinutes: 10,
      );

      expect(constraint, DateTime(2026, 6, 15, 10, 10));
    });

    test('returns latest constraint when task has multiple prerequisites', () {
      final p1 = _task(
        id: 'p1',
        startTime: DateTime(2026, 6, 15, 9, 0),
        endTime: DateTime(2026, 6, 15, 10, 0),
      );
      final p2 = _task(
        id: 'p2',
        startTime: DateTime(2026, 6, 15, 10, 30),
        endTime: DateTime(2026, 6, 15, 11, 30),
      );
      final task = _task(id: 't1', dependsOn: ['p1', 'p2']);

      final constraint = service.getPrerequisiteConstraintTime(
        task: task,
        scheduledOrCompletedTasks: {'p1': p1, 'p2': p2},
        bufferMinutes: 15,
      );

      // p2 ends at 11:30 + 15 min buffer = 11:45
      expect(constraint, DateTime(2026, 6, 15, 11, 45));
    });
  });
}
