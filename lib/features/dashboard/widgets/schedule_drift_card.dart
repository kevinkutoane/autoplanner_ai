import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/ui_kit.dart';
import '../../planner/controllers/task_controller.dart';

/// Interactive dashboard banner that detects schedule drift (overrunning/late tasks)
/// and offers one-tap autonomous "Auto-Ripple" schedule healing.
class ScheduleDriftCard extends ConsumerStatefulWidget {
  const ScheduleDriftCard({super.key});

  @override
  ConsumerState<ScheduleDriftCard> createState() => _ScheduleDriftCardState();
}

class _ScheduleDriftCardState extends ConsumerState<ScheduleDriftCard> {
  bool _isExpanded = false;
  bool _isRippling = false;

  Future<void> _handleAutoRipple() async {
    setState(() => _isRippling = true);
    try {
      final tasks = ref.read(taskControllerProvider);
      final settings = ref.read(settingsProvider);
      final driftService = ref.read(scheduleDriftServiceProvider);
      final rippleResult = driftService.rippleReschedule(
        allTasks: tasks,
        workStartHour: settings.workStartHour,
        workHoursPerDay: settings.workHoursPerDay,
        currentTime: DateTime.now(),
        chronotype: settings.chronotype,
      );

      if (rippleResult.updatedTasks.isNotEmpty) {
        ref
            .read(taskControllerProvider.notifier)
            .batchUpdateTasks(rippleResult.updatedTasks);

        HapticFeedback.mediumImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: kCyan.withAlpha(120),
                  width: 1,
                ),
              ),
              content: Row(
                children: [
                  const Icon(
                    Icons.auto_fix_high_rounded,
                    color: kCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Schedule self-healed! ${rippleResult.updatedTasks.length} task${rippleResult.updatedTasks.length > 1 ? 's' : ''} smoothly rippled.',
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
      }
    } finally {
      if (mounted) {
        setState(() => _isRippling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final drift = ref.watch(scheduleDriftProvider);
    if (!drift.hasDrift) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeFmt = DateFormat('h:mm a');

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kAmber.withAlpha(isDark ? 36 : 28),
                kCoral.withAlpha(isDark ? 28 : 20),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: kAmber.withAlpha(isDark ? 100 : 80),
              width: 1.2,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kAmber.withAlpha(50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: kAmber.withAlpha(120),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: kAmber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Schedule Drift Detected',
                              style: TextStyle(
                                color: isDark ? Colors.white : kDark0,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kAmber.withAlpha(40),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+${drift.totalDriftMinutes}m',
                                style: const TextStyle(
                                  color: kAmber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${drift.driftedTasks.length} task${drift.driftedTasks.length > 1 ? 's' : ''} running behind planned start',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white60 : Colors.black54,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _isExpanded = !_isExpanded);
                    },
                    visualDensity: VisualDensity.compact,
                    tooltip: _isExpanded ? 'Collapse' : 'View drifted tasks',
                  ),
                ],
              ),

              // Expanded task list
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withAlpha(60)
                        : Colors.white.withAlpha(80),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: drift.driftedTasks.map((task) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: kCoral.withAlpha(200),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : kDark0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              'was ${timeFmt.format(task.startTime)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Action Bar: 1-Tap Auto-Ripple Button
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _isRippling ? null : _handleAutoRipple,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kCoral,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isRippling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Auto-Ripple Schedule',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  if (drift.nextFixedAnchor != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message:
                          'Protected Fixed Anchor: ${drift.nextFixedAnchor!.title} at ${timeFmt.format(drift.nextFixedAnchor!.startTime)}',
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: kCyan.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: kCyan.withAlpha(80),
                          ),
                        ),
                        child: const Icon(
                          Icons.anchor_rounded,
                          color: kCyan,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
