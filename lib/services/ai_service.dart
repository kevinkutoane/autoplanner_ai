import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/ai/ai_provider.dart';
import '../core/ai/token_tracker.dart';
import '../core/models/task_model.dart';
import '../core/models/note_model.dart';
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
/// Every call is metered via [TokenTracker] and wrapped in
/// exponential-backoff retry logic.
class AIService {
  final AIProvider _provider;
  final TokenTracker _tracker;
  static const _uuid = Uuid();

  AIService({required AIProvider provider, required TokenTracker tracker})
    : _provider = provider,
      _tracker = tracker;

  // ── Input sanitization ───────────────────────────────────────────────────

  /// Neutralises prompt-injection vectors before interpolating user data.
  /// Replaces triple-quote sequences (our delimiter) and strips null bytes.
  String _sanitize(String input) =>
      input.replaceAll('"""', "'''").replaceAll('\x00', '').trim();

  // ── Retry wrapper ────────────────────────────────────────────────────────

  /// Retries [fn] up to [maxAttempts] times with exponential back-off.
  /// Waits 1 s → 2 s → 4 s between attempts.
  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
  }) async {
    var delay = const Duration(seconds: 1);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        if (attempt == maxAttempts - 1) rethrow;
        if (kDebugMode) {
          debugPrint('AI retry ${attempt + 1}/$maxAttempts after $delay: $e');
        }
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    throw StateError('unreachable');
  }

  // ── Task parsing ─────────────────────────────────────────────────────────

  /// Parses natural language into a [TaskItem] list with time, duration,
  /// and priority. Includes recent user memories as context.
  Future<List<TaskItem>> parseTasks(
    String input, {
    List<MemoryEntry>? memories,
  }) async {
    final memCtx = _buildMemoryContext(memories);
    final prompt =
        '''
You are AutoPlanner AI. Convert user input into a structured task list.
For each task include time (HH:mm), realistic duration, priority, and tags.
$memCtx
Schema — respond ONLY with a valid JSON array, no markdown, no explanation:
[{
  "title": "Short actionable title",
  "startTime": "09:00",
  "estimatedMinutes": 60,
  "priority": 1,
  "tags": ["work"]
}]

Priority: 0=low  1=medium  2=high  3=urgent
estimatedMinutes: 15–240 (be realistic — not everything takes an hour)
Return [] if the input is unparseable.

User input: "${_sanitize(input)}"
''';

    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'parseTasks', response: response);
      return _parseTasksFromJson(response.text);
    });
  }

  // ── Plan Day (AI enrichment pass) ────────────────────────────────────────

  /// AI-enrichment step for "Plan My Day".
  ///
  /// Re-scores priority and adds duration estimates to [existingTasks].
  /// Parses any [additionalInput] as extra tasks to add.
  ///
  /// Returns an updated task list. The caller should pipe this through
  /// [SchedulerService.scheduleDay] for actual time placement.
  Future<List<TaskItem>> planDay({
    required List<TaskItem> existingTasks,
    required List<MemoryEntry> memories,
    required int workStartHour,
    required int workHoursPerDay,
    String? additionalInput,
  }) async {
    final pending = existingTasks.where((t) => !t.isCompleted).toList();
    final workEnd = workStartHour + workHoursPerDay;

    final taskLines = pending.isEmpty
        ? '  (none)'
        : pending
              .map((t) => '  - [id: ${t.id}] "${t.title}" [${t.priorityLabel}]')
              .join('\n');

    final additionalSection = (additionalInput?.trim().isNotEmpty ?? false)
        ? '\nAdditional tasks from user input:\n  "${_sanitize(additionalInput!)}"\n'
        : '';

    final memCtx = _buildMemoryContext(memories, maxEntries: 8);

    final prompt =
        '''
You are AutoPlanner AI. Score priority and estimate duration for each task.

Work window: ${workStartHour.toString().padLeft(2, '0')}:00 – ${workEnd.toString().padLeft(2, '0')}:00

Current pending tasks:
$taskLines
$additionalSection$memCtx
For every task (existing + new), output:
  - "id": the existing task id string, or null for new tasks
  - "title": short actionable title (refine vague ones)
  - "estimatedMinutes": realistic completion time (15–240)
  - "priority": 0=low 1=medium 2=high 3=urgent
  - "tags": 1–3 lowercase topic tags

Respond ONLY with a valid JSON array — no markdown, no explanation:
[{"id":"existing-uuid-or-null","title":"...","estimatedMinutes":60,"priority":2,"tags":["work"]}]
''';

    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'planDay', response: response);
      return _parsePlanDayResult(response.text, existingTasks);
    });
  }

  // ── Note summarization ───────────────────────────────────────────────────

  Future<String?> summarizeNote(String content) async {
    if (content.trim().length < 50) return null;
    final prompt =
        '''
Summarize this note in 1-3 concise sentences. Respond with ONLY the summary text.

"""
${_sanitize(content)}
"""
''';
    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'summarizeNote', response: response);
      return response.text.trim();
    });
  }

  // ── Tag generation ───────────────────────────────────────────────────────

  Future<List<String>> generateTags(String content) async {
    if (content.trim().length < 20) return [];
    final prompt =
        '''
Generate 2-5 relevant topic tags for this text.
Return ONLY a JSON array of lowercase strings. Example: ["productivity","meeting"]

"""
${_sanitize(content)}
"""
''';
    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'generateTags', response: response);
      return _parseStringList(response.text);
    });
  }

  // ── Extract action items from notes ──────────────────────────────────────

  Future<List<TaskItem>> extractActionItems(String noteContent) async {
    final prompt =
        '''
Extract actionable tasks from this note with suggested time, duration, and priority.
Respond ONLY with a valid JSON array:
[{"title":"...","startTime":"09:00","estimatedMinutes":30,"priority":1,"tags":["from-note"]}]
If none found, return [].

"""
${_sanitize(noteContent)}
"""
''';
    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'extractActionItems', response: response);
      return _parseTasksFromJson(response.text);
    });
  }

  // ── Daily insight ────────────────────────────────────────────────────────

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
      if (kDebugMode) debugPrint('dailyInsight failed: $e');
      return null;
    }
  }

  // ── Memory extraction ─────────────────────────────────────────────────────

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
${_sanitize(context)}
"""
''';
    try {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'extractMemory', response: response);
      final text = response.text.trim();
      if (text != 'NONE' && text.isNotEmpty) return text;
    } catch (e) {
      if (kDebugMode) debugPrint('extractMemory failed: $e');
    }
    return null;
  }

  // ── Brain Dump ────────────────────────────────────────────────────────────

  /// Parses a stream-of-consciousness brain dump into tasks, notes, and
  /// memories. Streams partial text via [onChunk] for real-time UI feedback.
  Future<BrainDumpResult> brainDump(
    String input, {
    void Function(String accumulatedText)? onChunk,
  }) async {
    final prompt =
        '''
You are AutoPlanner AI. Parse this stream-of-consciousness brain dump.
Classify every piece into tasks, notes, or memories.

Respond ONLY with valid JSON (no markdown fences):
{
  "tasks": [{"title":"...","startTime":"HH:mm","estimatedMinutes":60,"priority":0,"tags":[]}],
  "notes": [{"title":"...","content":"..."}],
  "memories": ["one-sentence fact worth remembering long-term"]
}

Rules:
- tasks = concrete actions or to-dos
- notes = ideas, reference info, meeting context, longer thoughts
- memories = recurring preferences, key life facts, important patterns
- startTime = best suggested time in HH:mm (default "09:00")
- estimatedMinutes = realistic time to complete (15–240)
- priority = 0 low, 1 medium, 2 high, 3 urgent
- Use [] for any empty category

Brain dump:
"""
${_sanitize(input)}
"""
''';

    try {
      String fullText;
      if (onChunk != null) {
        final buffer = StringBuffer();
        await for (final chunk in _provider.streamComplete(prompt)) {
          buffer.write(chunk);
          onChunk(buffer.toString());
        }
        fullText = buffer.toString();
      } else {
        final response = await _provider.complete(prompt);
        fullText = response.text;
      }

      await _tracker.log(
        action: 'brainDump',
        response: AIResponse(
          text: fullText,
          promptTokens: (prompt.length / 4).ceil(),
          completionTokens: (fullText.length / 4).ceil(),
          model: _provider.modelName,
        ),
      );
      return _parseBrainDumpResult(fullText);
    } catch (e) {
      if (kDebugMode) debugPrint('brainDump failed: $e');
      return const BrainDumpResult(tasks: [], notes: [], memories: []);
    }
  }
  // ── Reschedule suggestion ────────────────────────────────────────────────

  /// Given a blocked event and a list of occupied windows, suggests 3
  /// alternative time slots.
  Future<List<Map<String, dynamic>>> suggestReschedule({
    required TaskItem blocked,
    required List<TaskItem> occupied,
    required int workStartHour,
    required int workHoursPerDay,
  }) async {
    final workEnd = workStartHour + workHoursPerDay;
    final occupiedLines = occupied.isEmpty
        ? '  (none)'
        : occupied
              .map(
                (t) =>
                    '  - "${t.title}" ${t.startTime.hour}:${t.startTime.minute.toString().padLeft(2, '0')} – ${(t.endTime ?? t.startTime.add(const Duration(hours: 1))).hour}:${(t.endTime ?? t.startTime.add(const Duration(hours: 1))).minute.toString().padLeft(2, '0')}',
              )
              .join('\n');

    final durationMins = blocked.endTime != null
        ? blocked.endTime!.difference(blocked.startTime).inMinutes
        : 60;

    final prompt =
        '''
You are AutoPlanner AI. Suggest 3 alternative time slots for a blocked task.

Blocked task: "${_sanitize(blocked.title)}" (duration: $durationMins minutes)
Work window: ${workStartHour.toString().padLeft(2, '0')}:00 – ${workEnd.toString().padLeft(2, '0')}:00

Already occupied:
$occupiedLines

Respond ONLY with a valid JSON array — no markdown, no explanation:
[{"startTime":"HH:mm","reason":"Short rationale"}]
''';

    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'suggestReschedule', response: response);
      try {
        final jsonStr = _extractJsonArray(response.text);
        if (jsonStr == null) return [];
        final list = jsonDecode(jsonStr) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      } catch (_) {
        return [];
      }
    });
  }

  // ── Note AI actions ────────────────────────────────────────────────────────

  /// Adds headings, bullets, and clean formatting to unstructured note text.
  Future<String?> structureNote(String content) async {
    if (content.trim().length < 30) return null;
    final prompt =
        '''
Restructure this note with clear headings (##), bullet points, and logical sections.
Preserve all original information — only improve formatting.
Respond with ONLY the formatted note text (no extra commentary).

"""
${_sanitize(content)}
"""
''';
    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'structureNote', response: response);
      return response.text.trim();
    });
  }

  /// Rewrites text to be more clear and concise.
  Future<String?> rephraseText(String content) async {
    if (content.trim().length < 10) return null;
    final prompt =
        '''
Rephrase this text to be clearer and more concise while preserving meaning.
Respond with ONLY the rephrased text.

"""
${_sanitize(content)}
"""
''';
    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'rephraseText', response: response);
      return response.text.trim();
    });
  }

  // ── Weekly review ──────────────────────────────────────────────────────────

  /// Generates a structured weekly review with highlights, patterns, and tips.
  Future<String?> generateWeeklyReview({
    required List<TaskItem> weekTasks,
    required List<NoteItem> weekNotes,
    required List<MemoryEntry> memories,
  }) async {
    final completed = weekTasks.where((t) => t.isCompleted).length;
    final total = weekTasks.length;
    final rate = total > 0 ? (completed / total * 100).round() : 0;

    final taskSummary = weekTasks.isEmpty
        ? '  (none)'
        : weekTasks
              .take(20)
              .map(
                (t) =>
                    '  - [${t.isCompleted ? "✓" : " "}] "${t.title}" [${t.priorityLabel}]',
              )
              .join('\n');

    final noteSummary = weekNotes.isEmpty
        ? '  (none)'
        : weekNotes.take(5).map((n) => '  - "${n.title}"').join('\n');

    final memCtx = _buildMemoryContext(memories, maxEntries: 5);

    final prompt =
        '''
You are AutoPlanner AI. Generate an insightful weekly review.

This week's stats: $completed/$total tasks completed ($rate% completion rate)

Tasks:
$taskSummary

Notes created:
$noteSummary
$memCtx
Write a structured weekly review with these sections:
1. **Highlights** — what went well
2. **Patterns noticed** — productivity trends or habits
3. **Suggestions for next week** — 2-3 actionable tips

Keep it encouraging, concise, and actionable. Use markdown formatting.
Respond with ONLY the review text.
''';
    try {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'weeklyReview', response: response);
      return response.text.trim();
    } catch (e) {
      if (kDebugMode) debugPrint('weeklyReview failed: $e');
      return null;
    }
  }
  // ── Private parsers ─────────────────────────────────────────────────────

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
      if (kDebugMode) debugPrint('_parseBrainDumpResult error: $e');
      return const BrainDumpResult(tasks: [], notes: [], memories: []);
    }
  }

  List<TaskItem> _parsePlanDayResult(
    String text,
    List<TaskItem> existingTasks,
  ) {
    try {
      final jsonStr = _extractJsonArray(text);
      if (jsonStr == null) return existingTasks;
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final existingMap = {for (final t in existingTasks) t.id: t};

      final results = <TaskItem>[];
      for (final item in jsonList) {
        final existingId = item['id'] as String?;
        final estimatedMins =
            ((item['estimatedMinutes'] as num?)?.toInt() ?? 60).clamp(15, 480);
        final duration = Duration(minutes: estimatedMins);

        if (existingId != null && existingMap.containsKey(existingId)) {
          final existing = existingMap[existingId]!;
          results.add(
            existing.copyWith(
              title: (item['title'] as String?)?.trim() ?? existing.title,
              priority:
                  (item['priority'] as int?)?.clamp(0, 3) ?? existing.priority,
              tags:
                  (item['tags'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  existing.tags,
              endTime: existing.startTime.add(duration),
            ),
          );
        } else {
          final now = DateTime.now();
          results.add(
            TaskItem(
              id: _uuid.v4(),
              title: (item['title'] as String?)?.trim() ?? 'New Task',
              startTime: now,
              endTime: now.add(duration),
              priority: (item['priority'] as int?)?.clamp(0, 3) ?? 1,
              tags:
                  (item['tags'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
            ),
          );
        }
      }
      return results;
    } catch (e) {
      if (kDebugMode) debugPrint('_parsePlanDayResult error: $e');
      return existingTasks;
    }
  }

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
        final start = DateTime(
          now.year,
          now.month,
          now.day,
          int.tryParse(timeParts[0]) ?? 9,
          int.tryParse(timeParts.elementAtOrNull(1) ?? '0') ?? 0,
        );
        final estimatedMins =
            ((task['estimatedMinutes'] as num?)?.toInt() ?? 60).clamp(15, 480);
        return TaskItem(
          id: _uuid.v4(),
          title: (task['title'] as String).trim(),
          startTime: start,
          endTime: start.add(Duration(minutes: estimatedMins)),
          priority: (task['priority'] as int?)?.clamp(0, 3) ?? 1,
          tags:
              (task['tags'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('_parseTasksFromJson error: $e');
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
      if (kDebugMode) debugPrint('_parseStringList error: $e');
      return [];
    }
  }

  String _buildMemoryContext(
    List<MemoryEntry>? memories, {
    int maxEntries = 10,
  }) {
    if (memories == null || memories.isEmpty) return '';
    final lines = memories
        .take(maxEntries)
        .map((m) => '  - ${m.content}')
        .join('\n');
    return '\nUser context from memory:\n$lines\n';
  }

  /// Strips markdown fences and returns the outermost JSON array `[...]`.
  String? _extractJsonArray(String text) {
    final stripped = text
        .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
        .replaceAll('`', '')
        .trim();
    final start = stripped.indexOf('[');
    final end = stripped.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return null;
    return stripped.substring(start, end + 1);
  }

  /// Returns the outermost JSON object `{...}`.
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
