import 'dart:convert';

/// Exception thrown when AI output violates structural schemas.
class AIValidationException implements Exception {
  final String message;
  final String context;
  const AIValidationException(this.message, this.context);

  @override
  String toString() => 'AIValidationException[$context]: $message';
}

/// Enforces strict schema boundaries on AI responses.
/// Prevents malformed or hallucinated LLM output from reaching business logic.
class AIValidator {
  /// Extracts a JSON array from AI output and validates it.
  /// Throws [AIValidationException] if the structure is invalid.
  static List<dynamic> extractArray(String text, {required String context}) {
    final stripped = _stripFences(text);
    final start = stripped.indexOf('[');
    final end = stripped.lastIndexOf(']');
    
    if (start == -1 || end == -1 || end <= start) {
      throw AIValidationException('No JSON array found in output', context);
    }
    
    try {
      final jsonStr = stripped.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) {
        throw AIValidationException('Parsed JSON is not an array', context);
      }
      return decoded;
    } catch (e) {
      if (e is AIValidationException) rethrow;
      throw AIValidationException('Invalid JSON syntax: $e', context);
    }
  }

  /// Extracts a JSON object from AI output and validates it.
  /// Throws [AIValidationException] if the structure is invalid.
  static Map<String, dynamic> extractObject(String text, {required String context}) {
    final stripped = _stripFences(text);
    final start = stripped.indexOf('{');
    final end = stripped.lastIndexOf('}');
    
    if (start == -1 || end == -1 || end <= start) {
      throw AIValidationException('No JSON object found in output', context);
    }
    
    try {
      final jsonStr = stripped.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw AIValidationException('Parsed JSON is not an object', context);
      }
      return decoded;
    } catch (e) {
      if (e is AIValidationException) rethrow;
      throw AIValidationException('Invalid JSON syntax: $e', context);
    }
  }

  /// Validates that a map contains required keys of specific types.
  static void validateSchema(
    Map<String, dynamic> data,
    Map<String, Type> requiredFields, {
    required String context,
  }) {
    for (final entry in requiredFields.entries) {
      final key = entry.key;
      final expectedType = entry.value;
      
      if (!data.containsKey(key)) {
        throw AIValidationException('Missing required field: "$key"', context);
      }
      
      final value = data[key];
      // Note: we can't do an exact `value.runtimeType == expectedType` easily for generic Lists, 
      // but we can do basic type checks.
      bool isMatch = false;
      if (expectedType == String && value is String) isMatch = true;
      if (expectedType == int && value is int) isMatch = true;
      if (expectedType == num && value is num) isMatch = true;
      if (expectedType == bool && value is bool) isMatch = true;
      if (expectedType == List && value is List) isMatch = true;
      if (expectedType == Map && value is Map) isMatch = true;
      if (expectedType == dynamic) isMatch = true;
      
      if (!isMatch) {
        throw AIValidationException(
          'Field "$key" has invalid type. Expected $expectedType, got ${value.runtimeType}',
          context,
        );
      }
    }
  }

  static String _stripFences(String text) {
    return text
        .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
        .replaceAll('`', '')
        .trim();
  }
}
