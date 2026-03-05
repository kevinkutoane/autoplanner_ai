import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/ai/ai_provider.dart';
import '../core/ai/token_tracker.dart';
import '../core/models/task_model.dart';
import '../core/models/memory_entry_model.dart';

/// Unified AI service layer.
///
/// All AI-powered features flow through here. Uses [AIProvider]
/// abstraction so the underlying model (Gemini, OpenAI, mock)
/// can be swapped without touching business logic.
///
/// Every call is metered via [TokenTracker].
class AIService {
  final AIProvider _provider;
  final TokenTracker _tracker;
  static const _uuid = Uuid();

  AIService({required AIProvider provider, required TokenTracker tracker})
    : _provider = provider,
      _tracker = tracker;

  // ---- TASK PARSING (structured JSON output) --------------------------

  Future<List<TaskItem>> parseTasks(
    String input, {
    List<MemoryEntry>? memories,
  }) async {
    String memoryContext = '';
    if (memories != null && memories.isNotEmpty) {
      final recentMemories = memories
          .take(10)
          .map((m) => '- ${m.content}')
          .join('\n');
      memoryContext = '\n\nUser context from memory:\n$recentMemories\n';
    }

    final prompt =
        '''
You are AutoPlanner AI. Convert user input into a structured daily task list.
Include time (HH:mm), priority (0=low,1=med,2=high,3=urgent), and tags.
$memoryContext
Respond ONLY with a valid JSON array:
[{"title":"...","startTime":"08:00","priority":1,"tags":["work"]}]
No markdown, no explanation. If unparseable, return [].

User input: "$input"
''';

    try {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'parseTasks', response: response);

      return _parseTasksFromJson(response.text);
    } catch (e) {
      if (kDebugMode) print('parseTasks failed: $e');
      return [];
    }
  }

  // ---- NOTE SUMMARIZATION ---------------------------------------------

  Future<String?> summarizeNote(String content) async {
    if (content.trim().length < 50) return null;

    final prompt =
        '''
Summarize this note in 1-3 concise sentences. Respond with ONLY the summary text.

"""
$content
"""
''';

    try {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'summarizeNote', response: response);
      return response.text.trim();
    } catch (e) {
      if (kDebugMode) print('summarizeNote failed: $e');
      return null;
    }
  }

  // ---- TAG GENERATION --------------------------------------------------

  Future<List<String>> generateTags(String content) async {
    if (content.trim().length < 20) return [];

    final prompt =
        '''
Generate 2-5 relevant topic tags for this text.
Return ONLY a JSON array of lowercase strings. Example: ["productivity","meeting"]

"""
$content
"""
''';

    try {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'generateTags', response: response);
      return _parseStringList(response.text);
    } catch (e) {
      if (kDebugMode) print('generateTags failed: $e');
      return [];
    }
  }

  // ---- EXTRACT ACTION ITEMS FROM NOTES ---------------------------------

  Future<List<TaskItem>> extractActionItems(String noteContent) async {
    final prompt =
        '''
Extract actionable tasks from this note with suggested time and priority.
Respond ONLY with a valid JSON array:
[{"title":"...","startTime":"09:00","priority":1,"tags":["from-note"]}]
If none found, return [].

"""
$noteContent
"""
''';

    try {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'extractActionItems', response: response);
      return _parseTasksFromJson(response.text);
    } catch (e) {
      if (kDebugMode) print('extractActionItems failed: $e');
      return [];
    }
  }

  // ---- DAILY INSIGHT ---------------------------------------------------

  Future<String?> generateDailyInsight(
    List<TaskItem> tasks,
    List<MemoryEntry> memories,
  ) async {
    final taskDesc = tasks.isEmpty
        ? 'No tasks yet.'
        : tasks
              .map(
                (t) =>
                    '- ${t.title} (${t.startTime.hour}:${t.startTime.minute.toString().padLeft(2, '0')}, ${t.priorityLabel}, ${t.isCompleted ? "done" : "pending"})',
              )
              .join('\n');

    final memDesc = memories.isEmpty
        ? 'No past context.'
        : memories.take(5).map((m) => '- ${m.content}').join('\n');

    final prompt =
        '''
Generate a brief, motivating daily insight (2-3 sentences) based on
the user's tasks and context. Include a productivity tip.
Respond with ONLY the insight text.

Tasks:
$taskDesc

Context:
$memDesc
''';

    try {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'dailyInsight', response: response);
      return response.text.trim();
    } catch (e) {
      if (kDebugMode) print('dailyInsight failed: $e');
      return null;
    }
  }

  // ---- MEMORY EXTRACTION -----------------------------------------------

  Future<String?> extractMemoryFromContext(
    String context,
    String sourceType,
  ) async {
    final prompt =
        '''
Extract a concise, reusable memory from this $sourceType context.
Single sentence capturing the key insight or pattern.
If nothing noteworthy, return "NONE".

"""
$context
"""
''';

    try {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'extractMemory', response: response);
      final text = response.text.trim();
      if (text != 'NONE' && text.isNotEmpty) return text;
    } catch (e) {
      if (kDebugMode) print('extractMemory failed: $e');
    }
    return null;
  }

  // ---- INTERNAL HELPERS ------------------------------------------------

  List<TaskItem> _parseTasksFromJson(String text) {
    final match = RegExp(r'(\[.*?\])', dotAll: true).firstMatch(text);
    final jsonStr = match != null ? match.group(0) : text;
    final List<dynamic> jsonList = jsonDecode(jsonStr!);
    final now = DateTime.now();

    return jsonList.map((task) {
      final timeParts = (task['startTime'] as String).split(':');
      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
      return TaskItem(
        id: _uuid.v4(),
        title: task['title'] as String,
        startTime: scheduledTime,
        priority: (task['priority'] as int?) ?? 1,
        tags:
            (task['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
    }).toList();
  }

  List<String> _parseStringList(String text) {
    final match = RegExp(r'(\[.*?\])', dotAll: true).firstMatch(text);
    final jsonStr = match != null ? match.group(0) : text;
    final List<dynamic> list = jsonDecode(jsonStr!);
    return list.map((e) => e.toString().toLowerCase()).toList();
  }
}
