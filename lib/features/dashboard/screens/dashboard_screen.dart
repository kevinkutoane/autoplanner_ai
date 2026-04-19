import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../planner/controllers/task_controller.dart';
import '../../../core/models/task_model.dart';
import '../../goals/controllers/goal_controller.dart';
import '../../calendar/controllers/calendar_controller.dart';
import '../../memory/controllers/memory_controller.dart';
import '../../notes/controllers/note_controller.dart';
import '../../settings/screens/help_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/streak_calculator.dart';

// ── Daily insight provider ───────────────────────────────────────────────────
// keepAlive() ensures the insight is fetched exactly once per app session and
// survives hot-reloads. Invalidate via ref.invalidate(dailyInsightProvider)
// to trigger a manual refresh.
final dailyInsightProvider = FutureProvider.autoDispose<String?>((ref) async {
  ref.keepAlive();
  final tasks = ref.read(taskControllerProvider);
  final memories = ref.read(memoryControllerProvider);
  final goals = ref.read(goalControllerProvider);
  final ai = ref.read(aiServiceProvider);
  return ai.generateDailyInsight(tasks, memories, goals: goals);
});

class DashboardScreen extends ConsumerWidget {
  final void Function(int tabIndex) onNavigateTo;
  const DashboardScreen({super.key, required this.onNavigateTo});

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData _sourceIcon(String t) {
    switch (t) {
      case 'task':
        return Icons.task_alt_rounded;
      case 'note':
        return Icons.sticky_note_2_rounded;
      case 'calendar':
        return Icons.calendar_month_rounded;
      default:
        return Icons.psychology_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider);
    final goals = ref.watch(goalControllerProvider);
    final activeGoals = goals.where((g) => !g.isArchived && !g.isCompleted).toList();
    final events = ref.watch(calendarControllerProvider);
    final memories = ref.watch(memoryControllerProvider);
    final insightAsync = ref.watch(dailyInsightProvider);
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayTasks = tasks.where((t) => isSameDay(t.startTime, now)).toList();
    final completedCount = todayTasks.where((t) => t.isCompleted).length;

    // ── Streak: consecutive days with ≥1 completed task ─────────────────────
    final streak = calculateStreak(tasks);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: RefreshIndicator(
          onRefresh: () async {
<<<<<<< HEAD
            ref.invalidate(dailyInsightProvider);
=======
            // Invalidate the daily insight so it re-fetches from AI.
            ref.invalidate(dailyInsightProvider);
            // Allow the spinner to show briefly for visual feedback.
            await Future.delayed(const Duration(milliseconds: 400));
>>>>>>> 01d288189b7546abc54d1782f3d0152a60f39575
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── Hero header ─────────────────────────────────────
              SliverToBoxAdapter(
                child: GradientHeader(
                  gradient: kGradientHero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE, MMM d').format(now),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpScreen(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withAlpha(40),
                                ),
                              ),
                              child: const Icon(
                                Icons.help_outline_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SearchScreen(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withAlpha(40),
                                ),
                              ),
                              child: const Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          _AIPulseIcon(
                            loading: insightAsync.isLoading,
                            onTap: () => ref.invalidate(dailyInsightProvider),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // AI insight glass card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withAlpha(40),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (b) =>
                                      kGradientTeal.createShader(b),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: insightAsync.isLoading
                                      ? const Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _ShimmerLine(width: 200),
                                            SizedBox(height: 6),
                                            _ShimmerLine(width: 140),
                                          ],
                                        )
                                      : Text(
                                          insightAsync.value ??
                                              'Start adding tasks to get personalised insights!',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            height: 1.45,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stats row ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Stagger(
                    index: 0,
                    child: Row(
                      children: [
                        GradStatCard(
                          icon: Icons.task_alt_rounded,
                          label: 'Tasks',
                          value: '$completedCount/${todayTasks.length}',
                          gradient: const [kIndigo, Color(0xFF9D97FF)],
                        ),
                        const SizedBox(width: 10),
                        GradStatCard(
                          icon: Icons.flag_rounded,
                          label: 'Goals',
                          value: '${activeGoals.length}',
                          gradient: const [kCoral, Color(0xFFFF8E8E)],
                        ),
                        const SizedBox(width: 10),
                        GradStatCard(
                          icon: Icons.calendar_month_rounded,
                          label: 'Events',
                          value: '${events.length}',
                          gradient: const [kCyan, Color(0xFF00B894)],
                        ),
                        const SizedBox(width: 10),
                        GradStatCard(
                          icon: Icons.psychology_rounded,
                          label: 'Memories',
                          value: '${memories.length}',
                          gradient: const [kAmber, Color(0xFFFFB347)],
                        ),
                        const SizedBox(width: 10),
                        GradStatCard(
                          icon: Icons.sticky_note_2_rounded,
                          label: 'Notes',
                          value: '${ref.watch(notesControllerProvider).length}',
                          gradient: const [Color(0xFF00B894), kCyan],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Streak motivator ───────────────────────────────
              if (streak > 0)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Stagger(
                      index: 1,
                      child: _StreakBadge(streak: streak),
                    ),
                  ),
                ),

              // ── Today's tasks ────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Stagger(
                    index: 1,
                    child: BodySectionHeader(
                      title: "Today's Tasks",
                      trailing: todayTasks.isEmpty
                          ? '+ Add'
                          : '${(completedCount / todayTasks.length * 100).toInt()}% · See all',
                      onTrailingTap: () => onNavigateTo(1),
                    ),
                  ),
                ),
              ),
              if (todayTasks.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Stagger(
                      index: 2,
                      child: EmptyState(
                        icon: Icons.task_alt_rounded,
                        message:
                            'No tasks yet. Tap + on the Plan tab to start!',
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final task = todayTasks[i];
                        return Stagger(
                          index: i + 2,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => onNavigateTo(1),
                              child: GlassCard(
                                padding: EdgeInsets.zero,
                                child: IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: _priorityGradient(
                                              task.priority,
                                            ),
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            bottomLeft: Radius.circular(20),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      task.title,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14,
                                                        decoration:
                                                            task.isCompleted
                                                            ? TextDecoration
                                                                  .lineThrough
                                                            : null,
                                                        color: task.isCompleted
                                                            ? (isDark
                                                                  ? Colors
                                                                        .white38
                                                                  : Colors
                                                                        .black38)
                                                            : null,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      DateFormat(
                                                        'h:mm a',
                                                      ).format(task.startTime),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isDark
                                                            ? Colors.white54
                                                            : const Color(
                                                                0xFF7C7C8A,
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => ref
                                                    .read(
                                                      taskControllerProvider
                                                          .notifier,
                                                    )
                                                    .toggleComplete(task.id),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 250,
                                                  ),
                                                  width: 26,
                                                  height: 26,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: task.isCompleted
                                                        ? kGradientTeal
                                                        : null,
                                                    border: task.isCompleted
                                                        ? null
                                                        : Border.all(
                                                            color: isDark
                                                                ? Colors.white38
                                                                : Colors
                                                                      .black26,
                                                            width: 1.5,
                                                          ),
                                                  ),
                                                  child: task.isCompleted
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
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: todayTasks.length > 5 ? 5 : todayTasks.length,
                    ),
                  ),
                ),

              // ── Active goals ────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Stagger(
                    index: 4,
                    child: BodySectionHeader(
                      title: 'Active Goals',
                      trailing: activeGoals.isEmpty ? null : 'See all',
                      onTrailingTap: activeGoals.isEmpty
                          ? null
                          : () => onNavigateTo(2),
                    ),
                  ),
                ),
              ),
              if (activeGoals.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Stagger(
                      index: 5,
                      child: EmptyState(
                        icon: Icons.flag_rounded,
                        message: 'No active goals. Add one in the Goals tab!',
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Stagger(
                      index: 5,
                      child: Column(
                        children: activeGoals
                            .take(3)
                            .map(
                              (g) => _GoalProgressCard(
                                goal: g,
                                tasks: tasks,
                                isDark: isDark,
                                onTap: () => onNavigateTo(2),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),

              // ── Memory insights ──────────────────────────────────
              if (memories.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Stagger(
                      index: 6,
                      child: const BodySectionHeader(title: 'Memory Insights'),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Stagger(
                      index: 7,
                      child: GlassCard(
                        child: Column(
                          children: memories
                              .take(3)
                              .map(
                                (m) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (b) =>
                                            kGradientMain.createShader(b),
                                        child: Icon(
                                          _sourceIcon(m.sourceType),
                                          size: 17,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          m.content,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.45,
                                            color: isDark
                                                ? Colors.white.withAlpha(200)
                                                : kDark0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
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

// ── Streak badge ─────────────────────────────────────────────────────────────
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    final milestones = [3, 7, 14, 30, 60, 100];
    final nextMilestone = milestones.firstWhere(
      (m) => m > streak,
      orElse: () => streak + 10,
    );
    final remaining = nextMilestone - streak;

    return GlassCard(
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => kGradientWarm.createShader(b),
            child: const Text('🔥', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak-day streak!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  remaining == 1
                      ? 'One more day to reach $nextMilestone!'
                      : '$remaining days to reach $nextMilestone',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          // Progress pip indicators
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: List.generate(
                  (nextMilestone -
                          (nextMilestone == milestones.first
                              ? 0
                              : (milestones[milestones.indexOf(nextMilestone) -
                                    1])))
                      .clamp(1, 10),
                  (i) {
                    final filled = i < streak.clamp(0, 10);
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: filled ? kGradientWarm : null,
                        color: filled ? null : Colors.grey.withAlpha(60),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AIPulseIcon extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _AIPulseIcon({required this.loading, required this.onTap});

  @override
  State<_AIPulseIcon> createState() => _AIPulseIconState();
}

class _AIPulseIconState extends State<_AIPulseIcon>
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(
          scale: widget.loading ? 1.0 + 0.08 * _c.value : 1.0,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: widget.loading ? kGradientTeal : null,
            color: widget.loading ? null : Colors.white.withAlpha(22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(40), width: 1),
          ),
          child: Icon(
            widget.loading ? Icons.sync_rounded : Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  const _ShimmerLine({required this.width});
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 12,
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(30),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

// ── Goal progress card for dashboard ──────────────────────────────────────

class _GoalProgressCard extends StatelessWidget {
  final dynamic goal; // GoalItem
  final List<TaskItem> tasks;
  final bool isDark;
  final VoidCallback onTap;
  const _GoalProgressCard({
    required this.goal,
    required this.tasks,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final linkedIds = (goal.linkedTaskIds as List<String>);
    final total = linkedIds.length;
    final completed = total == 0
        ? 0
        : tasks.where((t) => linkedIds.contains(t.id) && t.isCompleted).length;
    final fraction = total == 0 ? 0.0 : completed / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CustomPaint(
                  painter: _GoalRingPainter(
                    fraction: fraction,
                    trackColor: isDark
                        ? Colors.white.withAlpha(20)
                        : Colors.black.withAlpha(15),
                    progressColor: total == 0
                        ? Colors.grey
                        : fraction >= 1.0
                            ? kCyan
                            : kCoral,
                  ),
                  child: Center(
                    child:
                        Text(goal.emoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      total == 0
                          ? 'No linked tasks'
                          : '$completed / $total tasks done',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: total == 0
                            ? (isDark ? Colors.white38 : Colors.black38)
                            : (fraction >= 1.0 ? kCyan : kCoral),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  final double fraction;
  final Color trackColor;
  final Color progressColor;

  _GoalRingPainter({
    required this.fraction,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 3;
    const strokeWidth = 3.5;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Track
    canvas.drawCircle(center, radius, trackPaint);
    // Progress arc
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) =>
      old.fraction != fraction ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}
