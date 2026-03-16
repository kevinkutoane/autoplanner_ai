import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/ai/token_tracker.dart';
import 'package:autoplanner_ai/core/ai/ai_provider.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

AIResponse _response({
  int promptTokens = 100,
  int completionTokens = 50,
  int latencyMs = 200,
}) => AIResponse(
  text: 'test response',
  promptTokens: promptTokens,
  completionTokens: completionTokens,
  latencyMs: latencyMs,
  model: 'test-model',
);

// ── Suite ─────────────────────────────────────────────────────────────────────

void main() {
  late Directory tempDir;

  setUpAll(() async {
    // Enable tracking and set a low daily cap (1 000 tokens) for limit tests.
    dotenv.testLoad(
      fileInput: 'ENABLE_TOKEN_TRACKING=true\nMAX_TOKENS_PER_DAY=1000',
    );
    appConfig = EnvConfig.fromDotEnv();
    tempDir = await Directory.systemTemp.createTemp('token_tracker_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(AILogEntryAdapter());
    }
  });

  late TokenTracker tracker;

  setUp(() async {
    tracker = TokenTracker();
    await tracker.init(); // opens 'aiLogsBox' without encryption
  });

  tearDown(() async {
    if (Hive.isBoxOpen('aiLogsBox')) {
      await Hive.box<AILogEntry>('aiLogsBox').clear();
      await Hive.box<AILogEntry>('aiLogsBox').close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // ── todayTokens ──────────────────────────────────────────────────────────

  group('TokenTracker.todayTokens', () {
    test('returns 0 when no entries have been logged', () {
      expect(tracker.todayTokens, equals(0));
    });

    test('counts prompt + completion tokens from a single log call', () async {
      await tracker.log(
        action: 'parseTasks',
        response: _response(promptTokens: 100, completionTokens: 50),
      );
      expect(tracker.todayTokens, equals(150));
    });

    test('accumulates tokens across multiple log calls', () async {
      await tracker.log(
        action: 'parseTasks',
        response: _response(promptTokens: 100, completionTokens: 50),
      );
      await tracker.log(
        action: 'summarize',
        response: _response(promptTokens: 200, completionTokens: 100),
      );
      // 150 + 300 = 450
      expect(tracker.todayTokens, equals(450));
    });
  });

  // ── isOverLimit / guardRateLimit ─────────────────────────────────────────

  group('TokenTracker.isOverLimit / guardRateLimit', () {
    test('isOverLimit is false when no tokens have been logged', () {
      expect(tracker.isOverLimit, isFalse);
    });

    test('isOverLimit is false when usage is below the daily cap', () async {
      await tracker.log(
        action: 'test',
        response: _response(promptTokens: 400, completionTokens: 200),
      ); // 600 < 1000
      expect(tracker.isOverLimit, isFalse);
    });

    test('isOverLimit becomes true when usage meets the daily cap', () async {
      await tracker.log(
        action: 'test',
        response: _response(promptTokens: 600, completionTokens: 500),
      ); // 1100 >= 1000
      expect(tracker.isOverLimit, isTrue);
    });

    test('guardRateLimit does not throw when under the daily cap', () {
      expect(() => tracker.guardRateLimit(), returnsNormally);
    });

    test(
      'guardRateLimit throws RateLimitException when over the daily cap',
      () async {
        await tracker.log(
          action: 'test',
          response: _response(promptTokens: 600, completionTokens: 500),
        );
        expect(
          () => tracker.guardRateLimit(),
          throwsA(isA<RateLimitException>()),
        );
      },
    );
  });

  // ── remainingTokens ──────────────────────────────────────────────────────

  group('TokenTracker.remainingTokens', () {
    test('equals maxTokensPerDay when no tokens logged', () {
      expect(tracker.remainingTokens, equals(1000));
    });

    test('decreases proportionally after logging', () async {
      await tracker.log(
        action: 'test',
        response: _response(promptTokens: 200, completionTokens: 100),
      );
      expect(tracker.remainingTokens, equals(700)); // 1000 - 300
    });

    test('is clamped to 0 when usage exceeds the daily cap', () async {
      await tracker.log(
        action: 'test',
        response: _response(promptTokens: 800, completionTokens: 400),
      ); // 1200 total
      expect(tracker.remainingTokens, equals(0));
    });
  });

  // ── todayCallCount ───────────────────────────────────────────────────────

  group('TokenTracker.todayCallCount', () {
    test('returns 0 initially', () {
      expect(tracker.todayCallCount, equals(0));
    });

    test('counts each distinct log call', () async {
      await tracker.log(action: 'a', response: _response());
      await tracker.log(action: 'b', response: _response());
      await tracker.log(action: 'c', response: _response());
      expect(tracker.todayCallCount, equals(3));
    });
  });

  // ── todayAvgLatency ──────────────────────────────────────────────────────

  group('TokenTracker.todayAvgLatency', () {
    test('returns 0 when no calls have been made', () {
      expect(tracker.todayAvgLatency, equals(0));
    });

    test('returns the average latency in milliseconds', () async {
      await tracker.log(action: 'a', response: _response(latencyMs: 200));
      await tracker.log(action: 'b', response: _response(latencyMs: 400));
      expect(tracker.todayAvgLatency, equals(300.0));
    });

    test('returns the single value when only one call logged', () async {
      await tracker.log(action: 'single', response: _response(latencyMs: 350));
      expect(tracker.todayAvgLatency, equals(350.0));
    });
  });

  // ── usageHistory ─────────────────────────────────────────────────────────

  group('TokenTracker.usageHistory', () {
    test('returns a map with the requested number of day-keys', () async {
      final history = tracker.usageHistory(days: 7);
      expect(history.length, equals(7));
    });

    test('today key reflects tokens logged today', () async {
      await tracker.log(
        action: 'test',
        response: _response(promptTokens: 100, completionTokens: 50),
      );
      final history = tracker.usageHistory(days: 1);
      // One entry representing today — value should be 150.
      expect(history.values.first, equals(150));
    });

    test('returns zero-filled history when nothing logged', () {
      final history = tracker.usageHistory(days: 5);
      expect(history.values.every((v) => v == 0), isTrue);
    });
  });

  // ── AILogEntry model ─────────────────────────────────────────────────────

  group('AILogEntry', () {
    test('totalTokens equals promptTokens + completionTokens', () {
      final entry = AILogEntry(
        id: '1',
        model: 'gemini',
        action: 'parseTasks',
        promptTokens: 100,
        completionTokens: 50,
        latencyMs: 200,
        timestamp: DateTime.now(),
      );
      expect(entry.totalTokens, equals(150));
    });

    test('success field defaults to true', () {
      final entry = AILogEntry(
        id: '1',
        model: 'gemini',
        action: 'test',
        promptTokens: 0,
        completionTokens: 0,
        latencyMs: 0,
        timestamp: DateTime.now(),
      );
      expect(entry.success, isTrue);
    });
  });

  // ── RateLimitException ───────────────────────────────────────────────────

  group('RateLimitException', () {
    test('carries the error message', () {
      const ex = RateLimitException('Daily limit exceeded');
      expect(ex.message, equals('Daily limit exceeded'));
      expect(ex.toString(), contains('Daily limit exceeded'));
    });
  });
}
