import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Represents a queued AI request that can be persisted and retried.
///
/// When the device is offline, AI calls are serialised into [QueuedAIRequest]
/// objects and stored in a Hive box. When connectivity resumes, the queue
/// drains automatically in FIFO order.
class QueuedAIRequest {
  /// Unique identifier for deduplication.
  final String id;

  /// The AI method name (e.g. 'parseTasks', 'brainDump', 'dailyInsight').
  final String method;

  /// JSON-encoded arguments for the AI method.
  final String argsJson;

  /// ISO-8601 timestamp of when the request was queued.
  final String queuedAt;

  /// Number of times this request has been attempted.
  int attempts;

  /// Last error message, if any.
  String? lastError;

  /// True if the request failed fatally or exceeded max retries.
  bool isPermanentFailure;

  QueuedAIRequest({
    required this.id,
    required this.method,
    required this.argsJson,
    required this.queuedAt,
    this.attempts = 0,
    this.lastError,
    this.isPermanentFailure = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'method': method,
    'argsJson': argsJson,
    'queuedAt': queuedAt,
    'attempts': attempts,
    'lastError': lastError,
    'isPermanentFailure': isPermanentFailure,
  };

  factory QueuedAIRequest.fromMap(Map<dynamic, dynamic> map) => QueuedAIRequest(
    id: map['id'] as String,
    method: map['method'] as String,
    argsJson: map['argsJson'] as String,
    queuedAt: map['queuedAt'] as String,
    attempts: map['attempts'] as int? ?? 0,
    lastError: map['lastError'] as String?,
    isPermanentFailure: map['isPermanentFailure'] as bool? ?? false,
  );
}

/// Offline-resilient AI queue with at-least-once execution semantics.
///
/// Lifecycle:
///   enqueue → persist to Hive → reload/restart → reconnect → dispatch → execute → acknowledge (delete)
///
/// Execution Guarantee:
///   At-least-once execution. Requests are persisted to disk prior to dispatch.
///   If process termination occurs mid-execution, requests remain persisted and
///   are re-drained upon subsequent application startup. Handlers invoked by
///   [executeCallback] should be idempotent.
///
/// Fault Tolerance:
///   - Transient failures are retried up to [_maxAttempts] times with FIFO ordering.
///   - Exceeding [_maxAttempts] marks the request as [isPermanentFailure], retaining
///     it diagnostically without retrying infinitely.
///   - Fatal format or unsupported errors immediately dead-letter without retry.
///   - Acknowledgement (box deletion) occurs strictly AFTER [executeCallback] completes.
class OfflineAIQueue {
  static const String _boxName = 'aiQueueBox';
  static const int _maxAttempts = 5;
  static const _uuid = Uuid();

  late Box<Map> _box;
  StreamSubscription? _connectivitySub;
  Future<void>? _currentDrain;

  /// Callback that executes the actual AI call.
  /// Receives the method name and decoded arguments map.
  /// Should throw on failure so the queue can retry.
  final Future<void> Function(String method, Map<String, dynamic> args)
  executeCallback;

  /// Notifies listeners when the queue length changes.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  OfflineAIQueue({required this.executeCallback});

  /// Initialise the queue box and start listening for connectivity changes.
  /// If [cipher] is provided, the queue box is opened using AES-256 encryption.
  /// [customDir] can be passed for test isolation.
  /// [autoDrain] determines whether to trigger an immediate drain upon init.
  Future<void> init({
    HiveCipher? cipher,
    String? customDir,
    bool autoDrain = true,
  }) async {
    _box = await Hive.openBox<Map>(
      _boxName,
      encryptionCipher: cipher,
      path: customDir,
      crashRecovery: false,
    );
    _updatePendingCount();

    // Listen for connectivity changes and drain when online.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) drain();
    });

