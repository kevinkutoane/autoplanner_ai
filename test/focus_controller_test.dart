import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/features/focus/controllers/focus_controller.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late TaskItem testTask;

  setUp(() {
    testTask = TaskItem(
      id: 'task-1',
      title: 'Write project documentation',
      startTime: DateTime(2026, 3, 12, 10, 0),
      endTime: DateTime(2026, 3, 12, 10, 45), // 45 min
      priority: 2,
    );

    container = ProviderContainer(
      overrides: [
        // Mock task controller with in-memory list
        taskControllerProvider.overrideWith(
          () => _MockTaskController([testTask]),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('FocusController', () {
    test('initial state is idle and not running', () {
      final state = container.read(focusControllerProvider);
      expect(state.isRunning, isFalse);
      expect(state.isPaused, isFalse);
      expect(state.task, isNull);
      expect(state.elapsedSeconds, equals(0));
    });

    test('startSession initializes countdown with planned duration', () {
      final ctrl = container.read(focusControllerProvider.notifier);
      ctrl.startSession(testTask);

      final state = container.read(focusControllerProvider);
      expect(state.isRunning, isTrue);
      expect(state.isPaused, isFalse);
      expect(state.task?.id, equals('task-1'));
      expect(state.targetSeconds, equals(45 * 60));
      expect(state.elapsedSeconds, equals(0));
    });

    test('pause and resume toggle state and count pauses', () {
      final ctrl = container.read(focusControllerProvider.notifier);
      ctrl.startSession(testTask);

      ctrl.pause();
      var state = container.read(focusControllerProvider);
      expect(state.isRunning, isFalse);
      expect(state.isPaused, isTrue);
      expect(state.pausesCount, equals(1));

      ctrl.resume();
      state = container.read(focusControllerProvider);
      expect(state.isRunning, isTrue);
      expect(state.isPaused, isFalse);
    });

    test('addMinutes extends targetSeconds by specified minutes', () {
      final ctrl = container.read(focusControllerProvider.notifier);
      ctrl.startSession(testTask);

      ctrl.addMinutes(15);
      final state = container.read(focusControllerProvider);
      expect(state.targetSeconds, equals((45 + 15) * 60));
    });

    test('logDistraction records distraction notes without interrupting session', () {
      final ctrl = container.read(focusControllerProvider.notifier);
      ctrl.startSession(testTask);

      ctrl.logDistraction('Check server metrics');
      ctrl.logDistraction('Reply to email');

      final state = container.read(focusControllerProvider);
      expect(state.distractionNotes.length, equals(2));
      expect(state.distractionNotes[0], equals('Check server metrics'));
      expect(state.distractionNotes[1], equals('Reply to email'));
    });

    test('completeSession marks task completed, records actual duration & focus count', () {
      final ctrl = container.read(focusControllerProvider.notifier);
      ctrl.startSession(testTask);

      final completed = ctrl.completeSession();
      expect(completed, isNotNull);
      expect(completed!.isCompleted, isTrue);
      expect(completed.actualDurationMinutes, greaterThanOrEqualTo(1));
      expect(completed.completedAt, isNotNull);
      expect(completed.focusSessionsCount, equals(1));

      final state = container.read(focusControllerProvider);
      expect(state.isRunning, isFalse);
      expect(state.isFinished, isTrue);
    });
  });
}

class _MockTaskController extends TaskController {
  final List<TaskItem> _tasks;
  _MockTaskController(this._tasks);

  @override
  List<TaskItem> build() => List.from(_tasks);

  @override
  void updateTask(TaskItem task) {
    state = [
      for (final t in state)
        if (t.id == task.id) task else t,
    ];
  }
}
