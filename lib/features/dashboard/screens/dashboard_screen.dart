import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../planner/controllers/task_controller.dart';
import '../../notes/controllers/note_controller.dart';
import '../../notes/screens/note_editor_screen.dart';
import '../../calendar/controllers/calendar_controller.dart';
import '../../memory/controllers/memory_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final void Function(int tabIndex) onNavigateTo;
  const DashboardScreen({super.key, required this.onNavigateTo});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _dailyInsight;
  bool _loadingInsight = false;

  @override
  void initState() {
    super.initState();
    _loadDailyInsight();
  }

  Future<void> _loadDailyInsight() async {
    setState(() => _loadingInsight = true);
    try {
      final tasks = ref.read(taskControllerProvider);
      final memories = ref.read(memoryControllerProvider);
      final ai = ref.read(aiServiceProvider);
      final insight = await ai.generateDailyInsight(tasks, memories);
      if (mounted) {
        setState(() {
          _dailyInsight = insight;
          _loadingInsight = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInsight = false);
    }
  }

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
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskControllerProvider);
    final notes = ref.watch(noteControllerProvider);
    final events = ref.watch(calendarControllerProvider);
    final memories = ref.watch(memoryControllerProvider);
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayTasks = tasks.where((t) => isSameDay(t.startTime, now)).toList();
    final completedCount = todayTasks.where((t) => t.isCompleted).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
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
                        _AIPulseIcon(
                          loading: _loadingInsight,
                          onTap: _loadDailyInsight,
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
                                child: _loadingInsight
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          _ShimmerLine(width: 200),
                                          SizedBox(height: 6),
                                          _ShimmerLine(width: 140),
                                        ],
                                      )
                                    : Text(
                                        _dailyInsight ??
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
                        icon: Icons.sticky_note_2_rounded,
                        label: 'Notes',
                        value: '${notes.length}',
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
                    ],
                  ),
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
                        ? null
                        : '${(completedCount / todayTasks.length * 100).toInt()}% · See all',
                    onTrailingTap: () => widget.onNavigateTo(1),
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
                      message: 'No tasks yet. Tap + on the Plan tab to start!',
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) {
                    final task = todayTasks[i];
                    return Stagger(
                      index: i + 2,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => widget.onNavigateTo(1),
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
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    decoration: task.isCompleted
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : null,
                                                    color: task.isCompleted
                                                        ? (isDark
                                                              ? Colors.white38
                                                              : Colors.black38)
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
                                                            : Colors.black26,
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
                  }, childCount: todayTasks.length > 5 ? 5 : todayTasks.length),
                ),
              ),

            // ── Recent notes ────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Stagger(
                  index: 4,
                  child: BodySectionHeader(
                    title: 'Recent Notes',
                    trailing: notes.isEmpty ? null : 'See all',
                    onTrailingTap: notes.isEmpty
                        ? null
                        : () => widget.onNavigateTo(2),
                  ),
                ),
              ),
            ),
            if (notes.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Stagger(
                    index: 5,
                    child: EmptyState(
                      icon: Icons.sticky_note_2_rounded,
                      message: 'No notes yet. Capture your first idea!',
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Stagger(
                  index: 5,
                  child: SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: notes.length > 5 ? 5 : notes.length,
                      itemBuilder: (ctx, i) {
                        final note = notes[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NoteEditorScreen(note: note),
                            ),
                          ),
                          child: Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (note.isPinned)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.push_pin_rounded,
                                            size: 13,
                                            color: kCoral,
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          note.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: Text(
                                      note.summary ?? note.content,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF7C7C8A),
                                        height: 1.4,
                                      ),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
