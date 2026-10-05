import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/core/models/goal_model.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';
import 'package:autoplanner_ai/features/calendar/controllers/calendar_controller.dart';
import 'package:autoplanner_ai/features/goals/controllers/goal_controller.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';
import 'package:autoplanner_ai/features/planner/screens/planner_screen.dart';
import 'package:autoplanner_ai/features/planner/widgets/sample_starter_plan_card.dart';
import 'package:autoplanner_ai/features/settings/controllers/settings_controller.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';

class _MockTaskController extends TaskController {
  final List<TaskItem> _tasks;
  List<TaskItem> lastBatchUpdated = [];

  _MockTaskController(this._tasks);

  @override
  List<TaskItem> build() => _tasks;

  @override
  void batchUpdateTasks(List<TaskItem> tasks) {
    lastBatchUpdated = tasks;
    final map = {for (final t in state) t.id: t};
    for (final t in tasks) {
      map[t.id] = t;
    }
    state = map.values.toList();
  }
}

class _MockSettingsController extends SettingsController {
  final AppSettings _initial;
  bool dismissedStarterPlanCalled = false;

  _MockSettingsController(this._initial);

  @override
  AppSettings build() => _initial;

  @override
  Future<void> dismissStarterPlan() async {
    dismissedStarterPlanCalled = true;
    state = state.copyWith(hasDismissedStarterPlan: true);
  }
}

class _MockGoalController extends GoalController {
  @override
  List<GoalItem> build() => [];
}

class _MockCalendarController extends CalendarController {
  @override
  List<CalendarEvent> build() => [];
}

void main() {
  group('SampleStarterPlanCard Tests', () {
    testWidgets('renders all feature highlights and CTA buttons', (tester) async {
      final settingsCtrl = _MockSettingsController(AppSettings.defaults());
      final taskCtrl = _MockTaskController([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => settingsCtrl),
            taskControllerProvider.overrideWith(() => taskCtrl),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SampleStarterPlanCard(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Welcome to AutoPlanner AI'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Peak Energy Timing'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Locked Events'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Smart Breaks & Recovery'),
        ),
        findsOneWidget,
      );
      expect(find.text('Load Sample Plan'), findsOneWidget);
      expect(find.text('Start Fresh'), findsOneWidget);
    });

    testWidgets('tapping Load Sample Plan batches 4 tasks and dismisses starter pack',
        (tester) async {
      final settingsCtrl = _MockSettingsController(AppSettings.defaults());
      final taskCtrl = _MockTaskController([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => settingsCtrl),
            taskControllerProvider.overrideWith(() => taskCtrl),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SampleStarterPlanCard(),
              ),
            ),
          ),
        ),
      );

      final loadButton = find.text('Load Sample Plan');
      expect(loadButton, findsOneWidget);

      await tester.tap(loadButton);
      await tester.pumpAndSettle();

      expect(taskCtrl.lastBatchUpdated.length, 4);
      expect(settingsCtrl.dismissedStarterPlanCalled, isTrue);
      expect(find.textContaining('Sample workday loaded!'), findsOneWidget);
    });

    testWidgets('tapping Start Fresh dismisses starter plan without loading tasks',
        (tester) async {
      final settingsCtrl = _MockSettingsController(AppSettings.defaults());
      final taskCtrl = _MockTaskController([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => settingsCtrl),
            taskControllerProvider.overrideWith(() => taskCtrl),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SampleStarterPlanCard(),
              ),
            ),
          ),
        ),
      );

      final startFreshButton = find.text('Start Fresh');
      expect(startFreshButton, findsOneWidget);

      await tester.tap(startFreshButton);
      await tester.pumpAndSettle();

      expect(taskCtrl.lastBatchUpdated.isEmpty, isTrue);
      expect(settingsCtrl.dismissedStarterPlanCalled, isTrue);
    });

    testWidgets('dismiss close icon calls dismissStarterPlan', (tester) async {
      final settingsCtrl = _MockSettingsController(AppSettings.defaults());
      final taskCtrl = _MockTaskController([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => settingsCtrl),
            taskControllerProvider.overrideWith(() => taskCtrl),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SampleStarterPlanCard(),
              ),
            ),
          ),
        ),
      );

      final closeIcon = find.byTooltip('Dismiss starter pack');
      expect(closeIcon, findsOneWidget);

      await tester.tap(closeIcon);
      await tester.pumpAndSettle();

      expect(settingsCtrl.dismissedStarterPlanCalled, isTrue);
    });
  });

  group('PlannerScreen Starter Plan Integration Tests', () {
    testWidgets('displays SampleStarterPlanCard when tasks are empty and not dismissed',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final settingsCtrl = _MockSettingsController(
        AppSettings.defaults().copyWith(hasDismissedStarterPlan: false),
      );
      final taskCtrl = _MockTaskController([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => settingsCtrl),
            taskControllerProvider.overrideWith(() => taskCtrl),
            goalControllerProvider.overrideWith(() => _MockGoalController()),
            calendarControllerProvider.overrideWith(() => _MockCalendarController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PlannerScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(SampleStarterPlanCard), findsOneWidget);
    });

    testWidgets('hides SampleStarterPlanCard when hasDismissedStarterPlan is true',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final settingsCtrl = _MockSettingsController(
        AppSettings.defaults().copyWith(hasDismissedStarterPlan: true),
      );
      final taskCtrl = _MockTaskController([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(() => settingsCtrl),
            taskControllerProvider.overrideWith(() => taskCtrl),
            goalControllerProvider.overrideWith(() => _MockGoalController()),
            calendarControllerProvider.overrideWith(() => _MockCalendarController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PlannerScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(SampleStarterPlanCard), findsNothing);
    });
  });
}
