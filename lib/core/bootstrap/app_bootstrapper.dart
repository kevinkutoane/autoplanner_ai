import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../config/env_config.dart';
import '../diagnostics/crash_reporter.dart';
import '../diagnostics/provider_observer.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import '../models/note_model.dart';
import '../models/project_model.dart';
import '../models/calendar_event_model.dart';
import '../models/memory_entry_model.dart';
import '../models/gamification_model.dart';
import '../theme/ui_kit.dart';
import '../ai/token_tracker.dart';
import '../providers/providers.dart';
import '../../services/memory_service.dart';
import '../../services/secure_key_service.dart';
import '../../services/notification_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/app_monitor_service.dart';

/// Coordinates unified application initialization and returns the root
/// [ProviderContainer] for the Riverpod dependency hierarchy.
class AppBootstrapper {
  static CrashReporter _crashReporter = const NoOpCrashReporter();

  /// Exposes the configured crash reporter (Sentry or NoOp) for runApp wrapper.
  static CrashReporter get crashReporter => _crashReporter;

  /// Runs the full startup sequence in deterministic order:
  /// 1. Load `.env` and initialize [appConfig].
  /// 2. Initialize Workmanager if [callbackDispatcher] is provided.
  /// 3. Initialize Hive, register type adapters, and derive encryption key.
  /// 4. Pre-open encrypted boxes with corruption fallback recovery.
  /// 5. Initialize services ([TokenTracker], [MemoryService], [NotificationService], etc.).
  /// 6. Restore Google Auth session and schedule morning briefing.
  /// 7. Create root [ProviderContainer] with observers and service overrides.
  /// 8. Initialize offline AI queue.
  static Future<ProviderContainer> init({Function? callbackDispatcher}) async {
    // 1. Environment (.env)
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      try {
        await dotenv.load(fileName: '.env.example');
      } catch (e) {
        if (kDebugMode) debugPrint('.env load failed: $e');
      }
    }

