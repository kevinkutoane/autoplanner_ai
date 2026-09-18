import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';
import 'package:autoplanner_ai/features/calendar/controllers/calendar_controller.dart';
import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/services/routine_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    appConfig = const EnvConfig();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('routine_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RoutineService Unit Tests', () {
    test('generateEveningReview calculates completion metrics correctly', () {
      final now = DateTime.now();
      final completedTask = TaskItem(
        id: 't-1',
        title: 'Finished Task',
        startTime: now,
        isCompleted: true,
        actualDurationMinutes: 45,
      );
      final pendingTask = TaskItem(
        id: 't-2',
        title: 'Unfinished Task',
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        isCompleted: false,
      );

      final container = ProviderContainer(
        overrides: [
          taskControllerProvider.overrideWith(
            () => _MockTaskController([completedTask, pendingTask]),
          ),
          calendarControllerProvider.overrideWith(
            () => _MockCalendarController([]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final routineService = container.read(routineServiceProvider);
      final review = routineService.generateEveningReview();

      expect(review.totalTasks, 2);
      expect(review.completedTasks, 1);
      expect(review.completionRate, 0.5);
      expect(review.totalFocusMinutes, 45);
      expect(review.pendingTasks.length, 1);
      expect(review.pendingTasks.first.id, 't-2');
    });

    test('generateMorningBriefing picks Big 3 priorities and calculates focus hours', () async {
      final now = DateTime.now();
      final highP = TaskItem(
        id: 't-high',
        title: 'Critical Architecture Doc',
        startTime: now,
        priority: 2,
        isCompleted: false,
      );
      final medP = TaskItem(
        id: 't-med',
        title: 'Code Review',
        startTime: now,
        priority: 1,
        isCompleted: false,
      );
      final lowP = TaskItem(
        id: 't-low',
        title: 'Inbox zero',
        startTime: now,
        priority: 0,
        isCompleted: false,
      );

      final event = CalendarEvent(
        id: 'e-1',
        title: 'Team Sync',
        startTime: DateTime(now.year, now.month, now.day, 10, 0),
        endTime: DateTime(now.year, now.month, now.day, 11, 0),
      );

      final container = ProviderContainer(
        overrides: [
          taskControllerProvider.overrideWith(
            () => _MockTaskController([lowP, highP, medP]),
          ),
          calendarControllerProvider.overrideWith(
            () => _MockCalendarController([event]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final routineService = container.read(routineServiceProvider);
      final briefing = await routineService.generateMorningBriefing();

      expect(briefing.meetingsCount, 1);
      expect(briefing.big3.length, 3);
      // First in Big 3 should be highest priority
      expect(briefing.big3.first.id, 't-high');
      expect(briefing.availableFocusHours, greaterThan(0));
    });
  });
}

class _MockTaskController extends TaskController {
  final List<TaskItem> _initial;
  _MockTaskController(this._initial);

  @override
  List<TaskItem> build() => _initial;

  @override
  void updateTask(TaskItem task) {
    state = [
      for (final t in state)
        if (t.id == task.id) task else t,
    ];
  }
}

class _MockCalendarController extends CalendarController {
  final List<CalendarEvent> _events;
  _MockCalendarController(this._events);

  @override
  List<CalendarEvent> build() => _events;
}
