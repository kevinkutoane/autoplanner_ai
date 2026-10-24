import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings_model.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../services/secure_key_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/gamification_service.dart';

/// Manages all user-adjustable settings with Hive persistence.
/// The box stores individual key-value pairs — no type adapter required.
class SettingsController extends Notifier<AppSettings> {
  /// Delegate to open [AppSettings.boxName] safely with encryption
  /// when the box is not already open.
  ///
  /// Registered by [AppBootstrapper.registerSettingsBoxOpener] during startup.
  static Future<Box<dynamic>> Function()? boxOpener;

  @visibleForTesting
  static void resetBoxOpenerForTesting() {
    boxOpener = null;
  }

  Box<dynamic>? _rawBox;

  /// Active Hive box for app settings.
  ///
  /// Throws [SecureStorageException] if the box is unavailable or closed,
  /// failing closed rather than opening an unencrypted box.
  Box<dynamic> get _box {
    if (_rawBox != null && _rawBox!.isOpen) {
      return _rawBox!;
    }
    if (Hive.isBoxOpen(AppSettings.boxName)) {
      final box = Hive.box<dynamic>(AppSettings.boxName);
      _rawBox = box;
      return box;
    }
    throw const SecureStorageException(
      'Settings box "${AppSettings.boxName}" is not open or available.',
    );
  }

  Future<void>? _initFuture;

  @override
  AppSettings build() {
    // If settingsBox is already opened by AppBootstrapper, read stored settings immediately
    AppSettings initialSettings = AppSettings.defaults();
    if (Hive.isBoxOpen(AppSettings.boxName)) {
      _rawBox = Hive.box<dynamic>(AppSettings.boxName);
      if (_rawBox!.isNotEmpty) {
        initialSettings = AppSettings.fromMap(_rawBox!.toMap());
      }
    }

    AppHaptics.enabled = initialSettings.hapticsEnabled;
    _initFuture ??= _performInit();
    return initialSettings;
  }

  Future<Box<dynamic>> _resolveBox() async {
    if (Hive.isBoxOpen(AppSettings.boxName)) {
      return Hive.box<dynamic>(AppSettings.boxName);
    }
    final opener = boxOpener;
    if (opener != null) {
      return await opener();
    }
    throw const SecureStorageException(
      'Settings box "${AppSettings.boxName}" is not open and no safe cipher-aware opener is registered.',
    );
  }

  @visibleForTesting
  Future<Box<dynamic>> resolveBoxForTesting() => _resolveBox();

