import '../core/models/task_model.dart';
import '../features/settings/models/app_settings_model.dart';
import 'notification_service.dart';

/// Intelligently schedules morning briefing notifications based on the user's
/// task patterns and settings.
///
/// The scheduler analyses tomorrow's tasks to determine the optimal briefing
/// time — typically 30 minutes before the first scheduled task, clamped to
/// a reasonable window (06:00–09:00 by default).
///
/// Usage:
/// ```dart
/// final scheduler = SmartNotificationScheduler(NotificationService());
/// await scheduler.recalculate(tasks: tasks, settings: settings);
/// ```
class SmartNotificationScheduler {
  final NotificationService _notifications;

  SmartNotificationScheduler(this._notifications);

  /// The minimum hour for a morning briefing (inclusive).
  static const int _minHour = 5;

  /// The maximum hour for a morning briefing (inclusive).
  static const int _maxHour = 9;

  /// Minutes before the first task to fire the briefing.
  static const int _leadMinutes = 30;

  /// Recalculates and reschedules the morning briefing based on current
  /// tasks and user settings.
  ///
  /// If [settings.morningBriefingEnabled] is false, cancels any existing
  /// briefing. Otherwise, determines the optimal time from tomorrow's tasks
  /// and schedules accordingly.
  Future<void> recalculate({
    required List<TaskItem> tasks,
    required AppSettings settings,
  }) async {
    if (!settings.morningBriefingEnabled) {
      await _notifications.cancelMorningBriefing();
      return;
    }

    // Use the user's configured time unless it's the default (08:00),
    // in which case we auto-calculate from tomorrow's first task.
    final isDefaultTime =
        settings.morningBriefingHour == 8 && settings.morningBriefingMinute == 0;

    if (!isDefaultTime) {
      // User has explicitly set a custom time — respect it.
      await _notifications.scheduleMorningBriefing(
        hour: settings.morningBriefingHour,
        minute: settings.morningBriefingMinute,
        body: _buildBriefingBody(tasks),
      );
      return;
    }

    // Otherwise, auto-calculate from tomorrow's first task.
    final optimalTime = _calculateOptimalTime(tasks);
    await _notifications.scheduleMorningBriefing(
      hour: optimalTime.hour,
      minute: optimalTime.minute,
      body: _buildBriefingBody(tasks),
    );
  }

  /// Determines the optimal briefing time based on tomorrow's first task.
  ///
  /// Logic:
  /// 1. Find the earliest non-completed task scheduled for tomorrow.
  /// 2. Subtract [_leadMinutes] to give the user prep time.
  /// 3. Clamp the result to [_minHour]–[_maxHour] range.
  /// 4. If no tasks tomorrow, default to 07:30.
  _TimeOfDay _calculateOptimalTime(List<TaskItem> tasks) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dayAfter = DateTime(now.year, now.month, now.day + 2);

    // Find tomorrow's earliest incomplete task.
    TaskItem? earliest;
    for (final t in tasks) {
      if (t.isCompleted) continue;
      if (t.startTime.isAfter(tomorrow) && t.startTime.isBefore(dayAfter)) {
        if (earliest == null || t.startTime.isBefore(earliest.startTime)) {
          earliest = t;
        }
      }
    }

    if (earliest == null) {
      // No tasks tomorrow — default to 07:30.
      return const _TimeOfDay(7, 30);
    }

    // Subtract lead time.
    final briefingTime =
        earliest.startTime.subtract(Duration(minutes: _leadMinutes));
    var hour = briefingTime.hour;
    var minute = briefingTime.minute;

    // Clamp to reasonable window.
    if (hour < _minHour) {
      hour = _minHour;
      minute = 0;
    } else if (hour > _maxHour) {
      hour = _maxHour;
      minute = 0;
    }

    return _TimeOfDay(hour, minute);
  }

  /// Builds a contextual body line for the morning briefing notification.
  String _buildBriefingBody(List<TaskItem> tasks) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dayAfter = DateTime(now.year, now.month, now.day + 2);

    final tomorrowTasks = tasks.where((t) =>
        !t.isCompleted &&
        t.startTime.isAfter(tomorrow) &&
        t.startTime.isBefore(dayAfter));

    final count = tomorrowTasks.length;
    if (count == 0) return 'No tasks scheduled. Enjoy your day!';

    final urgent = tomorrowTasks.where((t) => t.priority >= 3).length;
    if (urgent > 0) {
      return '$count task${count == 1 ? '' : 's'} tomorrow ($urgent urgent). Tap to review.';
    }
    return '$count task${count == 1 ? '' : 's'} tomorrow. Tap to review your plan.';
  }
}

class _TimeOfDay {
  final int hour;
  final int minute;
  const _TimeOfDay(this.hour, this.minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
