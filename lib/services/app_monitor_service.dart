import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../core/diagnostics/crash_reporter.dart';

part 'app_monitor_service.g.dart';

// ── Event type constants ───────────────────────────────────────────────────
const _kSession = 'session';
const _kWarning = 'warning';
const _kError = 'error';
const _kFatal = 'fatal';

/// A single monitoring event persisted in the encrypted `appEventsBox`.
///
/// Four event types are recorded:
/// - `'session'` — foreground session; [durationMs] is set when the session
///   ends via [AppMonitorService.logSessionEnd].
/// - `'warning'` — startup configuration warning captured during app boot.
/// - `'error'`   — non-fatal Flutter framework error captured via
///   [FlutterError.onError].
/// - `'fatal'`   — unhandled async error captured via
///   [PlatformDispatcher.onError].
@HiveType(typeId: 11)
class AppEvent extends HiveObject {
  /// Unique identifier (UUID v4).
  @HiveField(0)
  String id;

  /// Event type: `'session'`, `'error'`, or `'fatal'`.
  @HiveField(1)
  String type;

  /// Short human-readable summary (≤ 200 chars).
  @HiveField(2)
  String message;

  /// Truncated stack trace or supplementary context (≤ 500 chars).
  /// Empty string for session events.
  @HiveField(3)
  String detail;

  /// When the event occurred.  For sessions this is the session start time.
  @HiveField(4)
  DateTime timestamp;

  /// Foreground duration in milliseconds.  Non-zero only for completed
  /// `'session'` events.
  @HiveField(5)
  int durationMs;

  AppEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.detail,
    required this.timestamp,
    this.durationMs = 0,
  });
}

/// Lightweight, fully on-device monitoring service.
///
/// Captures app sessions, non-fatal Flutter errors, and unhandled async
/// errors into an AES-256 encrypted Hive box (`appEventsBox`).  All data
/// stays on the device and is surfaced in **Analytics → App Health**.
///
/// ## Setup (in `main()`):
/// ```dart
/// final monitor = AppMonitorService();
/// await monitor.init(cipher: hiveCipher);
///
/// // Capture framework errors.
/// final originalOnError = FlutterError.onError;
/// FlutterError.onError = (details) {
///   originalOnError?.call(details);
///   monitor.logFlutterError(details);
/// };
///
/// // Capture unhandled async errors.
/// PlatformDispatcher.instance.onError = (error, stack) {
///   monitor.logFatalError(error, stack);
///   return !kDebugMode;
/// };
/// ```
class AppMonitorService {
  static const _uuid = Uuid();
  final CrashReporter _reporter;
  Box<AppEvent>? _box;
  DateTime? _sessionStart;

  AppMonitorService({CrashReporter? reporter})
    : _reporter = reporter ?? const NoOpCrashReporter();

  /// Opens (or reuses) the `appEventsBox` and prunes events > 30 days old.
  Future<void> init({HiveAesCipher? cipher}) async {
    _box = await Hive.openBox<AppEvent>(
      'appEventsBox',
      encryptionCipher: cipher,
    );
    await pruneOlderThan(days: 30);
  }

  // ── Session tracking ───────────────────────────────────────────────────────

  /// Records the moment the app enters the foreground.
  /// Call this in [WidgetsBindingObserver.didChangeAppLifecycleState] when
  /// state == [AppLifecycleState.resumed].
  void logSessionStart() => _sessionStart = DateTime.now();

  /// Persists the completed session started by [logSessionStart].
  /// Sessions shorter than one second are discarded (e.g. brief pauses).
  Future<void> logSessionEnd() async {
    final start = _sessionStart;
    if (start == null) return;
    final durationMs = DateTime.now().difference(start).inMilliseconds;
    _sessionStart = null;
    if (durationMs < 1000) return;
    final e = AppEvent(
      id: _uuid.v4(),
      type: _kSession,
      message: 'Session',
      detail: '',
      timestamp: start,
      durationMs: durationMs,
    );
    await _writeEvent(e);
  }

