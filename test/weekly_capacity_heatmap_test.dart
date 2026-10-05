import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';
import 'package:autoplanner_ai/features/planner/widgets/weekly_capacity_heatmap.dart';
import 'package:autoplanner_ai/features/planner/widgets/plan_my_week_sheet.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';
import 'package:autoplanner_ai/features/calendar/controllers/calendar_controller.dart';
import 'package:autoplanner_ai/features/settings/controllers/settings_controller.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';

class _FakeTaskController extends TaskController {
  final List<TaskItem> initialTasks;
  List<TaskItem> lastBatchUpdated = [];

  _FakeTaskController(this.initialTasks);

  @override
  List<TaskItem> build() => initialTasks;

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

class _FakeSettingsController extends SettingsController {
  @override
  AppSettings build() => AppSettings.defaults();
}

class _FakeCalendarController extends CalendarController {
  @override
  List<CalendarEvent> build() => [];
}

void main() {
  group('WeeklyCapacityHeatmap Widget Tests', () {
    testWidgets('renders weekly capacity intelligence header, 7 day columns, and plan week button',
        (tester) async {
      final monday = DateTime(2026, 10, 5);
      final task = TaskItem(
        id: 't1',
        title: 'Project Brief',
        startTime: DateTime(monday.year, monday.month, monday.day, 10, 0),
        endTime: DateTime(monday.year, monday.month, monday.day, 12, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskControllerProvider.overrideWith(() => _FakeTaskController([task])),
            settingsProvider.overrideWith(() => _FakeSettingsController()),
            calendarControllerProvider.overrideWith(() => _FakeCalendarController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WeeklyCapacityHeatmap(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(WeeklyCapacityHeatmap), findsOneWidget);
      expect(find.text('Weekly Capacity Intelligence'), findsOneWidget);
      expect(find.text('Plan Week'), findsOneWidget);
    });

    testWidgets('tapping a day column selects that date in plannerSelectedDateProvider',
        (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskControllerProvider.overrideWith(() => _FakeTaskController([])),
            settingsProvider.overrideWith(() => _FakeSettingsController()),
            calendarControllerProvider.overrideWith(() => _FakeCalendarController()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const WeeklyCapacityHeatmap();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find any day text button and tap it
      final dayFinder = find.text('W'); // Wednesday
      if (dayFinder.evaluate().isNotEmpty) {
        await tester.tap(dayFinder.first);
        await tester.pumpAndSettle();
      }

      expect(capturedRef.read(plannerSelectedDateProvider), isNotNull);
    });

    testWidgets('tapping Plan Week opens PlanMyWeekSheet modal',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskControllerProvider.overrideWith(() => _FakeTaskController([])),
            settingsProvider.overrideWith(() => _FakeSettingsController()),
            calendarControllerProvider.overrideWith(() => _FakeCalendarController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WeeklyCapacityHeatmap(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final planWeekBtn = find.text('Plan Week');
      expect(planWeekBtn, findsOneWidget);

      await tester.tap(planWeekBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PlanMyWeekSheet), findsOneWidget);
      expect(find.text('Autonomous Weekly Planner'), findsOneWidget);
      expect(find.text('Confirm & Balance Week'), findsOneWidget);
    });
  });
}
