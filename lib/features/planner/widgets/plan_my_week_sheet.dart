import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/ui_kit.dart';
import '../../calendar/controllers/calendar_controller.dart';
import '../controllers/task_controller.dart';

/// Shows the Plan My Week interactive bottom sheet modal.
Future<void> showPlanMyWeekSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PlanMyWeekSheet(),
  );
}

class PlanMyWeekSheet extends ConsumerStatefulWidget {
  const PlanMyWeekSheet({super.key});

  @override
  ConsumerState<PlanMyWeekSheet> createState() => _PlanMyWeekSheetState();
}

class _PlanMyWeekSheetState extends ConsumerState<PlanMyWeekSheet> {
  int _daysCount = 5; // 5-day work week default (Mon-Fri) or 7-day
  bool _includeMidweekRecovery = true;
  bool _isPlanning = false;
  WeeklyScheduleResult? _previewResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _computePreview();
    });
  }

  DateTime _getWeekStart() {
    final now = DateTime.now();
    final mondayOffset = (now.weekday - DateTime.monday) % 7;
    return DateTime(now.year, now.month, now.day).subtract(
      Duration(days: mondayOffset),
    );
  }

  void _computePreview() {
    final allTasks = ref.read(taskControllerProvider);
    final calendarEvents = ref.read(calendarControllerProvider);
    final settings = ref.read(settingsProvider);
    final weeklyService = ref.read(weeklyPlannerServiceProvider);

    final weekStart = _getWeekStart();

    WeeklyScheduleResult result;
    if (_includeMidweekRecovery && DateTime.now().weekday > DateTime.monday) {
      result = weeklyService.replanWeek(
        allTasks: allTasks,
        currentDay: DateTime.now(),
        daysCount: _daysCount,
        workStartHour: settings.workStartHour,
        workHoursPerDay: settings.workHoursPerDay,
        calendarEvents: calendarEvents,
        chronotype: settings.chronotype,
      );
    } else {
      result = weeklyService.planWeek(
        tasks: allTasks,
        weekStart: weekStart,
        daysCount: _daysCount,
        workStartHour: settings.workStartHour,
        workHoursPerDay: settings.workHoursPerDay,
        calendarEvents: calendarEvents,
        chronotype: settings.chronotype,
      );
    }

    if (mounted) {
      setState(() {
        _previewResult = result;
      });
    }
  }

  Future<void> _applyWeeklyPlan() async {
    if (_previewResult == null) return;

    setState(() => _isPlanning = true);
    HapticFeedback.mediumImpact();

    try {
      final taskCtrl = ref.read(taskControllerProvider.notifier);
      final tasksToUpdate = _previewResult!.allScheduledTasks;

      if (tasksToUpdate.isNotEmpty) {
        taskCtrl.batchUpdateTasks(tasksToUpdate);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16192E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: kIndigo, width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: kCyan, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Week planned! Balanced ${tasksToUpdate.length} tasks across $_daysCount days.',
                    style: const TextStyle(
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
    } finally {
      if (mounted) {
        setState(() => _isPlanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weekStart = _getWeekStart();
    final weekEnd = weekStart.add(Duration(days: _daysCount - 1));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F111E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 28,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kIndigo, const Color(0xFF7C3FFF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Autonomous Weekly Planner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(weekEnd)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Config Controls Row
                Row(
                  children: [
                    // 5-Day vs 7-Day choice
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_daysCount != 5) {
                                    setState(() => _daysCount = 5);
                                    _computePreview();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _daysCount == 5
                                        ? kIndigo
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '5-Day Work Week',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _daysCount == 5
                                          ? Colors.white
                                          : (isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_daysCount != 7) {
                                    setState(() => _daysCount = 7);
                                    _computePreview();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _daysCount == 7
                                        ? kIndigo
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '7-Day Full Week',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _daysCount == 7
                                          ? Colors.white
                                          : (isDark ? Colors.white60 : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Mid-week recovery toggle
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _includeMidweekRecovery,
                  activeThumbColor: kCyan,
                  title: const Text(
                    'Mid-Week Adaptive Recovery',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Automatically rolls uncompleted slipped tasks from past days into open capacity.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _includeMidweekRecovery = val);
                    _computePreview();
                  },
                ),

                const SizedBox(height: 16),

                // Preview Metrics Card
                if (_previewResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16192E) : const Color(0xFFF6F8FF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: kIndigo.withAlpha(isDark ? 60 : 30),
                      ),
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
                                const Text(
                                  'Workload Balance Score',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${_previewResult!.balanceScore.toStringAsFixed(0)}/100',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: kCyan,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _previewResult!.balanceScore >= 80
                                          ? '✨ Harmonious'
                                          : (_previewResult!.balanceScore >= 60
                                              ? '⚖️ Balanced'
                                              : '⚠️ High Variance'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: kIndigo.withAlpha(30),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_previewResult!.allScheduledTasks.length} Tasks Scheduled',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: kIndigo,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Text(
                          'Daily Distribution',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Day by day distribution bars
                        ..._previewResult!.dailySummaries.map((daySummary) {
                          final dayTasks = _previewResult!.dayAllocations[daySummary.date] ?? [];
                          final dayName = DateFormat('EEEE, MMM d').format(daySummary.date);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    dayName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: daySummary.capacityRatio.clamp(0.0, 1.0),
                                      minHeight: 8,
                                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        daySummary.status == DailyCapacityStatus.overloaded
                                            ? kCoral
                                            : (daySummary.status == DailyCapacityStatus.nearCapacity
                                                ? kAmber
                                                : kCyan),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${dayTasks.length} tasks (${(daySummary.scheduledTasksMinutes / 60).toStringAsFixed(1)}h)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  // Intelligent planning notices
                  if (_previewResult!.notices.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'AI Balancing Insights',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ..._previewResult!.notices.take(4).map((notice) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withAlpha(8)
                              : Colors.black.withAlpha(5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: notice.type == 'meeting_heavy'
                                ? kAmber.withAlpha(60)
                                : kCyan.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              notice.type == 'meeting_heavy'
                                  ? Icons.event_busy_rounded
                                  : Icons.lightbulb_outline_rounded,
                              color: notice.type == 'meeting_heavy' ? kAmber : kCyan,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                notice.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white.withAlpha(220)
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isPlanning ? null : _applyWeeklyPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kIndigo,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isPlanning
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Confirm & Balance Week',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
