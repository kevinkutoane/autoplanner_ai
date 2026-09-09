import '../core/models/task_model.dart';

/// Result of dependency graph analysis and topological ordering.
class DependencyResolutionResult {
  /// Tasks ordered such that prerequisites precede their dependents.
  final List<TaskItem> sortedTasks;

  /// IDs of tasks involved in detected circular dependency cycles.
  final List<String> cycleTaskIds;

  /// Human-readable warnings describing detected cycles or missing dependencies.
  final List<String> warnings;

  const DependencyResolutionResult({
    required this.sortedTasks,
    this.cycleTaskIds = const [],
    this.warnings = const [],
  });
}

/// Service managing Directed Acyclic Graph (DAG) construction, cycle detection,
/// and topological evaluation order for tasks with dependencies.
class DependencyGraphService {
  /// Analyzes task dependencies, detects and breaks cycles, and returns tasks
  /// topologically sorted so prerequisites are evaluated before dependents.
  DependencyResolutionResult resolveDependencies(List<TaskItem> tasks) {
    if (tasks.isEmpty) {
      return const DependencyResolutionResult(sortedTasks: []);
    }

    final taskMap = <String, TaskItem>{for (final t in tasks) t.id: t};
    final inDegree = <String, int>{for (final t in tasks) t.id: 0};
    final dependents = <String, List<String>>{for (final t in tasks) t.id: []};
    final warnings = <String>[];

    // Build adjacency list: prerequisite (A) -> dependent (B)
    for (final task in tasks) {
      for (final prereqId in task.dependsOnTaskIds) {
        if (taskMap.containsKey(prereqId)) {
          dependents[prereqId]!.add(task.id);
          inDegree[task.id] = (inDegree[task.id] ?? 0) + 1;
        } else {
          // Prerequisite is not in current day batch (could be completed or external)
          // We don't block in-degree unless known to be pending today.
        }
      }
    }

    // Kahn's algorithm: start with tasks having zero pending prerequisites
    final queue = <String>[
      for (final entry in inDegree.entries)
        if (entry.value == 0) entry.key,
    ];

    // Sort queue initially by priority descending to preserve priority ordering among root tasks
    queue.sort((a, b) => taskMap[b]!.priority.compareTo(taskMap[a]!.priority));

    final sorted = <TaskItem>[];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final currentTask = taskMap[currentId]!;
      sorted.add(currentTask);

      for (final depId in dependents[currentId]!) {
        inDegree[depId] = inDegree[depId]! - 1;
        if (inDegree[depId] == 0) {
          queue.add(depId);
        }
      }
      // Re-sort queue by priority so available high-priority tasks run first
      queue.sort(
        (a, b) => taskMap[b]!.priority.compareTo(taskMap[a]!.priority),
      );
    }

    // If some tasks were not visited, there is a cycle
    final cycleTaskIds = <String>[];
    if (sorted.length < tasks.length) {
      final unvisitedIds = inDegree.entries
          .where((e) => e.value > 0)
          .map((e) => e.key)
          .toList();

      cycleTaskIds.addAll(unvisitedIds);
      warnings.add(
        'Dependency cycle detected involving ${unvisitedIds.length} tasks '
        '(${unvisitedIds.join(", ")}). Breaking circular dependencies to allow scheduling.',
      );

      // Append remaining tasks sorted by priority to prevent dropping them
      final remaining = unvisitedIds.map((id) => taskMap[id]!).toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));
      sorted.addAll(remaining);
    }

    return DependencyResolutionResult(
      sortedTasks: sorted,
      cycleTaskIds: cycleTaskIds,
      warnings: warnings,
    );
  }

  /// Calculates the earliest permissible start time for [task] based on the
  /// end times of its completed or already-scheduled prerequisites.
  DateTime? getPrerequisiteConstraintTime({
    required TaskItem task,
    required Map<String, TaskItem> scheduledOrCompletedTasks,
    required int bufferMinutes,
  }) {
    if (task.dependsOnTaskIds.isEmpty) return null;

    DateTime? latestRequiredEnd;

    for (final prereqId in task.dependsOnTaskIds) {
      final prereq = scheduledOrCompletedTasks[prereqId];
      if (prereq != null && prereq.endTime != null) {
        final withBuffer = prereq.endTime!.add(
          Duration(minutes: bufferMinutes),
        );
        if (latestRequiredEnd == null ||
            withBuffer.isAfter(latestRequiredEnd)) {
          latestRequiredEnd = withBuffer;
        }
      }
    }

    return latestRequiredEnd;
  }
}
