import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../planner/controllers/task_controller.dart';
import '../../goals/controllers/goal_controller.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Generates a markdown weekly review. Auto-disposes so each visit re-fetches.
final weeklyReviewProvider = FutureProvider.autoDispose<String>((ref) async {
  final aiService = ref.watch(aiServiceProvider);
  final tasks = ref.watch(taskControllerProvider);
  final goals = ref.watch(goalControllerProvider);
  final memoryService = ref.watch(memoryServiceProvider);

  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));

  final weekTasks = tasks
      .where((t) => t.startTime.isAfter(weekAgo) && t.startTime.isBefore(now))
      .toList();
  final weekGoals = goals
      .where((g) => g.createdAt.isAfter(weekAgo) && g.createdAt.isBefore(now))
      .toList();
  final memories = memoryService.recentMemories.take(8).toList();

  final result = await aiService.generateWeeklyReview(
    weekTasks: weekTasks,
    weekGoals: weekGoals,
    memories: memories,
  );
  return result ??
      'No review generated. Please check your AI settings and try again.';
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class WeeklyReviewScreen extends ConsumerWidget {
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(weeklyReviewProvider);
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 6));
    final rangeLabel =
        '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d, yyyy').format(now)}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────
            SliverToBoxAdapter(
              child: GradientHeader(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A0040), Color(0xFF1A1040), kIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weekly Review',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rangeLabel,
                            style: TextStyle(
                              color: Colors.white.withAlpha(160),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    reviewAsync.when(
                      data: (_) => Row(
                        children: [
                          _HeaderButton(
                            icon: Icons.copy_rounded,
                            tooltip: 'Copy review',
                            onTap: () =>
                                _copyToClipboard(context, reviewAsync.value!),
                          ),
                          const SizedBox(width: 8),
                          _HeaderButton(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Regenerate',
                            onTap: () => ref.invalidate(weeklyReviewProvider),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => _HeaderButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Retry',
                        onTap: () => ref.invalidate(weeklyReviewProvider),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverToBoxAdapter(
                child: reviewAsync.when(
                  loading: () => const _ReviewSkeleton(),
                  error: (err, _) => _ErrorCard(
                    message: err.toString(),
                    onRetry: () => ref.invalidate(weeklyReviewProvider),
                  ),
                  data: (text) => _ReviewCard(text: text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Review copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ── Subwidgets ─────────────────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String text;
  const _ReviewCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Split on markdown headings (##) to render sections with visual hierarchy
    final sections = _parseSections(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections.map((section) {
        if (section.heading != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        section.heading!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (section.body.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      section.body,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: isDark
                            ? Colors.white.withAlpha(210)
                            : Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        // Plain text block
        if (section.body.trim().isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            child: Text(
              section.body,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: isDark ? Colors.white.withAlpha(210) : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<_Section> _parseSections(String text) {
    final lines = text.split('\n');
    final sections = <_Section>[];
    String? currentHeading;
    final bodyLines = <String>[];

    void flush() {
      if (currentHeading != null || bodyLines.isNotEmpty) {
        sections.add(
          _Section(heading: currentHeading, body: bodyLines.join('\n').trim()),
        );
      }
      currentHeading = null;
      bodyLines.clear();
    }

    for (final line in lines) {
      if (line.startsWith('## ') || line.startsWith('### ')) {
        flush();
        currentHeading = line.replaceFirst(RegExp(r'^#{2,3} '), '');
      } else if (line.startsWith('# ')) {
        // Skip top-level title — already shown in header
      } else {
        bodyLines.add(line);
      }
    }
    flush();
    return sections;
  }
}

class _Section {
  final String? heading;
  final String body;
  const _Section({this.heading, required this.body});
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = isDark
        ? Colors.white.withAlpha(20)
        : Colors.black.withAlpha(12);
    return Column(
      children:
          List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      3,
                      (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: shimmer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          })..add(
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Generating your weekly review…',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: kCoral, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Failed to generate review',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: kCoral),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
