import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/ai/ai_validator.dart';

void main() {
  group('AIValidator', () {
    test('extractArray extracts simple array', () {
      final input = '```json\n[1, 2, 3]\n```';
      final result = AIValidator.extractArray(input, context: 'test');
      expect(result, equals([1, 2, 3]));
    });

    test('extractArray throws on missing array', () {
      final input = 'No array here';
      expect(
        () => AIValidator.extractArray(input, context: 'test'),
        throwsA(isA<AIValidationException>()),
      );
    });

    test('extractObject extracts object', () {
      final input = '```json\n{"key": "value"}\n```';
      final result = AIValidator.extractObject(input, context: 'test');
      expect(result, equals({'key': 'value'}));
    });

    test('extractObject throws when array is found instead', () {
      final input = '```json\n[1, 2, 3]\n```';
      expect(
        () => AIValidator.extractObject(input, context: 'test'),
        throwsA(isA<AIValidationException>()),
      );
    });

    test('validateSchema passes for valid data', () {
      final data = {'title': 'Hello', 'count': 5, 'active': true};
      final schema = {'title': String, 'count': int, 'active': bool};

      expect(
        () => AIValidator.validateSchema(data, schema, context: 'test'),
        returnsNormally,
      );
    });

    test('validateSchema throws for missing field', () {
      final data = {'title': 'Hello'};
      final schema = {'title': String, 'count': int};

      expect(
        () => AIValidator.validateSchema(data, schema, context: 'test'),
        throwsA(
          isA<AIValidationException>().having(
            (e) => e.message,
            'message',
            contains('Missing required field'),
          ),
        ),
      );
    });

    test('validateSchema throws for wrong type', () {
      final data = {'count': '5'}; // should be int
      final schema = {'count': int};

      expect(
        () => AIValidator.validateSchema(data, schema, context: 'test'),
        throwsA(
          isA<AIValidationException>().having(
            (e) => e.message,
            'message',
            contains('invalid type'),
          ),
        ),
      );
    });

    group('validateTaskDomain', () {
      test('passes for valid task', () {
        final task = {
          'title': 'Valid Task',
          'priority': 2,
          'estimatedMinutes': 60,
          'startTime': '09:30',
        };
        expect(
          () => AIValidator.validateTaskDomain(task, context: 'test'),
          returnsNormally,
        );
      });

      test('passes for task with valid single-digit hour startTime', () {
        final task = {'title': 'Morning Task', 'startTime': '7:30'};
        expect(
          () => AIValidator.validateTaskDomain(task, context: 'test'),
          returnsNormally,
        );
      });

      test('throws AIDomainValidationException for missing title', () {
        final task = {'priority': 1};
        expect(
          () => AIValidator.validateTaskDomain(task, context: 'test'),
          throwsA(
            isA<AIDomainValidationException>().having(
              (e) => e.message,
              'message',
              contains('Missing required field: "title"'),
            ),
          ),
        );
      });

      test('throws AIDomainValidationException for empty or blank title', () {
        final task1 = {'title': ''};
        final task2 = {'title': '   '};
        expect(
          () => AIValidator.validateTaskDomain(task1, context: 'test'),
          throwsA(isA<AIDomainValidationException>()),
        );
        expect(
          () => AIValidator.validateTaskDomain(task2, context: 'test'),
          throwsA(isA<AIDomainValidationException>()),
        );
      });

      test('throws AIDomainValidationException for non-string title', () {
        final task = {'title': 12345};
        expect(
          () => AIValidator.validateTaskDomain(task, context: 'test'),
          throwsA(isA<AIDomainValidationException>()),
        );
      });

      test('throws AIDomainValidationException for out-of-bounds priority', () {
        final low = {'title': 'Task', 'priority': -1};
        final high = {'title': 'Task', 'priority': 4};
        final nonInt = {'title': 'Task', 'priority': 'high'};

        expect(
          () => AIValidator.validateTaskDomain(low, context: 'test'),
          throwsA(isA<AIDomainValidationException>()),
        );
        expect(
          () => AIValidator.validateTaskDomain(high, context: 'test'),
          throwsA(isA<AIDomainValidationException>()),
        );
        expect(
          () => AIValidator.validateTaskDomain(nonInt, context: 'test'),
          throwsA(isA<AIDomainValidationException>()),
        );
      });

      test(
        'throws AIDomainValidationException for out-of-bounds estimatedMinutes',
        () {
          final tooShort = {'title': 'Task', 'estimatedMinutes': 10};
          final tooLong = {'title': 'Task', 'estimatedMinutes': 500};
          final nonNum = {'title': 'Task', 'estimatedMinutes': '60m'};

          expect(
            () => AIValidator.validateTaskDomain(tooShort, context: 'test'),
            throwsA(isA<AIDomainValidationException>()),
          );
          expect(
            () => AIValidator.validateTaskDomain(tooLong, context: 'test'),
            throwsA(isA<AIDomainValidationException>()),
          );
          expect(
            () => AIValidator.validateTaskDomain(nonNum, context: 'test'),
            throwsA(isA<AIDomainValidationException>()),
          );
        },
      );

      test(
        'throws AIDomainValidationException for invalid startTime format',
        () {
          final invalidTimes = [
            '24:00',
            '25:30',
            '12:60',
            '12:99',
            'invalid',
            '1200',
            '12:5',
          ];
          for (final time in invalidTimes) {
            final task = {'title': 'Task', 'startTime': time};
            expect(
              () => AIValidator.validateTaskDomain(task, context: 'test'),
              throwsA(isA<AIDomainValidationException>()),
              reason: 'Should throw for startTime: $time',
            );
          }
        },
      );
    });
  });
}
