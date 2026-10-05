import '../core/models/goal_model.dart';
import '../core/models/memory_entry_model.dart';
import '../core/models/note_model.dart';
import '../core/models/project_model.dart';
import '../core/models/task_model.dart';

/// Synthesized cross-domain context representing a task's place in the user's personal knowledge graph.
class TaskContextSynthesis {
  final TaskItem task;
  final GoalItem? goal;
  final ProjectItem? project;
  final List<NoteItem> relatedNotes;
  final List<MemoryEntry> relevantMemories;
  final List<String> contextBadges;
  final double alignmentScore;

  const TaskContextSynthesis({
    required this.task,
    this.goal,
    this.project,
    this.relatedNotes = const [],
    this.relevantMemories = const [],
    this.contextBadges = const [],
    this.alignmentScore = 0.0,
  });

  bool get hasContext =>
      goal != null ||
      project != null ||
      relatedNotes.isNotEmpty ||
      relevantMemories.isNotEmpty;
}

/// Service that builds and traverses the personal knowledge graph across
/// Tasks ↔ Goals ↔ Projects ↔ Notes ↔ Memories.
class ContextualSynthesisService {
  /// Synthesizes cross-domain context for [task] given repository data.
  TaskContextSynthesis synthesizeContext({
    required TaskItem task,
    List<GoalItem> allGoals = const [],
    List<ProjectItem> allProjects = const [],
    List<NoteItem> allNotes = const [],
    List<MemoryEntry> allMemories = const [],
  }) {
    // 1. Resolve Linked Project
    ProjectItem? matchedProject;
    if (task.linkedProjectId != null) {
      matchedProject = allProjects.cast<ProjectItem?>().firstWhere(
            (p) => p?.id == task.linkedProjectId,
            orElse: () => null,
          );
    } else {
      // Fallback: check project linkedTaskIds
      matchedProject = allProjects.cast<ProjectItem?>().firstWhere(
            (p) => p != null && p.linkedTaskIds.contains(task.id),
            orElse: () => null,
          );
    }

    // 2. Resolve Linked Goal (direct or transitive via project)
    GoalItem? matchedGoal;
    if (task.linkedGoalId != null) {
      matchedGoal = allGoals.cast<GoalItem?>().firstWhere(
            (g) => g?.id == task.linkedGoalId,
            orElse: () => null,
          );
    } else if (matchedProject?.parentGoalId != null) {
      matchedGoal = allGoals.cast<GoalItem?>().firstWhere(
            (g) => g?.id == matchedProject!.parentGoalId,
            orElse: () => null,
          );
    }

    // 3. Resolve Related Notes (direct linkedNoteIds, task ID references, or shared tags)
    final matchedNotes = <NoteItem>[];
    final taskTagSet = task.tags.map((t) => t.trim().toLowerCase()).toSet();

    for (final note in allNotes) {
      final isDirectLink = task.linkedNoteIds.contains(note.id) ||
          note.linkedTaskIds.contains(task.id);
      final noteTagSet = note.tags.map((t) => t.trim().toLowerCase()).toSet();
      final hasSharedTag = taskTagSet.isNotEmpty &&
          taskTagSet.intersection(noteTagSet).isNotEmpty;

      if (isDirectLink || hasSharedTag) {
        matchedNotes.add(note);
      }
    }

    // 4. Resolve Relevant Memories (tag matching or title keyword overlap)
    final matchedMemories = <MemoryEntry>[];
    final titleWords = task.title
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();

    for (final mem in allMemories) {
      final memTagSet = mem.tags.map((t) => t.trim().toLowerCase()).toSet();
      final hasSharedTag = taskTagSet.isNotEmpty &&
          taskTagSet.intersection(memTagSet).isNotEmpty;

      final memContentLower = mem.content.toLowerCase();
      final hasKeywordMatch = titleWords.any(memContentLower.contains);

      if (hasSharedTag || hasKeywordMatch) {
        matchedMemories.add(mem);
      }
    }

    // 5. Generate Context Badges
    final badges = <String>[];
    var score = 0.0;

    if (matchedGoal != null) {
      badges.add('🎯 ${matchedGoal.title}');
      score += 0.4;
    }
    if (matchedProject != null) {
      badges.add('📁 ${matchedProject.title}');
      score += 0.3;
    }
    if (matchedNotes.isNotEmpty) {
      badges.add('📝 ${matchedNotes.length} note${matchedNotes.length == 1 ? '' : 's'}');
      score += 0.15;
    }
    if (matchedMemories.isNotEmpty) {
      badges.add('🧠 ${matchedMemories.length} memory');
      score += 0.15;
    }

    return TaskContextSynthesis(
      task: task,
      goal: matchedGoal,
      project: matchedProject,
      relatedNotes: matchedNotes,
      relevantMemories: matchedMemories,
      contextBadges: badges,
      alignmentScore: score.clamp(0.0, 1.0),
    );
  }
}
