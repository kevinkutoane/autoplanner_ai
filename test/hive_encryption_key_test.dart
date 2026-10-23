import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/bootstrap/app_bootstrapper.dart';
import 'package:autoplanner_ai/services/secure_key_service.dart';

class TestSecureStorageClient implements SecureStorageClient {
  final Map<String, String> values;
  bool failRead;
  bool failWrite;
  String? readOverride;
  String? readBackOverride;
  int readCount = 0;
  int writeCount = 0;

  TestSecureStorageClient({
    Map<String, String>? initialValues,
    this.failRead = false,
    this.failWrite = false,
    this.readOverride,
    this.readBackOverride,
  }) : values = initialValues != null ? Map.from(initialValues) : {};

  @override
  Future<String?> read({required String key}) async {
    readCount++;
    if (failRead) throw Exception('Simulated secure storage read failure');
    if (readCount > 1 && readBackOverride != null) return readBackOverride;
    if (readOverride != null) return readOverride;
    return values[key];
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    writeCount++;
    if (failWrite) throw Exception('Simulated secure storage write failure');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    SecureKeyService.resetStorageForTesting();
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('hive_encryption_test');
  });

  tearDown(() async {
    SecureKeyService.resetStorageForTesting();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Hive Encryption Key Lifecycle and Data-Loss Protection', () {
    test(
      '1. Fresh install: generates, writes, and verifies a 32-byte key',
      () async {
        final storage = TestSecureStorageClient();
        SecureKeyService.setStorageForTesting(storage);

        final key = await SecureKeyService.getOrCreateHiveEncryptionKey(
          hasExistingData: () => false,
        );

        expect(key, hasLength(32));
        expect(storage.writeCount, equals(1));
        expect(storage.values.containsKey('hive_encryption_key'), isTrue);

        final storedBase64 = storage.values['hive_encryption_key']!;
        final decoded = base64Decode(storedBase64);
        expect(decoded, equals(key));
      },
    );

    test(
      '2. Subsequent run: retrieves existing key without generating or writing',
      () async {
        final existingKey = List<int>.generate(32, (i) => i * 3);
        final storage = TestSecureStorageClient(
          initialValues: {'hive_encryption_key': base64Encode(existingKey)},
        );
        SecureKeyService.setStorageForTesting(storage);

        final key = await SecureKeyService.getOrCreateHiveEncryptionKey(
          hasExistingData: () => true,
        );

        expect(key, equals(existingKey));
        expect(storage.writeCount, equals(0));
      },
    );

    test('3. Transient read failure throws SecureStorageException without overwriting key', () async {
      final existingKey = List<int>.generate(32, (i) => i + 10);
      final storage = TestSecureStorageClient(
        initialValues: {'hive_encryption_key': base64Encode(existingKey)},
        failRead: true,
      );
      SecureKeyService.setStorageForTesting(storage);

      expect(
        () => SecureKeyService.getOrCreateHiveEncryptionKey(),
        throwsA(
          isA<SecureStorageException>().having(
            (e) => e.message,
            'message',
            contains('Failed to read Hive encryption key'),
          ),
        ),
      );

      expect(storage.writeCount, equals(0));
      // Preserved original in storage map
      expect(
        storage.values['hive_encryption_key'],
        equals(base64Encode(existingKey)),
      );
    });

    test('4. DATA-LOSS PREVENTION: Absent key with existing data files refuses key generation', () async {
      final storage = TestSecureStorageClient();
      SecureKeyService.setStorageForTesting(storage);

      expect(
        () => SecureKeyService.getOrCreateHiveEncryptionKey(
          hasExistingData: () async => true,
        ),
        throwsA(
          isA<SecureStorageException>().having(
            (e) => e.message,
            'message',
            contains('Refusing to generate new Hive encryption key'),
          ),
        ),
      );

      // Invariant: NEVER write or generate a new key when existing data files are present
      expect(storage.writeCount, equals(0));
      expect(storage.values.containsKey('hive_encryption_key'), isFalse);
    });

    test(
      '5. Write failure during key generation throws SecureStorageException',
      () async {
        final storage = TestSecureStorageClient(failWrite: true);
        SecureKeyService.setStorageForTesting(storage);

        expect(
          () => SecureKeyService.getOrCreateHiveEncryptionKey(
            hasExistingData: () => false,
          ),
          throwsA(
            isA<SecureStorageException>().having(
              (e) => e.message,
              'message',
              contains('Failed to write new Hive encryption key'),
            ),
          ),
        );
      },
    );

    test(
      '6. Read-back verification mismatch throws SecureStorageException',
      () async {
        final mismatchedKey = base64Encode(List<int>.generate(32, (i) => 99));
        final storage = TestSecureStorageClient(
          readBackOverride: mismatchedKey,
        );
        SecureKeyService.setStorageForTesting(storage);

        expect(
          () => SecureKeyService.getOrCreateHiveEncryptionKey(
            hasExistingData: () => false,
          ),
          throwsA(
            isA<SecureStorageException>().having(
              (e) => e.message,
              'message',
              contains('Verification failed: secure storage did not persist'),
            ),
          ),
        );
      },
    );

    test(
      '7. Malformed key format in secure storage throws SecureStorageException',
      () async {
        final storage = TestSecureStorageClient(
          initialValues: {
            'hive_encryption_key': 'not-a-valid-base64-string!@#\$',
          },
        );
        SecureKeyService.setStorageForTesting(storage);

        expect(
          () => SecureKeyService.getOrCreateHiveEncryptionKey(),
          throwsA(
            isA<SecureStorageException>().having(
              (e) => e.message,
              'message',
              contains('Corrupted Hive encryption key format'),
            ),
          ),
        );
      },
    );

    test('8. Stored key with invalid length (!= 32 bytes) throws SecureStorageException', () async {
      final shortKey = List<int>.generate(16, (i) => i);
      final storage = TestSecureStorageClient(
        initialValues: {'hive_encryption_key': base64Encode(shortKey)},
      );
      SecureKeyService.setStorageForTesting(storage);

      expect(
        () => SecureKeyService.getOrCreateHiveEncryptionKey(),
        throwsA(
          isA<SecureStorageException>().having(
            (e) => e.message,
            'message',
            contains(
              'Invalid encryption key in secure storage: expected 32 bytes, got 16',
            ),
          ),
        ),
      );
    });

    test('9. AppBootstrapper.hasExistingEncryptedBoxes returns false for empty directory', () async {
      final exists = await AppBootstrapper.hasExistingEncryptedBoxes(
        tempDir.path,
      );
      expect(exists, isFalse);
    });

    test('10. AppBootstrapper.hasExistingEncryptedBoxes returns true when a core box file exists and is non-empty', () async {
      final tasksBoxFile = File('${tempDir.path}/tasksbox.hive');
      await tasksBoxFile.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

      final exists = await AppBootstrapper.hasExistingEncryptedBoxes(
        tempDir.path,
      );
      expect(exists, isTrue);
    });

    test('11. AppBootstrapper.hasExistingEncryptedBoxes returns false if box file is 0 bytes', () async {
      final emptyFile = File('${tempDir.path}/tasksbox.hive');
      await emptyFile.writeAsBytes([]);

      final exists = await AppBootstrapper.hasExistingEncryptedBoxes(
        tempDir.path,
      );
      expect(exists, isFalse);
    });
  });
}
