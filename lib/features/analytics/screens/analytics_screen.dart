import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../planner/controllers/task_controller.dart';
import '../../goals/controllers/goal_controller.dart';
import 'weekly_review_screen.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: GradientHeader(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1040), Color(0xFF0D2040), kIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your productivity at a glance',
                      style: TextStyle(
                        color: Colors.white.withAlpha(160),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withAlpha(120),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      indicator: UnderlineTabIndicator(
                        borderSide: const BorderSide(color: kCyan, width: 2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      tabs: const [
                        Tab(text: 'Performance'),
                        Tab(text: 'AI Usage'),
                        Tab(text: 'Weekly Review'),
                        Tab(text: 'App Health'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: const [
              _PerformanceTab(),
              _AiUsageTab(),
              WeeklyReviewScreen(),
              _AppHealthTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Performance tab (original content) ───────────────────────────────────────

class _PerformanceTab extends ConsumerWidget {
  const _PerformanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider);
    final goals = ref.watch(goalControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Weekly completion data (last 7 days) ─────────────────────────────────
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    int completedOnDay(DateTime day) => tasks.where((t) {
      return t.isCompleted &&
          t.startTime.year == day.year &&
          t.startTime.month == day.month &&
          t.startTime.day == day.day;
    }).length;

    int totalOnDay(DateTime day) => tasks
        .where(
          (t) =>
              t.startTime.year == day.year &&
              t.startTime.month == day.month &&
              t.startTime.day == day.day,
        )
        .length;

    final completedCounts = days.map(completedOnDay).toList();
    final totalCounts = days.map(totalOnDay).toList();
    final maxY = (totalCounts.reduce((a, b) => a > b ? a : b) + 1).toDouble();

    // ── Streak calculation ───────────────────────────────────────────────────
    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final d = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));
      final completed = tasks.where(
        (t) =>
            t.isCompleted &&
            t.startTime.year == d.year &&
            t.startTime.month == d.month &&
            t.startTime.day == d.day,
      );
      if (completed.isEmpty) break;
      streak++;
    }

    // ── All-time stats ───────────────────────────────────────────────────────
    final totalCompleted = tasks.where((t) => t.isCompleted).length;
    final totalAll = tasks.length;
    final overallRate = totalAll == 0 ? 0.0 : totalCompleted / totalAll;

    final priorityLabels = ['Low', 'Medium', 'High', 'Urgent'];
    final priorityColors = [Colors.grey, kIndigo, kAmber, kCoral];
    final priorityCounts = List.generate(4, (p) {
      return tasks.where((t) => t.isCompleted && t.priority == p).length;
    });

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Streak + completion rate cards ───────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ShaderMask(
                              shaderCallback: (b) =>
                                  kGradientWarm.createShader(b),
                              child: const Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Streak',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$streak',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          streak == 1 ? 'day' : 'days',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ShaderMask(
                              shaderCallback: (b) =>
                                  kGradientTeal.createShader(b),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Completion',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(overallRate * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          '$totalCompleted / $totalAll tasks',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black45,
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

        // ── Weekly bar chart ─────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last 7 Days',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Completed vs. Scheduled',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY < 2 ? 5 : maxY,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                              '${rod.toY.toInt()}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                final d = days[v.toInt()];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    DateFormat('E').format(d),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                              reservedSize: 28,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (v, meta) => Text(
                                v.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                              ),
                              reservedSize: 22,
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: isDark
                                ? Colors.white.withAlpha(15)
                                : Colors.black.withAlpha(12),
                            strokeWidth: 1,
                          ),
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(7, (i) {
                          final total = totalCounts[i].toDouble();
                          final done = completedCounts[i].toDouble();
                          final isToday =
                              days[i].day == today.day &&
                              days[i].month == today.month &&
                              days[i].year == today.year;
                          return BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: [
                              if (total > 0)
                                BarChartRodData(
                                  toY: total,
                                  width: 18,
                                  borderRadius: BorderRadius.circular(6),
                                  rodStackItems: [
                                    BarChartRodStackItem(
                                      0,
                                      done,
                                      isToday ? kCyan : kIndigo,
                                    ),
                                    if (total > done)
                                      BarChartRodStackItem(
                                        done,
                                        total,
                                        isDark
                                            ? Colors.white.withAlpha(25)
                                            : Colors.black.withAlpha(15),
                                      ),
                                  ],
                                )
                              else
                                BarChartRodData(
                                  toY: 0.2,
                                  width: 18,
                                  color: isDark
                                      ? Colors.white.withAlpha(15)
                                      : Colors.black.withAlpha(10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _LegendDot(color: kIndigo, label: 'Completed'),
                      const SizedBox(width: 16),
                      _LegendDot(
                        color: isDark
                            ? Colors.white.withAlpha(40)
                            : Colors.black.withAlpha(20),
                        label: 'Remaining',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Priority breakdown ───────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          sliver: SliverToBoxAdapter(
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Completed by Priority',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(4, (p) {
                    final count = priorityCounts[p];
                    final frac = totalCompleted == 0
                        ? 0.0
                        : count / totalCompleted;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                priorityLabels[p],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: priorityColors[p],
                                ),
                              ),
                              Text(
                                count.toString(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: frac,
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? Colors.white.withAlpha(20)
                                  : Colors.black.withAlpha(10),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                priorityColors[p],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        // ── Goals overview ───────────────────────────────────
        if (goals.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverToBoxAdapter(
              child: _GoalsOverviewCard(
                goals: goals,
                tasks: tasks,
                isDark: isDark,
              ),
            ),
          ),
      ],
    );
  }
}

class _GoalsOverviewCard extends StatelessWidget {
  final List<dynamic> goals;
  final List<dynamic> tasks;
  final bool isDark;

  const _GoalsOverviewCard({
    required this.goals,
    required this.tasks,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeGoals = goals.where((g) => !g.isCompleted).length;
    final completedGoals = goals.where((g) => g.isCompleted).length;

    // Compute average task completion across all goals with linked tasks.
    double avgCompletion = 0;
    int goalsWithTasks = 0;
    for (final g in goals) {
      final linked = (g.linkedTaskIds as List<String>?) ?? [];
      if (linked.isEmpty) continue;
      final linkedTasks = tasks.where((t) => linked.contains(t.id));
      if (linkedTasks.isEmpty) continue;
      goalsWithTasks++;
      avgCompletion += linkedTasks.where((t) => t.isCompleted).length /
          linkedTasks.length;
    }
    if (goalsWithTasks > 0) avgCompletion /= goalsWithTasks;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => kGradientWarm.createShader(b),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Goals Overview',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GoalStatChip(
                  label: 'Active',
                  value: '$activeGoals',
                  color: kCoral,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GoalStatChip(
                  label: 'Completed',
                  value: '$completedGoals',
                  color: kCyan,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GoalStatChip(
                  label: 'Avg Progress',
                  value: '${(avgCompletion * 100).toInt()}%',
                  color: kIndigo,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _GoalStatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 25 : 18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Usage tab ──────────────────────────────────────────────────────────────

class _AiUsageTab extends ConsumerWidget {
  const _AiUsageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(tokenTrackerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayTokens = tracker.todayTokens;
    final remainingTokens = tracker.remainingTokens;
    final todayCallCount = tracker.todayCallCount;
    final avgLatency = tracker.todayAvgLatency;
    final maxTokens = todayTokens + remainingTokens;
    final usageFrac = maxTokens == 0
        ? 0.0
        : (todayTokens / maxTokens).clamp(0.0, 1.0);

    // ── 7-day history ────────────────────────────────────────
    final history = tracker.usageHistory(days: 7);
    final historyEntries = history.entries.toList().reversed.toList();
    final historyMax = history.values.fold(0, (a, b) => a > b ? a : b);

    // ── Action breakdown (today's logs) ─────────────────────
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayLogs = tracker.allLogs
        .where((e) => e.timestamp.isAfter(todayStart))
        .toList();
    final actionMap = <String, int>{};
    for (final log in todayLogs) {
      actionMap[log.action] = (actionMap[log.action] ?? 0) + log.totalTokens;
    }
    final actions = actionMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Summary cards ────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => kGradientMain.createShader(b),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$todayTokens',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'tokens today',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => kGradientTeal.createShader(b),
                          child: const Icon(
                            Icons.call_made_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$todayCallCount',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'AI calls today',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
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

        // ── Token budget gauge ───────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daily Token Budget',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$remainingTokens remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: remainingTokens < maxTokens * 0.2
                              ? kCoral
                              : (isDark ? Colors.white54 : Colors.black45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: usageFrac,
                      minHeight: 10,
                      backgroundColor: isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(10),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        usageFrac > 0.85 ? kCoral : kCyan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$todayTokens used',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      if (avgLatency > 0)
                        Text(
                          'avg ${avgLatency.toStringAsFixed(0)} ms',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── 7-day token history ──────────────────────────────
        if (historyMax > 0)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Token Usage — Last 7 Days',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...historyEntries.map((entry) {
                      final frac = historyMax == 0
                          ? 0.0
                          : (entry.value / historyMax).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: frac,
                                  minHeight: 8,
                                  backgroundColor: isDark
                                      ? Colors.white.withAlpha(15)
                                      : Colors.black.withAlpha(8),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        kIndigo,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.value}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

        // ── Action breakdown ─────────────────────────────────
        if (actions.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverToBoxAdapter(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today by Action',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...actions.map((entry) {
                      final frac = todayTokens == 0
                          ? 0.0
                          : (entry.value / todayTokens).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${entry.value} tk',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: frac,
                                minHeight: 5,
                                backgroundColor: isDark
                                    ? Colors.white.withAlpha(15)
                                    : Colors.black.withAlpha(8),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  kCyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverToBoxAdapter(
              child: GlassCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No AI calls recorded today.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Legend dot ────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

// ── App Health tab ────────────────────────────────────────────────────────────
class _AppHealthTab extends ConsumerWidget {
  const _AppHealthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(appMonitorServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final crashFree = monitor.crashFreeRate(days: 7);
    final sessions7 = monitor.sessionsInDays(7).length;
    final errors7 = monitor.errorCountInDays(7);
    final avgDur = monitor.avgSessionDuration;
    final recentAlerts = monitor.recentAlerts.take(10).toList();

    String durStr(Duration d) {
      if (d == Duration.zero) return '—';
      if (d.inMinutes < 1) return '${d.inSeconds}s';
      if (d.inHours < 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Row 1: crash-free % and avg session
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => kGradientTeal.createShader(b),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(crashFree * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'crash-free (7d)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => kGradientMain.createShader(b),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          durStr(avgDur),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'avg session',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
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
        // Row 2: errors and sessions
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => kGradientWarm.createShader(b),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$errors7',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'errors (7d)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => kGradientTeal.createShader(b),
                          child: const Icon(
                            Icons.phone_android_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$sessions7',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'sessions (7d)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
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
        // Crash-free progress bar
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Crash-free sessions',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '7-day window',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: crashFree,
                      minHeight: 10,
                      backgroundColor: isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(10),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        crashFree >= 0.95
                            ? kCyan
                            : (crashFree >= 0.8 ? kAmber : kCoral),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sessions7 == 0
                        ? 'No sessions recorded yet.'
                        : '$sessions7 session${sessions7 == 1 ? '' : 's'}, '
                              '$errors7 error${errors7 == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Recent alerts list
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverToBoxAdapter(
            child: recentAlerts.isEmpty
                ? GlassCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (b) =>
                                  kGradientTeal.createShader(b),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No alerts recorded',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Alerts',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recentAlerts.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: switch (e.type) {
                                      'fatal' => kCoral.withAlpha(40),
                                      'warning' => kCyan.withAlpha(40),
                                      _ => kAmber.withAlpha(40),
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    e.type.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: switch (e.type) {
                                        'fatal' => kCoral,
                                        'warning' => kCyan,
                                        _ => kAmber,
                                      },
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.message,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat(
                                          'MMM d, HH:mm',
                                        ).format(e.timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                        ),
                                      ),
                                    ],
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
      ],
    );
  }
}
