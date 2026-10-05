import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';

// ── Suite ─────────────────────────────────────────────────────────────────────

void main() {
  // ── AppSettings.defaults ─────────────────────────────────────────────────
  group('AppSettings.defaults', () {
    late AppSettings defaults;

    setUp(() => defaults = AppSettings.defaults());

    test('userName defaults to empty string', () {
      expect(defaults.userName, '');
    });

    test('userEmail defaults to empty string', () {
      expect(defaults.userEmail, '');
    });

    test('userJobTitle defaults to empty string', () {
      expect(defaults.userJobTitle, '');
    });

    test('avatarEmoji defaults to the coder emoji', () {
      expect(defaults.avatarEmoji, '🧑‍💻');
    });

    test('themeMode defaults to system', () {
      expect(defaults.themeMode, ThemeMode.system);
    });

    test('workHoursPerDay defaults to 8', () {
      expect(defaults.workHoursPerDay, 8);
    });

    test('workStartHour defaults to 9', () {
      expect(defaults.workStartHour, 9);
    });

    test('workDays defaults to Mon–Fri (5 true, 2 false)', () {
      expect(defaults.workDays, [true, true, true, true, true, false, false]);
    });

    test('useMockAI defaults to false', () {
      expect(defaults.useMockAI, isFalse);
    });

    test('enableAILogging defaults to true', () {
      expect(defaults.enableAILogging, isTrue);
    });

    test('maxTokensPerDay defaults to 100000', () {
      expect(defaults.maxTokensPerDay, 100000);
    });

    test('isOnboardingDone defaults to false', () {
      expect(defaults.isOnboardingDone, isFalse);
    });

    test('geminiApiKey defaults to empty string', () {
      expect(defaults.geminiApiKey, '');
    });

    test('requireBiometrics defaults to false', () {
      expect(defaults.requireBiometrics, isFalse);
    });

    test('morningBriefingEnabled defaults to false', () {
      expect(defaults.morningBriefingEnabled, isFalse);
    });

    test('morningBriefingHour defaults to 8', () {
      expect(defaults.morningBriefingHour, 8);
    });

    test('isGoogleCalendarConnected defaults to false', () {
      expect(defaults.isGoogleCalendarConnected, isFalse);
    });

    test('googleAccountEmail defaults to empty string', () {
      expect(defaults.googleAccountEmail, '');
    });

    test('workDays has exactly 7 elements', () {
      expect(defaults.workDays, hasLength(7));
    });

    test('aiConnectionMode defaults to cloud_gateway', () {
      expect(defaults.aiConnectionMode, 'cloud_gateway');
    });

    test('cloudGatewayUrl defaults to local gateway', () {
      expect(defaults.cloudGatewayUrl, 'http://127.0.0.1:8000');
    });

    test('autoRippleDrift defaults to true', () {
      expect(defaults.autoRippleDrift, isTrue);
    });

    test('driftGraceMinutes defaults to 10', () {
      expect(defaults.driftGraceMinutes, 10);
    });
  });

  // ── AppSettings.copyWith ─────────────────────────────────────────────────
  group('AppSettings.copyWith', () {
    late AppSettings base;

    setUp(() => base = AppSettings.defaults());

    test('copyWith returns a new instance', () {
      final copy = base.copyWith(userName: 'Alice');
      expect(copy.userName, 'Alice');
      expect(base.userName, '');
    });

    test('copyWith preserves all other fields when one is changed', () {
      final copy = base.copyWith(userName: 'Bob');
      expect(copy.userEmail, base.userEmail);
      expect(copy.themeMode, base.themeMode);
      expect(copy.workHoursPerDay, base.workHoursPerDay);
      expect(copy.workStartHour, base.workStartHour);
      expect(copy.workDays, base.workDays);
      expect(copy.useMockAI, base.useMockAI);
      expect(copy.maxTokensPerDay, base.maxTokensPerDay);
    });

    test('copyWith can update userEmail', () {
      final copy = base.copyWith(userEmail: 'alice@example.com');
      expect(copy.userEmail, 'alice@example.com');
    });

    test('copyWith can update themeMode to dark', () {
      final copy = base.copyWith(themeMode: ThemeMode.dark);
      expect(copy.themeMode, ThemeMode.dark);
    });

    test('copyWith can update themeMode to light', () {
      final copy = base.copyWith(themeMode: ThemeMode.light);
      expect(copy.themeMode, ThemeMode.light);
    });

    test('copyWith can update workHoursPerDay', () {
      final copy = base.copyWith(workHoursPerDay: 6);
      expect(copy.workHoursPerDay, 6);
    });

    test('copyWith can update workStartHour', () {
      final copy = base.copyWith(workStartHour: 8);
      expect(copy.workStartHour, 8);
    });

    test('copyWith can enable useMockAI', () {
      final copy = base.copyWith(useMockAI: true);
      expect(copy.useMockAI, isTrue);
    });

    test('copyWith can disable enableAILogging', () {
      final copy = base.copyWith(enableAILogging: false);
      expect(copy.enableAILogging, isFalse);
    });

    test('copyWith can update maxTokensPerDay', () {
      final copy = base.copyWith(maxTokensPerDay: 50000);
      expect(copy.maxTokensPerDay, 50000);
    });

    test('copyWith can mark onboarding done', () {
      final copy = base.copyWith(isOnboardingDone: true);
      expect(copy.isOnboardingDone, isTrue);
    });

    test('copyWith can set geminiApiKey', () {
      final copy = base.copyWith(geminiApiKey: 'AIzatest');
      expect(copy.geminiApiKey, 'AIzatest');
    });

    test('copyWith can enable requireBiometrics', () {
      final copy = base.copyWith(requireBiometrics: true);
      expect(copy.requireBiometrics, isTrue);
    });

    test('copyWith can enable morning briefing', () {
      final copy = base.copyWith(morningBriefingEnabled: true);
      expect(copy.morningBriefingEnabled, isTrue);
    });

    test('copyWith can update morningBriefingHour', () {
      final copy = base.copyWith(morningBriefingHour: 7);
      expect(copy.morningBriefingHour, 7);
    });

    test('copyWith can mark Google Calendar connected', () {
      final copy = base.copyWith(
        isGoogleCalendarConnected: true,
        googleAccountEmail: 'user@gmail.com',
      );
      expect(copy.isGoogleCalendarConnected, isTrue);
      expect(copy.googleAccountEmail, 'user@gmail.com');
    });

    test('copyWith can update workDays to all-week', () {
      final allWeek = List.filled(7, true);
      final copy = base.copyWith(workDays: allWeek);
      expect(copy.workDays, allWeek);
    });

    test('copyWith can clear googleAccountEmail', () {
      final connected = base.copyWith(googleAccountEmail: 'user@gmail.com');
      final disconnected = connected.copyWith(googleAccountEmail: '');
      expect(disconnected.googleAccountEmail, '');
    });

    test('copyWith can update AI Gateway and drift settings', () {
      final updated = base.copyWith(
        aiConnectionMode: 'direct_gemini',
        cloudGatewayUrl: 'https://gateway.example.com',
        autoRippleDrift: false,
        driftGraceMinutes: 20,
      );
      expect(updated.aiConnectionMode, 'direct_gemini');
      expect(updated.cloudGatewayUrl, 'https://gateway.example.com');
      expect(updated.autoRippleDrift, isFalse);
      expect(updated.driftGraceMinutes, 20);
    });
  });

  // ── Serialization (toMap / fromMap) ───────────────────────────────────────
  group('AppSettings serialization', () {
    test('round-trips AI Gateway and drift settings through toMap and fromMap', () {
      final original = AppSettings.defaults().copyWith(
        aiConnectionMode: 'offline_mock',
        cloudGatewayUrl: 'http://custom-host:9000',
        autoRippleDrift: false,
        driftGraceMinutes: 15,
      );
      final map = original.toMap();
      final restored = AppSettings.fromMap(map);

      expect(restored.aiConnectionMode, 'offline_mock');
      expect(restored.cloudGatewayUrl, 'http://custom-host:9000');
      expect(restored.autoRippleDrift, isFalse);
      expect(restored.driftGraceMinutes, 15);
    });

    test('serializes and deserializes hasDismissedStarterPlan', () {
      final custom = AppSettings.defaults().copyWith(
        hasDismissedStarterPlan: true,
      );
      final map = custom.toMap();
      final restored = AppSettings.fromMap(map);

      expect(restored.hasDismissedStarterPlan, isTrue);
    });
  });

  // ── Hive box key constants ────────────────────────────────────────────────
  group('AppSettings Hive key constants', () {
    test('boxName is set', () {
      expect(AppSettings.boxName, isNotEmpty);
    });

    test('kUserName is non-empty', () {
      expect(AppSettings.kUserName, isNotEmpty);
    });

    test('kThemeMode is non-empty', () {
      expect(AppSettings.kThemeMode, isNotEmpty);
    });

    test('kWorkStartHour is non-empty', () {
      expect(AppSettings.kWorkStartHour, isNotEmpty);
    });

    test('kWorkHoursPerDay is non-empty', () {
      expect(AppSettings.kWorkHoursPerDay, isNotEmpty);
    });

    test('kMorningBriefingEnabled is non-empty', () {
      expect(AppSettings.kMorningBriefingEnabled, isNotEmpty);
    });

    test('kMorningBriefingHour is non-empty', () {
      expect(AppSettings.kMorningBriefingHour, isNotEmpty);
    });

    test('kIsGoogleCalendarConnected is non-empty', () {
      expect(AppSettings.kIsGoogleCalendarConnected, isNotEmpty);
    });

    test('AI Gateway and Drift constants are non-empty', () {
      expect(AppSettings.kAiConnectionMode, 'aiConnectionMode');
      expect(AppSettings.kCloudGatewayUrl, 'cloudGatewayUrl');
      expect(AppSettings.kAutoRippleDrift, 'autoRippleDrift');
      expect(AppSettings.kDriftGraceMinutes, 'driftGraceMinutes');
    });

    test('kHasDismissedStarterPlan constant is non-empty', () {
      expect(AppSettings.kHasDismissedStarterPlan, 'hasDismissedStarterPlan');
    });
  });
}
