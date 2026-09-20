import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../core/models/gamification_model.dart';
import '../core/models/task_model.dart';

/// Event dispatched when the user reaches a new level threshold.
class LevelUpEvent {
  final int newLevel;
  final String title;
  final int totalXp;

  const LevelUpEvent({
    required this.newLevel,
    required this.title,
    required this.totalXp,
  });
}

/// Event dispatched when an achievement badge is unlocked.
class BadgeUnlockedEvent {
  final BadgeDefinition badge;

  const BadgeUnlockedEvent({required this.badge});
}

class GamificationNotifier extends Notifier<GamificationProfile> {
  static const String boxName = 'gamificationBox';
  static const String profileKey = 'user_gamification_profile';

  Box? _box;
  final _levelUpController = StreamController<LevelUpEvent>.broadcast();
  final _badgeController = StreamController<BadgeUnlockedEvent>.broadcast();

  Stream<LevelUpEvent> get levelUpStream => _levelUpController.stream;
  Stream<BadgeUnlockedEvent> get badgeStream => _badgeController.stream;

  @override
  GamificationProfile build() {
    ref.onDispose(() {
      _levelUpController.close();
      _badgeController.close();
    });

    // If box is already open (from AppBootstrapper), load initial profile synchronously
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box(boxName);
      final raw = _box?.get(profileKey);
      if (raw != null) {
        if (raw is String) {
          return GamificationProfile.fromJson(raw);
        } else if (raw is Map) {
          return GamificationProfile.fromMap(Map<String, dynamic>.from(raw));
        }
      }
    }

    unawaited(_initHive());
    return const GamificationProfile();
  }

  Future<void> _initHive() async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box(boxName);
      } else if (Hive.isBoxOpen('tasksBox') || Hive.isBoxOpen('settingsBox')) {
        _box = await Hive.openBox(boxName);
      }
      final raw = _box?.get(profileKey);
      if (raw != null) {
        if (raw is String) {
          state = GamificationProfile.fromJson(raw);
        } else if (raw is Map) {
          state = GamificationProfile.fromMap(Map<String, dynamic>.from(raw));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GamificationNotifier: Failed to load profile — $e');
      }
    }
  }

  Future<void> _save(GamificationProfile profile) async {
    state = profile;
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.put(profileKey, profile.toJson());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GamificationNotifier: Failed to persist profile — $e');
      }
    }
  }

  /// Internal helper to safely add XP and detect level-ups.
  Future<void> _addXp(int rawXp) async {
    final prevLevel = state.currentLevel;
    final multiplier = state.streakMultiplier;
    final finalXp = (rawXp * multiplier).round();
    final newTotalXp = state.totalXp + finalXp;

    var updated = state.copyWith(
      totalXp: newTotalXp,
      lastActiveDate: DateTime.now(),
    );

    final newLevel = updated.currentLevel;
    if (newLevel > prevLevel) {
      _levelUpController.add(
        LevelUpEvent(
          newLevel: newLevel,
          title: updated.levelTitle,
          totalXp: newTotalXp,
        ),
      );
    }

    await _save(updated);
  }

  /// Evaluates and unlocks a badge if not already owned.
  Future<void> _tryUnlockBadge(String badgeId) async {
    if (state.unlockedBadgeIds.contains(badgeId)) return;
    final def = kBadgeCatalog[badgeId];
    if (def == null) return;

    final updatedBadges = [...state.unlockedBadgeIds, badgeId];
    final updated = state.copyWith(unlockedBadgeIds: updatedBadges);
    await _save(updated);

    // Award bonus XP for earning the badge
    await _addXp(def.xpReward);
    _badgeController.add(BadgeUnlockedEvent(badge: def));
  }

  /// Awards XP and evaluates badges upon task completion.
  Future<void> awardTaskCompletion(TaskItem task, {int? actualMinutes}) async {
    int xp = 50; // base reward

    // Priority bonus
    if (task.priority == 2) {
      xp += 30; // High priority
    } else if (task.priority == 1) {
      xp += 15; // Medium priority
    }

    // Early finish bonus (completed at or under estimated duration)
    final estimated = task.durationMinutes > 0 ? task.durationMinutes : 30;
    if (actualMinutes != null &&
        actualMinutes > 0 &&
        actualMinutes <= estimated) {
      xp += 20;
    }

    await _addXp(xp);

    // Check Early Bird badge (completed before 9:00 AM)
    final now = DateTime.now();
    if (now.hour < 9) {
      await _tryUnlockBadge('early_bird');
    }

    // Check Time Oracle badge (within 10% of estimate)
    if (actualMinutes != null && actualMinutes > 0 && estimated > 0) {
      final diffRatio = (actualMinutes - estimated).abs() / estimated;
      if (diffRatio <= 0.10) {
        await _tryUnlockBadge('time_oracle');
      }
    }
  }

  /// Awards XP and evaluates badges for deep work flow sessions.
  Future<void> awardFocusMinutes(int minutes) async {
    if (minutes <= 0) return;
    // 10 XP per 10 minutes focused
    final xp = (minutes / 10).ceil() * 10;
    await _addXp(xp);

    if (minutes >= 45) {
      await _tryUnlockBadge('deep_diver');
    }
  }

  /// Awards XP and milestone for completing the Morning Kickoff ritual.
  Future<void> awardMorningRitual() async {
    final now = DateTime.now();
    await _addXp(50);
    await _tryUnlockBadge('morning_warrior');
    await _save(state.copyWith(lastMorningRitualDate: now));
  }

  /// Awards XP and milestone for completing the Evening Shutdown ritual.
  Future<void> awardEveningRitual() async {
    final now = DateTime.now();
    await _addXp(50);
    await _tryUnlockBadge('zen_master');
    await _save(state.copyWith(lastEveningRitualDate: now));
  }

  /// Awards XP for mental decluttering via Brain Dump.
  Future<void> awardBrainDump() async {
    await _addXp(50);
  }

  /// General method to award custom XP with optional logging reason.
  Future<void> addXp(int xp, {String? reason}) async {
    if (xp <= 0) return;
    await _addXp(xp);
  }

  /// Awards Clean Slate badge when all planned tasks for today are finished.
  Future<void> awardCleanSlate() async {
    await _tryUnlockBadge('inbox_zero');
  }

  /// Synchronizes active streak and unlocks streak milestones.
  Future<void> syncStreak(int streak) async {
    if (streak == state.currentStreak && streak <= state.longestStreak) return;

    final longest = streak > state.longestStreak ? streak : state.longestStreak;
    final updated = state.copyWith(
      currentStreak: streak,
      longestStreak: longest,
    );
    await _save(updated);

    if (streak >= 3) {
      await _tryUnlockBadge('streak_hero');
    }
    if (streak >= 7) {
      await _tryUnlockBadge('streak_titan');
    }
  }
}

/// Global provider for gamification state and actions.
final gamificationServiceProvider =
    NotifierProvider<GamificationNotifier, GamificationProfile>(
      GamificationNotifier.new,
    );
