import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/models/task_model.dart';
import '../core/models/note_model.dart';
import '../core/models/goal_model.dart';
import '../features/settings/models/app_settings_model.dart';

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

  static const _shutdownChannelId = 'autoplanner_rituals';
  static const _shutdownChannelName = 'Daily Rituals & Shutdown';
  static const _shutdownChannelDesc =
      'Daily morning kickoff and evening shutdown rituals';
  static const _shutdownNotificationId = 9001;

  static const _streakNotificationId = 9002;

  // Offset applied to goal notification IDs to avoid collision with task IDs.
  static const _goalIdOffset = 1000000;

  Future<void> init() async {
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = timeZoneInfo.identifier;
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

    await _plugin.initialize(settings: initSettings);

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

    // Daily rituals & shutdown channel.
    const shutdownChannel = AndroidNotificationChannel(
      _shutdownChannelId,
      _shutdownChannelName,
      description: _shutdownChannelDesc,
      importance: Importance.high,
    );
    await androidImpl?.createNotificationChannel(shutdownChannel);

    _ready = true;
  }

  // ── Tasks ────────────────────────────────────────────────────────────────

  /// Schedules a timed reminder before [task.startTime].
  ///
  /// Honors user settings:
  /// - If [settings] is provided and [settings.taskRemindersEnabled] is false, does nothing.
  /// - If [settings.remindCrucialTasksOnly] is true, only priority ≥ 2 (High or Urgent) fires.
  /// - Uses [settings.reminderLeadTimeMinutes] (default 10) as the lead time.
  /// - Uses Urgent channel for Priority 3 (Urgent) tasks.
  Future<void> scheduleTaskReminder(
    TaskItem task, [
    AppSettings? settings,
  ]) async {
    if (!_ready) return;
    if (settings != null && !settings.taskRemindersEnabled) return;

    final crucialOnly = settings?.remindCrucialTasksOnly ?? true;
    if (crucialOnly && task.priority < 2) return;

    final leadMinutes =
        settings?.reminderLeadTimeMinutes ?? _reminderMinutesBefore;
    final reminderTime = task.startTime.subtract(
      Duration(minutes: leadMinutes),
    );
    if (reminderTime.isBefore(DateTime.now())) return;

    final id = task.id.hashCode;
    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

    final isUrgent = task.priority == 3;
    final channelId = isUrgent ? _urgentChannelId : _channelId;
    final channelName = isUrgent ? _urgentChannelName : _channelName;
    final channelDesc = isUrgent ? _urgentChannelDesc : _channelDesc;
    final importance = isUrgent ? Importance.max : Importance.high;
    final priority = isUrgent ? Priority.max : Priority.high;

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: isUrgent ? '🚨  ${task.title}' : '⏰  ${task.title}',
        body:
            'Starting in $leadMinutes minutes${isUrgent ? " • High Priority" : ""}',
        scheduledDate: tzTime,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDesc,
            importance: importance,
            priority: priority,
            icon: '@mipmap/ic_launcher',
            playSound: settings?.notificationSoundEnabled ?? true,
            enableVibration: settings?.notificationVibrateEnabled ?? true,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: isUrgent
                ? InterruptionLevel.timeSensitive
                : InterruptionLevel.active,
            presentSound: settings?.notificationSoundEnabled ?? true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.scheduleTaskReminder: $e');
      }
    }
  }

  /// Cancels any pending timed reminder for [taskId].
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_ready) return;
    await _plugin.cancel(id: taskId.hashCode);
    await _plugin.cancel(id: 'task_start_$taskId'.hashCode);
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
        id: id.hashCode,
        title: '🚨  $title',
        body: body,
        notificationDetails: const NotificationDetails(
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
        id: id,
        title: '📝  ${note.title}',
        body: 'You set a reminder for this note.',
        scheduledDate: tzTime,
        notificationDetails: const NotificationDetails(
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
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.scheduleNoteReminder: $e');
      }
    }
  }

  /// Cancels any pending reminder for [noteId].
  Future<void> cancelNoteReminder(String noteId) async {
    if (!_ready) return;
    await _plugin.cancel(id: 'note_$noteId'.hashCode);
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
        id: id,
        title: '🎯  Goal deadline tomorrow',
        body: '"${goal.title}" is due tomorrow.',
        scheduledDate: tzTime,
        notificationDetails: const NotificationDetails(
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
    await _plugin.cancel(id: goalId.hashCode + _goalIdOffset);
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
        id: _briefingNotificationId,
        title: '☀️  Good morning!',
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
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
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleMorningBriefing: $e');
    }
  }

  /// Cancels the daily morning briefing notification.
  Future<void> cancelMorningBriefing() async {
    if (!_ready) return;
    await _plugin.cancel(id: _briefingNotificationId);
  }

  // ── Evening shutdown ritual ──────────────────────────────────────────────

  /// Schedules daily evening shutdown ritual reminder.
  Future<void> scheduleEveningShutdown({
    required int hour,
    required int minute,
    String body = 'Time to review wins, reset the board, and log reflections.',
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
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: _shutdownNotificationId,
        title: '🌙  Evening Shutdown',
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _shutdownChannelId,
            _shutdownChannelName,
            channelDescription: _shutdownChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleEveningShutdown: $e');
    }
  }

  /// Cancels evening shutdown reminder.
  Future<void> cancelEveningShutdown() async {
    if (!_ready) return;
    await _plugin.cancel(id: _shutdownNotificationId);
  }

  // ── Streak Shield reminder ───────────────────────────────────────────────

  /// Schedules an alert at [hour]:[minute] to protect an active streak.
  Future<void> scheduleStreakShield({
    int hour = 20,
    int minute = 0,
    required int currentStreak,
  }) async {
    if (!_ready || currentStreak <= 0) return;
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
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: _streakNotificationId,
        title: '🛡️  Streak Shield: Keep your streak alive!',
        body:
            'You have a $currentStreak-day streak! Complete a task or log your evening reflection.',
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _urgentChannelId,
            _urgentChannelName,
            channelDescription: _urgentChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleStreakShield: $e');
    }
  }

  /// Cancels the streak shield reminder.
  Future<void> cancelStreakShield() async {
    if (!_ready) return;
    await _plugin.cancel(id: _streakNotificationId);
  }
}
