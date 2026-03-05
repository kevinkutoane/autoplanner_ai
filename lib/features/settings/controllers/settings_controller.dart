import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_settings_model.dart';

/// Manages all user-adjustable settings with Hive persistence.
/// The box stores individual key-value pairs — no type adapter required.
class SettingsController extends StateNotifier<AppSettings> {
  late Box _box;

  SettingsController() : super(AppSettings.defaults()) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox<dynamic>(AppSettings.boxName);
    if (_box.isNotEmpty) {
      state = AppSettings.fromMap(_box.toMap());
    }
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

  // ── Bulk profile update (edit dialog) ────────────────────────────

  Future<void> saveProfile({
    required String name,
    required String email,
    required String jobTitle,
    required String avatarEmoji,
  }) async {
    await _box.putAll({
      AppSettings.kUserName: name,
      AppSettings.kUserEmail: email,
      AppSettings.kUserJobTitle: jobTitle,
      AppSettings.kAvatarEmoji: avatarEmoji,
    });
    state = state.copyWith(
      userName: name,
      userEmail: email,
      userJobTitle: jobTitle,
      avatarEmoji: avatarEmoji,
    );
  }

  // ── Onboarding ─────────────────────────────────────────────────

  Future<void> completeOnboarding() async {
    await _box.put(AppSettings.kOnboardingSeen, true);
    state = state.copyWith(isOnboardingDone: true);
  }

  // ── Reset ────────────────────────────────────────────────────────

  Future<void> resetToDefaults() async {
    await _box.clear();
    state = AppSettings.defaults();
  }
}
