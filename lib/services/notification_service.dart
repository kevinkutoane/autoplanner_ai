import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/models/task_model.dart';

/// Wraps flutter_local_notifications.
/// Call [init] once at app startup (after Hive, before runApp).
/// Then call [scheduleTaskReminder] / [cancelTaskReminder] from TaskController.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'autoplanner_tasks';
  static const _channelName = 'Task Reminders';
  static const _channelDesc = 'Reminders shown before scheduled tasks begin';
  static const _reminderMinutesBefore = 10;

  static const _briefingChannelId = 'autoplanner_briefing';
  static const _briefingChannelName = 'Morning Briefing';
  static const _briefingChannelDesc =
      'Daily morning notification to start your day';
  static const _briefingNotificationId = 9000;

  Future<void> init() async {
    tz.initializeTimeZones();

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

    // Create the Android notification channel.
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // Create the morning briefing channel.
    const briefingChannel = AndroidNotificationChannel(
      _briefingChannelId,
      _briefingChannelName,
      description: _briefingChannelDesc,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(briefingChannel);

    _ready = true;
  }

  /// Schedules (or re-schedules) a reminder notification [_reminderMinutesBefore]
  /// minutes before [task.startTime]. Silently no-ops if notifications are
  /// not available or the start time is already in the past.
  Future<void> scheduleTaskReminder(TaskItem task) async {
    if (!_ready) return;
    final reminderTime = task.startTime.subtract(
      const Duration(minutes: _reminderMinutesBefore),
    );
    if (reminderTime.isBefore(DateTime.now())) return;

    // Use a stable int id derived from the task UUID.
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
      if (kDebugMode) debugPrint('NotificationService: $e');
    }
  }

  /// Cancels any pending reminder for [taskId].
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_ready) return;
    await _plugin.cancel(taskId.hashCode);
  }

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
        NotificationDetails(
          android: AndroidNotificationDetails(
            _briefingChannelId,
            _briefingChannelName,
            channelDescription: _briefingChannelDesc,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
