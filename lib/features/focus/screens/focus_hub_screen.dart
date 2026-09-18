import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ui_kit.dart';
import '../../../services/gamification_service.dart';
import '../../coach/widgets/achievements_sheet.dart';
import '../../planner/controllers/task_controller.dart';
import '../widgets/micro_wins_card.dart';
import 'focus_mode_screen.dart';

class FocusHubScreen extends ConsumerWidget {
  const FocusHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskControllerProvider);
    final profile = ref.watch(gamificationServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingTasks = tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final totalDeepWorkMinutes = tasks
        .where((t) => t.isCompleted && t.actualDurationMinutes != null)
        .fold<int>(0, (sum, t) => sum + t.actualDurationMinutes!);
    final deepWorkHours = (totalDeepWorkMinutes / 60.0).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: Column(
          children: [
            // Vibrant Header
            GradientHeader(
              gradient: kGradientNeonSunset,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Focus Hub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your deep work & flow command center',
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => AchievementsSheet.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: kElectricAmber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${profile.streakMultiplier.toStringAsFixed(1)}x XP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Flow Mastery Hero Card
                  VibrantGlassCard(
                    glowColor: kSunsetRose,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: kGradientCyberCyan,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.offline_bolt_rounded,
                                color: Color(0xFF0C0A1A),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Level ${profile.currentLevel} · ${profile.levelTitle}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '${profile.currentStreak}-day streak active · ${profile.streakMultiplier.toStringAsFixed(1)}x XP bonus',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => AchievementsSheet.show(context),
                              child: const Text('Badges →'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AnimatedXpBar(
                          progress: profile.levelProgress,
                          currentXp: profile.currentLevelXp,
                          maxXp: profile.currentLevelRange,
                          height: 9,
                          gradient: kGradientNeonSunset,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Context-Aware Micro-Wins
                  const MicroWinsCard(),

                  // Ready for Flow Section
                  const SectionLabel(
                    icon: Icons.flash_on_rounded,
                    label: 'READY FOR FLOW STATE',
                    color: kElectricAmber,
                  ),
                  const SizedBox(height: 12),
                  if (pendingTasks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.spa_rounded,
                              size: 40,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'All tasks conquered! Clean Slate achieved. 🎉',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...pendingTasks.take(5).map((t) {
                      final xpGain = t.priority == 2 ? 80 : 50;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: VibrantGlassCard(
                          glowColor: t.priority == 2 ? kSunsetRose : kCyan,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: (t.priority == 2 ? kCoral : kCyan)
                                      .withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.bolt_rounded,
                                  color: t.priority == 2 ? kCoral : kCyan,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          '${t.durationMinutes > 0 ? t.durationMinutes : 45} mins',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GlowBadge(
                                          label: '+$xpGain XP',
                                          color: kElectricAmber,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: const Text('Start'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kCoral,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FocusModeScreen(task: t),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),
                  const SectionLabel(
                    icon: Icons.bar_chart_rounded,
                    label: 'FLOW ANALYTICS',
                    color: kNeonCyan,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: VibrantGlassCard(
                          glowColor: kCyan,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tasks Completed',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${tasks.where((t) => t.isCompleted).length}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: kCyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: VibrantGlassCard(
                          glowColor: kIndigo,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deep Work Time',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${deepWorkHours}h',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: kIndigo,
                                ),
                              ),
                            ],
                          ),
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
}