    try {
      appConfig = EnvConfig.fromDotEnv();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EnvConfig.fromDotEnv() failed, using defaults: $e');
      }
      appConfig = const EnvConfig();
    }

    // 2. Workmanager (background tasks — Android/iOS only)
    if (callbackDispatcher != null) {
      try {
        await Workmanager().initialize(callbackDispatcher);
        await Workmanager().registerPeriodicTask(
          'calendarSyncTask',
          'calendarSync',
          frequency: const Duration(hours: 1),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
          constraints: Constraints(networkType: NetworkType.connected),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Workmanager init skipped: $e');
      }
    }

    // 3. Hive initialization & adapters
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskItemAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(NoteItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CalendarEventAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(MemoryEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(GoalItemAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(ProjectItemAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(AILogEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(AppEventAdapter());
    }

    // Derive device-unique encryption key stored in OS keychain
    final hiveKeyBytes = await SecureKeyService.getOrCreateHiveEncryptionKey(
      hasExistingData: hasExistingEncryptedBoxes,
    );
    final hiveCipher = HiveAesCipher(
      hiveKeyBytes,
    ); // 4. Pre-open encrypted data boxes in parallel with safe recovery
    await Future.wait([
      openBoxSafe<TaskItem>('tasksBox', hiveCipher),
      openBoxSafe<NoteItem>('notesBox', hiveCipher),
      openBoxSafe<GoalItem>('goalsBox', hiveCipher),
      openBoxSafe<ProjectItem>('projectsBox', hiveCipher),
      openBoxSafe<CalendarEvent>('calendarBox', hiveCipher),
      openBoxSafe<dynamic>('settingsBox', hiveCipher),
      openBoxSafe<AppEvent>('appEventsBox', hiveCipher),
      openBoxSafe<dynamic>('gamificationBox', hiveCipher),
    ]);

    // 5. Initialize services in parallel
    final tokenTracker = TokenTracker();
    final memoryService = MemoryService();
    final notificationService = NotificationService();
    final googleAuthService = GoogleAuthService();

    await Future.wait([
      tokenTracker.init(cipher: hiveCipher).catchError((e) {
        if (kDebugMode) debugPrint('TokenTracker init failed: $e');
      }),
      memoryService
          .init(cipher: hiveCipher)
          .then((_) {
            // Run stale memory decay in background without blocking startup
            unawaited(
              memoryService.decayStaleMemories().catchError((e) {
                if (kDebugMode) debugPrint('MemoryService decay failed: $e');
                return 0;
              }),
            );
          })
          .catchError((e) {
            if (kDebugMode) debugPrint('MemoryService init failed: $e');
          }),
      notificationService.init().catchError((e) {
        if (kDebugMode) debugPrint('Notification init skipped: $e');
      }),
      googleAuthService.tryRestoreSession().catchError((e) {
        if (kDebugMode) debugPrint('GoogleAuth restore skipped: $e');
      }),
    ]);

    // 6. Restore scheduled notifications & sensory preferences
    try {
      final settingsBox = Hive.box<dynamic>('settingsBox');
      AppHaptics.enabled =
          settingsBox.get('hapticsEnabled', defaultValue: true) as bool;

      final briefingEnabled = settingsBox.get(
        'morningBriefingEnabled',
        defaultValue: false,
      ) as bool;
      final briefingHour =
          settingsBox.get('morningBriefingHour', defaultValue: 8) as int;
      final briefingMinute =
          settingsBox.get('morningBriefingMinute', defaultValue: 0) as int;
      if (briefingEnabled) {
        unawaited(
          notificationService.scheduleMorningBriefing(
            hour: briefingHour,
            minute: briefingMinute,
            body: 'Good morning! Tap to review your plan for the day.',
          ),
        );
      }

      final shutdownEnabled = settingsBox.get(
        'eveningShutdownReminderEnabled',
        defaultValue: false,
      ) as bool;
      final shutdownHour =
          settingsBox.get('eveningShutdownHour', defaultValue: 21) as int;
      final shutdownMinute =
          settingsBox.get('eveningShutdownMinute', defaultValue: 0) as int;
      if (shutdownEnabled) {
        unawaited(
          notificationService.scheduleEveningShutdown(
            hour: shutdownHour,
            minute: shutdownMinute,
          ),
        );
      }

      final streakRemindersEnabled =
          settingsBox.get('streakRemindersEnabled', defaultValue: true) as bool;
      if (streakRemindersEnabled) {
        try {
          final gamificationBox = Hive.box<dynamic>('gamificationBox');
          final rawProfile = gamificationBox.get('user_gamification_profile');
          if (rawProfile != null) {
            final profile = rawProfile is String
                ? GamificationProfile.fromJson(rawProfile)
                : GamificationProfile.fromMap(
                    Map<String, dynamic>.from(rawProfile as Map),
                  );
            if (profile.currentStreak > 0) {
              unawaited(
                notificationService.scheduleStreakShield(
                  currentStreak: profile.currentStreak,
                ),
              );
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Notification & settings restore failed: $e');
    }

    final calendarSyncService = CalendarSyncService(
      googleAuth: googleAuthService,
    );

    // 7. Crash reporting & monitoring
    _crashReporter = appConfig.sentryDsn.isNotEmpty
        ? SentryCrashReporter(dsn: appConfig.sentryDsn)
        : const NoOpCrashReporter();
    final appMonitorService = AppMonitorService(reporter: _crashReporter);

    // 8. Root ProviderContainer
    final container = ProviderContainer(
      observers: [AppProviderObserver(appMonitorService)],
      overrides: [
        tokenTrackerProvider.overrideWithValue(tokenTracker),
        memoryServiceProvider.overrideWithValue(memoryService),
        notificationServiceProvider.overrideWithValue(notificationService),
        googleAuthServiceProvider.overrideWithValue(googleAuthService),
        calendarSyncServiceProvider.overrideWithValue(calendarSyncService),
        appMonitorServiceProvider.overrideWithValue(appMonitorService),
      ],
    );

    // 9. Offline AI Queue (encrypted with device-unique keychain key)
    try {
      final offlineAIQueue = container.read(offlineAIQueueProvider);
      await offlineAIQueue.init(cipher: hiveCipher);
    } catch (e) {
      if (kDebugMode) debugPrint('OfflineAIQueue init failed: $e');
    }

    return container;
  }

  /// Opens a Hive box; if the file is established as genuinely corrupt,
  /// creates a verified timestamped backup copy and safely reinitializes the box.
  ///
  /// Critical Invariant: If data is not established as corrupt, or if backup
  /// verification fails, original data is NEVER deleted.
  static Future<Box<T>> openBoxSafe<T>(
    String name,
    HiveAesCipher cipher, {
    String? customDir,
  }) async {
    try {
      return await Hive.openBox<T>(
        name,
        encryptionCipher: cipher,
        path: customDir,
        crashRecovery: false,
      );
    } catch (e) {
      final eStr = e.toString().toLowerCase();

      // 1. Filesystem / Storage problems — do NOT delete data
      if (e is FileSystemException ||
          eStr.contains('filesystemexception') ||
          eStr.contains('permission denied') ||
          eStr.contains('no space left') ||
          eStr.contains('read-only file system')) {
        if (kDebugMode) debugPrint('Filesystem error opening box "$name": $e');
        rethrow;
      }

      // 2. Programming / Configuration errors — do NOT delete data
      if (e is TypeError ||
          e is ArgumentError ||
          e is RangeError ||
          eStr.contains('is already open') ||
          eStr.contains('registered') ||
          eStr.contains('typeadapter') ||
          eStr.contains('type id') ||
          eStr.contains('box not found')) {
        if (kDebugMode) {
          debugPrint('Programming/Configuration error opening box "$name": $e');
        }
        rethrow;
      }

      final dirPath = customDir ?? await _resolveBoxDir();
      final boxLower = name.toLowerCase();
      var hiveFile = dirPath != null ? File('$dirPath/$boxLower.hive') : null;
      if (hiveFile != null && !await hiveFile.exists()) {
        hiveFile = File('$dirPath/$name.hive');
      }

      final fileExists = hiveFile != null && await hiveFile.exists();
      final fileLength = fileExists ? await hiveFile.length() : 0;

      // If file is smaller than Hive header size (32 bytes), it is definitively corrupted/truncated.
      final isTruncatedOrHeaderCorrupt =
          fileExists && fileLength > 0 && fileLength < 32;

      // 3. Encryption / Key Mismatch — do NOT delete encrypted user data
      // If the file is full-sized (>= 32 bytes) and throws 'wrong checksum' or cipher error,
      // it cannot be distinguished from a wrong encryption key.
      // Invariant: Do NOT delete it.
      if (!isTruncatedOrHeaderCorrupt &&
          (eStr.contains('wrong encryption key') ||
              eStr.contains('wrong key') ||
              eStr.contains('cipher') ||
              eStr.contains('mac mismatch') ||
              eStr.contains('unsupported cipher') ||
              eStr.contains('wrong checksum'))) {
        if (kDebugMode) {
          debugPrint(
            'Encryption key / checksum mismatch for box "$name": $e. Preserving box.',
          );
        }
        throw HiveKeyMismatchException(name, e);
      }

      // 4. Verify genuine corruption signatures before attempting recovery
      final isCorruption =
          isTruncatedOrHeaderCorrupt ||
          eStr.contains('unexpected eof') ||
          eStr.contains('invalid frame') ||
          eStr.contains('bad format') ||
          (eStr.contains('corrupt') && !eStr.contains('wrong checksum')) ||
          (e is HiveError &&
              (eStr.contains('format') || eStr.contains('header')));

      if (!isCorruption) {
        if (kDebugMode) {
          debugPrint(
            'Unexpected error opening box "$name" not established as corruption: $e',
          );
        }
        rethrow;
      }

      // Box is established as genuinely corrupt. Safe recovery procedure:
      if (kDebugMode) {
        debugPrint(
          'Hive box "$name" established as corrupt: $e. Initiating safe backup and recovery.',
        );
      }

      if (dirPath == null) {
        throw HiveRecoveryException(
          'Cannot locate database directory to safely backup corrupt box "$name". Aborting.',
          name,
        );
      }

      final targetFile = hiveFile ?? File('$dirPath/$boxLower.hive');
      if (await targetFile.exists()) {
        final originalLength = await targetFile.length();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final backupPath = '$dirPath/$name.corrupt.$timestamp.bak';
        final backupFile = File(backupPath);

        try {
          await targetFile.copy(backupPath);
        } catch (copyError) {
          if (kDebugMode) {
            debugPrint(
              'Failed to copy corrupt box "$name" to backup: $copyError',
            );
          }
          throw HiveRecoveryException(
            'Failed to create diagnostic backup copy ($copyError). Preserving original corrupt file.',
            name,
          );
        }

        // Verify backup exists and matches original size
        if (!await backupFile.exists() ||
            await backupFile.length() != originalLength) {
          throw HiveRecoveryException(
            'Backup verification failed: backup file does not exist or size mismatch. Preserving original file.',
            name,
          );
        }

        if (kDebugMode) {
          debugPrint(
            'Diagnostic backup successfully verified at $backupPath ($originalLength bytes).',
          );
        }
      }

      // Safe to quarantine and reset now that verified backup exists
      _crashReporter.captureException(
        HiveRecoveryException(
          'Hive box "$name" corrupted and quarantined with diagnostic backup',
          name,
        ),
        StackTrace.current,
      );

      try {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
      } catch (_) {}

      try {
        await Hive.deleteBoxFromDisk(name, path: customDir);
      } catch (_) {}

      try {
        return await Hive.openBox<T>(
          name,
          encryptionCipher: cipher,
          path: customDir,
          crashRecovery: false,
        );
      } catch (reopenError) {
        throw HiveRecoveryException(
          'Corrupt box "$name" quarantined to diagnostic backup, but could not be recreated: $reopenError',
          name,
        );
      }
    }
  }

  static Future<String?> _resolveBoxDir() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  /// Test seam: overrides how the Hive data directory is resolved.
  @visibleForTesting
  static Future<String?> Function()? boxDirResolverForTesting;

  /// Reports whether any non-empty Hive database file exists in the Hive
  /// data directory (the same directory used by [openBoxSafe]).
  ///
  /// Every `*.hive` file is considered, so boxes added in the future
  /// (e.g. memoryBox, aiLogsBox, aiQueueBox) are never silently omitted.
  ///
  /// Fail-safe contract: returns `true`/`false` only when the directory was
  /// positively inspected. If the directory cannot be resolved, does not
  /// exist, or any entry cannot be inspected, a [SecureStorageException] is
  /// thrown so callers never assume a fresh installation.
  static Future<bool> hasExistingEncryptedBoxes([String? customDir]) async {
    String? dirPath = customDir;
    if (dirPath == null) {
      final resolver = boxDirResolverForTesting ?? _resolveBoxDir;
      try {
        dirPath = await resolver();
      } catch (_) {
        dirPath = null;
      }
    }
    if (dirPath == null || dirPath.isEmpty) {
      throw const SecureStorageException(
        'Cannot determine whether existing app data is present: the data '
        'directory could not be resolved. Refusing to assume a fresh install.',
      );
    }

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        throw const SecureStorageException(
          'Cannot determine whether existing app data is present: the data '
          'directory does not exist or is inaccessible.',
        );
      }
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.hive')) continue;
        if (await entity.length() > 0) return true;
      }
      return false;
    } on SecureStorageException {
      rethrow;
    } catch (e) {
      throw SecureStorageException(
        'Cannot determine whether existing app data is present: the data '
        'directory could not be inspected. Refusing to assume a fresh install.',
        cause: e,
      );
    }
  }
}

/// Thrown when an encrypted Hive box cannot be decrypted due to key mismatch.
/// Invariant: Original encrypted data MUST NOT be deleted.
class HiveKeyMismatchException implements Exception {
  final String boxName;
  final Object originalError;
  const HiveKeyMismatchException(this.boxName, this.originalError);

  @override
  String toString() =>
      'HiveKeyMismatchException: Key/cipher mismatch for box "$boxName": $originalError';
}

/// Thrown when diagnostic backup verification fails during corruption recovery.
/// Invariant: Original box MUST NOT be deleted if backup cannot be verified.
class HiveRecoveryException implements Exception {
  final String message;
  final String boxName;
  const HiveRecoveryException(this.message, this.boxName);

  @override
  String toString() => 'HiveRecoveryException for box "$boxName": $message';
}
