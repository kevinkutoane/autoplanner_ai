import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';
import 'package:autoplanner_ai/features/calendar/controllers/calendar_controller.dart';
import 'package:autoplanner_ai/services/context_aware_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContextAwareService Unit Tests', () {
    test('currentPhase provides a valid phase name', () {
      final container = ProviderContainer(
        overrides: [
          taskControllerProvider.overrideWith(() => _MockTaskController([])),
          calendarControllerProvider.overrideWith(() => _MockCalendarController([])),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(contextAwareServiceProvider);
      expect(service.phaseName.isNotEmpty, isTrue);
    });

    test('findNextMicroWinWindow detects open calendar gap and fitting tasks', () {
      final now = DateTime.now();
      // Event starts in 30 minutes
      final upcomingEvent = CalendarEvent(
        id: 'event-standup',
        title: 'Daily Standup',
        startTime: now.add(const Duration(minutes: 30)),
        endTime: now.add(const Duration(minutes: 60)),
      );

      // Task that takes 20 minutes (fits in 30m gap)
      final quickTask = TaskItem(
        id: 'task-quick',
        title: 'Review PR #42',
        startTime: now,
        endTime: now.add(const Duration(minutes: 20)),
        isCompleted: false,
      );

      // Task that takes 90 minutes (too long to fit)
      final longTask = TaskItem(
        id: 'task-long',
        title: 'Deep Refactoring',
        startTime: now,
        endTime: now.add(const Duration(minutes: 90)),
        isCompleted: false,
      );

      final container = ProviderContainer(
        overrides: [
          taskControllerProvider.overrideWith(
            () => _MockTaskController([quickTask, longTask]),
          ),
          calendarControllerProvider.overrideWith(
            () => _MockCalendarController([upcomingEvent]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(contextAwareServiceProvider);
      final window = service.findNextMicroWinWindow();

      expect(window, isNotNull);
      expect(window!.nextEventTitle, 'Daily Standup');
      expect(window.fittingTasks.length, 1);
      expect(window.fittingTasks.first.id, 'task-quick');
    });
  });
}

class _MockTaskController extends TaskController {
  final List<TaskItem> _tasks;
  _MockTaskController(this._tasks);
  @override
  List<TaskItem> build() => _tasks;
}

class _MockCalendarController extends CalendarController {
  final List<CalendarEvent> _events;
  _MockCalendarController(this._events);
  @override
  List<CalendarEvent> build() => _events;
}
