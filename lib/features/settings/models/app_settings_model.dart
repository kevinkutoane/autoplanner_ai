import 'package:flutter/material.dart';

/// Immutable value-object for all user-adjustable settings.
///
/// Stored as individual key-value pairs in a `Hive<dynamic>` box
/// so no code-gen is required. Reconstruct via `AppSettings.copyWith`
/// and persist through [SettingsController].
class AppSettings {
  final String userName;
  final String userEmail;
  final String userJobTitle;

  /// Optional decorative emoji shown in the profile header.
  final String avatarEmoji;

  final ThemeMode themeMode;
  final int workHoursPerDay;

  /// Work-day start hour in 24-hour format (0–23).
  final int workStartHour;

  /// 7-element bitmask for Mon–Sun; `true` = that weekday is a work day.
  final List<bool> workDays;
  final bool useMockAI;
  final bool enableAILogging;
  final int maxTokensPerDay;
  final bool isOnboardingDone;

  /// The Gemini API key entered by the user.
  /// Loaded from secure storage at startup; never persisted to Hive.
  final String geminiApiKey;

  /// Whether to require biometric / device-credential unlock on resume.
  final bool requireBiometrics;

  /// Whether a daily morning briefing notification is enabled.
  final bool morningBriefingEnabled;

  /// Hour (0-23) at which the morning briefing fires.
  final int morningBriefingHour;

  /// Minute (0-59) at which the morning briefing fires.
  final int morningBriefingMinute;

  /// Whether Google Calendar is currently connected.
  final bool isGoogleCalendarConnected;

  /// Email of the connected Google account (empty when not connected).
  final String googleAccountEmail;

  /// Whether Microsoft Outlook Calendar is currently connected.
  final bool isOutlookConnected;

  const AppSettings({
    required this.userName,
    required this.userEmail,
    required this.userJobTitle,
    required this.avatarEmoji,
    required this.themeMode,
    required this.workHoursPerDay,
    required this.workStartHour,
    required this.workDays,
    required this.useMockAI,
    required this.enableAILogging,
    required this.maxTokensPerDay,
    this.isOnboardingDone = false,
    this.geminiApiKey = '',
    this.requireBiometrics = false,
    this.morningBriefingEnabled = false,
    this.morningBriefingHour = 8,
    this.morningBriefingMinute = 0,
    this.isGoogleCalendarConnected = false,
    this.googleAccountEmail = '',
    this.isOutlookConnected = false,
  });

  factory AppSettings.defaults() => AppSettings(
    userName: '',
    userEmail: '',
    userJobTitle: '',
    avatarEmoji: '🧑‍💻',
    themeMode: ThemeMode.system,
    workHoursPerDay: 8,
    workStartHour: 9,
    workDays: [true, true, true, true, true, false, false], // Mon-Fri
    useMockAI: false,
    enableAILogging: true,
    maxTokensPerDay: 100000,
    isOnboardingDone: false,
    geminiApiKey: '',
    requireBiometrics: false,
    morningBriefingEnabled: false,
    morningBriefingHour: 8,
    morningBriefingMinute: 0,
    isGoogleCalendarConnected: false,
    googleAccountEmail: '',
    isOutlookConnected: false,
  );

  AppSettings copyWith({
    String? userName,
    String? userEmail,
    String? userJobTitle,
    String? avatarEmoji,
    ThemeMode? themeMode,
    int? workHoursPerDay,
    int? workStartHour,
    List<bool>? workDays,
    bool? useMockAI,
    bool? enableAILogging,
    int? maxTokensPerDay,
    bool? isOnboardingDone,
    String? geminiApiKey,
    bool? requireBiometrics,
    bool? morningBriefingEnabled,
    int? morningBriefingHour,
    int? morningBriefingMinute,
    bool? isGoogleCalendarConnected,
    String? googleAccountEmail,
    bool? isOutlookConnected,
  }) {
    return AppSettings(
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userJobTitle: userJobTitle ?? this.userJobTitle,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      themeMode: themeMode ?? this.themeMode,
      workHoursPerDay: workHoursPerDay ?? this.workHoursPerDay,
      workStartHour: workStartHour ?? this.workStartHour,
      workDays: workDays ?? this.workDays,
      useMockAI: useMockAI ?? this.useMockAI,
      enableAILogging: enableAILogging ?? this.enableAILogging,
      maxTokensPerDay: maxTokensPerDay ?? this.maxTokensPerDay,
      isOnboardingDone: isOnboardingDone ?? this.isOnboardingDone,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      requireBiometrics: requireBiometrics ?? this.requireBiometrics,
      morningBriefingEnabled:
          morningBriefingEnabled ?? this.morningBriefingEnabled,
      morningBriefingHour: morningBriefingHour ?? this.morningBriefingHour,
      morningBriefingMinute:
          morningBriefingMinute ?? this.morningBriefingMinute,
      isGoogleCalendarConnected:
          isGoogleCalendarConnected ?? this.isGoogleCalendarConnected,
      googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
      isOutlookConnected: isOutlookConnected ?? this.isOutlookConnected,
    );
  }

