import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/ui_kit.dart';
import 'plan_my_week_sheet.dart';

/// 7-day workload capacity visualizer displaying meeting vs task allocations,
/// daily capacity thresholds, and quick access to autonomous multi-day planning.
class WeeklyCapacityHeatmap extends ConsumerWidget {
  const WeeklyCapacityHeatmap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDate = ref.watch(plannerSelectedDateProvider);

    // Compute start of current week (Monday)
    final mondayOffset = (selectedDate.weekday - DateTime.monday) % 7;
    final weekStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).subtract(Duration(days: mondayOffset));

    final summaries = ref.watch(weeklyCapacitySummaryProvider(weekStart));
    final debtReport = ref.watch(weeklyPlanningDebtReportProvider);

    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateRangeLabel =
        '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(weekEnd)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16192E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kIndigo.withAlpha(isDark ? 45 : 25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.view_week_rounded,
                    color: kIndigo,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Capacity Intelligence',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        dateRangeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Plan Week button
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showPlanMyWeekSheet(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kIndigo, const Color(0xFF7C3FFF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kIndigo.withAlpha(70),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Plan Week',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 7-Day Capacity Columns
            Row(
              children: summaries.map((summary) {
                final isSelected =
                    summary.date.year == selectedDate.year &&
                    summary.date.month == selectedDate.month &&
                    summary.date.day == selectedDate.day;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(plannerSelectedDateProvider.notifier)
                          .set(summary.date);
                    },
                    child: _DayCapacityColumn(
                      summary: summary,
                      isSelected: isSelected,
                      isDark: isDark,
                    ),
                  ),
                );
              }).toList(),
            ),

            // Planning debt notice footer if applicable
            if (debtReport.debtIndex > 20) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kCoral.withAlpha(isDark ? 28 : 16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kCoral.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: kCoral,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Planning Debt: ${debtReport.debtIndex.toStringAsFixed(0)}/100 (${debtReport.overdueTasks.length} overdue, ${debtReport.zombieTasks.length} zombie tasks)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kCoral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayCapacityColumn extends StatelessWidget {
  final DailyCapacitySummary summary;
  final bool isSelected;
  final bool isDark;

  const _DayCapacityColumn({
    required this.summary,
    required this.isSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color barColor;
    switch (summary.status) {
      case DailyCapacityStatus.overloaded:
        barColor = kCoral;
        break;
      case DailyCapacityStatus.nearCapacity:
        barColor = kAmber;
        break;
      case DailyCapacityStatus.optimal:
        barColor = kCyan;
        break;
      case DailyCapacityStatus.underloaded:
        barColor = kIndigo;
        break;
    }

    final dayName = DateFormat('E').format(summary.date);
    final dayNum = summary.date.day.toString();
    final fillRatio = summary.capacityRatio.clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? kIndigo.withAlpha(isDark ? 60 : 35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? kIndigo : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            dayName.substring(0, 1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? kIndigo
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dayNum,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(height: 6),

          // Vertical capacity bar
          Container(
            height: 48,
            width: 8,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fillRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),
          Text(
            '${(summary.capacityRatio * 100).toInt()}%',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}
