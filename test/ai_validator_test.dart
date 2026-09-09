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
  });
}
