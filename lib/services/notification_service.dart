import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/models/task_model.dart';
import '../core/models/note_model.dart';
import '../core/models/goal_model.dart';

/// Wraps flutter_local_notifications.
/// Call [init] once at app startup (after Hive, before runApp).
/// Then call [scheduleTaskReminder] / [cancelTaskReminder] from TaskController,
/// [scheduleNoteReminder] / [cancelNoteReminder] from NoteController, and
/// [scheduleGoalDeadlineReminder] / [cancelGoalDeadlineReminder] from GoalController.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // ── Channel IDs ──────────────────────────────────────────────────────────

  static const _channelId = 'autoplanner_tasks';
  static const _channelName = 'Task Reminders';
  static const _channelDesc = 'Reminders shown before scheduled tasks begin';
  static const _reminderMinutesBefore = 10;

  static const _urgentChannelId = 'autoplanner_urgent';
  static const _urgentChannelName = 'Urgent Alerts';
  static const _urgentChannelDesc =
      'Immediate alerts for urgent tasks and notes';

  static const _briefingChannelId = 'autoplanner_briefing';
  static const _briefingChannelName = 'Morning Briefing';
  static const _briefingChannelDesc =
      'Daily morning notification to start your day';
  static const _briefingNotificationId = 9000;

  // Offset applied to goal notification IDs to avoid collision with task IDs.
  static const _goalIdOffset = 1000000;

  Future<void> init() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // High-importance channel for timed task reminders.
    const taskChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await androidImpl?.createNotificationChannel(taskChannel);

    // Max-importance channel for urgent/immediate alerts.
    const urgentChannel = AndroidNotificationChannel(
      _urgentChannelId,
      _urgentChannelName,
      description: _urgentChannelDesc,
      importance: Importance.max,
    );
    await androidImpl?.createNotificationChannel(urgentChannel);

    // Default-importance channel for morning briefing.
    const briefingChannel = AndroidNotificationChannel(
      _briefingChannelId,
      _briefingChannelName,
      description: _briefingChannelDesc,
      importance: Importance.high,
    );
    await androidImpl?.createNotificationChannel(briefingChannel);

    _ready = true;
  }

  // ── Tasks ────────────────────────────────────────────────────────────────

  /// Schedules a timed reminder [_reminderMinutesBefore] minutes before
  /// [task.startTime]. Only fires for priority ≥ 2 (High or Urgent).
  /// No-ops if notifications are unavailable or the reminder time is past.
  Future<void> scheduleTaskReminder(TaskItem task) async {
    if (!_ready) return;
    if (task.priority < 2) return; // Low / Medium: no timed reminder noise
    final reminderTime = task.startTime.subtract(
      const Duration(minutes: _reminderMinutesBefore),
    );
    if (reminderTime.isBefore(DateTime.now())) return;

    final id = task.id.hashCode;
    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

    try {
      await _plugin.zonedSchedule(
        id,
        '⏰  ${task.title}',
        'Starting in $_reminderMinutesBefore minutes',
        tzTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService.scheduleTaskReminder: $e');
    }
  }

  /// Cancels any pending timed reminder for [taskId].
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_ready) return;
    await _plugin.cancel(taskId.hashCode);
  }

  // ── Urgent alerts (tasks & notes) ────────────────────────────────────────

  /// Fires an immediate (non-timed) max-importance alert.
  /// Used for priority=3 tasks and isUrgent notes at creation/update time.
  ///
  /// [notifId] must be unique per entity — use [id.hashCode] with an offset
  /// for different entity types if IDs could collide.
  Future<void> scheduleUrgentAlert({
    required String id,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id.hashCode,
        '🚨  $title',
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _urgentChannelId,
            _urgentChannelName,
            channelDescription: _urgentChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService.scheduleUrgentAlert: $e');
    }
  }

  // ── Notes ────────────────────────────────────────────────────────────────

  /// Schedules a one-shot reminder at [note.reminderAt].
  /// No-ops if [reminderAt] is null or in the past.
  Future<void> scheduleNoteReminder(NoteItem note) async {
    if (!_ready) return;
    final at = note.reminderAt;
    if (at == null || at.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(at, tz.local);
    // Use a hash offset to avoid collision between note IDs and task IDs.
    final id = ('note_${note.id}').hashCode;

    try {
      await _plugin.zonedSchedule(
        id,
        '📝  ${note.title}',
        'You set a reminder for this note.',
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService.scheduleNoteReminder: $e');
    }
  }

  /// Cancels any pending reminder for [noteId].
  Future<void> cancelNoteReminder(String noteId) async {
    if (!_ready) return;
    await _plugin.cancel(('note_$noteId').hashCode);
  }

  // ── Goals ────────────────────────────────────────────────────────────────

  /// Schedules a deadline alert 24 hours before [goal.deadline].
  /// No-ops if [deadline] is null, already past, or < 24 h away.
  Future<void> scheduleGoalDeadlineReminder(GoalItem goal) async {
    if (!_ready) return;
    final deadline = goal.deadline;
    if (deadline == null) return;
    final alertTime = deadline.subtract(const Duration(hours: 24));
    if (alertTime.isBefore(DateTime.now())) return;

    final id = goal.id.hashCode + _goalIdOffset;
    final tzTime = tz.TZDateTime.from(alertTime, tz.local);

    try {
      await _plugin.zonedSchedule(
        id,
        '🎯  Goal deadline tomorrow',
        '"${goal.title}" is due tomorrow.',
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.scheduleGoalDeadlineReminder: $e');
      }
    }
  }

  /// Cancels any pending deadline reminder for [goalId].
  Future<void> cancelGoalDeadlineReminder(String goalId) async {
    if (!_ready) return;
    await _plugin.cancel(goalId.hashCode + _goalIdOffset);
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  /// Requests runtime notification permission (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  // ── Morning briefing ─────────────────────────────────────────────────────

  /// Schedules (or re-schedules) a daily morning briefing notification.
  ///
  /// Fires every day at [hour]:[minute] local time. The [body] line is
  /// included in the notification so the user sees their task count even
  /// from the lock screen.
  Future<void> scheduleMorningBriefing({
    required int hour,
    required int minute,
    String body = 'Tap to review your plan for the day.',
  }) async {
    if (!_ready) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      // If today's time has already passed, start tomorrow.
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        _briefingNotificationId,
        '☀️  Good morning!',
        body,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _briefingChannelId,
            _briefingChannelName,
            channelDescription: _briefingChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleMorningBriefing: $e');
    }
  }

  /// Cancels the daily morning briefing notification.
  Future<void> cancelMorningBriefing() async {
    if (!_ready) return;
    await _plugin.cancel(_briefingNotificationId);
  }
}
