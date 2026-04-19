import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/goal_model.dart';
import '../../../core/models/project_model.dart';
import '../../../core/providers/providers.dart';
import '../../../services/notification_service.dart';

const _uuid = Uuid();

// ── GoalController ─────────────────────────────────────────────────────────

class GoalController extends StateNotifier<List<GoalItem>> {
  late final Box<GoalItem> _box;
  final NotificationService _notifications;

  GoalController({NotificationService? notifications})
    : _notifications = notifications ?? NotificationService(),
      super([]) {
    _box = Hive.box<GoalItem>('goalsBox');
    _refreshState();
  }

  void _refreshState() {
    state = _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Active (non-archived, non-completed) goals — used by dashboard and Brain Dump.
  List<GoalItem> get activeGoals =>
      state.where((g) => !g.isArchived && !g.isCompleted).toList();

  void addGoal(GoalItem goal) {
    _box.put(goal.id, goal);
    _refreshState();
    if (!goal.isCompleted && !goal.isArchived) {
      _notifications.scheduleGoalDeadlineReminder(goal);
    }
  }

  void createGoal({
    required String title,
    String description = '',
    String emoji = '🎯',
    DateTime? deadline,
    int color = 0xFF6C63FF,
  }) {
    final now = DateTime.now();
    final goal = GoalItem(
      id: _uuid.v4(),
      title: title,
      description: description,
      emoji: emoji,
      deadline: deadline,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
    _box.put(goal.id, goal);
    _refreshState();
    _notifications.scheduleGoalDeadlineReminder(goal);
  }

  void updateGoal(GoalItem updated) {
    _box.put(updated.id, updated.copyWith(updatedAt: DateTime.now()));
    _refreshState();
    // Re-schedule deadline reminder with potentially new deadline.
    _notifications.cancelGoalDeadlineReminder(updated.id);
    if (!updated.isCompleted && !updated.isArchived) {
      _notifications.scheduleGoalDeadlineReminder(updated);
    }
  }

  void removeGoal(String goalId) {
    _box.delete(goalId);
    _refreshState();
    _notifications.cancelGoalDeadlineReminder(goalId);
  }

  void toggleComplete(String goalId) {
    final goal = _box.get(goalId);
    if (goal == null) return;
    final updated = goal.copyWith(
      isCompleted: !goal.isCompleted,
      updatedAt: DateTime.now(),
    );
    _box.put(goalId, updated);
    _refreshState();
    // Cancel reminder when completing; restore if un-completing.
    if (updated.isCompleted) {
      _notifications.cancelGoalDeadlineReminder(goalId);
    } else {
      _notifications.scheduleGoalDeadlineReminder(updated);
    }
  }

  void toggleArchive(String goalId) {
    final goal = _box.get(goalId);
    if (goal == null) return;
    _box.put(
      goalId,
      goal.copyWith(isArchived: !goal.isArchived, updatedAt: DateTime.now()),
    );
    _refreshState();
  }

  void linkTask(String goalId, String taskId) {
    final goal = _box.get(goalId);
    if (goal == null) return;
    if (goal.linkedTaskIds.contains(taskId)) return;
    _box.put(
      goalId,
      goal.copyWith(
        linkedTaskIds: [...goal.linkedTaskIds, taskId],
        updatedAt: DateTime.now(),
      ),
    );
    _refreshState();
  }

  void unlinkTask(String goalId, String taskId) {
    final goal = _box.get(goalId);
    if (goal == null) return;
    _box.put(
      goalId,
      goal.copyWith(
        linkedTaskIds: goal.linkedTaskIds.where((id) => id != taskId).toList(),
        updatedAt: DateTime.now(),
      ),
    );
    _refreshState();
  }
}

final goalControllerProvider =
    StateNotifierProvider<GoalController, List<GoalItem>>(
  (ref) => GoalController(notifications: ref.read(notificationServiceProvider)),
);

// ── ProjectController ──────────────────────────────────────────────────────

class ProjectController extends StateNotifier<List<ProjectItem>> {
  late final Box<ProjectItem> _box;

  ProjectController() : super([]) {
    _box = Hive.box<ProjectItem>('projectsBox');
    _refreshState();
  }

  void _refreshState() {
    state = _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void createProject({
    required String title,
    String description = '',
    String? parentGoalId,
  }) {
    final now = DateTime.now();
    final project = ProjectItem(
      id: _uuid.v4(),
      title: title,
      description: description,
      parentGoalId: parentGoalId,
      createdAt: now,
      updatedAt: now,
    );
    _box.put(project.id, project);
    _refreshState();
  }

  void updateProject(ProjectItem updated) {
    _box.put(updated.id, updated.copyWith(updatedAt: DateTime.now()));
    _refreshState();
  }

  void removeProject(String projectId) {
    _box.delete(projectId);
    _refreshState();
  }

  void toggleComplete(String projectId) {
    final project = _box.get(projectId);
    if (project == null) return;
    _box.put(
      projectId,
      project.copyWith(
        isCompleted: !project.isCompleted,
        updatedAt: DateTime.now(),
      ),
    );
    _refreshState();
  }

  void linkTask(String projectId, String taskId) {
    final project = _box.get(projectId);
    if (project == null) return;
    if (project.linkedTaskIds.contains(taskId)) return;
    _box.put(
      projectId,
      project.copyWith(
        linkedTaskIds: [...project.linkedTaskIds, taskId],
        updatedAt: DateTime.now(),
      ),
    );
    _refreshState();
  }

  void unlinkTask(String projectId, String taskId) {
    final project = _box.get(projectId);
    if (project == null) return;
    _box.put(
      projectId,
      project.copyWith(
        linkedTaskIds:
            project.linkedTaskIds.where((id) => id != taskId).toList(),
        updatedAt: DateTime.now(),
      ),
    );
    _refreshState();
  }

  /// All projects belonging to a specific goal.
  List<ProjectItem> forGoal(String goalId) =>
      state.where((p) => p.parentGoalId == goalId).toList();
}

final projectControllerProvider =
    StateNotifierProvider<ProjectController, List<ProjectItem>>(
  (ref) => ProjectController(),
);
