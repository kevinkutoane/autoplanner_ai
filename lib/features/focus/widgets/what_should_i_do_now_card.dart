import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/core/theme/ui_kit.dart';
import 'package:autoplanner_ai/features/focus/controllers/focus_controller.dart';
import 'package:autoplanner_ai/features/focus/models/focus_recommendation.dart';
import 'package:autoplanner_ai/features/focus/providers/focus_recommendation_provider.dart';
import 'package:autoplanner_ai/features/focus/screens/focus_mode_screen.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';

/// Hero action card answering "What should I do right now?"
///
/// Prominently displays the optimal current or upcoming task and provides a 1-tap
/// gateway into [FocusModeScreen].
class WhatShouldIDoNowCard extends ConsumerWidget {
  const WhatShouldIDoNowCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendation = ref.watch(focusRecommendationProvider);
    final focusState = ref.watch(focusControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (recommendation == null) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kEmerald.withAlpha(isDark ? 40 : 25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: kEmerald,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Caught Up!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No pending tasks right now. Great time for deep rest or brain dump.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final task = recommendation.task;
    final isFocusingThis =
        focusState.task?.id == task.id && !focusState.isFinished;

    Color badgeColor;
    switch (recommendation.type) {
      case RecommendationType.activeNow:
        badgeColor = kIndigo;
        break;
      case RecommendationType.upcomingSoon:
        badgeColor = kAmber;
        break;
      case RecommendationType.highestPriority:
        badgeColor = kRose;
        break;
      case RecommendationType.energyMatch:
        badgeColor = kEmerald;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  badgeColor.withAlpha(45),
                  const Color(0xFF1E1E2E).withAlpha(200),
                ]
              : [badgeColor.withAlpha(25), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: badgeColor.withAlpha(isDark ? 80 : 50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withAlpha(isDark ? 40 : 20),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header pill & category
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(isDark ? 50 : 35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: badgeColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          recommendation.typeBadge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (task.energyLevel != null) ...[
                    Flexible(
                      child: Text(
                        task.energyLevel == 'high'
                            ? '⚡ High Energy'
                            : task.energyLevel == 'medium'
                            ? '🔋 Medium Energy'
                            : '🌱 Low Energy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Title & Subtitle
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                recommendation.subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  // Start / Resume Focus CTA
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [badgeColor, badgeColor.withAlpha(200)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withAlpha(100),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          isFocusingThis
                              ? (focusState.isPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.timer_outlined)
                              : Icons.center_focus_strong_rounded,
                          size: 20,
                        ),
                        label: Text(
                          isFocusingThis
                              ? (focusState.isPaused
                                    ? 'Resume Focus'
                                    : 'Open Focus Mode')
                              : 'Start Focus (${task.durationMinutes}m)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          if (!isFocusingThis) {
                            ref
                                .read(focusControllerProvider.notifier)
                                .startSession(task);
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FocusModeScreen(task: task),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Quick complete button
                  IconButton.filledTonal(
                    tooltip: 'Mark Completed',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(10),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.check_rounded,
                      color: kEmerald,
                      size: 22,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final completed = task.copyWith(
                        isCompleted: true,
                        completedAt: DateTime.now(),
                        actualDurationMinutes: task.durationMinutes,
                      );
                      ref
                          .read(taskControllerProvider.notifier)
                          .updateTask(completed);
                    },
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
