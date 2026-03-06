import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/ai/ai_provider.dart';
import '../core/ai/token_tracker.dart';
import '../core/models/task_model.dart';
import '../core/models/memory_entry_model.dart';

// ── Brain Dump result types ───────────────────────────────────────────────

class BrainNote {
  final String title;
  final String content;
  const BrainNote({required this.title, required this.content});
}

class BrainDumpResult {
  final List<TaskItem> tasks;
  final List<BrainNote> notes;
  final List<String> memories;
  const BrainDumpResult({
    required this.tasks,
    required this.notes,
    required this.memories,
  });

  bool get isEmpty => tasks.isEmpty && notes.isEmpty && memories.isEmpty;
}

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

  // ---- BRAIN DUMP (universal capture) ------------------------------------

  /// Takes a stream-of-consciousness input and returns structured tasks,
  /// notes, and memories extracted by AI.
  Future<BrainDumpResult> brainDump(String input) async {
    final prompt =
        '''
You are AutoPlanner AI. Parse this stream-of-consciousness brain dump.
Classify every piece into tasks, notes, or memories.

Respond ONLY with valid JSON (no markdown fences):
{
  "tasks": [{"title":"...","startTime":"HH:mm","priority":0,"tags":[]}],
  "notes": [{"title":"...","content":"..."}],
  "memories": ["one-sentence fact worth remembering long-term"]
}

Rules:
- tasks = concrete actions or to-dos
- notes = ideas, reference info, meeting context, longer thoughts
- memories = recurring preferences, key life facts, important patterns
- startTime = best suggested time in HH:mm (default "09:00")
- priority = 0 low, 1 medium, 2 high, 3 urgent
- Use [] for any category with nothing to add

Brain dump:
"""
$input
"""
''';

    try {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'brainDump', response: response);
      return _parseBrainDumpResult(response.text);
    } catch (e) {
      if (kDebugMode) print('brainDump failed: $e');
      return const BrainDumpResult(tasks: [], notes: [], memories: []);
    }
  }

  BrainDumpResult _parseBrainDumpResult(String text) {
    try {
      final jsonStr = _extractJsonObject(text);
      if (jsonStr == null) {
        return const BrainDumpResult(tasks: [], notes: [], memories: []);
      }
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final tasks = _parseTasksFromJson(jsonEncode(data['tasks'] ?? []));
      final notes = (data['notes'] as List<dynamic>? ?? [])
          .map(
            (n) => BrainNote(
              title: (n['title'] as String?)?.trim() ?? 'Note',
              content: (n['content'] as String?)?.trim() ?? '',
            ),
          )
          .toList();
      final memories = (data['memories'] as List<dynamic>? ?? [])
          .map((m) => m.toString().trim())
          .where((m) => m.isNotEmpty)
          .toList();

      return BrainDumpResult(tasks: tasks, notes: notes, memories: memories);
    } catch (e) {
      if (kDebugMode) debugPrint('_parseBrainDumpResult failed: $e');
      return const BrainDumpResult(tasks: [], notes: [], memories: []);
    }
  }

  // ---- INTERNAL HELPERS ------------------------------------------------

  List<TaskItem> _parseTasksFromJson(String text) {
    try {
      final jsonStr = _extractJsonArray(text);
      if (jsonStr == null) return [];
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final now = DateTime.now();
      return jsonList.map((task) {
        final timeParts = ((task['startTime'] as String?) ?? '09:00').split(
          ':',
        );
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(timeParts[0]),
          int.tryParse(timeParts.elementAtOrNull(1) ?? '0') ?? 0,
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
    } catch (e) {
      if (kDebugMode) debugPrint('_parseTasksFromJson failed: $e');
      return [];
    }
  }

  List<String> _parseStringList(String text) {
    try {
      final jsonStr = _extractJsonArray(text);
      if (jsonStr == null) return [];
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => e.toString().toLowerCase()).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('_parseStringList failed: $e');
      return [];
    }
  }

  /// Strips markdown fences and returns the outermost JSON array substring,
  /// or null if none is found. Uses first `[` / last `]` rather than a
  /// non-greedy regex so nested arrays (e.g. "tags") are preserved.
  String? _extractJsonArray(String text) {
    // Remove markdown code fences (```json ... ``` etc.)
    final stripped = text
        .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
        .replaceAll('`', '')
        .trim();
    final start = stripped.indexOf('[');
    final end = stripped.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return null;
    return stripped.substring(start, end + 1);
  }

  /// Same as [_extractJsonArray] but for a JSON object `{...}`.
  String? _extractJsonObject(String text) {
    final stripped = text
        .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
        .replaceAll('`', '')
        .trim();
    final start = stripped.indexOf('{');
    final end = stripped.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return stripped.substring(start, end + 1);
  }
}
