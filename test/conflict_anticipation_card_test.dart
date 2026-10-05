import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';
import 'package:autoplanner_ai/features/planner/widgets/conflict_anticipation_card.dart';
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
  group('ConflictAnticipationCard Widget Tests', () {
    testWidgets('renders SizedBox.shrink when there are no conflicts',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            anticipatedConflictsProvider.overrideWithValue([]),
            settingsProvider.overrideWith(() => _FakeSettingsController()),
            calendarControllerProvider.overrideWith(() => _FakeCalendarController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConflictAnticipationCard(),
            ),
          ),
        ),
      );

      expect(find.byType(ConflictAnticipationCard), findsOneWidget);
      expect(find.text('Conflict Anticipation'), findsNothing);
    });

    testWidgets('renders conflict anticipation card with count and 1-tap resolve',
        (tester) async {
      final base = DateTime(2026, 10, 2, 9, 0);
      final taskA = TaskItem(
        id: 't-1',
        title: 'Board Presentation Prep',
        startTime: base,
        endTime: base.add(const Duration(minutes: 60)),
      );
      final taskB = TaskItem(
        id: 't-2',
        title: 'Executive Sync',
        startTime: base.add(const Duration(minutes: 30)),
        endTime: base.add(const Duration(minutes: 90)),
      );

      final fakeConflict = AnticipatedConflict(
        id: 'conflict-overlap-1',
        type: ConflictType.directOverlap,
        severity: ConflictSeverity.critical,
        title: 'Direct Overlap Collision',
        description:
            '"Board Presentation Prep" collides with "Executive Sync" from 9:30 AM to 10:00 AM.',
        affectedTaskIds: ['t-1', 't-2'],
        anticipatedAt: base,
        resolutionAction: ConflictResolutionAction(
          actionType: 'reschedule_task',
          label: 'Shift Executive Sync by 30m',
          description: 'Move Executive Sync after Board Presentation Prep.',
          params: {
            'taskId': 't-2',
            'newStartTime': base.add(const Duration(minutes: 60)).toIso8601String(),
          },
        ),
      );

      final fakeCtrl = _FakeTaskController([taskA, taskB]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            anticipatedConflictsProvider.overrideWithValue([fakeConflict]),
            taskControllerProvider.overrideWith(() => fakeCtrl),
            settingsProvider.overrideWith(() => _FakeSettingsController()),
            calendarControllerProvider.overrideWith(() => _FakeCalendarController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ConflictAnticipationCard(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Conflict Anticipation'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Resolve'), findsOneWidget);
      expect(find.byIcon(Icons.radar_rounded), findsOneWidget);

      // Tap Resolve
      await tester.tap(find.text('Resolve'));
      await tester.pumpAndSettle();

      expect(fakeCtrl.lastBatchUpdated.length, 1);
      expect(fakeCtrl.lastBatchUpdated.first.id, 't-2');
      expect(fakeCtrl.lastBatchUpdated.first.startTime,
          base.add(const Duration(minutes: 60)));
      expect(find.textContaining('Conflict resolved'), findsOneWidget);
    });

    testWidgets('expands and displays all details and auto-resolve all action',
        (tester) async {
      final base = DateTime(2026, 10, 2, 9, 0);
      final task1 = TaskItem(
        id: 't-1',
        title: 'Task 1',
        startTime: base,
        endTime: base.add(const Duration(minutes: 45)),
      );
      final task2 = TaskItem(
        id: 't-2',
        title: 'Task 2',
        startTime: base.add(const Duration(minutes: 50)),
        endTime: base.add(const Duration(minutes: 90)),
      );

      final conflict1 = AnticipatedConflict(
        id: 'conflict-1',
        type: ConflictType.transitBufferCompression,
        severity: ConflictSeverity.warning,
        title: 'Buffer Compression',
        description: 'Only 5m buffer between Task 1 and Task 2.',
        affectedTaskIds: ['t-1', 't-2'],
        anticipatedAt: base,
        resolutionAction: ConflictResolutionAction(
          actionType: 'insert_buffer',
          label: 'Add 15m Buffer',
          description: 'Shift Task 2 to 10:00 AM.',
          params: {
            'taskId': 't-2',
            'bufferMinutes': 15,
          },
        ),
      );

      final conflict2 = AnticipatedConflict(
        id: 'conflict-2',
        type: ConflictType.deadlineCompression,
        severity: ConflictSeverity.critical,
        title: 'Deadline Risk',
        description: 'Task 1 has high deadline risk.',
        affectedTaskIds: ['t-1'],
        anticipatedAt: base,
        resolutionAction: ConflictResolutionAction(
          actionType: 'reschedule_task',
          label: 'Extend Margin',
          description: 'Start 30m earlier.',
          params: {
            'taskId': 't-1',
            'newStartTime': base.subtract(const Duration(minutes: 30)).toIso8601String(),
          },
        ),
      );

      final fakeCtrl = _FakeTaskController([task1, task2]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            anticipatedConflictsProvider.overrideWithValue([conflict1, conflict2]),
            taskControllerProvider.overrideWith(() => fakeCtrl),
            settingsProvider.overrideWith(() => _FakeSettingsController()),
            calendarControllerProvider.overrideWith(() => _FakeCalendarController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ConflictAnticipationCard(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);

      // Tap header to expand
      await tester.tap(find.text('Conflict Anticipation'));
      await tester.pumpAndSettle();

      expect(find.text('Buffer <15m'), findsOneWidget);
      expect(find.text('Deadline Risk'), findsOneWidget);
      expect(find.text('Auto-Resolve All (2)'), findsOneWidget);

      // Tap Auto-Resolve All
      await tester.tap(find.text('Auto-Resolve All (2)'));
      await tester.pumpAndSettle();

      expect(fakeCtrl.lastBatchUpdated.length, 2);
      expect(find.textContaining('All 2 schedule conflicts proactively resolved!'),
          findsOneWidget);
    });
  });
}
