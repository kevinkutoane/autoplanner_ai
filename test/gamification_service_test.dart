import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:autoplanner_ai/core/models/gamification_model.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/services/gamification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gamification_test');
    Hive.init(tempDir.path);
    await Hive.openBox('gamificationBox');
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('GamificationProfile Unit Tests', () {
    test('initial profile has level 1 Novice Planner and 1.0x multiplier', () {
      const profile = GamificationProfile();
      expect(profile.totalXp, 0);
      expect(profile.currentLevel, 1);
      expect(profile.levelTitle, 'Novice Planner');
      expect(profile.streakMultiplier, 1.0);
    });

    test('calculates correct level threshold progression', () {
      const p1 = GamificationProfile(totalXp: 150);
      expect(p1.currentLevel, 1);
      expect(p1.levelTitle, 'Novice Planner');
      expect(p1.currentLevelXp, 150);

      const p2 = GamificationProfile(totalXp: 250);
      expect(p2.currentLevel, 2);
      expect(p2.levelTitle, 'Apprentice Organizer');

      const p3 = GamificationProfile(totalXp: 1200);
      expect(p3.currentLevel, 4);
      expect(p3.levelTitle, 'Time Architect');
    });

    test('streak multiplier scales up to 2.0x max', () {
      const pZero = GamificationProfile(currentStreak: 0);
      expect(pZero.streakMultiplier, 1.0);

      const pOne = GamificationProfile(currentStreak: 1);
      expect(pOne.streakMultiplier, 1.0);

      const pThree = GamificationProfile(currentStreak: 3);
      expect(pThree.streakMultiplier, 1.2);

      const pSeven = GamificationProfile(currentStreak: 7);
      expect(pSeven.streakMultiplier, 1.6);

      const pSuper = GamificationProfile(currentStreak: 20);
      expect(pSuper.streakMultiplier, 2.0);
    });

    test('serialization round-trip to/from Map and JSON', () {
      final now = DateTime.now();
      final original = GamificationProfile(
        totalXp: 850,
        currentStreak: 4,
        longestStreak: 5,
        unlockedBadgeIds: const ['early_bird', 'deep_diver'],
        lastActiveDate: now,
      );

      final map = original.toMap();
      final restored = GamificationProfile.fromMap(map);

      expect(restored.totalXp, original.totalXp);
      expect(restored.currentStreak, original.currentStreak);
      expect(restored.longestStreak, original.longestStreak);
      expect(restored.unlockedBadgeIds, original.unlockedBadgeIds);
    });
  });

  group('GamificationNotifier Riverpod Tests', () {
    test('awardTaskCompletion gives base XP and priority bonus', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gamificationServiceProvider.notifier);

      final task = TaskItem(
        id: 't-1',
        title: 'High priority task',
        priority: 2, // High (+30)
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(minutes: 30)),
      );

      // Award task completion with actual time under estimate (+20)
      await notifier.awardTaskCompletion(task, actualMinutes: 25);

      final state = container.read(gamificationServiceProvider);
      // Base (50) + High (30) + Early (20) = 100 XP
      expect(state.totalXp, greaterThanOrEqualTo(100));
    });

    test('awardFocusMinutes scales XP by session duration', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gamificationServiceProvider.notifier);

      // 45 minutes of focus gives 50 XP + unlocks deep_diver (+80 XP)
      await notifier.awardFocusMinutes(45);

      final state = container.read(gamificationServiceProvider);
      expect(state.totalXp, greaterThanOrEqualTo(130));
      expect(state.unlockedBadgeIds.contains('deep_diver'), isTrue);
    });

    test(
      'syncStreak updates streak and unlocks streak_hero at 3 days',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(gamificationServiceProvider.notifier);

        await notifier.syncStreak(3);

        final state = container.read(gamificationServiceProvider);
        expect(state.currentStreak, 3);
        expect(state.longestStreak, 3);
        expect(state.unlockedBadgeIds.contains('streak_hero'), isTrue);
      },
    );
  });
}
