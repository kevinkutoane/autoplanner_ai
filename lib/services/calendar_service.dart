import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../core/models/calendar_event_model.dart';
import '../core/models/task_model.dart';

class CalendarService {
  Box<CalendarEvent>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<CalendarEvent>('calendarBox');
  }

  List<CalendarEvent> get allEvents => _box?.values.toList() ?? [];

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return allEvents.where((event) {
      return event.startTime.year == day.year &&
          event.startTime.month == day.month &&
          event.startTime.day == day.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<CalendarEvent> getEventsInRange(DateTime start, DateTime end) {
    return allEvents.where((event) {
      return event.startTime.isAfter(start.subtract(const Duration(days: 1))) &&
          event.startTime.isBefore(end.add(const Duration(days: 1)));
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> addEvent(CalendarEvent event) async {
    await _box?.put(event.id, event);
  }

  Future<void> updateEvent(CalendarEvent event) async {
    await _box?.put(event.id, event);
  }

  Future<void> deleteEvent(String id) async {
    await _box?.delete(id);
  }

  /// Create calendar events from tasks for a unified view
  List<CalendarEvent> taskToEvents(List<TaskItem> tasks) {
    return tasks.map((task) {
      return CalendarEvent(
        id: 'task_${task.id}',
        title: task.title,
        description: task.note,
        startTime: task.startTime,
        endTime: task.endTime ?? task.startTime.add(const Duration(hours: 1)),
        source: 'local',
        linkedTaskId: task.id,
        colorValue: _priorityToColor(task.priority),
      );
    }).toList();
  }

  int _priorityToColor(int priority) {
    switch (priority) {
      case 0:
        return 0xFF9E9E9E; // grey
      case 1:
        return 0xFF00D4AA; // cyan
      case 2:
        return 0xFFFF6B6B; // orange-red
      case 3:
        return 0xFFFF4444; // red
      default:
        return 0xFF6C63FF; // indigo
    }
  }

  // ─── Google Calendar Integration Stub ───────────────────────────────

  Future<List<CalendarEvent>> fetchGoogleCalendarEvents() async {
    // TODO: Implement Google Calendar API integration
    // Requires: googleapis, googleapis_auth packages
    // Setup: Google Cloud Console -> Calendar API -> OAuth 2.0
    return [];
  }

  Future<void> syncToGoogleCalendar(CalendarEvent event) async {
    // TODO: Push event to Google Calendar
  }

  // ─── Microsoft Outlook Integration Stub ─────────────────────────────

  Future<List<CalendarEvent>> fetchOutlookEvents() async {
    // TODO: Implement Microsoft Graph API integration
    // Requires: microsoft_graph package or REST API
    // Setup: Azure AD App Registration -> Calendar permissions
    return [];
  }

  Future<void> syncToOutlook(CalendarEvent event) async {
    // TODO: Push event to Outlook Calendar
  }
}

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});
