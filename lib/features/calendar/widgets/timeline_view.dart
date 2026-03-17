import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/models/calendar_event_model.dart';
import '../../../core/utils/date_utils.dart';

/// Scrollable hourly timeline for a single day.
///
/// Events are positioned absolutely within their respective hour rows.
/// A "now" indicator line is drawn at the current time of day.
class TimelineView extends StatefulWidget {
  final DateTime selectedDate;
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent>? onEventTap;

  const TimelineView({
    super.key,
    required this.selectedDate,
    required this.events,
    this.onEventTap,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  static const _hourHeight = 64.0;
  static const _labelWidth = 52.0;
  static const _startHour = 0;
  static const _endHour = 24;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final isToday = isSameDay(widget.selectedDate, now);
    if (!isToday) return;
    final offset =
        (now.hour + now.minute / 60.0 - 1.5).clamp(0, 23) * _hourHeight;
    if (_scroll.hasClients) {
      _scroll.jumpTo(offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday = isSameDay(widget.selectedDate, now);
    final totalHeight = (_endHour - _startHour) * _hourHeight;

    // Filter events for this day
    final dayEvents = widget.events
        .where((e) => isSameDay(e.startTime, widget.selectedDate))
        .toList();

    return SingleChildScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      child: SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hour labels column
            SizedBox(
              width: _labelWidth,
              height: totalHeight,
              child: Stack(
                children: List.generate(_endHour - _startHour, (i) {
                  final hour = _startHour + i;
                  final label = hour == 0
                      ? '12 AM'
                      : hour < 12
                      ? '$hour AM'
                      : hour == 12
                      ? '12 PM'
                      : '${hour - 12} PM';
                  return Positioned(
                    top: i * _hourHeight,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 6),
                      child: Text(
                        label,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF9090A0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Event area
            Expanded(
              child: Stack(
                children: [
                  // Hour divider lines
                  ...List.generate(_endHour - _startHour, (i) {
                    return Positioned(
                      top: i * _hourHeight,
                      left: 0,
                      right: 0,
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withAlpha(18)
                            : Colors.black.withAlpha(10),
                      ),
                    );
                  }),

                  // Now line
                  if (isToday)
                    Positioned(
                      top: (now.hour + now.minute / 60.0) * _hourHeight,
                      left: 0,
                      right: 0,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: kCoral,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(height: 1.5, color: kCoral),
                          ),
                        ],
                      ),
                    ),

                  // Events
                  ..._buildEventBlocks(dayEvents, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEventBlocks(List<CalendarEvent> events, bool isDark) {
    final widgets = <Widget>[];

    // Detect overlapping events and assign column indices
    final columns = _layoutColumns(events);

    for (final entry in columns.entries) {
      final event = entry.key;
      final colInfo = entry.value; // {index, total}
      final colIndex = colInfo.$1;
      final colTotal = colInfo.$2;

      final startFraction =
          (event.startTime.hour + event.startTime.minute / 60.0) - _startHour;
      final endFraction =
          (event.endTime.hour + event.endTime.minute / 60.0) - _startHour;
      final top = startFraction * _hourHeight;
      final height = ((endFraction - startFraction) * _hourHeight).clamp(
        _hourHeight * 0.3,
        double.infinity,
      );

      final isConflict = event.syncStatus == 'conflict';
      final color = isConflict ? kCoral : Color(event.colorValue);

      widgets.add(
        Positioned(
          top: top + 2,
          left: colIndex == 0 ? 2 : colIndex * (1 / colTotal) * 1000 * 0.001,
          right: ((colTotal - colIndex - 1) / colTotal) * 2,
          height: height - 4,
          child: GestureDetector(
            onTap: () => widget.onEventTap?.call(event),
            child: Container(
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 60 : 40),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: color, width: 3)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isConflict) ...[
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: kCoral,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (height > 28)
                    Text(
                      DateFormat('h:mm a').format(event.startTime),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF6060A0),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  /// Simple greedy column layout for overlapping events.
  /// Returns a map of event → (columnIndex, totalColumns).
  Map<CalendarEvent, (int, int)> _layoutColumns(List<CalendarEvent> events) {
    final sorted = [...events]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Groups of overlapping events
    final groups = <List<CalendarEvent>>[];
    for (final e in sorted) {
      bool placed = false;
      for (final group in groups) {
        if (group.any((g) => _overlaps(g, e))) {
          group.add(e);
          placed = true;
          break;
        }
      }
      if (!placed) groups.add([e]);
    }

    final result = <CalendarEvent, (int, int)>{};
    for (final group in groups) {
      for (var i = 0; i < group.length; i++) {
        result[group[i]] = (i, group.length);
      }
    }
    return result;
  }

  bool _overlaps(CalendarEvent a, CalendarEvent b) =>
      a.startTime.isBefore(b.endTime) && b.startTime.isBefore(a.endTime);
}
