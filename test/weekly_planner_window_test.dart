import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/features/settings/controllers/settings_controller.dart';
import 'package:autoplanner_ai/services/weekly_planner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = WeeklyPlannerService();
  // Monday 2099-06-15 is used as a fixed, far-future week start.
  final monday = DateTime(2099, 6, 15);

  TaskItem task(
    String id,
    DateTime start, {
    bool done = false,
    int mins = 60,
  }) => TaskItem(
    id: id,
    title: id,
    startTime: start,
    endTime: start.add(Duration(minutes: mins)),
    isCompleted: done,
  );

  group('WeeklyPlannerService window rules', () {
    test('completed tasks outside the window are not pulled in', () {
      final result = service.planWeek(
        tasks: [
          task('open', DateTime(2099, 6, 15, 9)),
          task('old_done', DateTime(2099, 5, 1, 9), done: true),
        ],
        weekStart: monday,
        daysCount: 5,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      final ids = result.allScheduledTasks.map((t) => t.id).toList();
      expect(ids, contains('open'));
      expect(ids, isNot(contains('old_done')));
    });

    test('tasks scheduled after the window are left alone', () {
      final result = service.planWeek(
        tasks: [
          task('later', DateTime(2099, 7, 20, 9)),
          task('now', DateTime(2099, 6, 15, 9)),
        ],
        weekStart: monday,
        daysCount: 5,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      final ids = result.allScheduledTasks.map((t) => t.id).toList();
      expect(ids, isNot(contains('later')));
    });

    test('split tasks come back under their original id (no duplicates)', () {
      final big = TaskItem(
        id: 'big',
        title: 'Big report',
        startTime: DateTime(2099, 6, 15, 9),
        endTime: DateTime(2099, 6, 15, 13),
        splittable: true,
        preferredBlockMinutes: 60,
      );
      final result = service.planWeek(
        tasks: [big],
        weekStart: monday,
        daysCount: 5,
        workStartHour: 9,
        workHoursPerDay: 8,
      );
      final ids = result.allScheduledTasks.map((t) => t.id).toList();
      expect(ids.where((i) => i.contains('_chunk_')), isEmpty);
      expect(ids.where((i) => i == 'big').length, lessThanOrEqualTo(1));
    });
  });

  group('Gateway URL validation', () {
    test('accepts https and empty', () {
      expect(SettingsController.isValidGatewayUrl(''), isTrue);
      expect(
        SettingsController.isValidGatewayUrl('https://gw.example.com'),
        isTrue,
      );
    });

    test('rejects non-http schemes and remote cleartext http', () {
      expect(SettingsController.isValidGatewayUrl('ftp://x.com'), isFalse);
      expect(SettingsController.isValidGatewayUrl('not a url'), isFalse);
      expect(
        SettingsController.isValidGatewayUrl('http://evil.example.com'),
        isFalse,
      );
    });
  });
}
