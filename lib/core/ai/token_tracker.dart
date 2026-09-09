import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../config/env_config.dart';
import 'ai_provider.dart';

part 'token_tracker.g.dart';

/// Persistent record of a single AI call for billing/audit.
@HiveType(typeId: 10)
class AILogEntry extends HiveObject {
  /// Unique identifier for this log entry (UUID v4).
  @HiveField(0)
  String id;

  /// Name of the model that produced the response (e.g. `'gemini-2.5-flash'`).
  @HiveField(1)
  String model;

  /// The high-level AI action that triggered this call (e.g. `'parseTasks'`,
  /// `'summarizeNote'`). Used for per-action cost analysis.
  @HiveField(2)
  String action;

  /// Number of tokens in the prompt sent to the model.
  @HiveField(3)
  int promptTokens;

  /// Number of tokens in the model's response.
  @HiveField(4)
  int completionTokens;

  /// Wall-clock time the model took to respond, in milliseconds.
  @HiveField(5)
  int latencyMs;

  /// When this call was made; used to bucket usage by calendar day.
  @HiveField(6)
  DateTime timestamp;

  /// Whether the call completed successfully. False for retried failures.
  @HiveField(7)
  bool success;

  /// Combined token count: [promptTokens] + [completionTokens].
  int get totalTokens => promptTokens + completionTokens;

  AILogEntry({
    required this.id,
    required this.model,
    required this.action,
    required this.promptTokens,
    required this.completionTokens,
    required this.latencyMs,
    required this.timestamp,
    this.success = true,
  });
}

/// Tracks AI token usage, enforces daily rate limits, and persists an audit
/// log of every model call in an encrypted Hive box.
///
/// Typical usage:
/// ```dart
/// final tracker = TokenTracker();
/// await tracker.init(cipher: hiveCipher); // once at app start
/// tracker.guardRateLimit();               // throws if daily cap exceeded
/// await tracker.log(action: 'parseTasks', response: response);
/// ```
class TokenTracker {
  static const _uuid = Uuid();
  Box<AILogEntry>? _box;

  // ── Cached daily tallies ──────────────────────────────────────────────────
  // Avoids scanning the entire Hive box on every todayTokens / todayCallCount
  // access. Cached values are invalidated when the calendar day rolls over.
  int _cachedDay = -1;
  int _cachedTokens = 0;
  int _cachedCalls = 0;
  int _cachedLatencySum = 0;

  /// Recomputes cached tallies if the calendar day has changed since the last
  /// call, or returns the cached values immediately.
  void _ensureDayCache() {
    final now = DateTime.now();
    final day = now.year * 10000 + now.month * 100 + now.day;
    if (day == _cachedDay) return;
    // Day rolled over — rebuild from box.
    final todayStart = DateTime(now.year, now.month, now.day);
    int tokens = 0, calls = 0, latency = 0;
    for (final e in (_box?.values ?? const <AILogEntry>[])) {
      if (e.timestamp.isAfter(todayStart)) {
        tokens += e.totalTokens;
        latency += e.latencyMs;
        calls++;
      }
    }
    _cachedDay = day;
    _cachedTokens = tokens;
    _cachedCalls = calls;
    _cachedLatencySum = latency;
  }

  Future<void> init({HiveAesCipher? cipher}) async {
    _box = await Hive.openBox<AILogEntry>(
      'aiLogsBox',
      encryptionCipher: cipher,
    );
  }

  /// Persists a token usage entry for [action] (when tracking is enabled).
  /// No operation when `appConfig.enableTokenTracking == false` or when
  /// [init] has not been called (box is null).
  Future<void> log({
    required String action,
    required AIResponse response,
    bool success = true,
  }) async {
    if (!appConfig.enableTokenTracking) return;

    final entry = AILogEntry(
      id: _uuid.v4(),
      model: response.model,
      action: action,
      promptTokens: response.promptTokens,
      completionTokens: response.completionTokens,
      latencyMs: response.latencyMs,
      timestamp: DateTime.now(),
      success: success,
    );

    // Update daily cache inline — no full rescan needed.
    _ensureDayCache();
    _cachedTokens += entry.totalTokens;
    _cachedCalls++;
    _cachedLatencySum += entry.latencyMs;

    await _box?.put(entry.id, entry);

    if (appConfig.enableAILogging && kDebugMode) {
      debugPrint(
        '🔢 Token usage: ${response.totalTokens} '
        '(${response.promptTokens}→${response.completionTokens}) '
        '| ${response.latencyMs}ms | ${response.model} | $action',
      );
    }
  }

  /// Total tokens consumed today (prompt + completion across all calls).
  int get todayTokens {
    _ensureDayCache();
    return _cachedTokens;
  }

  /// True when [todayTokens] has met or exceeded [EnvConfig.maxTokensPerDay].
  bool get isOverLimit => todayTokens >= appConfig.maxTokensPerDay;

  /// Throws [RateLimitException] if today's token budget is exhausted.
  void guardRateLimit() {
    if (isOverLimit) {
      throw RateLimitException(
        'Daily token limit reached ($todayTokens / ${appConfig.maxTokensPerDay})',
      );
    }
  }

  /// Tokens remaining in today's budget; clamped to 0 when over the limit.
  int get remainingTokens => (appConfig.maxTokensPerDay - todayTokens).clamp(
    0,
    appConfig.maxTokensPerDay,
  );

  /// Number of AI calls made today (each [log] invocation = one call).
  int get todayCallCount {
    _ensureDayCache();
    return _cachedCalls;
  }

  /// Average response latency in milliseconds across all calls today.
  /// Returns `0` when no calls have been made.
  double get todayAvgLatency {
    _ensureDayCache();
    if (_cachedCalls == 0) return 0;
    return _cachedLatencySum / _cachedCalls;
  }

  /// Per-day token totals for the last [days] calendar days.
  ///
  /// Keys are formatted as `'MM/DD'` for the calling locale. Useful for
  /// rendering sparkline charts on the analytics screen.
  Map<String, int> usageHistory({int days = 7}) {
    final now = DateTime.now();
    final result = <String, int>{};
    for (int i = 0; i < days; i++) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final tokens = (_box?.values ?? [])
          .where(
            (e) =>
                e.timestamp.isAfter(dayStart) && e.timestamp.isBefore(dayEnd),
          )
          .fold(0, (sum, e) => sum + e.totalTokens);
      final key =
          '${day.month.toString().padLeft(2, '0')}/${day.day.toString().padLeft(2, '0')}';
      result[key] = tokens;
    }
    return result;
  }

  /// All persisted log entries, sorted most-recent-first.
  List<AILogEntry> get allLogs {
    final entries = _box?.values.toList() ?? [];
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Deletes all log entries older than [days] days to keep the box lean.
  Future<void> pruneOlderThan({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final oldKeys = (_box?.toMap() ?? {}).entries
        .where((e) => e.value.timestamp.isBefore(cutoff))
        .map((e) => e.key);
    await _box?.deleteAll(oldKeys);
  }
}

/// Thrown when the daily AI token budget has been exhausted.
class RateLimitException implements Exception {
  final String message;
  const RateLimitException(this.message);
  @override
  String toString() => 'RateLimitException: $message';
}
