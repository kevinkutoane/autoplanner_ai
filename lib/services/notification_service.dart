import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/models/task_model.dart';
import '../core/models/note_model.dart';
import '../core/models/goal_model.dart';
import '../features/settings/models/app_settings_model.dart';
import 'notification_id_generator.dart';

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
  bool _exactAllowed = true;

  @visibleForTesting
  bool get isReady => _ready;

  @visibleForTesting
  set isReadyForTesting(bool value) => _ready = value;

  @visibleForTesting
  Future<void> Function(
    int id,
    String? title,
    String? body,
    NotificationDetails? details,
  )?
  onShowForTesting;

  @visibleForTesting
  Future<void> Function(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails? details,
    AndroidScheduleMode mode,
    DateTimeComponents? matchDateTimeComponents,
  )?
  onZonedScheduleForTesting;

  @visibleForTesting
  Future<void> Function(int id)? onCancelForTesting;

  @visibleForTesting
  void resetTestSeams() {
    onShowForTesting = null;
    onZonedScheduleForTesting = null;
    onCancelForTesting = null;
  }

  Future<void> _showNotification({
    required int id,
    String? title,
    String? body,
    required NotificationDetails notificationDetails,
  }) async {
    if (onShowForTesting != null) {
      await onShowForTesting!(id, title, body, notificationDetails);
      return;
    }
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  Future<void> _zonedScheduleNotification({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (onZonedScheduleForTesting != null) {
      await onZonedScheduleForTesting!(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode,
        matchDateTimeComponents,
      );
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: androidScheduleMode,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  Future<void> _cancelNotification(int id) async {
    if (onCancelForTesting != null) {
      await onCancelForTesting!(id);
      return;
    }
    await _plugin.cancel(id: id);
  }

  /// Exact alarms when the OS permits them, otherwise inexact (still delivered).
  AndroidScheduleMode get _mode => _exactAllowed
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

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
  static const _briefingNotificationId = NotificationIdGenerator.briefingId;

  static const _shutdownChannelId = 'autoplanner_rituals';
  static const _shutdownChannelName = 'Daily Rituals & Shutdown';
  static const _shutdownChannelDesc =
      'Daily morning kickoff and evening shutdown rituals';
  static const _shutdownNotificationId = NotificationIdGenerator.shutdownId;

  static const _streakNotificationId = NotificationIdGenerator.streakShieldId;

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

    try {
      _exactAllowed =
          await androidImpl?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      _exactAllowed = true;
    }

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

    final id = NotificationIdGenerator.taskReminder(task.id);
    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

    final isUrgent = task.priority == 3;
    final channelId = isUrgent ? _urgentChannelId : _channelId;
    final channelName = isUrgent ? _urgentChannelName : _channelName;
    final channelDesc = isUrgent ? _urgentChannelDesc : _channelDesc;
    final importance = isUrgent ? Importance.max : Importance.high;
    final priority = isUrgent ? Priority.max : Priority.high;

    Future<void> schedule(
      AndroidScheduleMode mode,
    ) => _zonedScheduleNotification(
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
      androidScheduleMode: mode,
    );

    try {
      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);
      } catch (_) {
        // Exact alarms denied — fall back so the reminder still fires.
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.scheduleTaskReminder: $e');
      }
    }
  }

  /// Immediately shows a test notification so users can verify delivery.
  Future<bool> showTestNotification() async {
    if (!_ready) return false;
    try {
      await _showNotification(
        id: NotificationIdGenerator.testNotificationId,
        title: '✅  Notifications are working',
        body: 'AutoPlanner AI reminders will appear like this.',
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
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService.showTest: $e');
      return false;
    }
  }

  /// Cancels any pending timed reminder for [taskId].
  ///
  /// Also cancels legacy ID for backward compatibility with tasks scheduled prior to Phase 1B.4.
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_ready) return;
    await _cancelNotification(NotificationIdGenerator.taskReminder(taskId));
    await _cancelNotification(
      NotificationIdGenerator.legacyTaskReminder(taskId),
    );
  }

  /// Cancels any active immediate urgent alert for [taskId].
  ///
  /// Also cancels legacy ID for backward compatibility where urgent alerts shared taskId.hashCode.
  Future<void> cancelTaskUrgentAlert(String taskId) async {
    if (!_ready) return;
    await _cancelNotification(NotificationIdGenerator.taskUrgent(taskId));
    await _cancelNotification(
      NotificationIdGenerator.legacyTaskReminder(taskId),
    );
  }

  // ── Urgent alerts (tasks & notes) ────────────────────────────────────────

  /// Fires an immediate (non-timed) max-importance alert.
  /// Used for priority=3 tasks and isUrgent notes at creation/update time.
  ///
  /// [id] identifies the entity. If prefixed with 'note_', it generates a
  /// note urgent alert ID; otherwise, it generates a task urgent alert ID.
  /// Uses domain partitioning to guarantee urgent alerts never overwrite or
  /// evict scheduled timed reminders for the same entity.
  Future<void> scheduleUrgentAlert({
    required String id,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    final isNote = id.startsWith('note_');
    final rawId = isNote ? id.substring(5) : id;
    final notifId = isNote
        ? NotificationIdGenerator.noteUrgent(rawId)
        : NotificationIdGenerator.taskUrgent(rawId);

    try {
      await _showNotification(
        id: notifId,
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
    // Use partitioned domain to avoid collision between note IDs and task IDs.
    final id = NotificationIdGenerator.noteReminder(note.id);

    try {
      await _zonedScheduleNotification(
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
        androidScheduleMode: _mode,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.scheduleNoteReminder: $e');
      }
    }
  }

  /// Cancels any pending reminder for [noteId].
  ///
  /// Also cancels active note urgent alerts and legacy note reminder IDs.
  Future<void> cancelNoteReminder(String noteId) async {
    if (!_ready) return;
    await _cancelNotification(NotificationIdGenerator.noteReminder(noteId));
    await _cancelNotification(NotificationIdGenerator.noteUrgent(noteId));
    await _cancelNotification(
      NotificationIdGenerator.legacyNoteReminder(noteId),
    );
  }

  /// Cancels any active immediate urgent alert for [noteId].
  Future<void> cancelNoteUrgentAlert(String noteId) async {
    if (!_ready) return;
    await _cancelNotification(NotificationIdGenerator.noteUrgent(noteId));
    await _cancelNotification(
      NotificationIdGenerator.legacyNoteReminder(noteId),
    );
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

    final id = NotificationIdGenerator.goalDeadline(goal.id);
    final tzTime = tz.TZDateTime.from(alertTime, tz.local);

    try {
      await _zonedScheduleNotification(
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
        androidScheduleMode: _mode,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.scheduleGoalDeadlineReminder: $e');
      }
    }
  }

  /// Cancels any pending deadline reminder for [goalId].
  ///
  /// Also cancels legacy goal deadline IDs for backward compatibility.
  Future<void> cancelGoalDeadlineReminder(String goalId) async {
    if (!_ready) return;
    await _cancelNotification(NotificationIdGenerator.goalDeadline(goalId));
    await _cancelNotification(
      NotificationIdGenerator.legacyGoalDeadline(goalId),
    );
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
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
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

      await _zonedScheduleNotification(
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
        androidScheduleMode: _mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleMorningBriefing: $e');
    }
  }

  /// Cancels the daily morning briefing notification.
  Future<void> cancelMorningBriefing() async {
    if (!_ready) return;
    await _cancelNotification(_briefingNotificationId);
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

      await _zonedScheduleNotification(
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
        androidScheduleMode: _mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleEveningShutdown: $e');
    }
  }

  /// Cancels evening shutdown reminder.
  Future<void> cancelEveningShutdown() async {
    if (!_ready) return;
    await _cancelNotification(_shutdownNotificationId);
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

      await _zonedScheduleNotification(
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
        androidScheduleMode: _mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleStreakShield: $e');
    }
  }

  /// Cancels the streak shield reminder.
  Future<void> cancelStreakShield() async {
    if (!_ready) return;
    await _cancelNotification(_streakNotificationId);
  }
}
