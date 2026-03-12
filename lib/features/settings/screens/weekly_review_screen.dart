import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../../features/planner/controllers/task_controller.dart';
import '../../../features/notes/controllers/note_controller.dart';
import '../../../features/memory/controllers/memory_controller.dart';

class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  String? _review;
  bool _loading = false;
  bool _generated = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _review = null;
    });

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final cutoff = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final allTasks = ref.read(taskControllerProvider);
    final allNotes = ref.read(noteControllerProvider);
    final memories = ref.read(memoryControllerProvider);

    final weekTasks = allTasks
        .where((t) => !t.startTime.isBefore(cutoff))
        .toList();
    final weekNotes = allNotes
        .where((n) => !n.createdAt.isBefore(cutoff))
        .toList();

    final ai = ref.read(aiServiceProvider);
    final result = await ai.generateWeeklyReview(
      weekTasks: weekTasks,
      weekNotes: weekNotes,
      memories: memories,
    );

    if (!mounted) return;
    setState(() {
      _review = result;
      _loading = false;
      _generated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(weekEnd)}';

    final allTasks = ref.watch(taskControllerProvider);
    final cutoff = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekTasks = allTasks
        .where((t) => !t.startTime.isBefore(cutoff))
        .toList();
    final completed = weekTasks.where((t) => t.isCompleted).length;
    final total = weekTasks.length;
    final rate = total > 0 ? (completed / total * 100).round() : 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Header ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: GradientHeader(
                gradient: const LinearGradient(
                  colors: [kDark0, Color(0xFF0E1B30)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (b) => kGradientWarm.createShader(b),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Weekly Review',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      weekLabel,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Stats row ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Stagger(
                  index: 0,
                  child: Row(
                    children: [
                      _StatCard(
                        label: 'Total Tasks',
                        value: '$total',
                        icon: Icons.task_alt_rounded,
                        gradient: kGradientMain,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Completed',
                        value: '$completed',
                        icon: Icons.check_circle_rounded,
                        gradient: kGradientTeal,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Rate',
                        value: '$rate%',
                        icon: Icons.trending_up_rounded,
                        gradient: kGradientWarm,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Generate / Review content ───────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              sliver: SliverToBoxAdapter(
                child: _generated && _review != null
                    ? Stagger(
                        index: 1,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  8,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (b) =>
                                          kGradientWarm.createShader(b),
                                      child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'AI Review',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 16,
                                        color: Colors.white54,
                                      ),
                                      tooltip: 'Copy',
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: _review!),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Review copied'),
                                            behavior: SnackBarBehavior.floating,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                        color: Colors.white54,
                                      ),
                                      tooltip: 'Regenerate',
                                      onPressed: _loading ? null : _generate,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: _MarkdownText(
                                  text: _review!,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _loading
                    ? Stagger(
                        index: 1,
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (b) =>
                                      kGradientWarm.createShader(b),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Generating your review…',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const LinearProgressIndicator(),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Stagger(
                        index: 1,
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (b) =>
                                      kGradientWarm.createShader(b),
                                  child: const Icon(
                                    Icons.bar_chart_rounded,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  total == 0
                                      ? 'No tasks this week yet.\nAdd some tasks first!'
                                      : 'Get an AI-powered summary of your week — what went well, patterns noticed, and tips for next week.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (total > 0)
                                  ElevatedButton.icon(
                                    onPressed: _generate,
                                    icon: const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Generate Review'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      backgroundColor: kIndigo,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final LinearGradient gradient;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient.colors.map((c) => c.withAlpha(40)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (b) => gradient.createShader(b),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Simple markdown renderer (bold + bullets only) ────────────────────────────
class _MarkdownText extends StatelessWidget {
  final String text;
  final bool isDark;
  const _MarkdownText({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // Section header: **text**
        if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
          final content = line.substring(2, line.length - 2);
          return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(
              content,
              style: TextStyle(
                color: isDark ? Colors.white : kDark0,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        // Inline **bold** inside line
        final styled = _buildInlineSpans(line, isDark);
        if (styled != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: RichText(text: TextSpan(children: styled)),
          );
        }
        // Bullet
        if (line.startsWith('- ') || line.startsWith('* ')) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: kCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF2A2A3A),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        // Blank line
        if (line.trim().isEmpty) return const SizedBox(height: 6);
        // Plain text
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            line,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF2A2A3A),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  List<InlineSpan>? _buildInlineSpans(String line, bool isDark) {
    if (!line.contains('**')) return null;
    final base = TextStyle(
      color: isDark ? Colors.white70 : const Color(0xFF2A2A3A),
      fontSize: 14,
      height: 1.5,
    );
    final bold = base.copyWith(
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : kDark0,
    );
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int pos = 0;
    for (final m in regex.allMatches(line)) {
      if (m.start > pos) {
        spans.add(TextSpan(text: line.substring(pos, m.start), style: base));
      }
      spans.add(TextSpan(text: m.group(1), style: bold));
      pos = m.end;
    }
    if (pos < line.length) {
      spans.add(TextSpan(text: line.substring(pos), style: base));
    }
    return spans;
  }
}