  Future<void> _performInit() async {
    try {
      final resolvedBox = await _resolveBox();
      _rawBox = resolvedBox;
      if (resolvedBox.isNotEmpty) {
        state = AppSettings.fromMap(resolvedBox.toMap());
      }

      // ── Credential Migration & Authoritative Storage ──
      // SecureKeyService is the single authoritative store for the Gemini API key.
      final secureKey = await SecureKeyService.getGeminiApiKey();
      final legacyHiveKey = _box.get(AppSettings.kGeminiApiKey) as String?;

      if (secureKey != null && secureKey.isNotEmpty) {
        state = state.copyWith(geminiApiKey: secureKey);
        // If an old legacy copy exists in Hive and matches secure storage, safely clean it up
        if (legacyHiveKey != null && legacyHiveKey == secureKey) {
          await _box.delete(AppSettings.kGeminiApiKey);
        }
      } else if (legacyHiveKey != null && legacyHiveKey.isNotEmpty) {
        // Attempt migration of legacy key from Hive into SecureKeyService
        try {
          await SecureKeyService.saveGeminiApiKey(legacyHiveKey);
          // Delete legacy copy ONLY after secure storage confirms receipt and verification
          await _box.delete(AppSettings.kGeminiApiKey);
          state = state.copyWith(geminiApiKey: legacyHiveKey);
        } catch (e) {
          // If migration fails, keep legacy key in _box for recoverability; never delete it
          if (kDebugMode) {
            debugPrint(
              'SettingsController: secure key migration encountered an error: $e',
            );
          }
          state = state.copyWith(geminiApiKey: legacyHiveKey);
        }
      }

      // ── Legacy Settings Migration for AI Connection Mode & Gateway URL ──
      // If a legacy user had cloud_gateway + default localhost:8000 saved, migrate them safely:
      // 1. If user has a Gemini key -> migrate to direct_gemini
      // 2. If user does NOT have a custom remote gateway URL -> migrate to direct_gemini
      // Do NOT overwrite deliberately configured remote custom URLs (e.g. https://... or custom IP).
      final isLegacyDefaultGateway =
          state.cloudGatewayUrl == 'http://127.0.0.1:8000' ||
          state.cloudGatewayUrl == 'http://localhost:8000';
      if (isLegacyDefaultGateway) {
        await _box.put(AppSettings.kCloudGatewayUrl, '');
        final newMode = state.geminiApiKey.isNotEmpty
            ? 'direct_gemini'
            : (state.isMockAI ? 'offline_mock' : 'direct_gemini');
        if (state.aiConnectionMode == 'cloud_gateway') {
          await _box.put(AppSettings.kAiConnectionMode, newMode);
          state = state.copyWith(
            cloudGatewayUrl: '',
            aiConnectionMode: newMode,
          );
        } else {
          state = state.copyWith(cloudGatewayUrl: '');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SettingsController._init() failed: $e');
    }
  }

  /// Resolves when the box has been loaded and state is ready.
  Future<void> ensureInitialized() {
    _initFuture ??= _performInit();
    return _initFuture!;
  }

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
    final mode = v
        ? 'offline_mock'
        : (state.aiConnectionMode == 'offline_mock'
              ? 'direct_gemini'
              : state.aiConnectionMode);
    await updateAIConnectionMode(mode);
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
    } else {
      try {
        final currentStreak = ref
            .read(gamificationServiceProvider)
            .currentStreak;
        if (currentStreak > 0) {
          await NotificationService().scheduleStreakShield(
            currentStreak: currentStreak,
          );
        }
      } catch (_) {}
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

  Future<void> updateUserMotto(String v) async {
    await _box.put(AppSettings.kUserMotto, v);
    state = state.copyWith(userMotto: v);
  }

  // ── Sensory & Haptic Experience ────────────────────────────────

  Future<void> updateHapticsEnabled(bool v) async {
    await _box.put(AppSettings.kHapticsEnabled, v);
    AppHaptics.enabled = v;
    state = state.copyWith(hapticsEnabled: v);
  }

  Future<void> updateConfettiCelebrationsEnabled(bool v) async {
    await _box.put(AppSettings.kConfettiCelebrationsEnabled, v);
    state = state.copyWith(confettiCelebrationsEnabled: v);
  }

  Future<void> updateGeminiApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await SecureKeyService.deleteGeminiApiKey();
      await _box.delete(AppSettings.kGeminiApiKey);
      state = state.copyWith(geminiApiKey: '');
    } else {
      await SecureKeyService.saveGeminiApiKey(trimmed);
      // Ensure key is NOT stored in the Hive box
      await _box.delete(AppSettings.kGeminiApiKey);
      await _box.put(AppSettings.kAiConnectionMode, 'direct_gemini');
      state = state.copyWith(
        geminiApiKey: trimmed,
        aiConnectionMode: 'direct_gemini',
      );
    }
  }

  // ── AI Engine & Gateway Settings ───────────────────────────────────

  Future<void> updateAIConnectionMode(String mode) async {
    await _box.put(AppSettings.kAiConnectionMode, mode);
    state = state.copyWith(aiConnectionMode: mode);
  }

  /// Returns true when [url] is empty or an acceptable gateway address.
  /// Release builds strictly require https; debug builds permit http only for local dev hosts.
  static bool isValidGatewayUrl(String url) {
    if (url.isEmpty) return true;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
    if (uri.scheme == 'https') return true;
    if (uri.scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    final isLocal =
        host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '10.0.2.2' ||
        host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.');
    return kDebugMode && isLocal;
  }

  Future<void> updateCloudGatewayUrl(String url) async {
    final trimmed = url.trim();
    if (!isValidGatewayUrl(trimmed)) return;
    await _box.put(AppSettings.kCloudGatewayUrl, trimmed);
    state = state.copyWith(cloudGatewayUrl: trimmed);
  }

  Future<void> updateAutoRippleDrift(bool v) async {
    await _box.put(AppSettings.kAutoRippleDrift, v);
    state = state.copyWith(autoRippleDrift: v);
  }

  Future<void> updateDriftGraceMinutes(int v) async {
    await _box.put(AppSettings.kDriftGraceMinutes, v);
    state = state.copyWith(driftGraceMinutes: v);
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

  Future<void> dismissStarterPlan() async {
    await _box.put(AppSettings.kHasDismissedStarterPlan, true);
    state = state.copyWith(hasDismissedStarterPlan: true);
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
