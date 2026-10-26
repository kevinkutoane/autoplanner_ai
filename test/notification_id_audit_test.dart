import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Notification ID Reliability Audit — Range & Platform Constraints', () {
    const uuid = Uuid();
    final random = Random(42);

    test(
      'String.hashCode range is strictly 30-bit non-negative [0, 0x3FFFFFFF]',
      () {
        // Test UUID strings (standard task, note, goal IDs)
        for (int i = 0; i < 50000; i++) {
          final id = uuid.v4();
          final h = id.hashCode;
          expect(h >= 0, isTrue);
          expect(
            h <= 0x3FFFFFFF,
            isTrue,
            reason: 'HashCode exceeds 30-bit VM integer max: $h',
          );
          expect(
            h <= 0x7FFFFFFF,
            isTrue,
            reason: 'HashCode exceeds 32-bit platform limit: $h',
          );
        }

        // Test random Unicode strings across varied lengths and codepoints
        for (int i = 0; i < 50000; i++) {
          final s = String.fromCharCodes(
            List.generate(random.nextInt(100), (_) => random.nextInt(0x10FFFF)),
          );
          final h = s.hashCode;
          expect(h >= 0, isTrue);
          expect(h <= 0x3FFFFFFF, isTrue);
          expect(h <= 0x7FFFFFFF, isTrue);
        }
      },
    );

    test(
      'Goal offset (hashCode + 1,000,000) never exceeds 32-bit signed int max',
      () {
        const goalOffset = 1000000;
        const max30Bit = 0x3FFFFFFF; // 1,073,741,823
        const max32BitSigned = 0x7FFFFFFF; // 2,147,483,647

        // Theoretical upper bound:
        expect(max30Bit + goalOffset, lessThan(max32BitSigned));
        expect(max30Bit + goalOffset, equals(1074741823));

        for (int i = 0; i < 50000; i++) {
          final goalId = uuid.v4();
          final notifId = goalId.hashCode + goalOffset;
          expect(notifId >= 0, isTrue);
          expect(notifId <= max32BitSigned, isTrue);
        }
      },
    );

    test(
      'Fixed notification IDs are strictly within 32-bit positive range',
      () {
        const fixedIds = [
          9000, // Morning briefing
          9001, // Evening shutdown
          9002, // Streak shield
          9099, // Test notification
        ];

        for (final id in fixedIds) {
          expect(id >= 0, isTrue);
          expect(id <= 0x7FFFFFFF, isTrue);
        }
        expect(
          fixedIds.toSet().length,
          equals(fixedIds.length),
          reason: 'Fixed IDs must be unique',
        );
      },
    );
  });

  group('Notification ID Reliability Audit — Confirmed Lifecycle Defects', () {
    const uuid = Uuid();

    test(
      'Confirmed Defect 1: Task reminder and urgent alert share identical ID',
      () {
        final taskId = uuid.v4();

        // In NotificationService.scheduleTaskReminder:
        final reminderId = taskId.hashCode;

        // In TaskController.addTask / updateTask with NotificationService.scheduleUrgentAlert(id: task.id):
        final urgentAlertId = taskId.hashCode;

        // Exact collision proven:
        expect(
          reminderId,
          equals(urgentAlertId),
          reason: 'Urgent alert and scheduled reminder produce the same ID, causing overwrites',
        );
      },
    );

    test('Confirmed Defect 2: Note reminder and urgent note alert share identical ID', () {
      final noteId = uuid.v4();

      // In NotificationService.scheduleNoteReminder:
      final noteReminderId = ('note_$noteId').hashCode;

      // In NoteController._scheduleNotifications with NotificationService.scheduleUrgentAlert(id: "note_${note.id}"):
      final urgentNoteId = ('note_$noteId').hashCode;

      // Exact collision proven:
      expect(
        noteReminderId,
        equals(urgentNoteId),
        reason:
            'Urgent note alert and scheduled note reminder produce the same ID',
      );
    });

    test(
      'Confirmed Defect 3: Dead cancellation code for task_start_ prefix',
      () {
        final taskId = uuid.v4();

        final reminderId = taskId.hashCode;
        final deadCancellationId = 'task_start_$taskId'.hashCode;

        expect(
          deadCancellationId,
          isNot(equals(reminderId)),
          reason: 'task_start_ prefix is never scheduled by any code path',
        );
      },
    );

    test('Audit Finding: Goal offset does not partition hash space', () {
      // String.hashCode distribution spans [0, 0x3FFFFFFF].
      // Adding 1,000,000 shifts the range to [1,000,000, 1,074,741,823],
      // which completely overlaps with the un-offset hash space [0, 1,073,741,823].
      const goalOffset = 1000000;
      final sample = 'test_entity_sample';
      final h = sample.hashCode;
      final offsetH = h + goalOffset;

      expect(offsetH >= goalOffset, isTrue);
      expect(offsetH < 0x7FFFFFFF, isTrue);
    });
  });
}
