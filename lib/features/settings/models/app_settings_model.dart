import 'package:flutter/material.dart';

/// Flat value-object for all user-adjustable settings.
/// Stored as individual key-value pairs in a `Hive<dynamic>` box
/// so no code-gen is required.
class AppSettings {
  final String userName;
  final String userEmail;
  final String userJobTitle;
  final String avatarEmoji; // optional decorative emoji
  final ThemeMode themeMode;
  final int workHoursPerDay;
  final int workStartHour; // 0-23
  final List<bool> workDays; // Mon-Sun (7 bools)
  final bool useMockAI;
  final bool enableAILogging;
  final int maxTokensPerDay;
  final bool isOnboardingDone;

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
