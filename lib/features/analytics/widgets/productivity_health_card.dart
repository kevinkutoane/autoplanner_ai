import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/core/theme/ui_kit.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';

/// Displays Schedule Accuracy Index, Planning Debt, and learned category multipliers.
class ProductivityHealthCard extends ConsumerWidget {
  const ProductivityHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accuracy = ref.watch(scheduleAccuracyProvider);
    final debtMinutes = ref.watch(planningDebtProvider);
    final calibrations = ref.watch(categoryCalibrationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color accuracyColor;
    if (accuracy >= 80) {
      accuracyColor = kEmerald;
    } else if (accuracy >= 60) {
      accuracyColor = kAmber;
    } else {
      accuracyColor = kCoral;
    }

    final activeCalibrations = calibrations.values
        .where(
          (c) =>
              c.sampleCount >= DurationLearningService.minSamplesForConfidence,
        )
        .toList();

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kIndigo.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: kIndigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Intelligence & Health',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Adaptive learning from actual execution',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2-Metric Grid: Accuracy vs Planning Debt
          Row(
            children: [
              // Schedule Accuracy
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accuracyColor.withAlpha(isDark ? 25 : 15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accuracyColor.withAlpha(50),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color: accuracyColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Accuracy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accuracyColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${accuracy.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        accuracy >= 75
                            ? 'Well calibrated'
                            : 'Learning your pace',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Planning Debt
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: debtMinutes == 0
                        ? kEmerald.withAlpha(isDark ? 25 : 15)
                        : kAmber.withAlpha(isDark ? 25 : 15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: debtMinutes == 0
                          ? kEmerald.withAlpha(50)
                          : kAmber.withAlpha(50),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timelapse_rounded,
                            size: 14,
                            color: debtMinutes == 0 ? kEmerald : kAmber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Planning Debt',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: debtMinutes == 0 ? kEmerald : kAmber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        debtMinutes == 0 ? '0m' : '${debtMinutes}m',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        debtMinutes == 0 ? 'Zero debt' : 'Overdue rolled over',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Category Calibrations Tag Bar (if available)
          if (activeCalibrations.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Learned Category Offsets:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: activeCalibrations.map((c) {
                final isOver = c.percentageDelta > 0;
                final chipColor = isOver ? kAmber : kCyan;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withAlpha(isDark ? 30 : 20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: chipColor.withAlpha(60),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '#${c.tag}: ${c.deltaDisplay}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: chipColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
