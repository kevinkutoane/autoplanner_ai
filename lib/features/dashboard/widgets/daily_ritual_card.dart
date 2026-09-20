import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ui_kit.dart';
import '../../../services/gamification_service.dart';
import 'morning_kickoff_sheet.dart';
import 'evening_shutdown_sheet.dart';

class DailyRitualCard extends ConsumerWidget {
  const DailyRitualCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final hour = now.hour;
    final isEvening = hour >= 17; // After 5 PM
    final profile = ref.watch(gamificationServiceProvider);

    // Check if ritual already completed today
    final isMorningCompleted =
        profile.lastMorningRitualDate != null &&
        profile.lastMorningRitualDate!.year == now.year &&
        profile.lastMorningRitualDate!.month == now.month &&
        profile.lastMorningRitualDate!.day == now.day;

    final isEveningCompleted =
        profile.lastEveningRitualDate != null &&
        profile.lastEveningRitualDate!.year == now.year &&
        profile.lastEveningRitualDate!.month == now.month &&
        profile.lastEveningRitualDate!.day == now.day;

    if (isEvening && isEveningCompleted) {
      return const SizedBox.shrink();
    }
    if (!isEvening && isMorningCompleted && hour < 17) {
      return const SizedBox.shrink();
    }

    final title = isEvening ? 'Evening Shutdown' : 'Morning Kickoff';
    final subtitle = isEvening
        ? 'Reflect on wins, clear lingering tasks, and earn +50 XP.'
        : 'Set today’s Big 3 priorities and activate your attack plan.';
    final icon = isEvening ? Icons.bedtime_rounded : Icons.wb_sunny_rounded;
    final gradient = isEvening ? kGradientMidnightGlow : kGradientNeonSunset;
    final glowColor = isEvening ? kNeonCyan : kSunsetRose;

    return VibrantGlassCard(
      glowColor: glowColor,
      padding: const EdgeInsets.all(18),
      onTap: () {
        if (isEvening) {
          EveningShutdownSheet.show(context);
        } else {
          MorningKickoffSheet.show(context);
        }
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withAlpha(80),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const GlowBadge(label: '+50 XP', color: kElectricAmber),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}
