import '../core/models/calendar_event_model.dart';

/// A pair of overlapping calendar events.
class ConflictPair {
  final CalendarEvent a;
  final CalendarEvent b;
  const ConflictPair(this.a, this.b);
}

/// Detects scheduling conflicts and sync conflicts in calendar events.
class ConflictDetector {
  /// Finds all pairs of events that overlap in time on the same day.
  /// Excludes all-day events from time-overlap detection.
  List<ConflictPair> detectTimeOverlaps(List<CalendarEvent> events) {
    final timed = events.where((e) => !e.isAllDay).toList();
    final conflicts = <ConflictPair>[];
    for (var i = 0; i < timed.length; i++) {
      for (var j = i + 1; j < timed.length; j++) {
        final a = timed[i];
        final b = timed[j];
        if (_overlaps(a, b)) {
          conflicts.add(ConflictPair(a, b));
        }
      }
    }
    return conflicts;
  }

  /// Returns all events whose syncStatus is 'conflict'.
  List<CalendarEvent> detectSyncConflicts(List<CalendarEvent> events) {
    return events.where((e) => e.syncStatus == 'conflict').toList();
  }

  bool _overlaps(CalendarEvent a, CalendarEvent b) {
    // Events overlap if one starts before the other ends.
    return a.startTime.isBefore(b.endTime) && b.startTime.isBefore(a.endTime);
  }
}
