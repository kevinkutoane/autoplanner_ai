import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/models/goal_model.dart';
import 'package:autoplanner_ai/core/models/memory_entry_model.dart';
import 'package:autoplanner_ai/core/models/note_model.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';
import 'package:autoplanner_ai/features/memory/controllers/memory_controller.dart';
import 'package:autoplanner_ai/features/notes/controllers/note_controller.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';
import 'package:autoplanner_ai/features/settings/controllers/settings_controller.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';
import 'package:autoplanner_ai/services/notification_id_generator.dart';
import 'package:autoplanner_ai/services/notification_service.dart';

class _TestSettingsController extends SettingsController {
  final AppSettings _initial;
  _TestSettingsController(this._initial);

  @override
  AppSettings build() => _initial;
}

class _FakeMemoryController extends MemoryController {
  @override
  List<MemoryEntry> build() => [];
  @override
  void addMemory(MemoryEntry entry) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('UTC'));

  late NotificationService service;
  late Directory tempDir;

  setUpAll(() {
    appConfig = const EnvConfig();
    tempDir = Directory.systemTemp.createTempSync(
      'notification_lifecycle_test_',
    );
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NoteItemAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(GoalItemAdapter());
  });

  tearDownAll(() {
    try {
      Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() {
    service = NotificationService();
    service.resetTestSeams();
    service.isReadyForTesting = true;
    service.onShowForTesting = (id, title, body, details) async {};
    service.onZonedScheduleForTesting = (
      id,
      title,
      body,
      date,
      details,
      mode,
      match,
    ) async {};
    service.onCancelForTesting = (id) async {};
  });

  tearDown(() {
    service.resetTestSeams();
  });

  group('Phase 1B.4 — 1. Urgent Task Alert and Reminder Disjoint IDs', () {
    test(
      'same urgent task schedules reminder and alert with non-identical IDs',
      () async {
        final scheduledCalls = <(int, String?)>[];
        final shownCalls = <(int, String?)>[];

        service.onZonedScheduleForTesting =
            (id, title, body, date, details, mode, match) async {
              scheduledCalls.add((id, title));
            };
        service.onShowForTesting = (id, title, body, details) async {
          shownCalls.add((id, title));
        };

        const taskId = 'urgent-task-uuid-101';
        final task = TaskItem(
          id: taskId,
          title: 'Launch Product V1',
          startTime: DateTime.now().toUtc().add(const Duration(hours: 2)),
          priority: 3, // Urgent
        );
        final settings = AppSettings.defaults();

        await service.scheduleTaskReminder(task, settings);
        await service.scheduleUrgentAlert(
          id: task.id,
          title: task.title,
          body: 'Urgent task added to your planner.',
        );

        expect(scheduledCalls.length, equals(1));
        expect(shownCalls.length, equals(1));

        final reminderId = scheduledCalls.first.$1;
        final alertId = shownCalls.first.$1;

        // Crucial assertion: Must NOT be equal!
        expect(reminderId, isNot(equals(alertId)));
        expect(
          reminderId,
          equals(NotificationIdGenerator.taskReminder(taskId)),
        );
        expect(alertId, equals(NotificationIdGenerator.taskUrgent(taskId)));
      },
    );
  });

  group('Phase 1B.4 — 2. Urgent Note Alert and Reminder Disjoint IDs', () {
    test(
      'same urgent note schedules reminder and alert with non-identical IDs',
      () async {
        final scheduledCalls = <(int, String?)>[];
        final shownCalls = <(int, String?)>[];

        service.onZonedScheduleForTesting =
            (id, title, body, date, details, mode, match) async {
              scheduledCalls.add((id, title));
            };
        service.onShowForTesting = (id, title, body, details) async {
          shownCalls.add((id, title));
        };

        const noteId = 'urgent-note-uuid-202';
        final note = NoteItem(
          id: noteId,
          title: 'Board Meeting Brief',
          content: 'Brief notes for board meeting',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isUrgent: true,
          reminderAt: DateTime.now().toUtc().add(const Duration(hours: 3)),
        );

        await service.scheduleNoteReminder(note);
        await service.scheduleUrgentAlert(
          id: 'note_${note.id}',
          title: note.title,
          body: 'Urgent note requires your attention.',
        );

        expect(scheduledCalls.length, equals(1));
        expect(shownCalls.length, equals(1));

        final reminderId = scheduledCalls.first.$1;
        final alertId = shownCalls.first.$1;

        expect(reminderId, isNot(equals(alertId)));
        expect(
          reminderId,
          equals(NotificationIdGenerator.noteReminder(noteId)),
        );
        expect(alertId, equals(NotificationIdGenerator.noteUrgent(noteId)));
      },
    );
  });

  group('Phase 1B.4 — 3. Scheduling and Cancellation Identity Consistency', () {
    test(
      'task reminder schedule and cancel resolve to the exact same ID',
      () async {
        int? scheduledId;
        final cancelledIds = <int>[];

        service.onZonedScheduleForTesting =
            (id, title, body, date, details, mode, match) async {
              scheduledId = id;
            };
        service.onCancelForTesting = (id) async {
          cancelledIds.add(id);
        };

        const taskId = 'consistency-task-303';
        final task = TaskItem(
          id: taskId,
          title: 'Review PR',
          startTime: DateTime.now().toUtc().add(const Duration(hours: 1)),
          priority: 2,
        );

        await service.scheduleTaskReminder(task, AppSettings.defaults());
        await service.cancelTaskReminder(taskId);

        expect(
          scheduledId,
          equals(NotificationIdGenerator.taskReminder(taskId)),
        );
        expect(cancelledIds, contains(scheduledId));
      },
    );

    test(
      'goal deadline schedule and cancel resolve to the exact same ID',
      () async {
        int? scheduledId;
        final cancelledIds = <int>[];

        service.onZonedScheduleForTesting =
            (id, title, body, date, details, mode, match) async {
              scheduledId = id;
            };
        service.onCancelForTesting = (id) async {
          cancelledIds.add(id);
        };

        const goalId = 'goal-uuid-304';
        final goal = GoalItem(
          id: goalId,
          title: 'Complete Phase 1B',
          deadline: DateTime.now().toUtc().add(const Duration(days: 3)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await service.scheduleGoalDeadlineReminder(goal);
        await service.cancelGoalDeadlineReminder(goalId);

        expect(
          scheduledId,
          equals(NotificationIdGenerator.goalDeadline(goalId)),
        );
        expect(cancelledIds, contains(scheduledId));
      },
    );

    test(
      'daily ritual schedules and cancellations resolve to exact fixed IDs',
      () async {
        final scheduledIds = <int>[];
        final cancelledIds = <int>[];

        service.onZonedScheduleForTesting =
            (id, title, body, date, details, mode, match) async {
              scheduledIds.add(id);
            };
        service.onCancelForTesting = (id) async {
          cancelledIds.add(id);
        };

        await service.scheduleMorningBriefing(hour: 8, minute: 0);
        await service.cancelMorningBriefing();
        await service.scheduleEveningShutdown(hour: 17, minute: 30);
        await service.cancelEveningShutdown();
        await service.scheduleStreakShield(currentStreak: 5);
        await service.cancelStreakShield();

        expect(scheduledIds, equals([9000, 9001, 9002]));
        expect(cancelledIds, equals([9000, 9001, 9002]));
      },
    );
  });

  group(
    'Phase 1B.4 — 4. Determinism Across Independent Executions and Contexts',
    () {
      test('deterministic FNV-1a produces identical IDs across independent instances', () {
        const fixtures = [
          'd41e75ca-3d44-469e-bfec-59114dca21e2',
          'a61b85fa-1234-4567-89ab-cdef01234567',
          'fixed-id-sample-xyz',
          '',
          'unicode-αβγ-🚀-999',
        ];

        for (final fixture in fixtures) {
          final hash1 = NotificationIdGenerator.fnv1a32(fixture);
          final hash2 = NotificationIdGenerator.fnv1a32(fixture);
          expect(hash1, equals(hash2));

          final taskRem1 = NotificationIdGenerator.taskReminder(fixture);
          final taskRem2 = NotificationIdGenerator.taskReminder(fixture);
          expect(taskRem1, equals(taskRem2));

          final taskUrg1 = NotificationIdGenerator.taskUrgent(fixture);
          final taskUrg2 = NotificationIdGenerator.taskUrgent(fixture);
          expect(taskUrg1, equals(taskUrg2));

          final noteRem1 = NotificationIdGenerator.noteReminder(fixture);
          final noteRem2 = NotificationIdGenerator.noteReminder(fixture);
          expect(noteRem1, equals(noteRem2));
        }
      });
    },
  );

  group(
    'Phase 1B.4 — 5. Range and Platform Constraints & Disjoint Namespaces',
    () {
      test('all domains are mathematically disjoint and fit within positive 32-bit int', () {
        const uuid = Uuid();
        const numSamples = 2000;

        for (var i = 0; i < numSamples; i++) {
          final id = uuid.v4();

          final taskRem = NotificationIdGenerator.taskReminder(id);
          final taskUrg = NotificationIdGenerator.taskUrgent(id);
          final noteRem = NotificationIdGenerator.noteReminder(id);
          final noteUrg = NotificationIdGenerator.noteUrgent(id);
          final goalRem = NotificationIdGenerator.goalDeadline(id);

          // Positive 32-bit integer bound (0 to 0x7FFFFFFF)
          for (final generatedId in [
            taskRem,
            taskUrg,
            noteRem,
            noteUrg,
            goalRem,
          ]) {
            expect(generatedId >= 0, isTrue);
            expect(generatedId <= 0x7FFFFFFF, isTrue);
            // Never collides with fixed system IDs (9000-9099)
            expect(generatedId > 100000, isTrue);
          }

          // Domain 1: Task Reminders: [134,217,728, 268,435,455]
          expect(taskRem >= (1 << 27), isTrue);
          expect(taskRem < (2 << 27), isTrue);

          // Domain 2: Task Urgent: [268,435,456, 402,653,183]
          expect(taskUrg >= (2 << 27), isTrue);
          expect(taskUrg < (3 << 27), isTrue);

          // Domain 3: Note Reminders: [402,653,184, 536,870,911]
          expect(noteRem >= (3 << 27), isTrue);
          expect(noteRem < (4 << 27), isTrue);

          // Domain 4: Note Urgent: [536,870,912, 671,088,639]
          expect(noteUrg >= (4 << 27), isTrue);
          expect(noteUrg < (5 << 27), isTrue);

          // Domain 5: Goal Deadline: [671,088,640, 805,306,367]
          expect(goalRem >= (5 << 27), isTrue);
          expect(goalRem < (6 << 27), isTrue);

          // Pairwise disjoint check for same entity ID
          final idsSet = {taskRem, taskUrg, noteRem, noteUrg, goalRem};
          expect(
            idsSet.length,
            equals(5),
            reason: 'All 5 notification IDs for the same ID must be mutually distinct',
          );
        }
      });
    },
  );

  group('Phase 1B.4 — 6. Entity Lifecycle: Task & Note Controller Integration', () {
    late ProviderContainer container;
    late Box<TaskItem> tasksBox;
    late Box<NoteItem> notesBox;

    setUp(() async {
      tasksBox = await Hive.openBox<TaskItem>('tasksBox');
      notesBox = await Hive.openBox<NoteItem>('notesBox');
      await tasksBox.clear();
      await notesBox.clear();

      container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(service),
          settingsProvider.overrideWith(
            () => _TestSettingsController(AppSettings.defaults()),
          ),
          memoryControllerProvider.overrideWith(() => _FakeMemoryController()),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await tasksBox.clear();
      await notesBox.clear();
    });

    test('TaskController: adding urgent task schedules timed reminder and urgent alert with distinct IDs', () async {
      final scheduledIds = <int>[];
      final shownIds = <int>[];

      service.onZonedScheduleForTesting =
          (id, title, body, date, details, mode, match) async {
            scheduledIds.add(id);
          };
      service.onShowForTesting = (id, title, body, details) async {
        shownIds.add(id);
      };

      final controller = container.read(taskControllerProvider.notifier);
      final task = TaskItem(
        id: 'urgent-task-lifecycle-1',
        title: 'Emergency Server Patch',
        startTime: DateTime.now().toUtc().add(const Duration(hours: 4)),
        priority: 3, // Urgent
      );

      controller.addTask(task);
      await Future<void>.delayed(Duration.zero);

      expect(scheduledIds.length, equals(1));
      expect(shownIds.length, equals(1));
      expect(scheduledIds.first, isNot(equals(shownIds.first)));
      expect(
        scheduledIds.first,
        equals(NotificationIdGenerator.taskReminder(task.id)),
      );
      expect(
        shownIds.first,
        equals(NotificationIdGenerator.taskUrgent(task.id)),
      );
    });

    test(
      'TaskController: demoting urgent task priority cancels the urgent alert',
      () async {
        final cancelledIds = <int>[];

        service.onCancelForTesting = (id) async {
          cancelledIds.add(id);
        };

        final controller = container.read(taskControllerProvider.notifier);
        final task = TaskItem(
          id: 'urgent-demote-task-2',
          title: 'Server Patch',
          startTime: DateTime.now().toUtc().add(const Duration(hours: 4)),
          priority: 3,
        );

        controller.addTask(task);
        await Future<void>.delayed(Duration.zero);
        cancelledIds.clear();

        // Demote to priority 2 (High)
        final demoted = task.copyWith(priority: 2);
        controller.updateTask(demoted);
        await Future<void>.delayed(Duration.zero);

        final urgentId = NotificationIdGenerator.taskUrgent(task.id);
        expect(cancelledIds, contains(urgentId));
      },
    );

    test('TaskController: completing task cancels both timed reminder and urgent alert', () async {
      final cancelledIds = <int>[];

      service.onCancelForTesting = (id) async {
        cancelledIds.add(id);
      };

      final controller = container.read(taskControllerProvider.notifier);
      final task = TaskItem(
        id: 'complete-task-3',
        title: 'Submit Report',
        startTime: DateTime.now().toUtc().add(const Duration(hours: 2)),
        priority: 3,
      );

      controller.addTask(task);
      await Future<void>.delayed(Duration.zero);
      cancelledIds.clear();

      final completed = task.copyWith(isCompleted: true);
      controller.updateTask(completed);
      await Future<void>.delayed(Duration.zero);

      expect(
        cancelledIds,
        contains(NotificationIdGenerator.taskReminder(task.id)),
      );
      expect(
        cancelledIds,
        contains(NotificationIdGenerator.taskUrgent(task.id)),
      );
    });

    test('TaskController: deleting task cancels both timed reminder and urgent alert', () async {
      final cancelledIds = <int>[];

      service.onCancelForTesting = (id) async {
        cancelledIds.add(id);
      };

      final controller = container.read(taskControllerProvider.notifier);
      final task = TaskItem(
        id: 'delete-task-4',
        title: 'Throwaway Task',
        startTime: DateTime.now().toUtc().add(const Duration(hours: 2)),
        priority: 3,
      );

      controller.addTask(task);
      await Future<void>.delayed(Duration.zero);
      cancelledIds.clear();

      controller.removeTask(task.id);
      await Future<void>.delayed(Duration.zero);

      expect(
        cancelledIds,
        contains(NotificationIdGenerator.taskReminder(task.id)),
      );
      expect(
        cancelledIds,
        contains(NotificationIdGenerator.taskUrgent(task.id)),
      );
    });

    test('NoteController: toggling urgent off cancels urgent alert', () async {
      final shownIds = <int>[];
      final cancelledIds = <int>[];

      service.onShowForTesting = (id, title, body, details) async {
        shownIds.add(id);
      };
      service.onCancelForTesting = (id) async {
        cancelledIds.add(id);
      };

      final controller = container.read(noteControllerProvider.notifier);
      final note = NoteItem(
        id: 'toggle-note-5',
        title: 'Client Note',
        content: 'Client project discussion notes',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isUrgent: true,
      );

      controller.addNote(note);
      await Future<void>.delayed(Duration.zero);
      expect(shownIds, contains(NotificationIdGenerator.noteUrgent(note.id)));

      // Toggle urgent off
      controller.toggleUrgent(note.id);
      await Future<void>.delayed(Duration.zero);
      expect(
        cancelledIds,
        contains(NotificationIdGenerator.noteUrgent(note.id)),
      );
    });

    test(
      'NoteController: deleting note cancels reminder and urgent alert',
      () async {
        final cancelledIds = <int>[];

        service.onCancelForTesting = (id) async {
          cancelledIds.add(id);
        };

        final controller = container.read(noteControllerProvider.notifier);
        final note = NoteItem(
          id: 'delete-note-6',
          title: 'Delete Note',
          content: 'Note to be deleted',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isUrgent: true,
          reminderAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );

        controller.addNote(note);
        await Future<void>.delayed(Duration.zero);
        cancelledIds.clear();

        controller.removeNote(note.id);
        await Future<void>.delayed(Duration.zero);

        expect(
          cancelledIds,
          contains(NotificationIdGenerator.noteReminder(note.id)),
        );
        expect(
          cancelledIds,
          contains(NotificationIdGenerator.noteUrgent(note.id)),
        );
      },
    );
  });

  group('Phase 1B.4 — 7. Goal Reminder Namespace Isolation', () {
    test('goal reminders cannot collide with other notification domains', () {
      const sampleId = 'entity-isolation-id-777';

      final goalId = NotificationIdGenerator.goalDeadline(sampleId);
      final taskReminderId = NotificationIdGenerator.taskReminder(sampleId);
      final taskUrgentId = NotificationIdGenerator.taskUrgent(sampleId);
      final noteReminderId = NotificationIdGenerator.noteReminder(sampleId);
      final noteUrgentId = NotificationIdGenerator.noteUrgent(sampleId);

      expect(goalId, isNot(equals(taskReminderId)));
      expect(goalId, isNot(equals(taskUrgentId)));
      expect(goalId, isNot(equals(noteReminderId)));
      expect(goalId, isNot(equals(noteUrgentId)));

      // Verify domain 5 bounds
      expect(goalId >= 671088640, isTrue);
      expect(goalId < 805306368, isTrue);
    });
  });

  group('Phase 1B.4 — 8. Backward-Compatible Cancellation for Pre-Upgrade Alarms', () {
    test('cancelTaskReminder cancels both new deterministic ID and legacy taskId.hashCode', () async {
      final cancelledIds = <int>[];

      service.onCancelForTesting = (id) async {
        cancelledIds.add(id);
      };

      const taskId = 'pre-upgrade-task-888';
      await service.cancelTaskReminder(taskId);

      final expectedNewId = NotificationIdGenerator.taskReminder(taskId);
      final expectedLegacyId = taskId.hashCode;

      expect(cancelledIds, contains(expectedNewId));
      expect(cancelledIds, contains(expectedLegacyId));
    });

    test(
      'cancelNoteReminder cancels both new deterministic ID and legacy note ID',
      () async {
        final cancelledIds = <int>[];

        service.onCancelForTesting = (id) async {
          cancelledIds.add(id);
        };

        const noteId = 'pre-upgrade-note-889';
        await service.cancelNoteReminder(noteId);

        final expectedNewId = NotificationIdGenerator.noteReminder(noteId);
        final expectedLegacyId = 'note_$noteId'.hashCode;

        expect(cancelledIds, contains(expectedNewId));
        expect(cancelledIds, contains(expectedLegacyId));
      },
    );

    test('cancelGoalDeadlineReminder cancels both new deterministic ID and legacy goal ID', () async {
      final cancelledIds = <int>[];

      service.onCancelForTesting = (id) async {
        cancelledIds.add(id);
      };

      const goalId = 'pre-upgrade-goal-890';
      await service.cancelGoalDeadlineReminder(goalId);

      final expectedNewId = NotificationIdGenerator.goalDeadline(goalId);
      final expectedLegacyId = goalId.hashCode + 1000000;

      expect(cancelledIds, contains(expectedNewId));
      expect(cancelledIds, contains(expectedLegacyId));
    });
  });

  group('Phase 1B.4 — 9. Obsolete task_start_ Removal Verification', () {
    test(
      'cancelTaskReminder does NOT attempt to cancel task_start_ prefix',
      () async {
        final cancelledIds = <int>[];

        service.onCancelForTesting = (id) async {
          cancelledIds.add(id);
        };

        const taskId = 'obsolete-code-test-999';
        await service.cancelTaskReminder(taskId);

        final obsoleteId = 'task_start_$taskId'.hashCode;

        // Confirms dead code removal
        expect(cancelledIds, isNot(contains(obsoleteId)));
        expect(
          cancelledIds.length,
          equals(2),
          reason: 'Only current taskReminder and legacy taskId.hashCode',
        );
      },
    );
  });
}
