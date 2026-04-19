import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/models/project_model.dart';
import '../../../core/models/goal_model.dart';
import '../../../core/models/task_model.dart';
import '../../goals/controllers/goal_controller.dart';
import '../../planner/controllers/task_controller.dart';

// ── ProjectsScreen ──────────────────────────────────────────────────────────
//
// Standalone project management screen with:
//  • Active / Completed tabs
//  • Project detail expansion with linked tasks
//  • Add project dialog with optional parent goal
//  • Swipe-to-delete and toggle-complete

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String? _expandedProjectId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Add Project Dialog ──────────────────────────────────────────────────

  void _showAddProjectDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final goals = ref.read(goalControllerProvider);
    GoalItem? selectedGoal;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Project title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (goals.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<GoalItem>(
                  decoration: const InputDecoration(
                    labelText: 'Parent goal (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: goals
                      .where((g) => !g.isArchived && !g.isCompleted)
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('${g.emoji} ${g.title}'),
                        ),
                      )
                      .toList(),
                  onChanged: (g) => setDialogState(() => selectedGoal = g),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                ref.read(projectControllerProvider.notifier).createProject(
                  title: title,
                  description: descCtrl.text.trim(),
                  parentGoalId: selectedGoal?.id,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit Project Dialog ─────────────────────────────────────────────────

  void _showEditProjectDialog(ProjectItem project) {
    final titleCtrl = TextEditingController(text: project.title);
    final descCtrl = TextEditingController(text: project.description);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Project title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              ref.read(projectControllerProvider.notifier).updateProject(
                project.copyWith(
                  title: title,
                  description: descCtrl.text.trim(),
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Delete Confirmation ─────────────────────────────────────────────────

  void _confirmDelete(ProjectItem project) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Delete "${project.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(projectControllerProvider.notifier).removeProject(project.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projects = ref.watch(projectControllerProvider);
    final active = projects.where((p) => !p.isCompleted).toList();
    final completed = projects.where((p) => p.isCompleted).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProjectDialog,
        backgroundColor: kIndigo,
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: OrbBackground(
        subtle: true,
        child: Column(
          children: [
            GradientHeader(
              gradient: const LinearGradient(
                colors: [kIndigo, Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Projects',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${active.length} active',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Organise work into deliverable milestones',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    tabs: [
                      Tab(text: 'Active (${active.length})'),
                      Tab(text: 'Completed (${completed.length})'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildProjectList(active, isDark, isEmpty: active.isEmpty),
                  _buildProjectList(completed, isDark, isEmpty: completed.isEmpty),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList(
    List<ProjectItem> projects,
    bool isDark, {
    required bool isEmpty,
  }) {
    if (isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_outlined,
        message: 'No projects here yet',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _ProjectExpandableCard(
          project: project,
          isDark: isDark,
          isExpanded: _expandedProjectId == project.id,
          onTap: () {
            setState(() {
              _expandedProjectId =
                  _expandedProjectId == project.id ? null : project.id;
            });
          },
          onEdit: () => _showEditProjectDialog(project),
          onDelete: () => _confirmDelete(project),
          onToggleComplete: () => ref
              .read(projectControllerProvider.notifier)
              .toggleComplete(project.id),
        );
      },
    );
  }
}

// ── Expandable Project Card ─────────────────────────────────────────────────

class _ProjectExpandableCard extends ConsumerWidget {
  final ProjectItem project;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleComplete;

  const _ProjectExpandableCard({
    required this.project,
    required this.isDark,
    required this.isExpanded,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalControllerProvider);
    final tasks = ref.watch(taskControllerProvider);

    // Find parent goal if any.
    final parentGoal = project.parentGoalId != null
        ? goals.where((g) => g.id == project.parentGoalId).firstOrNull
        : null;

    // Find linked tasks.
    final linkedTasks =
        tasks.where((t) => project.linkedTaskIds.contains(t.id)).toList();
    final completedTasks = linkedTasks.where((t) => t.isCompleted).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(10),
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ────────────────────────────────────────
                  Row(
                    children: [
                      Icon(
                        project.isCompleted
                            ? Icons.folder_open_rounded
                            : Icons.folder_outlined,
                        color: kIndigo,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                decoration: project.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: project.isCompleted
                                    ? (isDark ? Colors.white38 : Colors.black38)
                                    : null,
                              ),
                            ),
                            if (parentGoal != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${parentGoal.emoji} ${parentGoal.title}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Task progress chip
                      if (linkedTasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: kCyan.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$completedTasks/${linkedTasks.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kCyan,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // Complete toggle
                      GestureDetector(
                        onTap: onToggleComplete,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: project.isCompleted ? kGradientTeal : null,
                            border: project.isCompleted
                                ? null
                                : Border.all(
                                    color:
                                        isDark ? Colors.white38 : Colors.black26,
                                    width: 1.5,
                                  ),
                          ),
                          child: project.isCompleted
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ],
                  ),

                  // ── Description ───────────────────────────────────────
                  if (project.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      project.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ],

                  // ── Expanded section ──────────────────────────────────
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Linked tasks
                    if (linkedTasks.isNotEmpty) ...[
                      _SectionLabel(
                        label: 'Linked Tasks',
                        color: kCyan,
                      ),
                      ...linkedTasks.map(
                        (task) => _LinkedTaskRow(task: task, isDark: isDark),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Actions row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ActionChip(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onTap: onEdit,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          onTap: onDelete,
                          isDark: isDark,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Linked Task Row ─────────────────────────────────────────────────────────

class _LinkedTaskRow extends StatelessWidget {
  final TaskItem task;
  final bool isDark;
  const _LinkedTaskRow({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            task.isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: task.isCompleted ? kCyan : (isDark ? Colors.white38 : Colors.black38),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted
                    ? (isDark ? Colors.white38 : Colors.black38)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Chip ─────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isDestructive;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Colors.red
        : (isDark ? Colors.white54 : Colors.black54);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isDestructive ? Colors.red : Colors.grey).withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