  /// Persists non-fatal startup warnings so release config issues are visible.
  Future<void> logStartupWarnings(List<String> warnings) async {
    for (final warning in warnings) {
      final event = AppEvent(
        id: _uuid.v4(),
        type: _kWarning,
        message: warning,
        detail: '',
        timestamp: DateTime.now(),
      );
      await _writeEvent(event);
      _reporter.addBreadcrumb(warning, category: 'startup-warning');
    }
  }

  // ── Error logging ──────────────────────────────────────────────────────────

  /// Logs a Flutter framework error (hook into [FlutterError.onError]).
  Future<void> logFlutterError(FlutterErrorDetails details) async {
    final msg = details.exception.toString();
    final stack = details.stack?.toString() ?? '';
    final e = AppEvent(
      id: _uuid.v4(),
      type: _kError,
      message: msg.length > 200 ? '${msg.substring(0, 200)}…' : msg,
      detail: stack.length > 500 ? '${stack.substring(0, 500)}…' : stack,
      timestamp: DateTime.now(),
    );
    await _writeEvent(e);
    await _reporter.captureFlutterError(details);
  }

  /// Logs an unhandled async error (hook into [PlatformDispatcher.onError]).
  Future<void> logFatalError(Object error, StackTrace? stack) async {
    final msg = error.toString();
    final st = stack?.toString() ?? '';
    final e = AppEvent(
      id: _uuid.v4(),
      type: _kFatal,
      message: msg.length > 200 ? '${msg.substring(0, 200)}…' : msg,
      detail: st.length > 500 ? '${st.substring(0, 500)}…' : st,
      timestamp: DateTime.now(),
    );
    await _writeEvent(e);
    await _reporter.captureException(error, stack);
  }

  // ── Stats ──────────────────────────────────────────────────────────────────

  /// All warning, error, and fatal events, sorted most-recent-first.
  List<AppEvent> get recentAlerts {
    return (_box?.values ?? const <AppEvent>[])
        .where(
          (e) => e.type == _kWarning || e.type == _kError || e.type == _kFatal,
        )
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Completed session events within the last [days] days.
  List<AppEvent> sessionsInDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (_box?.values ?? const <AppEvent>[])
        .where((e) => e.type == _kSession && e.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Number of error/fatal events within the last [days] days.
  int errorCountInDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (_box?.values ?? const <AppEvent>[])
        .where(
          (e) =>
              (e.type == _kError || e.type == _kFatal) &&
              e.timestamp.isAfter(cutoff),
        )
        .length;
  }

  /// Average foreground session length, computed across all recorded sessions.
  Duration get avgSessionDuration {
    final sessions = (_box?.values ?? const <AppEvent>[])
        .where((e) => e.type == _kSession && e.durationMs > 0)
        .toList();
    if (sessions.isEmpty) return Duration.zero;
    final totalMs = sessions.fold<int>(0, (sum, e) => sum + e.durationMs);
    return Duration(milliseconds: totalMs ~/ sessions.length);
  }

  /// Estimated crash-free session rate over the last [days] days.
  ///
  /// Calculated as `(sessions - errors) / sessions`.  Returns `1.0` when
  /// there are no recorded sessions yet.
  double crashFreeRate({int days = 7}) {
    final sessions = sessionsInDays(days).length;
    if (sessions == 0) return 1.0;
    final errors = errorCountInDays(days);
    return (1.0 - (errors / sessions)).clamp(0.0, 1.0);
  }

  /// Removes all events older than [days] days to keep the box lean.
  Future<void> pruneOlderThan({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final oldKeys = (_box?.toMap() ?? {})
        .entries
        .where((e) => e.value.timestamp.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
    if (oldKeys.isNotEmpty) await _box?.deleteAll(oldKeys);
  }

  Future<void> _writeEvent(AppEvent event) async {
    await _box?.put(event.id, event);
  }

  // ── Debug helpers ─────────────────────────────────────────────────────────

  /// Clears all events (dev/test use only).
  Future<void> clearAll() async {
    if (kDebugMode) await _box?.clear();
  }
}
