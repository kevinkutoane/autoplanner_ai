import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task_model.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/ui_kit.dart';
import '../../planner/controllers/task_controller.dart';
import '../../calendar/controllers/calendar_controller.dart';

/// Autonomous proactive conflict anticipation card.
///
/// Detects direct collisions, tight transit buffers (<15m), deadline compressions,
/// and circadian energy mismatches before they disrupt the user's day, offering
/// 1-tap automated schedule resolution.
class ConflictAnticipationCard extends ConsumerStatefulWidget {
  const ConflictAnticipationCard({super.key});

  @override
  ConsumerState<ConflictAnticipationCard> createState() =>
      _ConflictAnticipationCardState();
}

class _ConflictAnticipationCardState
    extends ConsumerState<ConflictAnticipationCard> {
  bool _isExpanded = false;
  bool _isResolving = false;

  Future<void> _resolveConflict(ConflictResolutionAction action) async {
    setState(() => _isResolving = true);
    try {
      final tasks = ref.read(taskControllerProvider);
      final settings = ref.read(settingsProvider);
      final events = ref.read(calendarControllerProvider);
      final service = ref.read(conflictAnticipationServiceProvider);

      final result = service.applyResolution(
        action,
        tasks: tasks,
        workStartHour: settings.workStartHour,
        workHoursPerDay: settings.workHoursPerDay,
        calendarEvents: events,
        chronotypeId: settings.chronotype,
      );

      if (result.updatedTasks.isNotEmpty) {
        ref
            .read(taskControllerProvider.notifier)
            .batchUpdateTasks(result.updatedTasks);

        HapticFeedback.mediumImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: kNeonViolet.withAlpha(140),
                  width: 1,
                ),
              ),
              content: Row(
                children: [
                  const Icon(
                    Icons.auto_mode_rounded,
                    color: kNeonViolet,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Conflict resolved: ${action.label}',
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
        setState(() => _isResolving = false);
      }
    }
  }

  Future<void> _resolveAll(List<AnticipatedConflict> conflicts) async {
    setState(() => _isResolving = true);
    try {
      var currentTasks = List<TaskItem>.from(ref.read(taskControllerProvider));
      final settings = ref.read(settingsProvider);
      final events = ref.read(calendarControllerProvider);
      final service = ref.read(conflictAnticipationServiceProvider);
      final allUpdated = <String, TaskItem>{};

      for (final conflict in conflicts) {
        final res = service.applyResolution(
          conflict.resolutionAction,
          tasks: currentTasks,
          workStartHour: settings.workStartHour,
          workHoursPerDay: settings.workHoursPerDay,
          calendarEvents: events,
          chronotypeId: settings.chronotype,
        );
        for (final t in res.updatedTasks) {
          allUpdated[t.id] = t;
        }
        currentTasks = currentTasks.map((t) => allUpdated[t.id] ?? t).toList();
      }

      if (allUpdated.isNotEmpty) {
        ref
            .read(taskControllerProvider.notifier)
            .batchUpdateTasks(allUpdated.values.toList());

        HapticFeedback.heavyImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: kCyan.withAlpha(150),
                  width: 1,
                ),
              ),
              content: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: kCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All ${conflicts.length} schedule conflicts proactively resolved!',
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
        setState(() => _isResolving = false);
      }
    }
  }

  Color _severityColor(ConflictSeverity severity) {
    switch (severity) {
      case ConflictSeverity.critical:
        return kCoral;
      case ConflictSeverity.warning:
        return kAmber;
      case ConflictSeverity.advisory:
        return kIndigo;
    }
  }

  IconData _conflictIcon(ConflictType type) {
    switch (type) {
      case ConflictType.directOverlap:
        return Icons.layers_clear_rounded;
      case ConflictType.transitBufferCompression:
        return Icons.commute_rounded;
      case ConflictType.deadlineCompression:
        return Icons.timer_off_rounded;
      case ConflictType.circadianMismatch:
        return Icons.wb_twilight_rounded;
    }
  }

  String _conflictTypeLabel(ConflictType type) {
    switch (type) {
      case ConflictType.directOverlap:
        return 'Time Overlap';
      case ConflictType.transitBufferCompression:
        return 'Buffer <15m';
      case ConflictType.deadlineCompression:
        return 'Deadline Risk';
      case ConflictType.circadianMismatch:
        return 'Energy Zenith';
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = ref.watch(anticipatedConflictsProvider);
    if (conflicts.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCritical =
        conflicts.any((c) => c.severity == ConflictSeverity.critical);
    final accentColor = hasCritical ? kCoral : kAmber;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withAlpha(isDark ? 36 : 22),
                kIndigo.withAlpha(isDark ? 28 : 16),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withAlpha(isDark ? 90 : 60),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(isDark ? 40 : 20),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header Bar ──────────────────────────────────────────────
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(40),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withAlpha(100),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.radar_rounded,
                          color: accentColor,
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
                                  'Conflict Anticipation',
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withAlpha(45),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${conflicts.length}',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              conflicts.first.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 1-Tap Quick Action
                      if (!_isExpanded)
                        ElevatedButton.icon(
                          onPressed: _isResolving
                              ? null
                              : () => _resolveConflict(
                                    conflicts.first.resolutionAction,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isResolving
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.bolt_rounded, size: 14),
                          label: const Text(
                            'Resolve',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Expanded Conflict Details & Actions ─────────────────────
              if (_isExpanded) ...[
                const Divider(height: 1, thickness: 0.5, color: Colors.white24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    children: [
                      ...conflicts.map((conflict) {
                        final typeColor = _severityColor(conflict.severity);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.black.withAlpha(6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: typeColor.withAlpha(50),
                              width: 0.8,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _conflictIcon(conflict.type),
                                    size: 15,
                                    color: typeColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _conflictTypeLabel(conflict.type),
                                    style: TextStyle(
                                      color: typeColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    conflict.severity.name.toUpperCase(),
                                    style: TextStyle(
                                      color: typeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                conflict.description,
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white : Colors.black87,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      conflict.resolutionAction.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: _isResolving
                                        ? null
                                        : () => _resolveConflict(
                                              conflict.resolutionAction,
                                            ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: typeColor,
                                      side: BorderSide(
                                        color: typeColor.withAlpha(120),
                                        width: 1,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.auto_fix_high_rounded,
                                      size: 13,
                                    ),
                                    label: Text(
                                      conflict.resolutionAction.label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      if (conflicts.length > 1) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isResolving
                                ? null
                                : () => _resolveAll(conflicts),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kIndigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.done_all_rounded,
                              size: 16,
                            ),
                            label: Text(
                              'Auto-Resolve All (${conflicts.length})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
