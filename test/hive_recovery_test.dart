import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:autoplanner_ai/core/bootstrap/app_bootstrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late HiveAesCipher validCipher;
  late HiveAesCipher wrongCipher;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('hive_recovery_test_');
    Hive.init(tempDir.path);

    final key1 = Uint8List.fromList(List.generate(32, (i) => i));
    final key2 = Uint8List.fromList(List.generate(32, (i) => 255 - i));
    validCipher = HiveAesCipher(key1);
    wrongCipher = HiveAesCipher(key2);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test('openBoxSafe opens a healthy encrypted box normally', () async {
    final box = await AppBootstrapper.openBoxSafe<String>(
      'healthyBox',
      validCipher,
      customDir: tempDir.path,
    );
    await box.put('key1', 'value1');
    expect(box.get('key1'), equals('value1'));
    await box.close();
  });

  test('encryption key mismatch throws HiveKeyMismatchException and preserves file without deletion', () async {
    // 1. Create and write to box with validCipher
    var box = await AppBootstrapper.openBoxSafe<String>(
      'encryptedBox',
      validCipher,
      customDir: tempDir.path,
    );
    await box.put('secret', 'top_secret_data');
    await box.close();

    final hiveFile = File('${tempDir.path}/encryptedbox.hive');
    expect(hiveFile.existsSync(), isTrue);
    final originalLength = hiveFile.lengthSync();
    expect(originalLength, greaterThan(0));

    // 2. Attempt to open with wrongCipher
    bool didThrowKeyMismatch = false;
    final completer = Completer<void>();
    runZonedGuarded(
      () async {
        try {
          await AppBootstrapper.openBoxSafe<String>(
            'encryptedBox',
            wrongCipher,
            customDir: tempDir.path,
          );
        } on HiveKeyMismatchException {
          didThrowKeyMismatch = true;
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (error, stack) {
        if (error is HiveKeyMismatchException ||
            error.toString().contains('HiveKeyMismatchException')) {
          didThrowKeyMismatch = true;
        }
      },
    );
    await completer.future;
    expect(didThrowKeyMismatch, isTrue);

    // 3. Invariant: Original file MUST NOT be deleted or truncated!
    expect(hiveFile.existsSync(), isTrue);
    expect(hiveFile.lengthSync(), equals(originalLength));

    // 4. No .bak files created (because key mismatch is not corruption)
    final bakFiles = tempDir.listSync().where((f) => f.path.contains('.bak'));
    expect(bakFiles, isEmpty);
  });

  test(
    'corrupted box creates verified diagnostic backup and recovers safely',
    () async {
      // 1. Create a valid box, put data, and close it
      var box = await AppBootstrapper.openBoxSafe<String>(
        'corruptBox',
        validCipher,
        customDir: tempDir.path,
      );
      await box.put('key1', 'value1');
      await box.close();

      final hiveFile = File('${tempDir.path}/corruptbox.hive');
      expect(hiveFile.existsSync(), isTrue);

      // 2. Corrupt the file by truncating/corrupting byte contents
      final bytes = await hiveFile.readAsBytes();
      // Keep first 10 bytes to trigger unexpected EOF / frame corruption
      final corruptedBytes = Uint8List.fromList(bytes.sublist(0, 10));
      await hiveFile.writeAsBytes(corruptedBytes);
      final originalSize = hiveFile.lengthSync();

      // 3. Open box using openBoxSafe — triggers diagnostic quarantine backup
      final completer3 = Completer<void>();
      runZonedGuarded(
        () async {
          try {
            final recoveredBox = await AppBootstrapper.openBoxSafe<String>(
              'corruptBox',
              validCipher,
              customDir: tempDir.path,
            );
            expect(recoveredBox.isOpen, isTrue);
            await recoveredBox.close();
          } on HiveRecoveryException catch (e) {
            expect(e.boxName, equals('corruptBox'));
          } finally {
            if (!completer3.isCompleted) completer3.complete();
          }
        },
        (error, stack) {
          if (!completer3.isCompleted) completer3.complete();
        },
      );
      await completer3.future;
      await Future.delayed(const Duration(milliseconds: 100));

      // 4. Diagnostic backup file was verified and created with identical corrupted size
      final bakFiles = tempDir
          .listSync()
          .where((f) => f.path.toLowerCase().contains('.bak'))
          .toList();

      expect(bakFiles, hasLength(1));
      final backupFile = File(bakFiles.first.path);
      expect(backupFile.existsSync(), isTrue);
      expect(backupFile.lengthSync(), equals(originalSize));
    },
  );

  test(
    'programming error (type mismatch on open) rethrows without deleting data',
    () async {
      final box = await AppBootstrapper.openBoxSafe<String>(
        'typeMismatchBox',
        validCipher,
        customDir: tempDir.path,
      );
      await box.put('k', 'v');

      final hiveFile = File('${tempDir.path}/typemismatchbox.hive');
      expect(hiveFile.existsSync(), isTrue);
      final originalLength = hiveFile.lengthSync();

      // Opening an already opened box with a conflicting type (int vs String) throws
      bool didThrowProgError = false;
      try {
        await AppBootstrapper.openBoxSafe<int>(
          'typeMismatchBox',
          validCipher,
          customDir: tempDir.path,
        );
      } catch (_) {
        didThrowProgError = true;
      }
      expect(didThrowProgError, isTrue);

      // The file is preserved and intact
      expect(hiveFile.existsSync(), isTrue);
      expect(hiveFile.lengthSync(), equals(originalLength));
      await box.close();
    },
  );
}
