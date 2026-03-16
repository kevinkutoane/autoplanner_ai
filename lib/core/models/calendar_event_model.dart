import 'package:hive/hive.dart';

part 'calendar_event_model.g.dart';

/// A calendar event stored in the Hive `calendarBox` (typeId 2).
///
/// Events may be created locally, synced from Google Calendar, or synced
/// from Microsoft Outlook. The [syncStatus] field tracks the lifecycle of
/// each event through the bidirectional sync pipeline.
@HiveType(typeId: 2)
class CalendarEvent extends HiveObject {
  /// Unique local identifier (UUID v4).
  @HiveField(0)
  String id;

  /// Short display title shown in the calendar and timeline views.
  @HiveField(1)
  String title;

  /// Optional longer description; may be pulled from the provider.
  @HiveField(2)
  String? description;

  /// When the event begins.
  @HiveField(3)
  DateTime startTime;

  /// When the event ends.
  @HiveField(4)
  DateTime endTime;

  /// Origin of this event: `'local'`, `'google'`, or `'outlook'`.
  @HiveField(5)
  String source;

  /// ID of a linked [TaskItem], or null if not associated with a task.
  @HiveField(6)
  String? linkedTaskId;

  /// ARGB colour for the event chip (defaults to Material green 500).
  @HiveField(7)
  int colorValue;

  /// True when the event spans the entire day (no specific start/end time).
  @HiveField(8)
  bool isAllDay;

  // ── Sync fields (M3-B) ──────────────────────────────────────

  /// The ID from the external calendar provider (Google / Outlook).
  @HiveField(9)
  String? externalId;

  /// The ID of the external calendar (e.g. Google Calendar list ID).
  @HiveField(10)
  String? externalCalendarId;

  /// Sync lifecycle: 'local' | 'synced' | 'pending_push' | 'conflict'.
  @HiveField(11)
  String syncStatus;

  /// The etag returned by the provider, used for conflict detection.
  @HiveField(12)
  String? etag;

  /// When the event was last successfully synced with the provider.
  @HiveField(13)
  DateTime? lastSyncedAt;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.source = 'local',
    this.linkedTaskId,
    this.colorValue = 0xFF4CAF50,
    this.isAllDay = false,
    this.externalId,
    this.externalCalendarId,
    this.syncStatus = 'local',
    this.etag,
    this.lastSyncedAt,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? source,
    String? linkedTaskId,
    int? colorValue,
    bool? isAllDay,
    String? externalId,
    String? externalCalendarId,
    String? syncStatus,
    String? etag,
    DateTime? lastSyncedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      source: source ?? this.source,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      colorValue: colorValue ?? this.colorValue,
      isAllDay: isAllDay ?? this.isAllDay,
      externalId: externalId ?? this.externalId,
      externalCalendarId: externalCalendarId ?? this.externalCalendarId,
      syncStatus: syncStatus ?? this.syncStatus,
      etag: etag ?? this.etag,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
