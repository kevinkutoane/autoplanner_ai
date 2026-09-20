import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings_model.dart';
import '../../../services/secure_key_service.dart';
import '../../../services/notification_service.dart';

/// Manages all user-adjustable settings with Hive persistence.
/// The box stores individual key-value pairs — no type adapter required.
class SettingsController extends Notifier<AppSettings> {
  late Box _box;
  final Completer<void> _initCompleter = Completer<void>();

  @override
  AppSettings build() {
    // If settingsBox is already opened by AppBootstrapper, read stored settings immediately
    AppSettings initialSettings = AppSettings.defaults();
    if (Hive.isBoxOpen(AppSettings.boxName)) {
      _box = Hive.box<dynamic>(AppSettings.boxName);
      if (_box.isNotEmpty) {
        initialSettings = AppSettings.fromMap(_box.toMap());
      }
    }

    _init();
    return initialSettings;
  }

  Future<void> _init() async {
    try {
      // Use Hive.box() to grab the already-opened encrypted box from main().
      // Calling openBox<dynamic>() without a cipher would create an
      // unencrypted instance if it ran before main()'s _openBoxSafe.
      _box = Hive.isBoxOpen(AppSettings.boxName)
          ? Hive.box<dynamic>(AppSettings.boxName)
          : await Hive.openBox<dynamic>(AppSettings.boxName);
      if (_box.isNotEmpty) {
        state = AppSettings.fromMap(_box.toMap());
      }
      // Load the user's Gemini API key from secure storage.
      final savedKey = await SecureKeyService.getGeminiApiKey();
      if (savedKey != null && savedKey.isNotEmpty) {
        state = state.copyWith(geminiApiKey: savedKey);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SettingsController._init() failed: $e');
    } finally {
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }
  }

  /// Resolves when the box has been loaded and state is ready.
  Future<void> ensureInitialized() => _initCompleter.future;

  // ── Profile ──────────────────────────────────────────────────────

  Future<void> updateUserName(String v) async {
    await _box.put(AppSettings.kUserName, v);
    state = state.copyWith(userName: v);
  }

  Future<void> updateUserEmail(String v) async {
    await _box.put(AppSettings.kUserEmail, v);
    state = state.copyWith(userEmail: v);
  }

  Future<void> updateUserJobTitle(String v) async {
    await _box.put(AppSettings.kUserJobTitle, v);
    state = state.copyWith(userJobTitle: v);
  }

  Future<void> updateAvatarEmoji(String v) async {
    await _box.put(AppSettings.kAvatarEmoji, v);
    state = state.copyWith(avatarEmoji: v);
  }

  // ── Appearance ───────────────────────────────────────────────────

  Future<void> updateThemeMode(ThemeMode mode) async {
    final serialized = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await _box.put(AppSettings.kThemeMode, serialized);
    state = state.copyWith(themeMode: mode);
  }

  // ── Work preferences ─────────────────────────────────────────────

  Future<void> updateWorkHoursPerDay(int v) async {
    await _box.put(AppSettings.kWorkHoursPerDay, v);
    state = state.copyWith(workHoursPerDay: v);
  }

  Future<void> updateWorkStartHour(int v) async {
    await _box.put(AppSettings.kWorkStartHour, v);
    state = state.copyWith(workStartHour: v);
  }

  Future<void> updateWorkDays(List<bool> v) async {
    await _box.put(AppSettings.kWorkDays, v.map((e) => e.toString()).join(','));
    state = state.copyWith(workDays: v);
  }

  // ── AI settings ──────────────────────────────────────────────────

  Future<void> updateUseMockAI(bool v) async {
    await _box.put(AppSettings.kUseMockAI, v);
    state = state.copyWith(useMockAI: v);
  }

  Future<void> updateEnableAILogging(bool v) async {
    await _box.put(AppSettings.kEnableAILogging, v);
    state = state.copyWith(enableAILogging: v);
  }

  Future<void> updateMaxTokensPerDay(int v) async {
    await _box.put(AppSettings.kMaxTokensPerDay, v);
    state = state.copyWith(maxTokensPerDay: v);
  }

  Future<void> updateRequireBiometrics(bool v) async {
    await _box.put(AppSettings.kRequireBiometrics, v);
    state = state.copyWith(requireBiometrics: v);
  }

  Future<void> updateMorningBriefingEnabled(bool v) async {
    await _box.put(AppSettings.kMorningBriefingEnabled, v);
    state = state.copyWith(morningBriefingEnabled: v);
    if (v) {
      await NotificationService().scheduleMorningBriefing(
        hour: state.morningBriefingHour,
        minute: state.morningBriefingMinute,
      );
    } else {
      await NotificationService().cancelMorningBriefing();
    }
  }

  Future<void> updateMorningBriefingHour(int v) async {
    await _box.put(AppSettings.kMorningBriefingHour, v);
    state = state.copyWith(morningBriefingHour: v);
    if (state.morningBriefingEnabled) {
      await NotificationService().scheduleMorningBriefing(
        hour: v,
        minute: state.morningBriefingMinute,
      );
    }
  }

  Future<void> updateMorningBriefingMinute(int v) async {
    await _box.put(AppSettings.kMorningBriefingMinute, v);
    state = state.copyWith(morningBriefingMinute: v);
    if (state.morningBriefingEnabled) {
      await NotificationService().scheduleMorningBriefing(
        hour: state.morningBriefingHour,
        minute: v,
      );
    }
  }

  // ── Notification Enhancements ──────────────────────────────────

  Future<void> updateTaskRemindersEnabled(bool v) async {
    await _box.put(AppSettings.kTaskRemindersEnabled, v);
    state = state.copyWith(taskRemindersEnabled: v);
  }

  Future<void> updateRemindCrucialTasksOnly(bool v) async {
    await _box.put(AppSettings.kRemindCrucialTasksOnly, v);
    state = state.copyWith(remindCrucialTasksOnly: v);
  }

  Future<void> updateReminderLeadTimeMinutes(int v) async {
    await _box.put(AppSettings.kReminderLeadTimeMinutes, v);
    state = state.copyWith(reminderLeadTimeMinutes: v);
  }

  Future<void> updateEveningShutdownReminderEnabled(bool v) async {
    await _box.put(AppSettings.kEveningShutdownReminderEnabled, v);
    state = state.copyWith(eveningShutdownReminderEnabled: v);
    if (v) {
      await NotificationService().scheduleEveningShutdown(
        hour: state.eveningShutdownHour,
        minute: state.eveningShutdownMinute,
      );
    } else {
      await NotificationService().cancelEveningShutdown();
    }
  }

  Future<void> updateEveningShutdownHour(int v) async {
    await _box.put(AppSettings.kEveningShutdownHour, v);
    state = state.copyWith(eveningShutdownHour: v);
    if (state.eveningShutdownReminderEnabled) {
      await NotificationService().scheduleEveningShutdown(
        hour: v,
        minute: state.eveningShutdownMinute,
      );
    }
  }

  Future<void> updateEveningShutdownMinute(int v) async {
    await _box.put(AppSettings.kEveningShutdownMinute, v);
    state = state.copyWith(eveningShutdownMinute: v);
    if (state.eveningShutdownReminderEnabled) {
      await NotificationService().scheduleEveningShutdown(
        hour: state.eveningShutdownHour,
        minute: v,
      );
    }
  }

  Future<void> updateStreakRemindersEnabled(bool v) async {
    await _box.put(AppSettings.kStreakRemindersEnabled, v);
    state = state.copyWith(streakRemindersEnabled: v);
    if (!v) {
      await NotificationService().cancelStreakShield();
    }
  }

  Future<void> updateNotificationSoundEnabled(bool v) async {
    await _box.put(AppSettings.kNotificationSoundEnabled, v);
    state = state.copyWith(notificationSoundEnabled: v);
  }

  Future<void> updateNotificationVibrateEnabled(bool v) async {
    await _box.put(AppSettings.kNotificationVibrateEnabled, v);
    state = state.copyWith(notificationVibrateEnabled: v);
  }

  // ── Productivity & Circadian Persona ───────────────────────────

  Future<void> updateChronotype(String v) async {
    await _box.put(AppSettings.kChronotype, v);
    state = state.copyWith(chronotype: v);
  }

  Future<void> updateDailyFocusGoalMinutes(int v) async {
    await _box.put(AppSettings.kDailyFocusGoalMinutes, v);
    state = state.copyWith(dailyFocusGoalMinutes: v);
  }

  Future<void> updateCoachingStyle(String v) async {
    await _box.put(AppSettings.kCoachingStyle, v);
    state = state.copyWith(coachingStyle: v);
  }

  Future<void> updateUserMotto(String v) async {
    await _box.put(AppSettings.kUserMotto, v);
    state = state.copyWith(userMotto: v);
  }

  // ── Sensory & Haptic Experience ────────────────────────────────

  Future<void> updateHapticsEnabled(bool v) async {
    await _box.put(AppSettings.kHapticsEnabled, v);
    state = state.copyWith(hapticsEnabled: v);
  }

  Future<void> updateConfettiCelebrationsEnabled(bool v) async {
    await _box.put(AppSettings.kConfettiCelebrationsEnabled, v);
    state = state.copyWith(confettiCelebrationsEnabled: v);
  }

  Future<void> updateGeminiApiKey(String key) async {
    if (key.trim().isEmpty) {
      await SecureKeyService.deleteGeminiApiKey();
      state = state.copyWith(geminiApiKey: '');
    } else {
      await SecureKeyService.saveGeminiApiKey(key.trim());
      state = state.copyWith(geminiApiKey: key.trim());
    }
  }

  // ── Bulk profile update (edit dialog) ────────────────────────────

  Future<void> saveProfile({
    required String name,
    required String email,
    required String jobTitle,
    required String avatarEmoji,
    String? userMotto,
  }) async {
    final map = <String, dynamic>{
      AppSettings.kUserName: name,
      AppSettings.kUserEmail: email,
      AppSettings.kUserJobTitle: jobTitle,
      AppSettings.kAvatarEmoji: avatarEmoji,
    };
    if (userMotto != null) {
      map[AppSettings.kUserMotto] = userMotto;
    }
    await _box.putAll(map);
    state = state.copyWith(
      userName: name,
      userEmail: email,
      userJobTitle: jobTitle,
      avatarEmoji: avatarEmoji,
      userMotto: userMotto ?? state.userMotto,
    );
  }

  // ── Onboarding ─────────────────────────────────────────────────

  Future<void> completeOnboarding() async {
    await _box.put(AppSettings.kOnboardingSeen, true);
    state = state.copyWith(isOnboardingDone: true);
  }

  // ── Calendar integrations ────────────────────────────────────────

  Future<void> updateGoogleCalendarConnection({
    required bool connected,
    String email = '',
  }) async {
    await _box.put(AppSettings.kIsGoogleCalendarConnected, connected);
    await _box.put(AppSettings.kGoogleAccountEmail, email);
    state = state.copyWith(
      isGoogleCalendarConnected: connected,
      googleAccountEmail: connected ? email : '',
    );
  }

  Future<void> updateSyncTasksToGoogleCalendar(bool v) async {
    await _box.put(AppSettings.kSyncTasksToGoogleCalendar, v);
    state = state.copyWith(syncTasksToGoogleCalendar: v);
  }

  // ── Reset ────────────────────────────────────────────────────────

  Future<void> resetToDefaults() async {
    await _box.clear();
    state = AppSettings.defaults();
  }
}
