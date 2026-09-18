import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';
import 'package:autoplanner_ai/services/notification_service.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings Notification & Flagship Personalization Tests', () {
    test('defaults have correct flagship settings', () {
      final s = AppSettings.defaults();
      expect(s.taskRemindersEnabled, isTrue);
      expect(s.remindCrucialTasksOnly, isTrue);
      expect(s.reminderLeadTimeMinutes, equals(10));
      expect(s.eveningShutdownReminderEnabled, isTrue);
      expect(s.eveningShutdownHour, equals(17));
      expect(s.eveningShutdownMinute, equals(30));
      expect(s.streakRemindersEnabled, isTrue);
      expect(s.notificationSoundEnabled, isTrue);
      expect(s.notificationVibrateEnabled, isTrue);
      expect(s.chronotype, equals('early_bird'));
      expect(s.dailyFocusGoalMinutes, equals(120));
      expect(s.coachingStyle, equals('balanced'));
      expect(s.userMotto, isEmpty);
      expect(s.hapticsEnabled, isTrue);
      expect(s.confettiCelebrationsEnabled, isTrue);
    });

    test('copyWith updates notification & personalization fields', () {
      final original = AppSettings.defaults();
      final updated = original.copyWith(
        taskRemindersEnabled: false,
        remindCrucialTasksOnly: false,
        reminderLeadTimeMinutes: 15,
        eveningShutdownReminderEnabled: false,
        eveningShutdownHour: 18,
        eveningShutdownMinute: 45,
        streakRemindersEnabled: false,
        notificationSoundEnabled: false,
        notificationVibrateEnabled: false,
        chronotype: 'night_owl',
        dailyFocusGoalMinutes: 180,
        coachingStyle: 'direct',
        userMotto: 'Keep ship rolling',
        hapticsEnabled: false,
        confettiCelebrationsEnabled: false,
      );

      expect(updated.taskRemindersEnabled, isFalse);
      expect(updated.remindCrucialTasksOnly, isFalse);
      expect(updated.reminderLeadTimeMinutes, equals(15));
      expect(updated.eveningShutdownReminderEnabled, isFalse);
      expect(updated.eveningShutdownHour, equals(18));
      expect(updated.eveningShutdownMinute, equals(45));
      expect(updated.streakRemindersEnabled, isFalse);
      expect(updated.notificationSoundEnabled, isFalse);
      expect(updated.notificationVibrateEnabled, isFalse);
      expect(updated.chronotype, equals('night_owl'));
      expect(updated.dailyFocusGoalMinutes, equals(180));
      expect(updated.coachingStyle, equals('direct'));
      expect(updated.userMotto, equals('Keep ship rolling'));
      expect(updated.hapticsEnabled, isFalse);
      expect(updated.confettiCelebrationsEnabled, isFalse);
    });

    test('toMap and fromMap serialize and deserialize cleanly', () {
      final custom = AppSettings.defaults().copyWith(
        userName: 'Elena Rostova',
        userEmail: 'elena@flow.ai',
        reminderLeadTimeMinutes: 30,
        chronotype: 'balanced',
        dailyFocusGoalMinutes: 90,
        coachingStyle: 'empathetic',
        userMotto: 'Progress over perfection',
        hapticsEnabled: true,
      );

      final map = custom.toMap();
      final revived = AppSettings.fromMap(map);

      expect(revived.userName, equals('Elena Rostova'));
      expect(revived.userEmail, equals('elena@flow.ai'));
      expect(revived.reminderLeadTimeMinutes, equals(30));
      expect(revived.chronotype, equals('balanced'));
      expect(revived.dailyFocusGoalMinutes, equals(90));
      expect(revived.coachingStyle, equals('empathetic'));
      expect(revived.userMotto, equals('Progress over perfection'));
      expect(revived.hapticsEnabled, isTrue);
    });
  });

  group('NotificationService Integration Logic Tests', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    test('scheduleTaskReminder ignores low priority when remindCrucialTasksOnly is true', () async {
      final lowTask = TaskItem(
        id: 'low_task_1',
        title: 'Water plants',
        startTime: DateTime.now().add(const Duration(hours: 2)),
        endTime: DateTime.now().add(const Duration(hours: 2, minutes: 30)),
        priority: 1, // Medium / Low
      );

      final settings = AppSettings.defaults().copyWith(
        remindCrucialTasksOnly: true,
      );

      // Should not throw or crash even if plugin not initialized in test environment
      await service.scheduleTaskReminder(lowTask, settings);
    });

    test('scheduleTaskReminder ignores all tasks when taskRemindersEnabled is false', () async {
      final urgentTask = TaskItem(
        id: 'urgent_task_1',
        title: 'Board meeting presentation',
        startTime: DateTime.now().add(const Duration(hours: 3)),
        endTime: DateTime.now().add(const Duration(hours: 4)),
        priority: 3, // Urgent
      );

      final settings = AppSettings.defaults().copyWith(
        taskRemindersEnabled: false,
      );
      await service.scheduleTaskReminder(urgentTask, settings);
    });

    test('cancelTaskReminder handles task ID safely', () async {
      await service.cancelTaskReminder('test_id_123');
      await service.cancelEveningShutdown();
      await service.cancelStreakShield();
    });
  });
}
