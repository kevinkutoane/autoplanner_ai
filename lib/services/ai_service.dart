import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/ai/ai_guard.dart';
import '../core/ai/ai_provider.dart';
import '../core/ai/token_tracker.dart';
import '../core/models/task_model.dart';
import '../core/models/goal_model.dart';
import '../core/models/memory_entry_model.dart';
import '../core/ai/ai_validator.dart';
import 'app_monitor_service.dart';

// ── Brain Dump result types ───────────────────────────────────────────────

/// A goal entity produced by the brain-dump AI pass.
///
/// Distinct from [GoalItem] because it has not yet been persisted to Hive;
/// the caller (BrainDumpSheet) writes it after the AI stream completes.
class BrainGoal {
  /// Short descriptive title for the goal.
  final String title;

  /// Optional description / notes for the goal.
  final String description;

  const BrainGoal({required this.title, this.description = ''});
}

/// Aggregated output of a single brain-dump AI invocation.
///
/// Contains three categories of structured items extracted from free-form
/// user input — tasks, goals, and long-term memory strings — which are
/// persisted to their respective Hive boxes by the caller.
class BrainDumpResult {
  /// Tasks extracted from the brain dump, ready to be written to `tasksBox`.
  final List<TaskItem> tasks;

  /// Goals extracted from the brain dump, ready to be written to `goalsBox`.
  final List<BrainGoal> goals;

  /// Raw memory strings to be stored in `memoryBox` as [MemoryEntry] records.
  final List<String> memories;

  /// Maps task index → goal title (from `goalTitle` field in AI output).
  /// Only present for tasks that the AI linked to a goal.
  final Map<int, String> taskGoalLinks;

  const BrainDumpResult({
    required this.tasks,
    required this.goals,
    required this.memories,
    this.taskGoalLinks = const {},
  });

  /// True when all three result lists are empty (model produced nothing useful).
  bool get isEmpty => tasks.isEmpty && goals.isEmpty && memories.isEmpty;
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
  final AppMonitorService? _monitor;

  /// Abuse-prevention guard — validates inputs, throttles calls, screens outputs.
  final AIGuard _guard = AIGuard.instance;

  static const _uuid = Uuid();

  AIService({
    required AIProvider provider,
    required TokenTracker tracker,
    AppMonitorService? monitor,
  }) : _provider = provider,
       _tracker = tracker,
       _monitor = monitor;

  // ── Input sanitization ───────────────────────────────────────────────────

  /// Max characters accepted from any single user-supplied string.
  static const _maxInputLength = 8000;

  /// Neutralises prompt-injection vectors before interpolating user data.
  ///
  /// - Caps input length to [_maxInputLength] to prevent context flooding.
  /// - Strips null bytes and our triple-quote delimiter.
  /// - Removes common LLM role-switch markers used in injection attacks.
  String _sanitize(String input) {
    var s = input.length > _maxInputLength
        ? input.substring(0, _maxInputLength)
        : input;
    // Strip injection role markers (case-insensitive via replaceAll patterns).
    const injectionPatterns = [
      '\nSystem:',
      '\nsystem:',
      '\nHuman:',
      '\nhuman:',
      '\nAssistant:',
      '\nassistant:',
      '[INST]',
      '[/INST]',
      '<s>',
      '</s>',
      '"""',
      '\x00',
    ];
    for (final p in injectionPatterns) {
      s = s.replaceAll(p, '');
    }
    return s.trim();
  }

  // ── Retry wrapper ────────────────────────────────────────────────────────

