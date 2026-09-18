import 'package:flutter/material.dart';
import '../../../core/models/task_model.dart';
import '../../../core/theme/ui_kit.dart';

/// An interactive, editable triage card for an extracted task.
/// Allows instant duration adjustment (15m/30m/45m/60m), priority cycling,
/// schedule slot visibility, and one-tap conversion to a Note.
class BrainDumpTaskTile extends StatelessWidget {
  final TaskItem task;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<int> onPriorityChanged;
  final VoidCallback? onConvertToNote;
  final String? scheduleFitMessage;
  final bool isClash;

  const BrainDumpTaskTile({
    super.key,
    required this.task,
    required this.selected,
    required this.onSelectedChanged,
    required this.onDurationChanged,
    required this.onPriorityChanged,
    this.onConvertToNote,
    this.scheduleFitMessage,
    this.isClash = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final duration = task.durationMinutes > 0 ? task.durationMinutes : 30;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: selected
            ? (isDark ? const Color(0xFF1E1F38) : Colors.white)
            : (isDark ? Colors.white.withAlpha(6) : Colors.black.withAlpha(4)),
        border: Border.all(
          color: selected
              ? (isClash ? kSunsetRose : kNeonCyan).withAlpha(isDark ? 90 : 70)
              : (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10)),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: (isClash ? kSunsetRose : kNeonCyan).withAlpha(isDark ? 40 : 25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Checkbox, Title, and Convert to Note action
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => onSelectedChanged(!selected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 2, right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? kNeonCyan : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? kNeonCyan
                          : (isDark ? Colors.white38 : Colors.black26),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Color(0xFF0F0F1E),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.white38 : Colors.black38),
                        decoration: selected ? null : TextDecoration.lineThrough,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Schedule slot & gap feasibility badge
                    if (scheduleFitMessage != null) ...[
                      Row(
                        children: [
                          Icon(
                            isClash
                                ? Icons.warning_amber_rounded
                                : Icons.schedule_rounded,
                            size: 12,
                            color: isClash ? kSunsetRose : kUltraEmerald,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            scheduleFitMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isClash ? kSunsetRose : kUltraEmerald,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),

              // Convert to Note quick button
              if (onConvertToNote != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Convert to Note',
                  icon: Icon(
                    Icons.note_alt_outlined,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  onPressed: onConvertToNote,
                ),
            ],
          ),

          // Row 2: Duration quick chips & Priority selector
          if (selected) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Duration:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(width: 8),
                ...[15, 30, 45, 60].map((mins) {
                  final isActive = duration == mins;
                  return GestureDetector(
                    onTap: () => onDurationChanged(mins),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isActive
                            ? kNeonCyan.withAlpha(isDark ? 50 : 35)
                            : (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(6)),
                        border: Border.all(
                          color: isActive
                              ? kNeonCyan
                              : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12)),
                          width: isActive ? 1.2 : 1,
                        ),
                      ),
                      child: Text(
                        '${mins}m',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                          color: isActive
                              ? (isDark ? kNeonCyan : const Color(0xFF00838F))
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),

                // Priority Badge / Cycle
                GestureDetector(
                  onTap: () => onPriorityChanged((task.priority + 1) % 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _priorityColor(task.priority).withAlpha(isDark ? 40 : 25),
                      border: Border.all(
                        color: _priorityColor(task.priority).withAlpha(120),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 11,
                          color: _priorityColor(task.priority),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.priorityLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _priorityColor(task.priority),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 3:
        return kSunsetRose;
      case 2:
        return kElectricAmber;
      case 1:
        return kNeonCyan;
      default:
        return Colors.blueGrey;
    }
  }
}
