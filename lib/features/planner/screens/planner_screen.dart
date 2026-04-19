import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../planner/controllers/task_controller.dart';
import '../../../core/models/task_model.dart';
import '../../../core/ai/token_tracker.dart';
import '../../goals/controllers/goal_controller.dart';
import '../../../core/models/goal_model.dart';
import '../../../services/reschedule_service.dart';
import '../../../core/models/memory_entry_model.dart';
import '../../memory/controllers/memory_controller.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(taskControllerProvider);
    final searchQuery = ref.watch(plannerSearchProvider).toLowerCase();
    final goalFilter = ref.watch(plannerGoalFilterProvider);
    final goals = ref.watch(goalControllerProvider);
    final now = DateTime.now();
    final tasks =
        allTasks
            .where(
              (t) =>
                  t.startTime.year == now.year &&
                  t.startTime.month == now.month &&
                  t.startTime.day == now.day,
            )
            .where(
              (t) =>
                  searchQuery.isEmpty ||
                  t.title.toLowerCase().contains(searchQuery) ||
                  (t.note?.toLowerCase().contains(searchQuery) ?? false) ||
                  t.tags.any((tag) => tag.toLowerCase().contains(searchQuery)),
            )
            .where(
              (t) => goalFilter == null || t.linkedGoalId == goalFilter,
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // ── Time-overlap detection ────────────────────────────────────────
    // Build a set of task IDs that have at least one time conflict.
    final conflictingIds = <String>{};
    for (var i = 0; i < tasks.length; i++) {
      for (var j = i + 1; j < tasks.length; j++) {
        final a = tasks[i];
        final b = tasks[j];
        final aEnd = a.endTime ?? a.startTime.add(const Duration(hours: 1));
        final bEnd = b.endTime ?? b.startTime.add(const Duration(hours: 1));
        // Overlap: a starts before b ends AND b starts before a ends
        if (a.startTime.isBefore(bEnd) && b.startTime.isBefore(aEnd)) {
          conflictingIds.add(a.id);
          conflictingIds.add(b.id);
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _GlowFab(
        onTap: () => _showInputDialog(context, ref),
      ),
      body: OrbBackground(
        subtle: true,
        child: RefreshIndicator(
          onRefresh: () async {
            // Invalidate task suggestions so they re-fetch from AI.
            ref.invalidate(taskSuggestionsProvider);
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
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

              // ── Search bar ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withAlpha(100),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) =>
                        ref.read(plannerSearchProvider.notifier).state = v,
                  ),
                ),
              ),

              // ── Goal filter chips ────────────────────────────────────────
              if (goals.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _GoalFilterChip(
                            label: 'All',
                            emoji: null,
                            selected: goalFilter == null,
                            onTap: () => ref
                                .read(plannerGoalFilterProvider.notifier)
                                .state = null,
                          ),
                          for (final g in goals.where((g) => !g.isCompleted))
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _GoalFilterChip(
                                label: g.title,
                                emoji: g.emoji,
                                selected: goalFilter == g.id,
                                onTap: () => ref
                                    .read(plannerGoalFilterProvider.notifier)
                                    .state = goalFilter == g.id ? null : g.id,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Empty search state ──────────────────────────────────────
              if (searchQuery.isNotEmpty &&
                  tasks.isEmpty &&
                  allTasks.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      message:
                          'No tasks match "${searchQuery.length > 24 ? '${searchQuery.substring(0, 24)}\u2026' : searchQuery}"',
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
                // AI-powered suggestions for an empty day
                const SliverToBoxAdapter(child: _TaskSuggestionsPanel())
              else ...[
                SliverToBoxAdapter(
                  child: _PlanMyDayBanner(
                    pendingCount: tasks.where((t) => !t.isCompleted).length,
                    onTap: () => _showPlanMyDaySheet(context, ref),
                  ),
                ),
                // ── Proactive reschedule banner ────────────────────────────
                const SliverToBoxAdapter(child: _OverdueBanner()),
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
                                child: _TaskRow(
                                  task: task,
                                  index: i,
                                  isConflicting: conflictingIds.contains(
                                    task.id,
                                  ),
                                ),
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
  final bool isConflicting;
  const _TaskRow({
    required this.task,
    required this.index,
    this.isConflicting = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pColors = _priorityGradient(task.priority);
    // Resolve linked goal (if any) for the badge
    final linkedGoal = task.linkedGoalId != null
        ? ref.watch(goalControllerProvider.select((goals) {
            try {
              return goals.firstWhere((g) => g.id == task.linkedGoalId);
            } catch (_) {
              return null;
            }
          }))
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Conflict warning banner ───────────────────────
            if (isConflicting)
              GestureDetector(
                onTap: () => _showRescheduleSheet(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: kCoral.withAlpha(30),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: kCoral,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Time conflict — tap to get AI reschedule suggestions',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kCoral,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.auto_fix_high_rounded,
                        size: 13,
                        color: kCoral,
                      ),
                    ],
                  ),
                ),
              ),
            IntrinsicHeight(
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                            // ── Linked goal badge ──────────────
                            if (linkedGoal != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kCoral.withAlpha(25),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: kCoral.withAlpha(60),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          linkedGoal.emoji,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        const SizedBox(width: 4),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 100,
                                          ),
                                          child: Text(
                                            linkedGoal.title,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: kCoral,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                      Semantics(
                        button: true,
                        label: task.isCompleted
                            ? 'Mark ${task.title} as pending'
                            : 'Mark ${task.title} as complete',
                        child: GestureDetector(
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
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black26,
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
                      ),
                      // delete
                      Semantics(
                        button: true,
                        label: 'Delete ${task.title}',
                        child: GestureDetector(
                          onTap: () {
                            final messenger = ScaffoldMessenger.of(context);
                            ref
                                .read(taskControllerProvider.notifier)
                                .removeTask(task.id);
                            messenger
                              ..clearSnackBars()
                              ..showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  showCloseIcon: true,
                                  duration: const Duration(seconds: 8),
                                  content: Text('"${task.title}" deleted'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () {
                                      try {
                                        ref
                                            .read(
                                              taskControllerProvider.notifier,
                                            )
                                            .addTask(task.copyWith());
                                      } catch (_) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Could not restore task.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
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
          ],
        ),
      ),
    );
  }

  void _showRescheduleSheet(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final scheduler = ref.read(schedulerServiceProvider);
    final allTasks = ref.read(taskControllerProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final busyTasks = allTasks
        .where(
          (t) =>
              t.startTime.year == today.year &&
              t.startTime.month == today.month &&
              t.startTime.day == today.day &&
              t.id != task.id,
        )
        .toList();
    final duration = task.endTime != null
        ? task.endTime!.difference(task.startTime)
        : const Duration(hours: 1);
    final slots = scheduler.freeSlots(
      day: today,
      workStartHour: settings.workStartHour,
      workHoursPerDay: settings.workHoursPerDay,
      slotDuration: duration,
      busyTasks: busyTasks,
      count: 4,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RescheduleSheet(
        taskTitle: task.title,
        slots: slots,
        onApply: (newStart) {
          ref
              .read(taskControllerProvider.notifier)
              .updateTask(
                task.copyWith(
                  startTime: newStart,
                  endTime: newStart.add(duration),
                ),
              );
        },
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
        _error = e is RateLimitException
            ? 'Daily AI limit reached. Try again tomorrow.'
            : 'AI failed — please try again.';
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
                        height: 52,
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
    child: Semantics(
      button: true,
      label: 'Add tasks with AI',
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
    ),
  );
}

// ── AI Task Suggestions Panel (empty day) ───────────────────────────────────
class _TaskSuggestionsPanel extends ConsumerWidget {
  const _TaskSuggestionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(taskSuggestionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return suggestionsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (b) => kGradientTeal.createShader(b),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI is suggesting tasks…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 30, 16, 8),
            child: Center(
              child: EmptyState(
                icon: Icons.schedule_rounded,
                message: 'No tasks planned. Tap + to add tasks with AI!',
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => kGradientTeal.createShader(b),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Based on your patterns, you might want to:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((title) {
                  return _SuggestionChip(
                    title: title,
                    onTap: () async {
                      final ai = ref.read(aiServiceProvider);
                      final tasks = await ai.parseTasks(title);
                      for (final t in tasks) {
                        ref.read(taskControllerProvider.notifier).addTask(t);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Suggestion chip ──────────────────────────────────────────────────────────
class _SuggestionChip extends StatefulWidget {
  final String title;
  final VoidCallback onTap;
  const _SuggestionChip({required this.title, required this.onTap});

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _added
          ? null
          : () {
              setState(() => _added = true);
              widget.onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: _added ? kGradientTeal : null,
          color: _added
              ? null
              : (isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.black.withAlpha(8)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _added
                ? Colors.transparent
                : (isDark
                      ? Colors.white.withAlpha(30)
                      : Colors.black.withAlpha(20)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _added ? Icons.check_rounded : Icons.add_rounded,
              size: 14,
              color: _added
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _added
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AI Reschedule bottom sheet ───────────────────────────────────────────────
class _RescheduleSheet extends StatelessWidget {
  final String taskTitle;
  final List<DateTime> slots;
  final void Function(DateTime newStart) onApply;

  const _RescheduleSheet({
    required this.taskTitle,
    required this.slots,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : Colors.black.withAlpha(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high_rounded, color: kCoral, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reschedule "$taskTitle"',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a free slot for today',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 16),
          if (slots.isEmpty)
            Text(
              'No free slots found in your work window.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            )
          else
            ...slots.map((slot) {
              final h = slot.hour.toString().padLeft(2, '0');
              final m = slot.minute.toString().padLeft(2, '0');
              final timeStr = '$h:$m';
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onApply(slot);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1040), kIndigo],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
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
  bool _feedbackGiven = false;

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

      // Re-read persisted tasks so the count includes both scheduler output
      // and tasks that were already scheduled/completed earlier today.
      final updatedAll = ref.read(taskControllerProvider);
      final todayCount = updatedAll.where((t) {
        return t.startTime.year == now.year &&
            t.startTime.month == now.month &&
            t.startTime.day == now.day &&
            !t.isCompleted;
      }).length;

      setState(() {
        _state = _PlanState.done;
        _scheduledCount = todayCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _PlanState.idle;
        _error = e is RateLimitException
            ? 'Daily AI limit reached. Try again tomorrow.'
            : 'Planning failed — please try again.';
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
              const SizedBox(height: 16),
              if (!_feedbackGiven)
                _AiFeedbackBar(
                  onFeedback: (isPositive) {
                    setState(() => _feedbackGiven = true);
                    // Persist feedback as a memory so future AI calls improve.
                    final memCtrl = ref.read(memoryControllerProvider.notifier);
                    memCtrl.addMemory(
                      MemoryEntry(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        content: isPositive
                            ? 'User rated the AI day plan positively'
                            : 'User rated the AI day plan negatively — schedule may need adjustment',
                        sourceType: 'ai',
                        tags: const ['feedback', 'planday'],
                        createdAt: DateTime.now(),
                        relevanceScore: isPositive ? 0.7 : 0.4,
                      ),
                    );
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Thanks for the feedback!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
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
        : (List.of(
            _durationOptions,
          )..sort((a, b) => (a - dur).abs().compareTo((b - dur).abs()))).first;
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
              const SizedBox(height: 16),

              // Linked Notes
              _LinkedGoalSection(task: widget.task),
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

// ── Linked Goal section ───────────────────────────────────────────────────────

class _LinkedGoalSection extends ConsumerWidget {
  final TaskItem task;
  const _LinkedGoalSection({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allGoals = ref.watch(goalControllerProvider);
    final currentGoalId = task.linkedGoalId;
    final currentGoal =
        allGoals.where((g) => g.id == currentGoalId).firstOrNull;

    void unlink() {
      ref.read(taskControllerProvider.notifier).unlinkGoal(task.id);
      if (currentGoalId != null) {
        ref
            .read(goalControllerProvider.notifier)
            .unlinkTask(currentGoalId, task.id);
      }
    }

    Future<void> showLinkDialog() async {
      final available =
          allGoals.where((g) => !g.isArchived && !g.isCompleted).toList();
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active goals available.')),
        );
        return;
      }
      final chosen = await showDialog<GoalItem>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Link to a goal'),
          children: available
              .map(
                (g) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, g),
                  child: Text(
                    '${g.emoji} ${g.title}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (chosen != null) {
        ref.read(taskControllerProvider.notifier).linkGoal(task.id, chosen.id);
        ref
            .read(goalControllerProvider.notifier)
            .linkTask(chosen.id, task.id);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Linked Goal',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            GestureDetector(
              onTap: showLinkDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Link',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (currentGoal == null)
          Text(
            'No linked goal',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          )
        else
          Chip(
            label: Text(
              '${currentGoal.emoji} ${currentGoal.title}',
              style: const TextStyle(fontSize: 12),
            ),
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: unlink,
            backgroundColor: kCoral.withAlpha(isDark ? 40 : 20),
            side: BorderSide(color: kCoral.withAlpha(80)),
            labelStyle: const TextStyle(color: kCoral),
            deleteIconColor: kCoral,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

// ── Overdue / reschedule banner ─────────────────────────────────────────────────

/// Amber banner that appears when Gemini has a reschedule suggestion.
/// Watches [rescheduleSuggestionProvider].
class _OverdueBanner extends ConsumerStatefulWidget {
  const _OverdueBanner();
  @override
  ConsumerState<_OverdueBanner> createState() => _OverdueBannerState();
}

class _OverdueBannerState extends ConsumerState<_OverdueBanner> {
  // Task IDs dismissed this session — prevents same task re-appearing.
  static final _dismissed = <String>{};

  void _accept(RescheduleSuggestion s) {
    final notifier = ref.read(taskControllerProvider.notifier);
    notifier.updateTask(
      s.task.copyWith(startTime: s.proposedTime, endTime: s.proposedEndTime),
    );
    ref.read(rescheduleSuggestionProvider.notifier).state = null;
  }

  void _dismiss(String taskId) {
    _dismissed.add(taskId);
    ref.read(rescheduleSuggestionProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = ref.watch(rescheduleSuggestionProvider);
    if (suggestion == null || _dismissed.contains(suggestion.task.id)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = suggestion.proposedTime.hour.toString().padLeft(2, '0');
    final m = suggestion.proposedTime.minute.toString().padLeft(2, '0');
    final timeLabel = '$h:$m';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kAmber.withAlpha(isDark ? 40 : 30),
              kAmber.withAlpha(isDark ? 20 : 15),
            ],
          ),
          border: Border.all(color: kAmber.withAlpha(100), width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: kAmber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Missed: ${suggestion.task.title}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : kDark0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI suggests moving to $timeLabel',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: kAmber,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _accept(suggestion),
                child: const Text(
                  'Move',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: () => _dismiss(suggestion.task.id),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AI Feedback bar ───────────────────────────────────────────────────────

/// Thumbs-up / thumbs-down rating row shown after AI generates a plan.
///
/// Calls [onFeedback] once with `true` for positive and `false` for negative.
/// Dismissed automatically after one selection.
class _AiFeedbackBar extends StatelessWidget {
  final void Function(bool isPositive) onFeedback;
  const _AiFeedbackBar({required this.onFeedback});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Was this plan helpful?',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: 'Rate plan as helpful',
          child: GestureDetector(
            onTap: () => onFeedback(true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withAlpha(18)
                    : Colors.black.withAlpha(10),
              ),
              child: const Icon(
                Icons.thumb_up_rounded,
                size: 18,
                color: Color(0xFF00C896),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Rate plan as not helpful',
          child: GestureDetector(
            onTap: () => onFeedback(false),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withAlpha(18)
                    : Colors.black.withAlpha(10),
              ),
              child: Icon(
                Icons.thumb_down_rounded,
                size: 18,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Goal filter chip ──────────────────────────────────────────────────────────

class _GoalFilterChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  const _GoalFilterChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? kCoral.withAlpha(isDark ? 50 : 35)
              : (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kCoral.withAlpha(120) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? kCoral
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
