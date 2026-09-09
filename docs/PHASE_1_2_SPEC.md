# AutoPlanner AI — Phase 1.2 Specification: Smart Scheduling Engine

> **Document Status**: READY FOR IMPLEMENTATION  
> **Target Version**: `1.2.0`  
> **Prerequisites**: Phase 1.1 (Reliability & Hardening) Completed & Verified  

---

## 1. Executive Summary

Phase 1.1 established foundational reliability: deterministic clock testing, safe Hive corruption recovery, structured AI validation boundaries, unified bootstrapping, and an operational offline AI queue.

Phase 1.2 transforms the scheduling engine from a naive priority-sorted greedy slot packer into an **Intelligent Constraint-Based Planning Engine**. The engine will respect hard temporal constraints, enforce task dependency graphs (DAGs), dynamically split large work blocks, score soft constraints (energy, deadlines, switch penalties), and output clear explainability rationale for every scheduled slot.

---

## 2. Domain Model Evolution (`TaskItem`)

The `TaskItem` Hive model (`lib/core/models/task_model.dart`, TypeId 0) will be extended with backward-compatible fields:

```dart
@HiveType(typeId: 0)
class TaskItem extends HiveObject {
  // Existing fields (0 to 11)
  @HiveField(0) String id;
  @HiveField(1) String title;
  @HiveField(2) DateTime startTime;
  @HiveField(3) DateTime? endTime;
  @HiveField(4) String? note;
  @HiveField(5) bool isCompleted;
  @HiveField(6) int priority; // 0=Low, 1=Medium, 2=High, 3=Urgent
  @HiveField(7) List<String> tags;
  @Deprecated('Reserved') @HiveField(8) List<String> linkedNoteIds;
  @HiveField(9) String? recurrence;
  @HiveField(10) List<int> recurrenceDays;
  @HiveField(11) String? linkedGoalId;

  // ── Phase 1.2 New Constraint Fields (12 to 22) ──────────────────────────
  /// Hard deadline; scheduler flags warning if unable to fit before this time.
  @HiveField(12) DateTime? deadline;

  /// Earliest moment this task is permitted to start.
  @HiveField(13) DateTime? earliestStart;

  /// Latest moment this task must finish.
  @HiveField(14) DateTime? latestFinish;

  /// If true, startTime/endTime cannot be moved by auto-scheduler.
  @HiveField(15) bool isFixed;

  /// Energy requirement: 'low' | 'medium' | 'high'.
  @HiveField(16) String? energyLevel;

  /// Preferred time of day: 'morning' | 'afternoon' | 'evening'.
  @HiveField(17) String? preferredTimeOfDay;

  /// Whether long tasks can be split across multiple sessions.
  @HiveField(18) bool splittable;

  /// Target chunk size in minutes when split (default 60m).
  @HiveField(19) int? preferredBlockMinutes;

  /// IDs of tasks that must complete before this task can start.
  @HiveField(20) List<String> dependsOnTaskIds;

  /// ID of the parent ProjectItem, if any.
  @HiveField(21) String? linkedProjectId;

  /// For split tasks: ID of the parent task this chunk belongs to.
  @HiveField(22) String? parentTaskId;
}
```

### Backward Compatibility Invariants
- All new fields provide non-null safe defaults in the constructor and `copyWith`.
- Existing Hive boxes deserialise smoothly because Hive ignores unpopulated trailing field indexes.

---

## 3. Task Dependencies Directed Acyclic Graph (DAG)

### 3.1 Cycle Detection & Topological Sorting
Before scheduling, the engine constructs an adjacency list from `dependsOnTaskIds`.

1. **Cycle Detection (Tarjan / Kahn's algorithm)**:
   - If a dependency cycle is detected (e.g., $A \rightarrow B \rightarrow A$), the scheduler breaks the cycle by removing the lowest-priority dependency and records an `UnresolvableDependencyWarning`.
2. **Topological Ordering**:
   - Tasks are resolved in topological order so that prerequisite tasks are scheduled prior to their dependents.
3. **Temporal Invariant**:
   $$\forall B \text{ where } B.\text{dependsOnTaskIds.contains}(A.\text{id}):$$
   $$B.\text{startTime} \ge A.\text{endTime} + \text{bufferMinutes}$$

---

## 4. Task Splitting Engine

When a task has `splittable == true` and its duration exceeds `preferredBlockMinutes`:

1. The engine calculates the required number of blocks:
   $$N = \lceil \text{durationMinutes} / \text{preferredBlockMinutes} \rceil$$
2. Produces $N$ contiguous or distributed child tasks (`Part 1 of N`, `Part 2 of N`, etc.), linked via `parentTaskId`.
3. Enforces that `Part K` depends on `Part K-1`.
4. Automatically inserts restorative transition buffers (10–15 min) between chunks.

---

## 5. Multi-Factor Planning Score Function

Instead of a 1-dimensional priority sort, candidate tasks and candidate slots are evaluated using a multi-factor scoring function:

$$\text{Score}(T, S) = W_p \cdot P(T) + W_d \cdot U(T, S) + W_g \cdot G(T) + W_e \cdot E(T, S) - C(T, S_{\text{prev}})$$

Where:
- $P(T) \in [0, 3]$: Priority score (Urgent=3, High=2, Medium=1, Low=0).
- $U(T, S) \in [0, 5]$: Deadline Urgency: exponential increase as slot $S$ approaches deadline $D$.
- $G(T) \in \{0, 1.5\}$: Goal alignment boost (tasks tied to active high-level goals).
- $E(T, S) \in [0, 2]$: Energy Fit (e.g., high-energy tasks rewarded in morning slots 08:00–11:30).
- $C(T, S_{\text{prev}}) \in [0, 1]$: Context Switch Cost (penalty for switching unrelated tags/projects).

---

## 6. Schedule Output & Explainability Model

The scheduler outputs a structured `ScheduleResult`:

```dart
class ScheduleResult {
  final List<TaskItem> scheduledTasks;
  final List<TaskItem> unplacedTasks;
  final Map<String, TaskPlacementRationale> explanations;
  final List<ScheduleWarning> warnings;
}

class TaskPlacementRationale {
  final String taskId;
  final DateTime assignedStart;
  final DateTime assignedEnd;
  final double score;
  final List<String> factors; // e.g., ["High priority", "Prerequisite 'Draft Spec' completed at 10:00", "Matched morning energy preference"]
}
```

---

## 7. Implementation Phasing for Phase 1.2

1. **Step 1: Domain & Hive Schema**: Update `TaskItem`, add fields 12–22, update TypeAdapter and tests.
2. **Step 2: DAG & Dependency Validator**: Implement cycle detection and topological sorting in `lib/services/dependency_graph_service.dart`.
3. **Step 3: Task Splitting Logic**: Implement block decomposition for splittable tasks.
4. **Step 5: Constraint Solver & Scoring**: Upgrade `SchedulerService.scheduleDay` with multi-factor scoring.
5. **Step 5: Explainability & UI**: Integrate `ScheduleResult` and surface rationale in the day planner UI.
6. **Step 6: Verification**: Unit tests, DAG property tests, invariant tests, analyze, and build.
