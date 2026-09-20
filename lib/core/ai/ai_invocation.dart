import 'package:flutter/foundation.dart';

/// Strongly typed semantic AI operations supported by AutoPlanner.
///
/// These operation identifiers allow client and server to agree on the intent
/// of an AI call without relying solely on opaque prompt string matching.
enum AIOperation {
  brainDump,
  parseTasks,
  planDay,
  chatCoach,
  dailyInsight,
  suggestReschedule,
  summarizeNote,
  generateTags,
  extractMemory,
  extractPatterns,
  suggestTasks,
  weeklyReview,
  parseScheduleCommand;

  /// Wire format name used in HTTP/JSON transport to the AI gateway.
  String get wireName => switch (this) {
    AIOperation.brainDump => 'brain_dump',
    AIOperation.parseTasks => 'parse_tasks',
    AIOperation.planDay => 'plan_day',
    AIOperation.chatCoach => 'chat_coach',
    AIOperation.dailyInsight => 'daily_insight',
    AIOperation.suggestReschedule => 'suggest_reschedule',
    AIOperation.summarizeNote => 'summarize_note',
    AIOperation.generateTags => 'generate_tags',
    AIOperation.extractMemory => 'extract_memory',
    AIOperation.extractPatterns => 'extract_patterns',
    AIOperation.suggestTasks => 'suggest_tasks',
    AIOperation.weeklyReview => 'weekly_review',
    AIOperation.parseScheduleCommand => 'parse_schedule_command',
  };

  /// Parses a wire string into its typed [AIOperation] equivalent, or null if unknown.
  static AIOperation? tryParse(String? name) {
    if (name == null) return null;
    final clean = name.trim().toLowerCase();
    for (final op in AIOperation.values) {
      if (op.wireName == clean || op.name.toLowerCase() == clean) {
        return op;
      }
    }
    return null;
  }
}

/// An immutable, structured representation of an AI request.
///
/// Decouples the intent and structured context of an AI interaction from
/// raw prompt strings, making the request cloud-ready and provider-agnostic.
@immutable
class AIInvocation {
  /// Unique invocation / request identifier for tracing, deduplication, and telemetry.
  final String id;

  /// The semantic operation being executed.
  final AIOperation operation;

  /// Structured input parameters specific to the operation.
  /// Example: {'text': '...', 'messages': [...]}
  final Map<String, dynamic> input;

  /// Optional contextual data attached to the invocation.
  /// Example: {'memories': [...], 'goals': [...], 'workHours': 8}
  final Map<String, dynamic> context;

  /// Client telemetry metadata.
  final Map<String, dynamic> client;

  /// Timestamp when the invocation was created.
  final DateTime timestamp;

  AIInvocation({
    required this.id,
    required this.operation,
    required this.input,
    Map<String, dynamic>? context,
    Map<String, dynamic>? client,
    DateTime? timestamp,
  }) : context = context != null ? Map.unmodifiable(context) : const {},
       client = client != null ? Map.unmodifiable(client) : const {},
       timestamp = timestamp ?? DateTime.now();

  /// Serializes the invocation to a standard JSON map for network transport.
  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation.wireName,
    'input': input,
    'context': context,
    'client': client,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Deserializes an [AIInvocation] from a JSON map.
  factory AIInvocation.fromJson(Map<String, dynamic> json) {
    return AIInvocation(
      id: json['id'] as String? ?? '',
      operation:
          AIOperation.tryParse(json['operation'] as String?) ??
          AIOperation.parseTasks,
      input: json['input'] is Map
          ? Map<String, dynamic>.from(json['input'] as Map)
          : {},
      context: json['context'] is Map
          ? Map<String, dynamic>.from(json['context'] as Map)
          : {},
      client: json['client'] is Map
          ? Map<String, dynamic>.from(json['client'] as Map)
          : {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  AIInvocation copyWith({
    String? id,
    AIOperation? operation,
    Map<String, dynamic>? input,
    Map<String, dynamic>? context,
    Map<String, dynamic>? client,
    DateTime? timestamp,
  }) {
    return AIInvocation(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      input: input ?? this.input,
      context: context ?? this.context,
      client: client ?? this.client,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