  // ── Hive box key constants ─────────────────────────────────────────
  static const String boxName = 'settingsBox';
  static const String kOnboardingSeen = 'onboardingSeen';
  static const String kUserName = 'userName';
  static const String kUserEmail = 'userEmail';
  static const String kUserJobTitle = 'userJobTitle';
  static const String kAvatarEmoji = 'avatarEmoji';
  static const String kThemeMode = 'themeMode'; // 'system'|'light'|'dark'
  static const String kWorkHoursPerDay = 'workHoursPerDay';
  static const String kWorkStartHour = 'workStartHour';
  static const String kWorkDays = 'workDays'; // comma-joined booleans
  static const String kUseMockAI = 'useMockAI';
  static const String kEnableAILogging = 'enableAILogging';
  static const String kMaxTokensPerDay = 'maxTokensPerDay';
  static const String kRequireBiometrics = 'requireBiometrics';
  static const String kMorningBriefingEnabled = 'morningBriefingEnabled';
  static const String kMorningBriefingHour = 'morningBriefingHour';
  static const String kMorningBriefingMinute = 'morningBriefingMinute';
  static const String kIsGoogleCalendarConnected = 'isGoogleCalendarConnected';
  static const String kGoogleAccountEmail = 'googleAccountEmail';
  static const String kIsOutlookConnected = 'isOutlookConnected';

  // ── Serialization helpers ──────────────────────────────────────────
  static ThemeMode _parseThemeMode(String? v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _serializeThemeMode(ThemeMode m) => switch (m) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    _ => 'system',
  };

  static List<bool> _parseWorkDays(String? v) {
    if (v == null) return [true, true, true, true, true, false, false];
    final parts = v.split(',');
    if (parts.length != 7) return [true, true, true, true, true, false, false];
    return parts.map((e) => e == 'true').toList();
  }

  Map<String, dynamic> toMap() => {
    kUserName: userName,
    kUserEmail: userEmail,
    kUserJobTitle: userJobTitle,
    kAvatarEmoji: avatarEmoji,
    kThemeMode: _serializeThemeMode(themeMode),
    kWorkHoursPerDay: workHoursPerDay,
    kWorkStartHour: workStartHour,
    kWorkDays: workDays.map((e) => e.toString()).join(','),
    kUseMockAI: useMockAI,
    kEnableAILogging: enableAILogging,
    kMaxTokensPerDay: maxTokensPerDay,
    kOnboardingSeen: isOnboardingDone,
    kRequireBiometrics: requireBiometrics,
    kMorningBriefingEnabled: morningBriefingEnabled,
    kMorningBriefingHour: morningBriefingHour,
    kMorningBriefingMinute: morningBriefingMinute,
    kIsGoogleCalendarConnected: isGoogleCalendarConnected,
    kGoogleAccountEmail: googleAccountEmail,
    kIsOutlookConnected: isOutlookConnected,
  };

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) => AppSettings(
    userName: (map[kUserName] as String?) ?? '',
    userEmail: (map[kUserEmail] as String?) ?? '',
    userJobTitle: (map[kUserJobTitle] as String?) ?? '',
    avatarEmoji: (map[kAvatarEmoji] as String?) ?? '🧑‍💻',
    themeMode: _parseThemeMode(map[kThemeMode] as String?),
    workHoursPerDay: (map[kWorkHoursPerDay] as int?) ?? 8,
    workStartHour: (map[kWorkStartHour] as int?) ?? 9,
    workDays: _parseWorkDays(map[kWorkDays] as String?),
    useMockAI: (map[kUseMockAI] as bool?) ?? false,
    enableAILogging: (map[kEnableAILogging] as bool?) ?? true,
    maxTokensPerDay: (map[kMaxTokensPerDay] as int?) ?? 100000,
    isOnboardingDone: (map[kOnboardingSeen] as bool?) ?? false,
    requireBiometrics: (map[kRequireBiometrics] as bool?) ?? false,
    morningBriefingEnabled: (map[kMorningBriefingEnabled] as bool?) ?? false,
    morningBriefingHour: (map[kMorningBriefingHour] as int?) ?? 8,
    morningBriefingMinute: (map[kMorningBriefingMinute] as int?) ?? 0,
    isGoogleCalendarConnected:
        (map[kIsGoogleCalendarConnected] as bool?) ?? false,
    googleAccountEmail: (map[kGoogleAccountEmail] as String?) ?? '',
    isOutlookConnected: (map[kIsOutlookConnected] as bool?) ?? false,
  );

  /// Convenience: human-friendly display name (falls back to 'You').
  String get displayName => userName.trim().isEmpty ? 'You' : userName.trim();

  /// Initials for avatar (up to 2 chars).
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get workStartLabel {
    final hour = workStartHour;
    final suffix = hour < 12 ? 'AM' : 'PM';
    final display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$display:00 $suffix';
  }
}
