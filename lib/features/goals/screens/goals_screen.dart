import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/ui_kit.dart';
import '../controllers/goal_controller.dart';
import '../../../core/models/goal_model.dart';
import '../../../core/models/project_model.dart';
import 'goal_detail_screen.dart';

const _uuid = Uuid();

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

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

  void _showAddGoalDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String emoji = '🎯';
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await _pickEmoji(ctx);
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
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
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
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Description / notes (optional)',
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
                final now = DateTime.now();
                ref
                    .read(goalControllerProvider.notifier)
                    .addGoal(
                      GoalItem(
                        id: _uuid.v4(),
                        title: title,
                        description: descCtrl.text.trim(),
                        emoji: emoji,
                        createdAt: now,
                        updatedAt: now,
                      ),
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
                  initialValue: selectedGoal,
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
                ref
                    .read(projectControllerProvider.notifier)
                    .createProject(
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

  Future<String?> _pickEmoji(BuildContext context) async {
    const emojis = [
      '🎯',
      '🚀',
      '💡',
      '🌟',
      '🏆',
      '📈',
      '💪',
      '🎓',
      '🌱',
      '❤️',
      '💰',
      '🏃',
      '📚',
      '🎨',
      '🔬',
      '🌍',
      '✨',
      '🎵',
      '🏠',
      '👨‍💻',
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
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
                      onTap: () => Navigator.pop(ctx, e),
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _GoalsFab(
        onAddGoal: _showAddGoalDialog,
        onAddProject: _showAddProjectDialog,
      ),
      body: OrbBackground(
        subtle: true,
        child: Column(
          children: [
            GradientHeader(
              gradient: const LinearGradient(
                colors: [kCoral, Color(0xFFFF8E8E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Goals & Projects',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Track what matters most',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(text: 'Goals'),
                      Tab(text: 'Projects'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _GoalsTab(isDark: isDark),
                  _ProjectsTab(isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goals tab ──────────────────────────────────────────────────────────────

class _GoalsTab extends ConsumerWidget {
  final bool isDark;
  const _GoalsTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalControllerProvider);
    final active = goals.where((g) => !g.isArchived && !g.isCompleted).toList();
    final completed = goals.where((g) => g.isCompleted).toList();
    final archived = goals
        .where((g) => g.isArchived && !g.isCompleted)
        .toList();

    if (goals.isEmpty) {
      return EmptyState(
        icon: Icons.flag_rounded,
        message: 'No goals yet. Tap + to add your first goal!',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (active.isNotEmpty) ...[
          _SectionLabel(label: 'Active', color: kCoral),
          ...active.map((g) => _GoalCard(goal: g, isDark: isDark)),
          const SizedBox(height: 12),
        ],
        if (completed.isNotEmpty) ...[
          _SectionLabel(label: 'Completed', color: kCyan),
          ...completed.map((g) => _GoalCard(goal: g, isDark: isDark)),
          const SizedBox(height: 12),
        ],
        if (archived.isNotEmpty) ...[
          _SectionLabel(label: 'Archived', color: Colors.grey),
          ...archived.map((g) => _GoalCard(goal: g, isDark: isDark)),
        ],
      ],
    );
  }
}

// ── Projects tab ───────────────────────────────────────────────────────────

class _ProjectsTab extends ConsumerWidget {
  final bool isDark;
  const _ProjectsTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectControllerProvider);
    final active = projects.where((p) => !p.isCompleted).toList();
    final completed = projects.where((p) => p.isCompleted).toList();

    if (projects.isEmpty) {
      return EmptyState(
        icon: Icons.folder_outlined,
        message: 'No projects yet. Tap + to create one!',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (active.isNotEmpty) ...[
          _SectionLabel(label: 'Active', color: kIndigo),
          ...active.map((p) => _ProjectCard(project: p, isDark: isDark)),
          const SizedBox(height: 12),
        ],
        if (completed.isNotEmpty) ...[
          _SectionLabel(label: 'Completed', color: kCyan),
          ...completed.map((p) => _ProjectCard(project: p, isDark: isDark)),
        ],
      ],
    );
  }
}

// ── Goal card ──────────────────────────────────────────────────────────────

class _GoalCard extends ConsumerWidget {
  final GoalItem goal;
  final bool isDark;
  const _GoalCard({required this.goal, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: 'Open goal: ${goal.title}',
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GoalDetailScreen(goalId: goal.id),
            ),
          ),
          onLongPress: () => _showContextMenu(context, ref),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Text(goal.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          decoration: goal.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: goal.isCompleted
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : null,
                        ),
                      ),
                      if (goal.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          goal.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (goal.linkedTaskIds.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${goal.linkedTaskIds.length} linked task${goal.linkedTaskIds.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? kCoral.withAlpha(180) : kCoral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(goalControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                goal.isCompleted
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle_outline,
              ),
              title: Text(
                goal.isCompleted ? 'Mark as active' : 'Mark as completed',
              ),
              onTap: () {
                ctrl.toggleComplete(goal.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                goal.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(goal.isArchived ? 'Unarchive' : 'Archive'),
              onTap: () {
                ctrl.toggleArchive(goal.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                ctrl.removeGoal(goal.id);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Project card ───────────────────────────────────────────────────────────

class _ProjectCard extends ConsumerWidget {
  final ProjectItem project;
  final bool isDark;
  const _ProjectCard({required this.project, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
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
                  if (project.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      project.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => ref
                  .read(projectControllerProvider.notifier)
                  .toggleComplete(project.id),
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
                          color: isDark ? Colors.white38 : Colors.black26,
                          width: 1.5,
                        ),
                ),
                child: project.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────

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

// ── FAB ────────────────────────────────────────────────────────────────────

class _GoalsFab extends StatefulWidget {
  final VoidCallback onAddGoal;
  final VoidCallback onAddProject;
  const _GoalsFab({required this.onAddGoal, required this.onAddProject});

  @override
  State<_GoalsFab> createState() => _GoalsFabState();
}

class _GoalsFabState extends State<_GoalsFab>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ac;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _anim = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ac.forward();
    } else {
      _ac.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ScaleTransition(
          scale: _anim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniAction(
                icon: Icons.folder_outlined,
                label: 'Project',
                onTap: () {
                  _toggle();
                  widget.onAddProject();
                },
              ),
              const SizedBox(height: 8),
              _MiniAction(
                icon: Icons.flag_outlined,
                label: 'Goal',
                onTap: () {
                  _toggle();
                  widget.onAddGoal();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: kCoral,
          foregroundColor: Colors.white,
          elevation: 6,
          child: AnimatedRotation(
            turns: _expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ],
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(20) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kCoral.withAlpha(200),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kCoral.withAlpha(80),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
