import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../config/env_config.dart';
import 'ai_provider.dart';

part 'token_tracker.g.dart';

/// Persistent record of a single AI call for billing/audit.
@HiveType(typeId: 10)
class AILogEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String model;

  @HiveField(2)
  String action; // e.g. 'parseTasks', 'summarizeNote'

  @HiveField(3)
  int promptTokens;

  @HiveField(4)
  int completionTokens;

  @HiveField(5)
  int latencyMs;

  @HiveField(6)
  DateTime timestamp;

  @HiveField(7)
  bool success;

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

/// Tracks AI token usage and enforces daily limits.
class TokenTracker {
  Box<AILogEntry>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<AILogEntry>('aiLogsBox');
  }

  /// Log an AI response
  Future<void> log({
    required String action,
    required AIResponse response,
    bool success = true,
  }) async {
    if (!appConfig.enableTokenTracking) return;

    final entry = AILogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      model: response.model,
      action: action,
      promptTokens: response.promptTokens,
      completionTokens: response.completionTokens,
      latencyMs: response.latencyMs,
      timestamp: DateTime.now(),
      success: success,
    );

    await _box?.put(entry.id, entry);

    if (appConfig.enableAILogging && kDebugMode) {
      if (kDebugMode) {
        print(
        '🔢 Token usage: ${response.totalTokens} '
        '(${response.promptTokens}→${response.completionTokens}) '
        '| ${response.latencyMs}ms | ${response.model} | $action',
      );
      }
    }
  }

  /// Total tokens used today
  int get todayTokens {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return (_box?.values ?? [])
        .where((e) => e.timestamp.isAfter(todayStart))
        .fold(0, (sum, e) => sum + e.totalTokens);
  }

  /// Check if daily limit is exceeded
  bool get isOverLimit => todayTokens >= appConfig.maxTokensPerDay;

  /// Remaining tokens for today
  int get remainingTokens => (appConfig.maxTokensPerDay - todayTokens).clamp(
    0,
    appConfig.maxTokensPerDay,
  );

  /// Today's call count
  int get todayCallCount {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return (_box?.values ?? [])
        .where((e) => e.timestamp.isAfter(todayStart))
        .length;
  }

  /// Average latency today (ms)
  double get todayAvgLatency {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEntries = (_box?.values ?? [])
        .where((e) => e.timestamp.isAfter(todayStart))
        .toList();
    if (todayEntries.isEmpty) return 0;
    return todayEntries.fold(0, (sum, e) => sum + e.latencyMs) /
        todayEntries.length;
  }

  /// Usage history — last N days
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

  /// All log entries (most recent first)
  List<AILogEntry> get allLogs {
    final entries = _box?.values.toList() ?? [];
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Clear old logs (keep last N days)
  Future<void> pruneOlderThan({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final oldKeys = (_box?.toMap() ?? {}).entries
        .where((e) => e.value.timestamp.isBefore(cutoff))
        .map((e) => e.key);
    await _box?.deleteAll(oldKeys);
  }
}
