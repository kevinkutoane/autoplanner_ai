import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:autoplanner_ai/services/offline_ai_queue.dart';

/// Tests for the OfflineAIQueue data model and serialisation.
///
/// The full queue lifecycle (init/drain/enqueue) requires platform channels
/// for connectivity_plus which are unavailable in unit tests. These tests
/// validate the request model, Hive persistence, and queue logic at the
/// data layer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('offline_queue_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('QueuedAIRequest', () {
    test('serialises to map and back', () {
      final req = QueuedAIRequest(
        id: 'test_123',
        method: 'brainDump',
        argsJson: '{"text":"hello"}',
        queuedAt: '2026-04-21T10:00:00.000Z',
        attempts: 2,
        lastError: 'timeout',
      );

      final map = req.toMap();
      expect(map['id'], equals('test_123'));
      expect(map['method'], equals('brainDump'));
      expect(map['argsJson'], equals('{"text":"hello"}'));
      expect(map['queuedAt'], equals('2026-04-21T10:00:00.000Z'));
      expect(map['attempts'], equals(2));
      expect(map['lastError'], equals('timeout'));
      expect(map['isPermanentFailure'], isFalse);

      final restored = QueuedAIRequest.fromMap(map);
      expect(restored.id, equals('test_123'));
      expect(restored.method, equals('brainDump'));
      expect(restored.argsJson, equals('{"text":"hello"}'));
      expect(restored.queuedAt, equals('2026-04-21T10:00:00.000Z'));
      expect(restored.attempts, equals(2));
      expect(restored.lastError, equals('timeout'));
      expect(restored.isPermanentFailure, isFalse);
    });

    test('fromMap handles missing optional fields', () {
      final map = {
        'id': 'test_456',
        'method': 'dailyInsight',
        'argsJson': '{}',
        'queuedAt': '2026-04-21T12:00:00.000Z',
      };

      final req = QueuedAIRequest.fromMap(map);
      expect(req.attempts, equals(0));
      expect(req.lastError, isNull);
      expect(req.isPermanentFailure, isFalse);
    });

    test('argsJson round-trips through JSON encode/decode', () {
      final originalArgs = {
        'tasks': ['Buy groceries', 'Call dentist'],
        'memories': [
          {'text': 'Had a good day', 'score': 0.8},
        ],
      };

      final req = QueuedAIRequest(
        id: 'roundtrip_1',
        method: 'brainDump',
        argsJson: jsonEncode(originalArgs),
        queuedAt: DateTime.now().toIso8601String(),
      );

      final decoded = jsonDecode(req.argsJson) as Map<String, dynamic>;
      expect(decoded['tasks'], equals(['Buy groceries', 'Call dentist']));
      expect((decoded['memories'] as List).first['score'], equals(0.8));
    });

    test('attempt counter increments correctly', () {
      final req = QueuedAIRequest(
        id: 'retry_test',
        method: 'suggestTasks',
        argsJson: '{}',
        queuedAt: DateTime.now().toIso8601String(),
      );
      expect(req.attempts, equals(0));

      req.attempts++;
      req.lastError = 'Timeout';
      expect(req.attempts, equals(1));
      expect(req.lastError, equals('Timeout'));

      // Serialise and restore — attempts should persist
      final restored = QueuedAIRequest.fromMap(req.toMap());
      expect(restored.attempts, equals(1));
      expect(restored.lastError, equals('Timeout'));
    });
  });

  group('OfflineAIQueue Hive persistence', () {
    test('requests persist in Hive box and survive re-open', () async {
      final boxName = 'test_queue_persist';
      var box = await Hive.openBox<Map>(boxName);

      final req = QueuedAIRequest(
        id: 'persist_1',
        method: 'dailyInsight',
        argsJson: jsonEncode({'tasks': []}),
        queuedAt: DateTime.now().toIso8601String(),
      );
      await box.put(req.id, req.toMap());
      expect(box.length, equals(1));

      // Close and re-open to simulate app restart
      await box.close();
      box = await Hive.openBox<Map>(boxName);

      expect(box.length, equals(1));
      final restored = QueuedAIRequest.fromMap(box.get('persist_1')!);
      expect(restored.method, equals('dailyInsight'));
      expect(restored.id, equals('persist_1'));

      await box.close();
    });

    test('multiple requests maintain insertion order', () async {
      final boxName = 'test_queue_order';
      final box = await Hive.openBox<Map>(boxName);

      for (var i = 0; i < 5; i++) {
        final req = QueuedAIRequest(
          id: 'order_$i',
          method: 'method_$i',
          argsJson: '{}',
          queuedAt: DateTime(2026, 4, 21, 10, i).toIso8601String(),
        );
        await box.put(req.id, req.toMap());
      }

      expect(box.length, equals(5));

      // Verify FIFO order (Hive preserves insertion order)
      final keys = box.keys.toList();
      for (var i = 0; i < 5; i++) {
        expect(keys[i], equals('order_$i'));
      }

      await box.close();
    });

    test('deleting a request removes it from the box', () async {
      final boxName = 'test_queue_delete';
      final box = await Hive.openBox<Map>(boxName);

      final req = QueuedAIRequest(
        id: 'delete_me',
        method: 'brainDump',
        argsJson: '{}',
        queuedAt: DateTime.now().toIso8601String(),
      );
      await box.put(req.id, req.toMap());
      expect(box.length, equals(1));

      await box.delete('delete_me');
      expect(box.length, equals(0));
      expect(box.get('delete_me'), isNull);

      await box.close();
    });

    test('clear removes all requests', () async {
      final boxName = 'test_queue_clear';
      final box = await Hive.openBox<Map>(boxName);

      for (var i = 0; i < 3; i++) {
        final req = QueuedAIRequest(
          id: 'clear_$i',
          method: 'method_$i',
          argsJson: '{}',
          queuedAt: DateTime.now().toIso8601String(),
        );
        await box.put(req.id, req.toMap());
      }
      expect(box.length, equals(3));

      await box.clear();
      expect(box.length, equals(0));

      await box.close();
    });

    test('updating attempt count persists to box', () async {
      final boxName = 'test_queue_update';
      final box = await Hive.openBox<Map>(boxName);

      final req = QueuedAIRequest(
        id: 'update_me',
        method: 'suggestTasks',
        argsJson: '{}',
        queuedAt: DateTime.now().toIso8601String(),
      );
      await box.put(req.id, req.toMap());

      // Simulate retry: read, increment, write back
      final raw = box.get('update_me')!;
      final loaded = QueuedAIRequest.fromMap(raw);
      loaded.attempts++;
      loaded.lastError = 'Connection refused';
      await box.put(loaded.id, loaded.toMap());

      // Verify persistence
      final reloaded = QueuedAIRequest.fromMap(box.get('update_me')!);
      expect(reloaded.attempts, equals(1));
      expect(reloaded.lastError, equals('Connection refused'));

      await box.close();
    });

    test(
      'exceeding max attempts marks as permanent failure instead of deleting',
      () async {
        final queue = OfflineAIQueue(
          executeCallback: (method, args) async => throw Exception('fail'),
        );
        await queue.init();

        await queue.enqueue('suggestTasks', {});
        // Wait for the synchronous part of enqueue's background drain to finish
        await Future.delayed(const Duration(milliseconds: 50));

        // Drain until marked as permanent failure (maxAttempts = 5).
        for (var i = 0; i < 6; i++) {
          if (queue.pendingRequests.isNotEmpty &&
              queue.pendingRequests.first.isPermanentFailure) {
            break;
          }
          await queue.drain();
          await Future.delayed(const Duration(milliseconds: 20));
        }

        // It should NOT be deleted, but marked as permanent failure.
        expect(queue.pending, equals(1));
        final pendingReq = queue.pendingRequests.first;
        expect(pendingReq.isPermanentFailure, isTrue);
        expect(pendingReq.lastError, equals('Exceeded 5 attempts'));

        queue.dispose();
        await Hive.deleteBoxFromDisk('aiQueueBox');
      },
    );

    test('failing safely for unknown operations (UnsupportedError) immediately marks as permanent failure', () async {
      final queue = OfflineAIQueue(
        executeCallback: (method, args) async =>
            throw UnsupportedError('Unsupported method $method'),
      );
      await queue.init();

      await queue.enqueue('unknownMethod', {});
      await Future.delayed(const Duration(milliseconds: 50));

      expect(queue.pending, equals(1));
      final pendingReq = queue.pendingRequests.first;
      expect(pendingReq.isPermanentFailure, isTrue);
      expect(pendingReq.lastError, contains('Unsupported method'));
      // attempt should be 1 because it failed on the first try and stopped
      expect(pendingReq.attempts, equals(1));

      queue.dispose();
      await Hive.deleteBoxFromDisk('aiQueueBox');
    });

    test('AES-256 encryption lifecycle: enqueued requests persist across simulated app restart', () async {
      final key = List<int>.generate(32, (i) => (i * 7 + 13) % 256);
      final cipher = HiveAesCipher(key);

      bool isOnline = false;
      final executed = <String>[];
      final queue1 = OfflineAIQueue(
        executeCallback: (method, args) async {
          if (!isOnline) throw Exception('Network offline');
          executed.add(method);
        },
      );
      await queue1.init(cipher: cipher, customDir: tempDir.path);

      // Enqueue while offline
      await queue1.enqueue('parseTasks', {'raw': 'meeting tomorrow'});
      await queue1.enqueue('brainDump', {'text': 'new project idea'});
      expect(queue1.pending, equals(2));

      // 2. Simulate app termination: dispose queue and close Hive
      queue1.dispose();
      await Hive.close();

      // 3. Second app launch: re-init Hive and re-open with same encryption key
      Hive.init(tempDir.path);
      final queue2 = OfflineAIQueue(
        executeCallback: (method, args) async {
          if (!isOnline) throw Exception('Network offline');
          executed.add(method);
        },
      );
      await queue2.init(
        cipher: cipher,
        customDir: tempDir.path,
        autoDrain: false,
      );

      // Verify requests were safely preserved in encrypted storage
      expect(queue2.pending, equals(2));
      final pending = queue2.pendingRequests;
      expect(pending.map((r) => r.method).toList(), [
        'parseTasks',
        'brainDump',
      ]);

      // 4. Reconnect to network and drain
      isOnline = true;
      await queue2.drain();
      expect(executed, ['parseTasks', 'brainDump']);
      expect(queue2.pending, equals(0));

      queue2.dispose();
      await Hive.close();
      Hive.init(tempDir.path);
    });

    test('opening encrypted queue with incorrect key fails safely', () async {
      final key1 = List<int>.generate(32, (i) => i);
      final key2 = List<int>.generate(32, (i) => 255 - i);
      final cipher1 = HiveAesCipher(key1);
      final cipher2 = HiveAesCipher(key2);

      final queue1 = OfflineAIQueue(
        executeCallback: (m, a) async => throw Exception('Offline'),
      );
      await queue1.init(cipher: cipher1, customDir: tempDir.path);
      await queue1.enqueue('dailyInsight', {});
      queue1.dispose();
      await Hive.close();

      Hive.init(tempDir.path);
      final queue2 = OfflineAIQueue(executeCallback: (m, a) async {});
      bool didThrow = false;
      final completer = Completer<void>();
      runZonedGuarded(
        () async {
          try {
            await queue2.init(cipher: cipher2, customDir: tempDir.path);
          } catch (e) {
            if (e is HiveError || e.toString().contains('checksum')) {
              didThrow = true;
            }
          } finally {
            if (!completer.isCompleted) completer.complete();
          }
        },
        (error, stack) {
          if (error is HiveError || error.toString().contains('checksum')) {
            didThrow = true;
          }
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future;
      expect(didThrow, isTrue);
      await Hive.close();
      Hive.init(tempDir.path);
    });

    test('concurrent drain calls do not execute duplicate requests', () async {
      int executionCount = 0;
      final queue = OfflineAIQueue(
        executeCallback: (method, args) async {
          executionCount++;
          await Future.delayed(const Duration(milliseconds: 30));
        },
      );
      await queue.init(customDir: tempDir.path);
      await queue.enqueue('taskA', {});

      // Launch 3 simultaneous drain calls
      await Future.wait([queue.drain(), queue.drain(), queue.drain()]);

      expect(executionCount, equals(1));
      expect(queue.pending, equals(0));

      queue.dispose();
      await Hive.close();
      Hive.init(tempDir.path);
    });
  });
}
