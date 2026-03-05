import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../planner/controllers/task_controller.dart';
import '../../../core/models/task_model.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _GlowFab(
        onTap: () => _showInputDialog(context, ref),
      ),
      body: OrbBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                gradient: LinearGradient(
                  colors: [kDark0, const Color(0xFF1A1040)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Day Planner',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMM d').format(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: kGradientMain,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${tasks.where((t) => t.isCompleted).length}/${tasks.length} done',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (tasks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: EmptyState(
                    icon: Icons.schedule_rounded,
                    message:
                        'No tasks planned. Tap the button below to add tasks with AI!',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverToBoxAdapter(
                  child: AnimationLimiter(
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tasks.length,
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final reordered = List<TaskItem>.from(tasks)
                          ..removeAt(oldIndex)
                          ..insert(newIndex, tasks[oldIndex]);
                        // recalc start times from 06:00
                        final base = DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          DateTime.now().day,
                          6,
                          0,
                        );
                        var runningTime = base;
                        final ctrl = ref.read(taskControllerProvider.notifier);
                        ctrl.clearAll();
                        for (var i = 0; i < reordered.length; i++) {
                          final t = reordered[i];
                          final dur = t.endTime != null
                              ? t.endTime!.difference(t.startTime)
                              : const Duration(hours: 1);
                          final updated = t.copyWith(
                            startTime: runningTime,
                            endTime: runningTime.add(dur),
                          );
                          reordered[i] = updated;
                          ctrl.addTask(updated);
                          runningTime = updated.endTime!;
                        }
                      },
                      itemBuilder: (ctx, i) {
                        final task = tasks[i];
                        return AnimationConfiguration.staggeredList(
                          key: ValueKey(task.id),
                          position: i,
                          duration: const Duration(milliseconds: 400),
                          child: SlideAnimation(
                            verticalOffset: 30,
                            child: FadeInAnimation(
                              child: _TaskRow(task: task, index: i),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showInputDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddTaskDialog(
        controller: controller,
        onSubmit: (text) async {
          final ai = ref.read(aiServiceProvider);
          final tasks = await ai.parseTasks(text);
          for (final t in tasks) {
            ref.read(taskControllerProvider.notifier).addTask(t);
          }
          return tasks.length;
        },
      ),
    );
  }
}

// ── Task row ────────────────────────────────────────────────────────────────
class _TaskRow extends ConsumerWidget {
  final TaskItem task;
  final int index;
  const _TaskRow({required this.task, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pColors = _priorityGradient(task.priority);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // priority bar
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: pColors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              // time column
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('h:mm').format(task.startTime),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kIndigo,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: kIndigo.withAlpha(60),
                    ),
                    Text(
                      DateFormat('h:mm a').format(
                        task.endTime ??
                            task.startTime.add(const Duration(hours: 1)),
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF9090A0),
                      ),
                    ),
                  ],
                ),
              ),
              // content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : null,
                        ),
                      ),
                      if (task.note?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.note ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF7C7C8A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (task.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: task.tags
                              .take(3)
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kIndigo.withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: kIndigo,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // complete toggle
                  GestureDetector(
                    onTap: () => ref
                        .read(taskControllerProvider.notifier)
                        .toggleComplete(task.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 4),
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
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  // delete
                  GestureDetector(
                    onTap: () => ref
                        .read(taskControllerProvider.notifier)
                        .removeTask(task.id),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                    ),
                  ),
                  // drag handle
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 20,
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _priorityGradient(int p) {
    switch (p) {
      case 3:
        return const [Color(0xFFFF4444), kCoral];
      case 2:
        return const [kCoral, kAmber];
      case 1:
        return const [kCyan, kIndigo];
      default:
        return [Colors.grey.shade400, Colors.grey.shade600];
    }
  }
}

// ── Add task dialog ─────────────────────────────────────────────────────────
class _AddTaskDialog extends StatefulWidget {
  final TextEditingController controller;
  // Returns the number of tasks added; throws on error.
  final Future<int> Function(String) onSubmit;
  const _AddTaskDialog({required this.controller, required this.onSubmit});

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = CurvedAnimation(parent: _ac, curve: Curves.elasticOut);
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final txt = widget.controller.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final count = await widget.onSubmit(txt);
      if (!mounted) return;
      Navigator.pop(context);
      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "AI couldn't parse any tasks. Try being more specific.",
            ),
            backgroundColor: Color(0xFFFF6B6B),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'AI failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScaleTransition(
      scale: _scale,
      child: AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C3A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => kGradientMain.createShader(b),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'AI Task Planner',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Describe your day or paste tasks, and AI will plan your schedule.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              GlassField(
                controller: widget.controller,
                label: 'Describe your tasks',
                hintText:
                    'e.g. "Team meeting at 9am, gym at 6pm, review reports"',
                maxLines: 4,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: GhostBtn(
                  label: 'Cancel',
                  onTap: _loading ? null : () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _loading
                    ? Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: kGradientMain,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    : GradBtn(
                        label: 'Plan with AI',
                        icon: Icons.auto_awesome_rounded,
                        gradient: kGradientMain,
                        onTap: _submit,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Glow FAB ────────────────────────────────────────────────────────────────
class _GlowFab extends StatefulWidget {
  final VoidCallback onTap;
  const _GlowFab({required this.onTap});

  @override
  State<_GlowFab> createState() => _GlowFabState();
}

class _GlowFabState extends State<_GlowFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) =>
        Transform.scale(scale: 1.0 + 0.04 * _c.value, child: child),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: kGradientMain,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kIndigo.withAlpha(120),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    ),
  );
}