  /// Retries [fn] up to [maxAttempts] times with exponential back-off.
  /// Checks rate limit before each attempt.
  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
  }) async {
    // Token-budget check (daily cap via TokenTracker)
    _tracker.guardRateLimit();
    // Call-frequency throttle (per-minute / per-hour via AIGuard)
    _guard.checkCallFrequency();
    var delay = const Duration(seconds: 1);
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e) {
        if (attempt == maxAttempts - 1) rethrow;
        if (kDebugMode) {
          debugPrint('AI retry ${attempt + 1}/$maxAttempts after $delay: $e');
        }
        
        // Fail fast on explicit validation errors (do not loop infinitely for hallucinated output)
        if (e is AIValidationException) {
          if (kDebugMode) debugPrint('Aborting retries due to AIValidationException: $e');
          rethrow;
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
    String rawInput, {
    List<MemoryEntry>? memories,
  }) async {
    // Validate and sanitise before building the prompt
    final input = _guard.validateInput(rawInput, context: 'parseTasks');
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
(Input pre-screened for safety)
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
    // Validate any free-text additional input before embedding in prompt
    final safeAdditional = additionalInput != null && additionalInput.trim().isNotEmpty
        ? _guard.validateInput(additionalInput, context: 'planDay')
        : null;
    final pending = existingTasks.where((t) => !t.isCompleted).toList();
    final workEnd = workStartHour + workHoursPerDay;

    final taskLines = pending.isEmpty
        ? '  (none)'
        : pending
              .map((t) => '  - [id: ${t.id}] "${t.title}" [${t.priorityLabel}]')
              .join('\n');

    final additionalSection = (safeAdditional?.trim().isNotEmpty ?? false)
        ? '\nAdditional tasks from user input:\n  "${_sanitize(safeAdditional!)}"\n'
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

  // ── Proactive re-scheduling ──────────────────────────────────────────────

  /// Given an overdue [task] and a list of candidate free [slots] (DateTime),
  /// asks Gemini to pick the single best slot considering user memory patterns.
  /// Returns the chosen [DateTime], or the first slot as a fallback.
  Future<DateTime?> suggestReschedule({
    required TaskItem task,
    required List<DateTime> slots,
    List<MemoryEntry>? memories,
    GoalItem? linkedGoal,
  }) async {
    if (slots.isEmpty) return null;

    final slotLines = slots
        .asMap()
        .entries
        .map((e) => '  ${e.key + 1}. ${_formatSlot(e.value)}')
        .join('\n');
    final memCtx = _buildMemoryContext(memories, maxEntries: 5);
    final goalCtx = linkedGoal != null
        ? '\nThis task is linked to the goal "${_sanitize(linkedGoal.title)}"'
            '${linkedGoal.deadline != null ? ' with a deadline of ${linkedGoal.deadline!.day}/${linkedGoal.deadline!.month}/${linkedGoal.deadline!.year}' : ''}.'
            ' Prioritise accordingly.\n'
        : '';
    final prompt =
        '''
You are AutoPlanner AI. A task was missed and needs rescheduling.

Task: "${_sanitize(task.title)}" [${task.priorityLabel}]
Duration: ${_taskDurationMinutes(task)} min
$goalCtx
Available slots today:
$slotLines
$memCtx
Pick the single best slot number considering priority, goal urgency, the user's energy patterns from memory, and realistic buffer time.
Respond with ONLY the slot number as a single integer (e.g. "2"). No explanation.
''';

    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'suggestReschedule', response: response);
      final pick = int.tryParse(response.text.trim());
      if (pick != null && pick >= 1 && pick <= slots.length) {
        return slots[pick - 1];
      }
      return slots.first; // fallback if model returns invalid index
    });
  }

  String _formatSlot(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _taskDurationMinutes(TaskItem task) {
    if (task.endTime != null) {
      final d = task.endTime!.difference(task.startTime).inMinutes;
      if (d >= 15) return d;
    }
    return 60;
  }

  // ── Note summarization ───────────────────────────────────────────────────

  /// Returns a 1–3 sentence summary of [content], or `null` if the content
  /// is shorter than 50 characters or the model returns an empty string.
  ///
  /// Useful for automatically populating [GoalItem.description] after saving.
  Future<String?> summarizeNote(String rawContent) async {
    final content = _guard.validateInput(rawContent, context: 'summarizeNote');
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
      // Screen output before returning to UI
      _guard.validateOutput(response.text);
      return response.text.trim();
    });
  }

  // ── Tag generation ───────────────────────────────────────────────────────

  /// Generates 2–5 lowercase topic tags for [content].
  ///
  /// Returns an empty list when [content] is shorter than 20 characters or
  /// when the model cannot produce a parseable JSON array.
  Future<List<String>> generateTags(String rawContent) async {
    final content = _guard.validateInput(rawContent, context: 'generateTags');
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

  // ── Daily insight ────────────────────────────────────────────────────────

  /// Generates a 2–3 sentence motivating daily insight from [tasks] and
  /// [memories], including a productivity tip.
  ///
  /// Returns `null` on failure (e.g. network error). The failure is logged in
  /// debug mode but not rethrown, so callers can treat it as optional UI.
  Future<String?> generateDailyInsight(
    List<TaskItem> tasks,
    List<MemoryEntry> memories, {
    List<GoalItem> goals = const [],
  }) async {
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

    final goalDesc = goals.isEmpty
        ? ''
        : '\nActive goals:\n${goals.take(5).map((g) {
            final dl = g.deadline != null
                ? ' (deadline: ${g.deadline!.day}/${g.deadline!.month}/${g.deadline!.year})'
                : '';
            return '- ${g.emoji} ${g.title}$dl — ${g.linkedTaskIds.length} linked tasks';
          }).join('\n')}\n';

    final prompt =
        '''
Generate a brief, motivating daily insight (2-3 sentences) based on
the user's tasks, goals, and context. Reference active goals when relevant.
Include a productivity tip.
Respond with ONLY the insight text.

Tasks:
$taskDesc
$goalDesc
Context:
$memDesc
''';
    try {
      return await _withRetry(() async {
        final response = await _provider.complete(prompt);
        await _tracker.log(action: 'dailyInsight', response: response);
        // Screen output before returning to UI
        _guard.validateOutput(response.text);
        return response.text.trim();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('dailyInsight failed after retries: $e');
      return null;
    }
  }

  // ── Memory extraction ─────────────────────────────────────────────────────

  /// Extracts a single reusable insight from [context] for long-term storage.
  ///
  /// [sourceType] describes where the context came from (e.g. `'task'`,
  /// `'note'`, `'calendar'`). Returns `null` when the model responds with
  /// `"NONE"` or on network failure.
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
      return await _withRetry(() async {
        final response = await _provider.complete(prompt);
        await _tracker.log(action: 'extractMemory', response: response);
        final text = response.text.trim();
        if (text != 'NONE' && text.isNotEmpty) return text;
        return null;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('extractMemory failed after retries: $e');
      return null;
    }
  }

  // ── Brain Dump ────────────────────────────────────────────────────────────

  /// Parses a stream-of-consciousness brain dump into tasks, notes, and
  /// memories. Streams partial text via [onChunk] for real-time UI feedback.
  Future<BrainDumpResult> brainDump(
    String rawInput, {
    void Function(String accumulatedText)? onChunk,
  }) async {
    // Validate and sanitise before building the prompt — this is the
    // highest-risk user input path (free-form, long-form text).
    final input = _guard.validateInput(rawInput, context: 'brainDump');
    final prompt =
        '''
You are AutoPlanner AI. Parse this stream-of-consciousness brain dump.
Classify every piece into tasks, goals, or memories.

Respond ONLY with valid JSON (no markdown fences):
{
  "tasks": [{"title":"...","startTime":"HH:mm","estimatedMinutes":60,"priority":0,"tags":[],"goalTitle":""}],
  "goals": [{"title":"...","description":"..."}],
  "memories": ["one-sentence fact worth remembering long-term"]
}

Rules:
- tasks = concrete actions or to-dos with a clear completion state
- goals = aspirational outcomes, bigger intentions, projects to pursue, ideas to develop
- memories = recurring preferences, key life facts, important patterns
- startTime = best suggested time in HH:mm (default "09:00")
- estimatedMinutes = realistic time to complete (15–240)
- priority = 0 low, 1 medium, 2 high, 3 urgent
- goalTitle = if a task clearly belongs to one of the extracted goals, set this to the exact goal title; otherwise ""
- Use [] for any empty category

Brain dump:
"""
${_sanitize(input)}
"""
''';

    try {
      return await _withRetry(() async {
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
      });
    } catch (e) {
      if (kDebugMode) debugPrint('brainDump failed after retries: $e');
      return const BrainDumpResult(tasks: [], goals: [], memories: []);
    }
  }
  // ── Behavioural pattern extraction ──────────────────────────────────────

  /// Analyses completed-task history to extract reusable behavioural patterns.
  ///
  /// Returns a list of patterns like:
  /// `[{"pattern":"User focuses on creative work before noon","confidence":0.8,"category":"time"}]`
  ///
  /// Results should be stored as [MemoryEntry] records with `sourceType='pattern'`.
  Future<List<Map<String, dynamic>>> extractPatterns(
    List<TaskItem> history, {
    List<MemoryEntry>? memories,
  }) async {
    final completed = history.where((t) => t.isCompleted).toList();
    if (completed.length < 3) return []; // not enough data

    final taskLines = completed
        .take(40)
        .map((t) {
          final h = t.startTime.hour;
          final period = h < 12
              ? 'morning'
              : (h < 17 ? 'afternoon' : 'evening');
          return '  - "${t.title}" [$period] [${t.priorityLabel}] tags: ${t.tags.join(", ")}';
        })
        .join('\n');

    final memCtx = _buildMemoryContext(memories, maxEntries: 5);

    final prompt =
        '''
You are AutoPlanner AI. Analyse the user's task completion history and extract 3-6 meaningful behavioural patterns.
Focus on: time-of-day preferences, task category habits, productivity rhythms, recurring behaviours.
$memCtx
Completed tasks:
$taskLines

Respond ONLY with a valid JSON array — no markdown, no explanation:
[{"pattern":"One-sentence pattern description","confidence":0.7,"category":"time|task|habit|productivity"}]

Rules:
- confidence: 0.3 (weak signal) to 0.9 (very consistent)
- Only include patterns supported by the data
- Be specific and actionable (e.g., NOT "user likes mornings" but "user completes high-priority tasks before 11am")
''';

    return await _withRetry(() async {
      final response = await _provider.complete(prompt);
      await _tracker.log(action: 'extractPatterns', response: response);
      try {
        final list = AIValidator.extractArray(response.text, context: 'extractPatterns');
        return list.cast<Map<String, dynamic>>();
      } catch (e) {
        if (kDebugMode) debugPrint('extractPatterns error: $e');
        return <Map<String, dynamic>>[];
      }
    });
  }

  // ── Proactive task suggestions ───────────────────────────────────────────

  /// Suggests tasks the user might want to schedule based on memory context,
  /// past behaviour patterns, and the target [date].
  ///
  /// Returns a short list of actionable task title strings (not full objects)
  /// so the UI can render them as quick-add chips.
  Future<List<String>> suggestTasks({
    required List<MemoryEntry> memories,
    required DateTime date,
    List<TaskItem>? recentHistory,
  }) async {
    if (memories.isEmpty && (recentHistory?.isEmpty ?? true)) return [];

    final memCtx = _buildMemoryContext(memories, maxEntries: 12);

    final historyLines = recentHistory == null || recentHistory.isEmpty
        ? '  (none)'
        : recentHistory
              .take(15)
              .map((t) => '  - "${t.title}" [${t.priorityLabel}]')
              .join('\n');

    final dayName = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][date.weekday - 1];

    final prompt =
        '''
You are AutoPlanner AI. Suggest 4-6 tasks the user might want to add to their schedule for $dayName.
Base suggestions on their memory context, recent history, and typical patterns.
$memCtx
Recent task history:
$historyLines

Respond ONLY with a valid JSON array of short, actionable task titles — no markdown, no explanation:
["Review project proposal","Call dentist","30-min workout","Weekly grocery run"]

Rules:
- Keep each title under 40 characters
- Be concrete and actionable — not vague like "work on project"
- Vary by type (health, work, personal, admin)
- Only suggest things plausibly relevant to this user's context
''';

    try {
      return await _withRetry(() async {
        final response = await _provider.complete(prompt);
        await _tracker.log(action: 'suggestTasks', response: response);
        return _parseStringList(response.text);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('suggestTasks failed after retries: $e');
      return [];
    }
  }

  // ── Weekly review ──────────────────────────────────────────────────────────

  /// Generates a structured weekly review with highlights, patterns, and tips.
  Future<String?> generateWeeklyReview({
    required List<TaskItem> weekTasks,
    required List<GoalItem> weekGoals,
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

    final goalSummary = weekGoals.isEmpty
        ? '  (none)'
        : weekGoals.take(5).map((g) {
            final linked = weekTasks.where(
              (t) => (g.linkedTaskIds).contains(t.id),
            );
            final done = linked.where((t) => t.isCompleted).length;
            final total = linked.length;
            final pct = total > 0 ? (done / total * 100).round() : 0;
            final deadlineStr = g.deadline != null
                ? ' (deadline: ${g.deadline!.day}/${g.deadline!.month}/${g.deadline!.year})'
                : '';
            return '  - "${g.title}" — $done/$total linked tasks done ($pct%)$deadlineStr';
          }).join('\n');

    final memCtx = _buildMemoryContext(memories, maxEntries: 5);

    final prompt =
        '''
You are AutoPlanner AI. Generate an insightful weekly review.

This week's stats: $completed/$total tasks completed ($rate% completion rate)

Tasks:
$taskSummary

Active goals:
$goalSummary
$memCtx
Write a structured weekly review with these sections:
1. **Highlights** — what went well
2. **Patterns noticed** — productivity trends or habits
3. **Goal progress** — how active goals are tracking and what to focus on
4. **Suggestions for next week** — 2-3 actionable tips

Keep it encouraging, concise, and actionable. Use markdown formatting.
Respond with ONLY the review text.
''';
    try {
      return await _withRetry(() async {
        final response = await _provider.complete(prompt);
        await _tracker.log(action: 'weeklyReview', response: response);
        // Screen output before returning to UI
        _guard.validateOutput(response.text);
        return response.text.trim();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('weeklyReview failed after retries: $e');
      return null;
    }
  }
  // ── Private parsers ─────────────────────────────────────────────────────

  BrainDumpResult _parseBrainDumpResult(String text) {
    try {
      final data = AIValidator.extractObject(text, context: 'brainDump');

      // Extract goal-title links before they are lost during task parsing.
      final rawTasks = data['tasks'] as List<dynamic>? ?? [];
      final taskGoalLinks = <int, String>{};
      for (var i = 0; i < rawTasks.length; i++) {
        final gt = (rawTasks[i] as Map<String, dynamic>?)?['goalTitle'];
        if (gt is String && gt.trim().isNotEmpty) {
          taskGoalLinks[i] = gt.trim();
        }
      }

      final tasks = _parseTasksFromJson(jsonEncode(rawTasks));
      final goals = (data['goals'] as List<dynamic>? ?? [])
          .map(
            (g) => BrainGoal(
              title: (g['title'] as String?)?.trim() ?? 'Goal',
              description: (g['description'] as String?)?.trim() ?? '',
            ),
          )
          .toList();
      final memories = (data['memories'] as List<dynamic>? ?? [])
          .map((m) => m.toString().trim())
          .where((m) => m.isNotEmpty)
          .toList();

      return BrainDumpResult(
        tasks: tasks,
        goals: goals,
        memories: memories,
        taskGoalLinks: taskGoalLinks,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('_parseBrainDumpResult error: $e');
      return const BrainDumpResult(tasks: [], goals: [], memories: []);
    }
  }

  List<TaskItem> _parsePlanDayResult(
    String text,
    List<TaskItem> existingTasks,
  ) {
    try {
      final jsonList = AIValidator.extractArray(text, context: 'planDay');
      final existingMap = {for (final t in existingTasks) t.id: t};

      final results = <TaskItem>[];
      for (final item in jsonList) {
        try {
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
        } catch (e) {
          if (kDebugMode) debugPrint('Skipping malformed planDay item: $e');
        }
      }
      return results;
    } catch (e) {
      _monitor?.logAIError(
        action: 'planDay',
        message: 'JSON decoding failed: $e',
        detail: text,
      );
      if (kDebugMode) debugPrint('_parsePlanDayResult error: $e');
      return existingTasks;
    }
  }

  List<TaskItem> _parseTasksFromJson(String text) {
    try {
      final jsonList = AIValidator.extractArray(text, context: 'parseTasks');
      final now = DateTime.now();
      final results = <TaskItem>[];
      for (final task in jsonList) {
        try {
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
          results.add(
            TaskItem(
              id: _uuid.v4(),
              title: (task['title'] as String?)?.trim() ?? 'Task',
              startTime: start,
              endTime: start.add(Duration(minutes: estimatedMins)),
              priority: (task['priority'] as int?)?.clamp(0, 3) ?? 1,
              tags:
                  (task['tags'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [],
            ),
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Skipping malformed task item: $e');
        }
      }
      return results;
    } catch (e) {
      _monitor?.logAIError(
        action: 'parseTasks',
        message: 'JSON decoding failed: $e',
        detail: text,
      );
      if (kDebugMode) debugPrint('_parseTasksFromJson error: $e');
      return [];
    }
  }

  List<String> _parseStringList(String text) {
    try {
      final list = AIValidator.extractArray(text, context: 'parseStringList');
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
    final sorted = List<MemoryEntry>.from(memories)
      ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    final lines = sorted
        .take(maxEntries)
        .map((m) => '  - ${_sanitize(m.content)}')
        .join('\n');
    return lines.isEmpty ? '' : '\nUser memory context:\n$lines\n';
  }
}
