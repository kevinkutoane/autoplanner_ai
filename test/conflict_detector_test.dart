import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/services/conflict_detector.dart';

CalendarEvent _event({
  required String id,
  required DateTime start,
  required DateTime end,
  String syncStatus = 'local',
  bool isAllDay = false,
}) => CalendarEvent(
  id: id,
  title: 'Event $id',
  startTime: start,
  endTime: end,
  syncStatus: syncStatus,
  isAllDay: isAllDay,
);

void main() {
  late ConflictDetector detector;

  // Fixed reference time.
  final base = DateTime(2025, 6, 1, 9, 0);

  setUp(() => detector = ConflictDetector());

  // ── detectTimeOverlaps ─────────────────────────────────────────────────────
  group('ConflictDetector.detectTimeOverlaps', () {
    test('returns empty for empty list', () {
      expect(detector.detectTimeOverlaps([]), isEmpty);
    });

    test('returns empty for a single event', () {
      final events = [
        _event(id: '1', start: base, end: base.add(const Duration(hours: 1))),
      ];
      expect(detector.detectTimeOverlaps(events), isEmpty);
    });

    test('detects two fully overlapping events', () {
      final events = [
        _event(id: '1', start: base, end: base.add(const Duration(hours: 2))),
        _event(id: '2', start: base, end: base.add(const Duration(hours: 2))),
      ];
      final conflicts = detector.detectTimeOverlaps(events);
      expect(conflicts, hasLength(1));
      expect(conflicts.first.a.id, '1');
      expect(conflicts.first.b.id, '2');
    });

    test('detects partial overlap (A starts before B ends)', () {
      // A: 09:00 – 10:30
      // B: 10:00 – 11:00  → overlap 10:00–10:30
      final events = [
        _event(
          id: 'A',
          start: base,
          end: base.add(const Duration(minutes: 90)),
        ),
        _event(
          id: 'B',
          start: base.add(const Duration(hours: 1)),
          end: base.add(const Duration(hours: 2)),
        ),
      ];
      final conflicts = detector.detectTimeOverlaps(events);
      expect(conflicts, hasLength(1));
    });

    test('no conflict when events are back-to-back (A.end == B.start)', () {
      // A: 09:00 – 10:00
      // B: 10:00 – 11:00  → touching but not overlapping
      final events = [
        _event(id: 'A', start: base, end: base.add(const Duration(hours: 1))),
        _event(
          id: 'B',
          start: base.add(const Duration(hours: 1)),
          end: base.add(const Duration(hours: 2)),
        ),
      ];
      expect(detector.detectTimeOverlaps(events), isEmpty);
    });

    test('no conflict when events are sequential with a gap', () {
      final events = [
        _event(id: 'A', start: base, end: base.add(const Duration(hours: 1))),
        _event(
          id: 'B',
          start: base.add(const Duration(hours: 2)),
          end: base.add(const Duration(hours: 3)),
        ),
      ];
      expect(detector.detectTimeOverlaps(events), isEmpty);
    });

    test('detects multiple conflicts in a list of several events', () {
      // A: 09:00–11:00, B: 10:00–12:00, C: 13:00–14:00
      // A overlaps B; B does not overlap C; A does not overlap C → 1 conflict
      final events = [
        _event(id: 'A', start: base, end: base.add(const Duration(hours: 2))),
        _event(
          id: 'B',
          start: base.add(const Duration(hours: 1)),
          end: base.add(const Duration(hours: 3)),
        ),
        _event(
          id: 'C',
          start: base.add(const Duration(hours: 4)),
          end: base.add(const Duration(hours: 5)),
        ),
      ];
      expect(detector.detectTimeOverlaps(events), hasLength(1));
    });

    test('all-day events are excluded from time-overlap detection', () {
      final events = [
        _event(
          id: 'allDay',
          start: base,
          end: base.add(const Duration(hours: 8)),
          isAllDay: true,
        ),
        _event(
          id: 'timed',
          start: base,
          end: base.add(const Duration(hours: 1)),
        ),
      ];
      // Only 'timed' participates; no pair → no conflict.
      expect(detector.detectTimeOverlaps(events), isEmpty);
    });

    test('three mutually overlapping events produce three conflict pairs', () {
      // A: 09–11, B: 10–12, C: 09:30–10:30  → A∩B, A∩C, B∩C = 3 pairs
      final events = [
        _event(id: 'A', start: base, end: base.add(const Duration(hours: 2))),
        _event(
          id: 'B',
          start: base.add(const Duration(hours: 1)),
          end: base.add(const Duration(hours: 3)),
        ),
        _event(
          id: 'C',
          start: base.add(const Duration(minutes: 30)),
          end: base.add(const Duration(minutes: 90)),
        ),
      ];
      expect(detector.detectTimeOverlaps(events), hasLength(3));
    });
  });

  // ── detectSyncConflicts ────────────────────────────────────────────────────
  group('ConflictDetector.detectSyncConflicts', () {
    test('returns empty for empty list', () {
      expect(detector.detectSyncConflicts([]), isEmpty);
    });

    test('returns only events with syncStatus == conflict', () {
      final events = [
        _event(
          id: '1',
          start: base,
          end: base.add(const Duration(hours: 1)),
          syncStatus: 'synced',
        ),
        _event(
          id: '2',
          start: base,
          end: base.add(const Duration(hours: 1)),
          syncStatus: 'conflict',
        ),
        _event(
          id: '3',
          start: base,
          end: base.add(const Duration(hours: 1)),
          syncStatus: 'pending_push',
        ),
        _event(
          id: '4',
          start: base,
          end: base.add(const Duration(hours: 1)),
          syncStatus: 'conflict',
        ),
      ];

      final conflicts = detector.detectSyncConflicts(events);
      expect(conflicts, hasLength(2));
      expect(conflicts.map((e) => e.id), containsAll(['2', '4']));
    });

    test('returns empty when no event has conflict status', () {
      final events = [
        _event(
          id: '1',
          start: base,
          end: base.add(const Duration(hours: 1)),
          syncStatus: 'local',
        ),
        _event(
          id: '2',
          start: base,
          end: base.add(const Duration(hours: 1)),
          syncStatus: 'synced',
        ),
      ];
      expect(detector.detectSyncConflicts(events), isEmpty);
    });
  });
}
