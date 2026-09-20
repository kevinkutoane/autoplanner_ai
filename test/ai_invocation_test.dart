import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/ai/ai_invocation.dart';

void main() {
  group('AIOperation', () {
    test('all 13 operations have distinct non-empty wireNames', () {
      final operations = AIOperation.values;
      expect(operations.length, equals(13));

      final wireNames = operations.map((op) => op.wireName).toSet();
      expect(wireNames.length, equals(13));

      for (final op in operations) {
        expect(op.wireName.isNotEmpty, isTrue);
        expect(op.wireName, equals(op.wireName.toLowerCase()));
      }
    });

    test('tryParse parses exact wire names', () {
      expect(AIOperation.tryParse('brain_dump'), equals(AIOperation.brainDump));
      expect(
        AIOperation.tryParse('parse_tasks'),
        equals(AIOperation.parseTasks),
      );
      expect(AIOperation.tryParse('plan_day'), equals(AIOperation.planDay));
      expect(AIOperation.tryParse('chat_coach'), equals(AIOperation.chatCoach));
      expect(
        AIOperation.tryParse('daily_insight'),
        equals(AIOperation.dailyInsight),
      );
      expect(
        AIOperation.tryParse('suggest_reschedule'),
        equals(AIOperation.suggestReschedule),
      );
      expect(
        AIOperation.tryParse('summarize_note'),
        equals(AIOperation.summarizeNote),
      );
      expect(
        AIOperation.tryParse('generate_tags'),
        equals(AIOperation.generateTags),
      );
      expect(
        AIOperation.tryParse('extract_memory'),
        equals(AIOperation.extractMemory),
      );
      expect(
        AIOperation.tryParse('extract_patterns'),
        equals(AIOperation.extractPatterns),
      );
      expect(
        AIOperation.tryParse('suggest_tasks'),
        equals(AIOperation.suggestTasks),
      );
      expect(
        AIOperation.tryParse('weekly_review'),
        equals(AIOperation.weeklyReview),
      );
      expect(
        AIOperation.tryParse('parse_schedule_command'),
        equals(AIOperation.parseScheduleCommand),
      );
    });

    test('tryParse parses enum names and case-insensitive inputs', () {
      expect(AIOperation.tryParse('brainDump'), equals(AIOperation.brainDump));
      expect(
        AIOperation.tryParse('PARSE_TASKS'),
        equals(AIOperation.parseTasks),
      );
      expect(
        AIOperation.tryParse('  chat_coach  '),
        equals(AIOperation.chatCoach),
      );
      expect(AIOperation.tryParse('unknown_operation'), isNull);
      expect(AIOperation.tryParse(null), isNull);
    });
  });

  group('AIInvocation', () {
    test('serializes to JSON correctly with wireName', () {
      final now = DateTime.utc(2026, 9, 19, 20, 0, 0);
      final invocation = AIInvocation(
        id: 'inv-1234',
        operation: AIOperation.brainDump,
        input: {'rawInput': 'Finish quarterly tax review'},
        context: {'workHours': 8},
        client: {'appVersion': '2.3.1', 'platform': 'android'},
        timestamp: now,
      );

      final json = invocation.toJson();

      expect(json['id'], equals('inv-1234'));
      expect(json['operation'], equals('brain_dump'));
      expect(
        json['input'],
        equals({'rawInput': 'Finish quarterly tax review'}),
      );
      expect(json['context'], equals({'workHours': 8}));
      expect(
        json['client'],
        equals({'appVersion': '2.3.1', 'platform': 'android'}),
      );
      expect(json['timestamp'], equals(now.toIso8601String()));
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'inv-5678',
        'operation': 'plan_day',
        'input': {'additionalInput': 'Gym at 5pm'},
        'context': {'workStartHour': 9},
        'client': {'platform': 'ios'},
        'timestamp': '2026-09-19T20:00:00.000Z',
      };

      final invocation = AIInvocation.fromJson(json);

      expect(invocation.id, equals('inv-5678'));
      expect(invocation.operation, equals(AIOperation.planDay));
      expect(invocation.input['additionalInput'], equals('Gym at 5pm'));
      expect(invocation.context['workStartHour'], equals(9));
      expect(invocation.client['platform'], equals('ios'));
      expect(
        invocation.timestamp.toUtc(),
        equals(DateTime.utc(2026, 9, 19, 20, 0, 0)),
      );
    });

    test('deserializes gracefully with missing optional fields', () {
      final invocation = AIInvocation.fromJson({
        'id': 'inv-default',
        'input': {'text': 'test'},
      });

      expect(invocation.id, equals('inv-default'));
      expect(invocation.operation, equals(AIOperation.parseTasks));
      expect(invocation.input, equals({'text': 'test'}));
      expect(invocation.context, isEmpty);
      expect(invocation.client, isEmpty);
      expect(invocation.timestamp, isNotNull);
    });

    test('copyWith updates specified fields only', () {
      final original = AIInvocation(
        id: 'orig-1',
        operation: AIOperation.summarizeNote,
        input: {'content': 'My notes'},
      );

      final copy = original.copyWith(
        id: 'copy-1',
        operation: AIOperation.generateTags,
        input: {'content': 'Updated notes'},
      );

      expect(copy.id, equals('copy-1'));
      expect(copy.operation, equals(AIOperation.generateTags));
      expect(copy.input['content'], equals('Updated notes'));
      expect(copy.context, isEmpty);
    });
  });
}
