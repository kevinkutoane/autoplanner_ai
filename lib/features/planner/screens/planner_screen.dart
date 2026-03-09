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
    final allTasks = ref.watch(taskControllerProvider);
    final now = DateTime.now();
    final tasks =
        allTasks
            .where(
              (t) =>
                  t.startTime.year == now.year &&
                  t.startTime.month == now.month &&
                  t.startTime.day == now.day,
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

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
              // Plan My Day banner is always visible so users can kick off
              // AI planning even when no tasks exist yet.
              SliverToBoxAdapter(
                child: _PlanMyDayBanner(
                  pendingCount: 0,
                  onTap: () => _showPlanMyDaySheet(context, ref),
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
            else ...[
              SliverToBoxAdapter(
                child: _PlanMyDayBanner(
                  pendingCount: tasks.where((t) => !t.isCompleted).length,
                  onTap: () => _showPlanMyDaySheet(context, ref),
                ),
              ),
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
                        // Just swap the two tasks' times with each other
                        final reordered = List<TaskItem>.from(tasks)
                          ..removeAt(oldIndex)
                          ..insert(newIndex, tasks[oldIndex]);
                        // Swap only the start/end times of affected items
                        // keeping original durations and relative offsets
                        final updated = <TaskItem>[];
                        for (var i = 0; i < reordered.length; i++) {
                          final t = reordered[i];
                          final dur = t.endTime != null
                              ? t.endTime!.difference(t.startTime)
                              : const Duration(hours: 1);
                          // Find the slot time from the original position
                          final slotTime = i < tasks.length
                              ? tasks[i].startTime
                              : tasks.last.endTime ??
                                    tasks.last.startTime.add(
                                      const Duration(hours: 1),
                                    );
                          updated.add(
                            t.copyWith(
                              startTime: slotTime,
                              endTime: slotTime.add(dur),
                            ),
                          );
                        }
                        ref
                            .read(taskControllerProvider.notifier)
                            .reorderTasks(updated);
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

  void _showPlanMyDaySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PlanMyDaySheet(),
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
              // content — tap to edit
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _TaskEditSheet(task: task),
                  ),
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
                ), // GestureDetector
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
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete task?'),
                          content: Text('"${task.title}"'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: kCoral),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        ref
                            .read(taskControllerProvider.notifier)
                            .removeTask(task.id);
                      }
                    },
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

