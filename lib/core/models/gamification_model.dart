import 'dart:convert';

/// Represents a level milestone with floor XP and title.
class LevelThreshold {
  final int level;
  final String title;
  final int minXp;
  final int maxXp;

  const LevelThreshold({
    required this.level,
    required this.title,
    required this.minXp,
    required this.maxXp,
  });
}

/// Catalog of all unlockable badges in AutoPlanner AI.
class BadgeDefinition {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final int xpReward;

  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    this.xpReward = 50,
  });
}

/// Known badge catalog.
const kBadgeCatalog = <String, BadgeDefinition>{
  'early_bird': BadgeDefinition(
    id: 'early_bird',
    title: 'Early Bird',
    description: 'Completed a priority task before 9:00 AM',
    iconName: 'wb_sunny_rounded',
    xpReward: 60,
  ),
  'deep_diver': BadgeDefinition(
    id: 'deep_diver',
    title: 'Deep Diver',
    description: 'Logged 45+ minutes of continuous flow in Focus Mode',
    iconName: 'scuba_diving_rounded',
    xpReward: 80,
  ),
  'streak_hero': BadgeDefinition(
    id: 'streak_hero',
    title: 'Streak Hero',
    description: 'Maintained a 3-day unbroken daily planning streak',
    iconName: 'local_fire_department_rounded',
    xpReward: 100,
  ),
  'streak_titan': BadgeDefinition(
    id: 'streak_titan',
    title: 'Streak Titan',
    description: 'Achieved an epic 7-day uninterrupted streak',
    iconName: 'military_tech_rounded',
    xpReward: 250,
  ),
  'inbox_zero': BadgeDefinition(
    id: 'inbox_zero',
    title: 'Clean Slate',
    description: 'Completed 100% of all tasks planned for the day',
    iconName: 'task_alt_rounded',
    xpReward: 75,
  ),
  'morning_warrior': BadgeDefinition(
    id: 'morning_warrior',
    title: 'Morning Warrior',
    description: 'Activated the Morning Kickoff attack plan before noon',
    iconName: 'lightbulb_circle_rounded',
    xpReward: 50,
  ),
  'zen_master': BadgeDefinition(
    id: 'zen_master',
    title: 'Zen Master',
    description: 'Completed the Evening Shutdown and logged daily reflection',
    iconName: 'bedtime_rounded',
    xpReward: 50,
  ),
  'time_oracle': BadgeDefinition(
    id: 'time_oracle',
    title: 'Time Oracle',
    description: 'Completed a task within 10% of your predicted duration',
    iconName: 'auto_awesome_rounded',
    xpReward: 70,
  ),
};

/// Core user profile for XP, levels, and unlocked achievements.
class GamificationProfile {
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final List<String> unlockedBadgeIds;
  final DateTime? lastActiveDate;
  final DateTime? lastMorningRitualDate;
  final DateTime? lastEveningRitualDate;

  const GamificationProfile({
    this.totalXp = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.unlockedBadgeIds = const [],
    this.lastActiveDate,
    this.lastMorningRitualDate,
    this.lastEveningRitualDate,
  });

  static const List<LevelThreshold> levelThresholds = [
    LevelThreshold(level: 1, title: 'Novice Planner', minXp: 0, maxXp: 200),
    LevelThreshold(level: 2, title: 'Apprentice Organizer', minXp: 200, maxXp: 500),
    LevelThreshold(level: 3, title: 'Flow Initiate', minXp: 500, maxXp: 1000),
    LevelThreshold(level: 4, title: 'Time Architect', minXp: 1000, maxXp: 1800),
    LevelThreshold(level: 5, title: 'Deep Diver', minXp: 1800, maxXp: 3000),
    LevelThreshold(level: 6, title: 'Productivity Alchemist', minXp: 3000, maxXp: 4600),
    LevelThreshold(level: 7, title: 'Focus Maestro', minXp: 4600, maxXp: 6600),
    LevelThreshold(level: 8, title: 'Zen Strategist', minXp: 6600, maxXp: 9200),
    LevelThreshold(level: 9, title: 'Grandmaster of Time', minXp: 9200, maxXp: 12500),
    LevelThreshold(level: 10, title: 'Legendary Producer', minXp: 12500, maxXp: 20000),
  ];

  /// Resolves current level info from total XP.
  LevelThreshold get levelInfo {
    for (final t in levelThresholds) {
      if (totalXp < t.maxXp) return t;
    }
    return levelThresholds.last;
  }

  int get currentLevel => levelInfo.level;
  String get levelTitle => levelInfo.title;

  /// Progress fraction (0.0 to 1.0) towards the next level.
  double get levelProgress {
    final info = levelInfo;
    final range = info.maxXp - info.minXp;
    if (range <= 0) return 1.0;
    return ((totalXp - info.minXp) / range).clamp(0.0, 1.0);
  }

  /// XP earned within the current level bracket.
  int get currentLevelXp => totalXp - levelInfo.minXp;

  /// XP needed to reach next level from current level floor.
  int get currentLevelRange => levelInfo.maxXp - levelInfo.minXp;

  /// Streak XP multiplier (e.g. 3-day streak -> 1.3x, capped at 2.0x).
  double get streakMultiplier {
    if (currentStreak <= 1) return 1.0;
    final bonus = (currentStreak - 1) * 0.1;
    return (1.0 + bonus).clamp(1.0, 2.0);
  }

  GamificationProfile copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    List<String>? unlockedBadgeIds,
    DateTime? lastActiveDate,
    DateTime? lastMorningRitualDate,
    DateTime? lastEveningRitualDate,
  }) {
    return GamificationProfile(
      totalXp: totalXp ?? this.totalXp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      unlockedBadgeIds: unlockedBadgeIds ?? this.unlockedBadgeIds,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      lastMorningRitualDate:
          lastMorningRitualDate ?? this.lastMorningRitualDate,
      lastEveningRitualDate:
          lastEveningRitualDate ?? this.lastEveningRitualDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalXp': totalXp,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'unlockedBadgeIds': unlockedBadgeIds,
      'lastActiveDate': lastActiveDate?.toIso8601String(),
      'lastMorningRitualDate': lastMorningRitualDate?.toIso8601String(),
      'lastEveningRitualDate': lastEveningRitualDate?.toIso8601String(),
    };
  }

  factory GamificationProfile.fromMap(Map<String, dynamic> map) {
    return GamificationProfile(
      totalXp: (map['totalXp'] as num?)?.toInt() ?? 0,
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      unlockedBadgeIds: (map['unlockedBadgeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      lastActiveDate: map['lastActiveDate'] != null
          ? DateTime.tryParse(map['lastActiveDate'] as String)
          : null,
      lastMorningRitualDate: map['lastMorningRitualDate'] != null
          ? DateTime.tryParse(map['lastMorningRitualDate'] as String)
          : null,
      lastEveningRitualDate: map['lastEveningRitualDate'] != null
          ? DateTime.tryParse(map['lastEveningRitualDate'] as String)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GamificationProfile.fromJson(String source) =>
      GamificationProfile.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
