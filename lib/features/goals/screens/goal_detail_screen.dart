import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/ui_kit.dart';
import '../controllers/goal_controller.dart';
import '../../../core/models/goal_model.dart';
import '../../../core/models/project_model.dart';
import '../../../core/models/task_model.dart';
import '../../planner/controllers/task_controller.dart';

class GoalDetailScreen extends ConsumerStatefulWidget {
  final String goalId;
  const GoalDetailScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  bool _editingDesc = false;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    final goal = _findGoal();
    _descCtrl = TextEditingController(text: goal?.description ?? '');
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  GoalItem? _findGoal() {
    final goals = ref.read(goalControllerProvider);
    try {
      return goals.firstWhere((g) => g.id == widget.goalId);
    } catch (_) {
      return null;
    }
  }

  void _saveDescription() {
    final goal = _findGoal();
    if (goal == null) return;
    ref.read(goalControllerProvider.notifier).updateGoal(
      goal.copyWith(description: _descCtrl.text.trim()),
    );
    setState(() => _editingDesc = false);
  }

  void _showEditTitleDialog(BuildContext context, GoalItem goal) {
    final titleCtrl = TextEditingController(text: goal.title);
    String emoji = goal.emoji;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Goal'),
          content: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  const emojis = [
                    '🎯', '🚀', '💡', '🌟', '🏆', '📈', '💪', '🎓', '🌱', '❤️',
                    '💰', '🏃', '📚', '🎨', '🔬', '🌍', '✨', '🎵', '🏠', '👨‍💻',
                  ];
                  final picked = await showDialog<String>(
                    context: ctx,
                    builder: (ectx) => SimpleDialog(
                      title: const Text('Choose emoji'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: emojis
                                .map(
                                  (e) => GestureDetector(
                                    onTap: () => Navigator.pop(ectx, e),
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (picked != null) {
                    setDialogState(() => emoji = picked);
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: kCoral.withAlpha(120)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Goal title',
                    border: OutlineInputBorder(),
                  ),
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
                final currentGoal = ref.read(goalControllerProvider).where((g) => g.id == widget.goalId).firstOrNull;
                if (currentGoal != null) {
                  ref.read(goalControllerProvider.notifier).updateGoal(
                    currentGoal.copyWith(title: title, emoji: emoji),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalControllerProvider);
    final goalMatch = goals.where((g) => g.id == widget.goalId);
    if (goalMatch.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Goal')),
        body: const Center(child: Text('Goal not found')),
      );
    }
    final goal = goalMatch.first;

    final projects = ref
        .watch(projectControllerProvider)
        .where((p) => p.parentGoalId == widget.goalId)
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTasks = ref.watch(taskControllerProvider);
    final linkedTasks = allTasks
        .where((t) => goal.linkedTaskIds.contains(t.id))
        .toList();
    final taskCount = linkedTasks.length;
    final completedTaskCount =
        linkedTasks.where((t) => t.isCompleted).length;
    final taskFraction =
        taskCount == 0 ? 0.0 : completedTaskCount / taskCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              expandedHeight: 180,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        kCoral,
                        const Color(0xFFFF8E8E),
                        kCoral.withAlpha(160),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            goal.emoji,
                            style: const TextStyle(fontSize: 40),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  goal.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (taskCount > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '$taskCount linked task${taskCount == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white70,
                            ),
                            onPressed: () =>
                                _showEditTitleDialog(context, goal),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status chips
                    Row(
                      children: [
                        _StatusChip(
                          label: goal.isCompleted ? 'Completed' : 'Active',
                          color: goal.isCompleted ? kCyan : kCoral,
                          icon: goal.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_checked_rounded,
                          onTap: () => ref
                              .read(goalControllerProvider.notifier)
                              .toggleComplete(goal.id),
                        ),
                        const SizedBox(width: 8),
                        if (goal.deadline != null)
                          _StatusChip(
                            label: _formatDeadline(goal.deadline!),
                            color: _isOverdue(goal.deadline!)
                                ? Colors.red
                                : kAmber,
                            icon: Icons.calendar_today_rounded,
                            onTap: () => _pickDeadline(context, goal),
                          )
                        else
                          _StatusChip(
                            label: 'Add deadline',
                            color: Colors.grey,
                            icon: Icons.calendar_today_outlined,
                            onTap: () => _pickDeadline(context, goal),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Description / Notes
                    _SectionHeader(label: 'Description', icon: Icons.notes_rounded),
                    const SizedBox(height: 8),
                    GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: _editingDesc
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                TextField(
                                  controller: _descCtrl,
                                  minLines: 3,
                                  maxLines: 10,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Add notes, context, or details…',
                                    border: InputBorder.none,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => setState(
                                        () => _editingDesc = false,
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: _saveDescription,
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : GestureDetector(
                              onTap: () => setState(() {
                                _descCtrl.text = goal.description;
                                _editingDesc = true;
                              }),
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  goal.description.isEmpty
                                      ? 'Tap to add notes…'
                                      : goal.description,
                                  style: TextStyle(
                                    color: goal.description.isEmpty
                                        ? (isDark
                                            ? Colors.white38
                                            : Colors.black38)
                                        : null,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // Linked tasks progress
                    _SectionHeader(
                      label: 'Linked Tasks',
                      icon: Icons.checklist_rounded,
                    ),
                    const SizedBox(height: 8),
                    if (taskCount == 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No tasks linked yet. Link tasks from the Planner.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      )
                    else ...[
                      // Progress bar
                      GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$completedTaskCount / $taskCount tasks',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${(taskFraction * 100).round()}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: taskFraction >= 1.0
                                        ? kCyan
                                        : kCoral,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: taskFraction,
                                minHeight: 6,
                                backgroundColor: isDark
                                    ? Colors.white.withAlpha(20)
                                    : Colors.black.withAlpha(12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  taskFraction >= 1.0 ? kCyan : kCoral,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Task rows
                      ...linkedTasks.map(
                        (t) => _LinkedTaskRow(
                          task: t,
                          isDark: isDark,
                          onToggle: () => ref
                              .read(taskControllerProvider.notifier)
                              .toggleComplete(t.id),
                          onUnlink: () {
                            ref
                                .read(taskControllerProvider.notifier)
                                .unlinkGoal(t.id);
                            ref
                                .read(goalControllerProvider.notifier)
                                .unlinkTask(goal.id, t.id);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Projects
                    _SectionHeader(
                      label: 'Projects',
                      icon: Icons.folder_outlined,
                    ),
                    const SizedBox(height: 8),
                    if (projects.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No projects linked to this goal.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      )
                    else
                      ...projects.map(
                        (p) => _GoalProjectRow(project: p, isDark: isDark),
                      ),

                    const SizedBox(height: 24),

                    // Danger zone
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete goal'),
                        onPressed: () =>
                            _confirmDelete(context, ref, goal.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeadline(BuildContext context, GoalItem goal) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: goal.deadline ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      final currentGoal = ref.read(goalControllerProvider).where((g) => g.id == widget.goalId).firstOrNull;
      if (currentGoal != null) {
        ref.read(goalControllerProvider.notifier).updateGoal(
          currentGoal.copyWith(deadline: picked),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String goalId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text(
          'This will permanently delete the goal. Tasks will remain in your planner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(goalControllerProvider.notifier).removeGoal(goalId);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDeadline(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 0) return 'Overdue';
    return '${d.day}/${d.month}/${d.year}';
  }

  bool _isOverdue(DateTime d) => d.isBefore(DateTime.now());
}

// ── Supporting widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kCoral),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          border: Border.all(color: color.withAlpha(100)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalProjectRow extends ConsumerWidget {
  final ProjectItem project;
  final bool isDark;
  const _GoalProjectRow({required this.project, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              project.isCompleted
                  ? Icons.folder_open_rounded
                  : Icons.folder_outlined,
              color: kIndigo,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                project.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  decoration:
                      project.isCompleted ? TextDecoration.lineThrough : null,
                  color: project.isCompleted
                      ? (isDark ? Colors.white38 : Colors.black38)
                      : null,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => ref
                  .read(projectControllerProvider.notifier)
                  .toggleComplete(project.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: project.isCompleted ? kGradientTeal : null,
                  border: project.isCompleted
                      ? null
                      : Border.all(
                          color: isDark ? Colors.white38 : Colors.black26,
                          width: 1.5,
                        ),
                ),
                child: project.isCompleted
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Linked task row ───────────────────────────────────────────────────────

class _LinkedTaskRow extends StatelessWidget {
  final TaskItem task;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onUnlink;
  const _LinkedTaskRow({
    required this.task,
    required this.isDark,
    required this.onToggle,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: task.isCompleted ? kGradientTeal : null,
                  border: task.isCompleted
                      ? null
                      : Border.all(
                          color: isDark ? Colors.white38 : Colors.black26,
                          width: 1.5,
                        ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                  color: task.isCompleted
                      ? (isDark ? Colors.white38 : Colors.black38)
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: onUnlink,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.link_off_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
