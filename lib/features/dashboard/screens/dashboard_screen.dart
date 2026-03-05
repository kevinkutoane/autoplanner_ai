import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../planner/controllers/task_controller.dart';
import '../../notes/controllers/note_controller.dart';
import '../../calendar/controllers/calendar_controller.dart';
import '../../memory/controllers/memory_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

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
      final aiService = ref.read(aiServiceProvider);
      final insight = await aiService.generateDailyInsight(tasks, memories);
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

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskControllerProvider);
    final notes = ref.watch(noteControllerProvider);
    final events = ref.watch(calendarControllerProvider);
    final memories = ref.watch(memoryControllerProvider);

    final now = DateTime.now();
    final todayTasks = tasks.where((t) {
      return t.startTime.year == now.year &&
          t.startTime.month == now.month &&
          t.startTime.day == now.day;
    }).toList();
    final completedCount = todayTasks.where((t) => t.isCompleted).length;
    final greeting = _getGreeting();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Hero Header ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
                bottom: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMM d').format(now),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // AI Insight Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.psychology,
                          color: AppTheme.accentCyan,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _loadingInsight
                              ? const Text(
                                  'Analyzing your day...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              : Text(
                                  _dailyInsight ??
                                      'Start adding tasks to get personalized insights!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Stats Row ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatCard(
                    icon: Icons.task_alt,
                    label: 'Tasks',
                    value: '$completedCount/${todayTasks.length}',
                    color: AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.note_alt,
                    label: 'Notes',
                    value: '${notes.length}',
                    color: AppTheme.accentIndigo,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.calendar_month,
                    label: 'Events',
                    value: '${events.length}',
                    color: AppTheme.accentOrange,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.psychology,
                    label: 'Memories',
                    value: '${memories.length}',
                    color: AppTheme.accentYellow,
                  ),
                ],
              ),
            ),
          ),

          // ─── Today's Tasks ──────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: "Today's Tasks",
              trailing: todayTasks.isNotEmpty
                  ? '${(completedCount / todayTasks.length * 100).toInt()}%'
                  : null,
            ),
          ),
          if (todayTasks.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptyState(
                icon: Icons.task_alt,
                message: 'No tasks yet. Tap + on the Plan tab to start!',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final task = todayTasks[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.priorityColor(task.priority),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('hh:mm a').format(task.startTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: task.isCompleted
                              ? Colors.grey
                              : AppTheme.textSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          task.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: task.isCompleted
                              ? AppTheme.accentCyan
                              : AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          ref
                              .read(taskControllerProvider.notifier)
                              .toggleComplete(task.id);
                        },
                      ),
                    ),
                  ),
                );
              }, childCount: todayTasks.length > 5 ? 5 : todayTasks.length),
            ),

          // ─── Recent Notes ───────────────────────────────────────
          const SliverToBoxAdapter(
            child: _SectionHeader(title: 'Recent Notes'),
          ),
          if (notes.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptyState(
                icon: Icons.note_alt,
                message: 'No notes yet. Capture your first idea!',
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: notes.length > 5 ? 5 : notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      child: Card(
                        child: Padding(
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
                                        Icons.push_pin,
                                        size: 14,
                                        color: AppTheme.accentOrange,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      note.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  note.summary ?? note.content,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (note.tags.isNotEmpty)
                                Wrap(
                                  spacing: 4,
                                  children: note.tags.take(2).map((tag) {
                                    return Chip(
                                      label: Text(tag),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
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

          // ─── Memory Insights ────────────────────────────────────
          if (memories.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'Memory Insights'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: memories.take(3).map((m) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _sourceIcon(m.sourceType),
                                size: 18,
                                color: AppTheme.accentIndigo,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  m.content,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData _sourceIcon(String sourceType) {
    switch (sourceType) {
      case 'task':
        return Icons.task_alt;
      case 'note':
        return Icons.note_alt;
      case 'calendar':
        return Icons.calendar_month;
      default:
        return Icons.psychology;
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  color: AppTheme.accentCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 40, color: AppTheme.textSecondary.withAlpha(80)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
