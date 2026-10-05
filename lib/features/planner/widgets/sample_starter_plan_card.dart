import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task_model.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/ui_kit.dart';
import '../controllers/task_controller.dart';

/// An interactive first-run onboarding starter card displayed on [PlannerScreen]
/// when the planner has no tasks, giving users an immediate demonstration of
/// circadian matching, deep work routing, and conflict-free scheduling.
class SampleStarterPlanCard extends ConsumerWidget {
  const SampleStarterPlanCard({super.key});

  void _loadSampleWorkday(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskCtrl = ref.read(taskControllerProvider.notifier);
    final settingsCtrl = ref.read(settingsProvider.notifier);
    final scheduler = ref.read(schedulerServiceProvider);
    final settings = ref.read(settingsProvider);

    final sampleTasks = [
      TaskItem(
        id: 'sample_deep_work',
        title: 'Strategic Architecture Review',
        startTime: DateTime(today.year, today.month, today.day, 9, 30),
        endTime: DateTime(today.year, today.month, today.day, 11, 30),
        priority: 3, // Urgent
        energyLevel: 'high',
        tags: const ['architecture', 'coding', 'strategy'],
        note: 'Deep focus block automatically aligned with morning circadian peak.',
      ),
      TaskItem(
        id: 'sample_sync_meeting',
        title: 'Quarterly Team Sync & Milestone Alignment',
        startTime: DateTime(today.year, today.month, today.day, 13, 0),
        endTime: DateTime(today.year, today.month, today.day, 14, 0),
        priority: 2, // High
        isFixed: true, // Fixed anchor
        tags: const ['meeting', 'sync'],
        note: 'Immutable calendar anchor: scheduler packs other tasks around this.',
      ),
      TaskItem(
        id: 'sample_shallow_triage',
        title: 'Customer Feedback & Inbox Triage',
        startTime: DateTime(today.year, today.month, today.day, 14, 15),
        endTime: DateTime(today.year, today.month, today.day, 15, 0),
        priority: 1, // Medium
        energyLevel: 'low',
        tags: const ['admin', 'email'],
        note: 'Low-energy administrative task scheduled during afternoon recovery dip.',
      ),
      TaskItem(
        id: 'sample_evening_reflection',
        title: 'Evening Shutdown & 1-Line Reflection',
        startTime: DateTime(today.year, today.month, today.day, 16, 30),
        endTime: DateTime(today.year, today.month, today.day, 17, 0),
        priority: 2, // High
        tags: const ['ritual', 'reflection'],
        note: 'Closing routine to reflect on micro-wins and prepare tomorrow.',
      ),
    ];

    // Optimize schedule using circadian intelligence
    final scheduledResult = scheduler.scheduleDayWithDetails(
      tasks: sampleTasks,
      day: today,
      workStartHour: settings.workStartHour,
      workHoursPerDay: settings.workHoursPerDay,
      chronotype: settings.chronotype,
    );

    final finalTasks =
        scheduledResult.scheduledTasks.length == sampleTasks.length
            ? scheduledResult.scheduledTasks
            : sampleTasks;

    taskCtrl.batchUpdateTasks(finalTasks);
    settingsCtrl.dismissStarterPlan();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16192E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kIndigo, width: 1.5),
        ),
        content: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: kCyan, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sample workday loaded! Explore your scheduled tasks and focus times.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsCtrl = ref.read(settingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kIndigo.withAlpha(isDark ? 45 : 25),
              const Color(0xFF7C3FFF).withAlpha(isDark ? 35 : 18),
              kCyan.withAlpha(isDark ? 25 : 12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: kIndigo.withAlpha(isDark ? 80 : 50),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: kIndigo.withAlpha(isDark ? 40 : 20),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kIndigo.withAlpha(isDark ? 60 : 35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: kCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                  const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to AutoPlanner AI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Smart Day Planner & Focus Assistant',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kCyan,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss starter pack',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    settingsCtrl.dismissStarterPlan();
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              'Your day is currently open. You can speak freely in Brain Dump, type tasks into the quick-add bar, or load a sample day to see how AutoPlanner works.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),

            const SizedBox(height: 14),

            // Feature Highlights
            _FeatureRow(
              icon: Icons.psychology_rounded,
              color: kCyan,
              title: 'Peak Energy Timing',
              subtitle: 'Important focus blocks scheduled when your energy is highest.',
            ),
            const SizedBox(height: 8),
            _FeatureRow(
              icon: Icons.shield_rounded,
              color: kIndigo,
              title: 'Locked Events',
              subtitle: 'Calendar meetings and fixed appointments stay locked in place.',
            ),
            const SizedBox(height: 8),
            _FeatureRow(
              icon: Icons.coffee_rounded,
              color: kAmber,
              title: 'Smart Breaks & Recovery',
              subtitle: 'Lighter administrative tasks scheduled during afternoon recovery periods.',
            ),

            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _loadSampleWorkday(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kIndigo,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text(
                      'Load Sample Plan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    settingsCtrl.dismissStarterPlan();
                  },
                  child: Text(
                    'Start Fresh',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
