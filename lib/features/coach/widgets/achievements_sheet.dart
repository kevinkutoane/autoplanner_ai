import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/gamification_model.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../services/gamification_service.dart';

class AchievementsSheet extends ConsumerWidget {
  const AchievementsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(120),
      builder: (_) => const AchievementsSheet(),
    );
  }

  IconData _resolveIcon(String name) {
    switch (name) {
      case 'wb_sunny_rounded':
        return Icons.wb_sunny_rounded;
      case 'scuba_diving_rounded':
        return Icons.pool_rounded;
      case 'local_fire_department_rounded':
        return Icons.local_fire_department_rounded;
      case 'military_tech_rounded':
        return Icons.military_tech_rounded;
      case 'task_alt_rounded':
        return Icons.task_alt_rounded;
      case 'lightbulb_circle_rounded':
        return Icons.lightbulb_circle_rounded;
      case 'bedtime_rounded':
        return Icons.bedtime_rounded;
      case 'auto_awesome_rounded':
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(gamificationServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allBadges = kBadgeCatalog.values.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollCtrl) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: isDark
                  ? const Color(0xFF0F0E1E).withAlpha(240)
                  : Colors.white.withAlpha(245),
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: kGradientNeonSunset,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Achievements & Trophies',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : kDark0,
                              ),
                            ),
                            Text(
                              'Level ${profile.currentLevel} · ${profile.levelTitle}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: kElectricAmber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Progress Card
                  VibrantGlassCard(
                    glowColor: kNeonViolet,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL SCORE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            Text(
                              '${profile.totalXp} XP',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: kCyan,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AnimatedXpBar(
                          progress: profile.levelProgress,
                          currentXp: profile.currentLevelXp,
                          maxXp: profile.currentLevelRange,
                          height: 10,
                          gradient: kGradientNeonSunset,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _MiniStat(
                              label: 'Current Streak',
                              value: '${profile.currentStreak} days',
                              icon: Icons.local_fire_department_rounded,
                              color: kCoral,
                            ),
                            _MiniStat(
                              label: 'Multiplier',
                              value:
                                  '${profile.streakMultiplier.toStringAsFixed(1)}x XP',
                              icon: Icons.bolt_rounded,
                              color: kElectricAmber,
                            ),
                            _MiniStat(
                              label: 'Unlocked',
                              value:
                                  '${profile.unlockedBadgeIds.length}/${allBadges.length}',
                              icon: Icons.military_tech_rounded,
                              color: kUltraEmerald,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'BADGES & MILESTONES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...allBadges.map((badge) {
                    final isUnlocked = profile.unlockedBadgeIds.contains(
                      badge.id,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isUnlocked
                              ? (isDark
                                    ? Colors.white.withAlpha(15)
                                    : Colors.white)
                              : (isDark
                                    ? Colors.white.withAlpha(6)
                                    : Colors.black.withAlpha(4)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUnlocked
                                ? kElectricAmber.withAlpha(100)
                                : (isDark
                                      ? Colors.white.withAlpha(16)
                                      : Colors.black12),
                            width: isUnlocked ? 1.2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isUnlocked
                                    ? kGradientNeonSunset
                                    : null,
                                color: isUnlocked
                                    ? null
                                    : (isDark
                                          ? Colors.white12
                                          : Colors.black12),
                              ),
                              child: Icon(
                                _resolveIcon(badge.iconName),
                                color: isUnlocked
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white38
                                          : Colors.black38),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        badge.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isUnlocked
                                              ? (isDark ? Colors.white : kDark0)
                                              : (isDark
                                                    ? Colors.white54
                                                    : Colors.black45),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isUnlocked)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: kUltraEmerald.withAlpha(30),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Text(
                                            'UNLOCKED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: kUltraEmerald,
                                            ),
                                          ),
                                        )
                                      else
                                        Text(
                                          '+${badge.xpReward} XP',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black38,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    badge.description,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : kDark0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