    // Attempt an initial drain in case we came online while the app was closed.
    if (autoDrain) {
      drain();
    }
  }

  /// Enqueue an AI request for later execution.
  ///
  /// If the device is currently online, the queue will attempt to drain
  /// immediately after enqueuing.
  Future<void> enqueue(String method, Map<String, dynamic> args) async {
    final request = QueuedAIRequest(
      id: '${method}_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}',
      method: method,
      argsJson: jsonEncode(args),
      queuedAt: DateTime.now().toIso8601String(),
    );
    await _box.put(request.id, request.toMap());
    _updatePendingCount();
    if (kDebugMode) {
      debugPrint(
        'OfflineAIQueue: enqueued $method (${pendingCount.value} pending)',
      );
    }
    // Try to drain immediately — if online, it will execute right away.
    await drain();
  }

  /// Drain the queue, executing pending requests in FIFO order.
  ///
  /// Requests that fail are retried up to [_maxAttempts] times.
  /// Requests exceeding the limit are removed from the queue.
  Future<void> drain() async {
    if (!_box.isOpen) return;
    if (_currentDrain != null) {
      await _currentDrain;
      return;
    }
    final completer = Completer<void>();
    _currentDrain = completer.future;
    try {
      bool continueDraining = true;
      while (continueDraining && _box.isOpen) {
        final hadTransientError = await _performDrain();
        if (hadTransientError) {
          break; // Stop draining, network still down or rate limited
        }
        // Check if new actionable items were added while draining
        continueDraining = activePending > 0;
      }
    } finally {
      _currentDrain = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Executes actionable requests in strict FIFO order by [queuedAt].
  /// Returns `true` if drain halted due to a transient failure.
  Future<bool> _performDrain() async {
    bool hadTransientFailure = false;
    if (!_box.isOpen) return false;

    // Process in strict FIFO order sorted by queuedAt timestamp
    final requests = pendingRequests;
    for (final queued in requests) {
      final key = queued.id;
      if (!_box.isOpen) return false;
      final raw = _box.get(key);
      if (raw == null) continue;

      final request = QueuedAIRequest.fromMap(raw);

      if (request.isPermanentFailure) continue;

      if (request.attempts >= _maxAttempts) {
        // Exceeded max attempts — mark as permanent failure instead of deleting.
        request.isPermanentFailure = true;
        request.lastError = 'Exceeded $_maxAttempts attempts';
        if (!_box.isOpen) return false;
        await _box.put(key, request.toMap());
        _updatePendingCount();
        if (kDebugMode) {
          debugPrint(
            'OfflineAIQueue: marked ${request.method} as permanent failure',
          );
        }
        continue;
      }

      try {
        final args = jsonDecode(request.argsJson) as Map<String, dynamic>;
        await executeCallback(request.method, args);
        // Success — remove from queue.
        if (!_box.isOpen) return false;
        await _box.delete(key);
        _updatePendingCount();
        if (kDebugMode) {
          debugPrint('OfflineAIQueue: completed ${request.method}');
        }
      } catch (e) {
        // Failure — increment attempts and store the error.
        request.attempts++;
        request.lastError = e.toString();

        // Fail safely for unknown operations (UnsupportedError) or max attempts
        if (request.attempts >= _maxAttempts) {
          request.isPermanentFailure = true;
          request.lastError = 'Exceeded $_maxAttempts attempts';
        } else if (e is UnsupportedError || e is FormatException) {
          request.isPermanentFailure = true;
        }

        if (!_box.isOpen) return false;
        await _box.put(key, request.toMap());
        _updatePendingCount();
        if (kDebugMode) {
          debugPrint(
            'OfflineAIQueue: ${request.method} attempt ${request.attempts} failed: $e',
          );
        }
        // Stop draining on first transient failure — likely still offline or rate limited.
        if (!request.isPermanentFailure) {
          hadTransientFailure = true;
          break;
        }
      }
    }
    return hadTransientFailure;
  }

  /// Total number of requests in the queue box.
  int get pending => _box.length;

  /// Number of actionable requests (excluding diagnostic permanent failures).
  int get activePending =>
      pendingRequests.where((r) => !r.isPermanentFailure).length;

  /// All pending requests, for UI display.
  List<QueuedAIRequest> get pendingRequests {
    return _box.values.map((raw) => QueuedAIRequest.fromMap(raw)).toList()
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
  }

  /// Remove a specific request from the queue.
  Future<void> remove(String id) async {
    await _box.delete(id);
    _updatePendingCount();
  }

  /// Clear all pending requests.
  Future<void> clearAll() async {
    await _box.clear();
    _updatePendingCount();
  }

  void _updatePendingCount() {
    pendingCount.value = _box.length;
  }

  /// Clean up resources.
  void dispose() {
    _connectivitySub?.cancel();
    pendingCount.dispose();
  }
}