// ── Plan My Day banner ──────────────────────────────────────────────────────
class _PlanMyDayBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;
  const _PlanMyDayBanner({required this.pendingCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kIndigo.withAlpha(isDark ? 40 : 25),
                const Color(0xFF7C3FFF).withAlpha(isDark ? 40 : 20),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kIndigo.withAlpha(isDark ? 80 : 50),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => kGradientMain.createShader(b),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plan My Day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      pendingCount == 0
                          ? 'AI will structure your day from scratch'
                          : 'AI will score & schedule $pendingCount pending tasks',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Plan My Day sheet ───────────────────────────────────────────────────────
class _PlanMyDaySheet extends ConsumerStatefulWidget {
  const _PlanMyDaySheet();

  @override
  ConsumerState<_PlanMyDaySheet> createState() => _PlanMyDaySheetState();
}

class _PlanMyDaySheetState extends ConsumerState<_PlanMyDaySheet> {
  final _extraCtrl = TextEditingController();
  _PlanState _state = _PlanState.idle;
  String _statusMsg = '';
  int _scheduledCount = 0;
  String? _error;

  @override
  void dispose() {
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _scheduleMyDay() async {
    setState(() {
      _state = _PlanState.loading;
      _statusMsg = 'Asking AI to score & estimate your tasks…';
      _error = null;
    });

    try {
      final ai = ref.read(aiServiceProvider);
      final scheduler = ref.read(schedulerServiceProvider);
      final settings = ref.read(settingsProvider);
      final memSvc = ref.read(memoryServiceProvider);
      final taskCtrl = ref.read(taskControllerProvider.notifier);

      final allTasks = ref.read(taskControllerProvider);
      final now = DateTime.now();
      final todayTasks = allTasks
          .where(
            (t) =>
                t.startTime.year == now.year &&
                t.startTime.month == now.month &&
                t.startTime.day == now.day,
          )
          .toList();

      // Step 1: AI enrichment — re-score priority + estimate durations.
      final enriched = await ai.planDay(
        existingTasks: todayTasks,
        memories: memSvc.recentMemories,
        workStartHour: settings.workStartHour,
        workHoursPerDay: settings.workHoursPerDay,
        additionalInput: _extraCtrl.text.trim().isNotEmpty
            ? _extraCtrl.text.trim()
            : null,
      );

      if (!mounted) return;
      setState(() => _statusMsg = 'Packing tasks into your work window…');

      // Step 2: Deterministic slot-packing — assigns real start/end times.
      final scheduled = scheduler.scheduleDay(
        tasks: enriched,
        day: now,
        workStartHour: settings.workStartHour,
        workHoursPerDay: settings.workHoursPerDay,
      );

      // Step 3: Persist — update existing tasks, add brand-new ones.
      final existingIds = {for (final t in todayTasks) t.id};
      for (final t in scheduled) {
        if (existingIds.contains(t.id)) {
          taskCtrl.updateTask(t);
        } else {
          taskCtrl.addTask(t);
        }
      }

      if (!mounted) return;
      setState(() {
        _state = _PlanState.done;
        _scheduledCount = scheduled.where((t) => !t.isCompleted).length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _PlanState.idle;
        _error = 'Planning failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInset = MediaQuery.of(context).viewInsets.bottom;
    final bg = isDark ? const Color(0xFF17172E) : Colors.white;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInset),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // header
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) => kGradientMain.createShader(b),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Plan My Day',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_state == _PlanState.done) ...[
              // ── Success state ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kIndigo.withAlpha(30),
                      const Color(0xFF00C896).withAlpha(30),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF00C896),
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Scheduled $_scheduledCount tasks for today!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GradBtn(
                  label: 'Done',
                  gradient: kGradientTeal,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ] else if (_state == _PlanState.loading) ...[
              // ── Loading state ──────────────────────────────────────────
              const SizedBox(height: 12),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _statusMsg,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
            ] else ...[
              // ── Idle state ─────────────────────────────────────────────
              Text(
                'AI will score your tasks, estimate how long each takes, '
                'and pack them into your work window.',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              GlassField(
                controller: _extraCtrl,
                label: 'Anything to add? (optional)',
                hintText: 'e.g. "call dentist at 11am, pick up groceries"',
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: kCoral, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GhostBtn(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradBtn(
                      label: 'Schedule My Day',
                      icon: Icons.auto_awesome_rounded,
                      gradient: kGradientMain,
                      onTap: _scheduleMyDay,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _PlanState { idle, loading, done }

// ── Task edit sheet ─────────────────────────────────────────────────────────
class _TaskEditSheet extends ConsumerStatefulWidget {
  final TaskItem task;
  const _TaskEditSheet({required this.task});

  @override
  ConsumerState<_TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<_TaskEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late int _priority;
  late TimeOfDay _startTime;
  late int _durationMinutes;
  late String? _recurrence;

  static const _durationOptions = [15, 30, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _noteCtrl = TextEditingController(text: widget.task.note ?? '');
    _priority = widget.task.priority;
    _startTime = TimeOfDay.fromDateTime(widget.task.startTime);
    final dur = widget.task.endTime != null
        ? widget.task.endTime!.difference(widget.task.startTime).inMinutes
        : 60;
    _durationMinutes = _durationOptions.contains(dur)
        ? dur
        : (_durationOptions
                ..sort((a, b) => (a - dur).abs().compareTo((b - dur).abs())))
              .first;
    _recurrence = widget.task.recurrence;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final base = widget.task.startTime;
    final start = DateTime(
      base.year,
      base.month,
      base.day,
      _startTime.hour,
      _startTime.minute,
    );
    final updated = widget.task.copyWith(
      title: title,
      priority: _priority,
      startTime: start,
      endTime: start.add(Duration(minutes: _durationMinutes)),
      note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
      recurrence: _recurrence,
    );
    ref.read(taskControllerProvider.notifier).updateTask(updated);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${widget.task.title}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: kCoral)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(taskControllerProvider.notifier).removeTask(widget.task.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInset = MediaQuery.of(context).viewInsets.bottom;
    final bg = isDark ? const Color(0xFF17172E) : Colors.white;

    final priorityLabels = ['Low', 'Medium', 'High', 'Urgent'];
    final priorityColors = [Colors.grey, kIndigo, kAmber, kCoral];

    return Padding(
      padding: EdgeInsets.only(bottom: viewInset),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Edit Task',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),

              // Title
              GlassField(
                controller: _titleCtrl,
                label: 'Title',
                hintText: 'Task title',
              ),
              const SizedBox(height: 16),

              // Priority
              const Text(
                'Priority',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(4, (i) {
                  final selected = _priority == i;
                  return GestureDetector(
                    onTap: () => setState(() => _priority = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? priorityColors[i].withAlpha(40)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? priorityColors[i]
                              : (isDark ? Colors.white24 : Colors.black12),
                          width: selected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        priorityLabels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected
                              ? priorityColors[i]
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Start time
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start Time',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                            );
                            if (picked != null) {
                              setState(() => _startTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark ? Colors.white24 : Colors.black12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: kIndigo,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _startTime.format(context),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: kIndigo,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Duration
              const Text(
                'Duration',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _durationOptions.map((mins) {
                  final selected = _durationMinutes == mins;
                  final label = mins < 60
                      ? '${mins}m'
                      : (mins % 60 == 0
                            ? '${mins ~/ 60}h'
                            : '${mins ~/ 60}h ${mins % 60}m');
                  return GestureDetector(
                    onTap: () => setState(() => _durationMinutes = mins),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: selected ? kGradientMain : null,
                        border: selected
                            ? null
                            : Border.all(
                                color: isDark ? Colors.white24 : Colors.black12,
                              ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Recurrence
              const Text(
                'Repeat',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _RecurrenceChip(
                    label: 'Never',
                    selected: _recurrence == null,
                    onTap: () => setState(() => _recurrence = null),
                    isDark: isDark,
                  ),
                  _RecurrenceChip(
                    label: 'Daily',
                    selected: _recurrence == 'daily',
                    onTap: () => setState(() => _recurrence = 'daily'),
                    isDark: isDark,
                  ),
                  _RecurrenceChip(
                    label: 'Weekdays',
                    selected: _recurrence == 'weekdays',
                    onTap: () => setState(() => _recurrence = 'weekdays'),
                    isDark: isDark,
                  ),
                  _RecurrenceChip(
                    label: 'Weekly',
                    selected: _recurrence == 'weekly',
                    onTap: () => setState(() => _recurrence = 'weekly'),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Note
              GlassField(
                controller: _noteCtrl,
                label: 'Note (optional)',
                hintText: 'Any context or details…',
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  // Delete
                  GestureDetector(
                    onTap: _delete,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: kCoral.withAlpha(80)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: kCoral,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GhostBtn(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradBtn(
                      label: 'Save',
                      gradient: kGradientMain,
                      onTap: _save,
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
}

// ── Recurrence chip ───────────────────────────────────────────────────────────
class _RecurrenceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  const _RecurrenceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? kGradientMain : null,
          border: selected
              ? null
              : Border.all(color: isDark ? Colors.white24 : Colors.black12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
