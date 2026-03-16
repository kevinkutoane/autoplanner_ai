import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';

// ── Test helper ──────────────────────────────────────────────────────────────

CalendarEvent _event({
  String id = 'e1',
  String title = 'Test Event',
  String? description,
  DateTime? startTime,
  DateTime? endTime,
  String source = 'local',
  String? linkedTaskId,
  int colorValue = 0xFF4CAF50,
  bool isAllDay = false,
  String? externalId,
  String? externalCalendarId,
  String syncStatus = 'local',
  String? etag,
  DateTime? lastSyncedAt,
}) {
  final now = DateTime(2026, 3, 12, 9, 0);
  return CalendarEvent(
    id: id,
    title: title,
    description: description,
    startTime: startTime ?? now,
    endTime: endTime ?? now.add(const Duration(hours: 1)),
    source: source,
    linkedTaskId: linkedTaskId,
    colorValue: colorValue,
    isAllDay: isAllDay,
    externalId: externalId,
    externalCalendarId: externalCalendarId,
    syncStatus: syncStatus,
    etag: etag,
    lastSyncedAt: lastSyncedAt,
  );
}

// ── Suite ─────────────────────────────────────────────────────────────────────

void main() {
  final base = DateTime(2026, 3, 12, 9, 0);

  // ── Constructor defaults ─────────────────────────────────────────────────
  group('CalendarEvent constructor defaults', () {
    test('source defaults to "local"', () {
      expect(_event().source, 'local');
    });

    test('colorValue defaults to 0xFF4CAF50 (Material green 500)', () {
      expect(_event().colorValue, 0xFF4CAF50);
    });

    test('isAllDay defaults to false', () {
      expect(_event().isAllDay, isFalse);
    });

    test('syncStatus defaults to "local"', () {
      expect(_event().syncStatus, 'local');
    });

    test('description defaults to null', () {
      expect(_event().description, isNull);
    });

    test('linkedTaskId defaults to null', () {
      expect(_event().linkedTaskId, isNull);
    });

    test('externalId defaults to null', () {
      expect(_event().externalId, isNull);
    });

    test('externalCalendarId defaults to null', () {
      expect(_event().externalCalendarId, isNull);
    });

    test('etag defaults to null', () {
      expect(_event().etag, isNull);
    });

    test('lastSyncedAt defaults to null', () {
      expect(_event().lastSyncedAt, isNull);
    });

    test('id and title are stored correctly', () {
      final e = _event(id: 'abc', title: 'Dentist');
      expect(e.id, 'abc');
      expect(e.title, 'Dentist');
    });

    test('startTime and endTime are preserved', () {
      final start = base;
      final end = base.add(const Duration(hours: 2));
      final e = _event(startTime: start, endTime: end);
      expect(e.startTime, start);
      expect(e.endTime, end);
    });
  });

  // ── Constructor with explicit values ─────────────────────────────────────
  group('CalendarEvent explicit values', () {
    test('source google is stored', () {
      expect(_event(source: 'google').source, 'google');
    });

    test('source outlook is stored', () {
      expect(_event(source: 'outlook').source, 'outlook');
    });

    test('custom colorValue is stored', () {
      expect(_event(colorValue: 0xFF2196F3).colorValue, 0xFF2196F3);
    });

    test('isAllDay = true is stored', () {
      expect(_event(isAllDay: true).isAllDay, isTrue);
    });

    test('syncStatus "synced" is stored', () {
      expect(_event(syncStatus: 'synced').syncStatus, 'synced');
    });

    test('syncStatus "pending_push" is stored', () {
      expect(_event(syncStatus: 'pending_push').syncStatus, 'pending_push');
    });

    test('syncStatus "conflict" is stored', () {
      expect(_event(syncStatus: 'conflict').syncStatus, 'conflict');
    });

    test('externalId is stored', () {
      expect(_event(externalId: 'goog_123').externalId, 'goog_123');
    });

    test('etag is stored', () {
      expect(_event(etag: '"abc123"').etag, '"abc123"');
    });

    test('lastSyncedAt is stored', () {
      final t = DateTime(2026, 1, 1);
      expect(_event(lastSyncedAt: t).lastSyncedAt, t);
    });

    test('description is stored', () {
      expect(_event(description: 'Team meeting').description, 'Team meeting');
    });

    test('linkedTaskId is stored', () {
      expect(_event(linkedTaskId: 'task_1').linkedTaskId, 'task_1');
    });
  });

  // ── copyWith ─────────────────────────────────────────────────────────────
  group('CalendarEvent.copyWith', () {
    test('copyWith returns a new instance', () {
      final original = _event(id: 'orig');
      final copy = original.copyWith(title: 'Updated');
      expect(copy.title, 'Updated');
      expect(original.title, 'Test Event');
    });

    test('copyWith preserves unchanged fields', () {
      final original = _event(source: 'google', colorValue: 0xFF2196F3);
      final copy = original.copyWith(title: 'New Title');
      expect(copy.source, 'google');
      expect(copy.colorValue, 0xFF2196F3);
    });

    test('copyWith can update syncStatus to "synced"', () {
      final e = _event(syncStatus: 'local');
      final synced = e.copyWith(syncStatus: 'synced');
      expect(synced.syncStatus, 'synced');
    });

    test('copyWith can update syncStatus to "conflict"', () {
      final e = _event(syncStatus: 'pending_push');
      final conflict = e.copyWith(syncStatus: 'conflict');
      expect(conflict.syncStatus, 'conflict');
    });

    test('copyWith can set externalId', () {
      final e = _event();
      final linked = e.copyWith(externalId: 'google_99');
      expect(linked.externalId, 'google_99');
    });

    test('copyWith can set etag', () {
      final e = _event();
      final withEtag = e.copyWith(etag: '"newEtag"');
      expect(withEtag.etag, '"newEtag"');
    });

    test('copyWith can update startTime and endTime', () {
      final e = _event(
        startTime: base,
        endTime: base.add(const Duration(hours: 1)),
      );
      final newStart = base.add(const Duration(hours: 2));
      final newEnd = base.add(const Duration(hours: 3));
      final updated = e.copyWith(startTime: newStart, endTime: newEnd);
      expect(updated.startTime, newStart);
      expect(updated.endTime, newEnd);
    });

    test('copyWith can mark event as all-day', () {
      final e = _event(isAllDay: false);
      final allDay = e.copyWith(isAllDay: true);
      expect(allDay.isAllDay, isTrue);
    });

    test('copyWith can link to a task', () {
      final e = _event();
      final linked = e.copyWith(linkedTaskId: 'task_42');
      expect(linked.linkedTaskId, 'task_42');
    });

    test('copyWith can set lastSyncedAt', () {
      final e = _event();
      final t = DateTime(2026, 3, 1);
      final synced = e.copyWith(lastSyncedAt: t);
      expect(synced.lastSyncedAt, t);
    });
  });
}
