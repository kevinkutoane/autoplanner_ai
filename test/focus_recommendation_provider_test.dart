import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/features/focus/controllers/focus_controller.dart';
import 'package:autoplanner_ai/features/focus/models/focus_recommendation.dart';
import 'package:autoplanner_ai/features/focus/providers/focus_recommendation_provider.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('focusRecommendationProvider', () {
    test('returns active task if focus session is in progress', () {
      final task = TaskItem(
        id: 't-active',
        title: 'Deep coding',
        startTime: DateTime(2026, 3, 12, 10, 0),
      );

      final container = ProviderContainer(
        overrides: [
          taskControllerProvider.overrideWith(
            () => _MockTaskController([task]),
          ),
        ],
      );

      container.read(focusControllerProvider.notifier).startSession(task);

      final rec = container.read(focusRecommendationProvider);
      expect(rec, isNotNull);
      expect(rec!.task.id, equals('t-active'));
      expect(rec.type, equals(RecommendationType.activeNow));
    });

    test(
      'recommends currently scheduled task if clock is within task window',
      () {
        final nowTime = DateTime(2026, 3, 12, 14, 15);
        final activeTask = TaskItem(
          id: 't-sched-now',
          title: 'Design review meeting',
          startTime: DateTime(2026, 3, 12, 14, 0),
          endTime: DateTime(2026, 3, 12, 14, 45),
          priority: 2,
        );

        withClock(Clock.fixed(nowTime), () {
          final container = ProviderContainer(
            overrides: [
              taskControllerProvider.overrideWith(
                () => _MockTaskController([activeTask]),
              ),
            ],
          );

          final rec = container.read(focusRecommendationProvider);
          expect(rec, isNotNull);
          expect(rec!.task.id, equals('t-sched-now'));
          expect(rec.type, equals(RecommendationType.activeNow));
        });
      },
    );

    test('recommends upcoming task starting within 45 minutes', () {
      final nowTime = DateTime(2026, 3, 12, 9, 40);
      final upcomingTask = TaskItem(
        id: 't-upcoming',
        title: 'Team sync',
        startTime: DateTime(2026, 3, 12, 10, 0),
        priority: 1,
      );

      withClock(Clock.fixed(nowTime), () {
        final container = ProviderContainer(
          overrides: [
            taskControllerProvider.overrideWith(
              () => _MockTaskController([upcomingTask]),
            ),
          ],
        );

        final rec = container.read(focusRecommendationProvider);
        expect(rec, isNotNull);
        expect(rec!.task.id, equals('t-upcoming'));
        expect(rec.type, equals(RecommendationType.upcomingSoon));
        expect(rec.minutesUntilStart, equals(20));
      });
    });

    test('recommends energy matching task for morning (high energy)', () {
      final morningTime = DateTime(2026, 3, 12, 8, 30);
      final lowEnergyTask = TaskItem(
        id: 't-low',
        title: 'Clear inbox',
        startTime: DateTime(2026, 3, 12, 16, 0),
        energyLevel: 'low',
        priority: 1,
      );
      final highEnergyTask = TaskItem(
        id: 't-high',
        title: 'Architect neural network',
        startTime: DateTime(2026, 3, 12, 17, 0),
        energyLevel: 'high',
        priority: 1,
      );

      withClock(Clock.fixed(morningTime), () {
        final container = ProviderContainer(
          overrides: [
            taskControllerProvider.overrideWith(
              () => _MockTaskController([lowEnergyTask, highEnergyTask]),
            ),
          ],
        );

        final rec = container.read(focusRecommendationProvider);
        expect(rec, isNotNull);
        expect(rec!.task.id, equals('t-high'));
        expect(rec.type, equals(RecommendationType.energyMatch));
      });
    });

    test('returns null when all tasks are completed', () {
      final nowTime = DateTime(2026, 3, 12, 12, 0);
      final doneTask = TaskItem(
        id: 't-done',
        title: 'Finished sprint demo',
        startTime: DateTime(2026, 3, 12, 9, 0),
        isCompleted: true,
      );

      withClock(Clock.fixed(nowTime), () {
        final container = ProviderContainer(
          overrides: [
            taskControllerProvider.overrideWith(
              () => _MockTaskController([doneTask]),
            ),
          ],
        );

        final rec = container.read(focusRecommendationProvider);
        expect(rec, isNull);
      });
    });
  });
}

class _MockTaskController extends TaskController {
  final List<TaskItem> _tasks;
  _MockTaskController(this._tasks);

  @override
  List<TaskItem> build() => List.from(_tasks);
}
