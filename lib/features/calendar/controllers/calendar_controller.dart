import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/models/calendar_event_model.dart';
import '../../../core/models/task_model.dart';

class CalendarController extends StateNotifier<List<CalendarEvent>> {
  Box<CalendarEvent>? _box;

  CalendarController() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<CalendarEvent>('calendarBox');
    _refreshState();
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return state.where((event) {
      return event.startTime.year == day.year &&
          event.startTime.month == day.month &&
          event.startTime.day == day.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<CalendarEvent> getUpcomingEvents({int days = 7}) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return state.where((event) {
      return event.startTime.isAfter(now) && event.startTime.isBefore(cutoff);
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void addEvent(CalendarEvent event) {
    if (_box == null) return;
    _box!.put(event.id, event);
    _refreshState();
  }

  void updateEvent(CalendarEvent event) {
    if (_box == null) return;
    _box!.put(event.id, event);
    _refreshState();
  }

  void deleteEvent(String id) {
    if (_box == null) return;
    _box!.delete(id);
    _refreshState();
  }

  /// Sync tasks to calendar as events
  void syncTasksToCalendar(List<TaskItem> tasks) {
    if (_box == null) return;

    // Remove old task-linked events
    final taskEventIds = state
        .where((e) => e.linkedTaskId != null)
        .map((e) => e.id)
        .toList();
    for (final id in taskEventIds) {
      _box!.delete(id);
    }

    // Add current tasks as events
    for (final task in tasks) {
      final event = CalendarEvent(
        id: 'task_${task.id}',
        title: task.title,
        description: task.note,
        startTime: task.startTime,
        endTime: task.endTime ?? task.startTime.add(const Duration(hours: 1)),
        source: 'local',
        linkedTaskId: task.id,
        colorValue: _priorityToColor(task.priority),
      );
      _box!.put(event.id, event);
    }

    _refreshState();
  }

  int _priorityToColor(int priority) {
    switch (priority) {
      case 0:
        return 0xFF9E9E9E;
      case 1:
        return 0xFF00D4AA;
      case 2:
        return 0xFFFF6B6B;
      case 3:
        return 0xFFFF4444;
      default:
        return 0xFF6C63FF;
    }
  }

  void _refreshState() {
    state = _box!.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}

final calendarControllerProvider =
    StateNotifierProvider<CalendarController, List<CalendarEvent>>(
      (ref) => CalendarController(),
    );
