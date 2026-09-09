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
      if (kDebugMode)
        debugPrint('EnvConfig.fromDotEnv() failed, using defaults: $e');
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
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskItemAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NoteItemAdapter());
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(CalendarEventAdapter());
    if (!Hive.isAdapterRegistered(3))
      Hive.registerAdapter(MemoryEntryAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(GoalItemAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(ProjectItemAdapter());
    if (!Hive.isAdapterRegistered(10))
      Hive.registerAdapter(AILogEntryAdapter());
    if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(AppEventAdapter());

    // Derive device-unique encryption key stored in OS keychain
    final hiveKeyBytes = await SecureKeyService.getOrCreateHiveEncryptionKey();
    final hiveCipher = HiveAesCipher(hiveKeyBytes);

    // 4. Pre-open encrypted data boxes with safe recovery
    await openBoxSafe<TaskItem>('tasksBox', hiveCipher);
    await openBoxSafe<NoteItem>('notesBox', hiveCipher);
    await openBoxSafe<GoalItem>('goalsBox', hiveCipher);
    await openBoxSafe<ProjectItem>('projectsBox', hiveCipher);
    await openBoxSafe<CalendarEvent>('calendarBox', hiveCipher);
    await openBoxSafe<dynamic>('settingsBox', hiveCipher);
    await openBoxSafe<AppEvent>('appEventsBox', hiveCipher);

    // 5. Initialize services that require Hive
    final tokenTracker = TokenTracker();
    try {
      await tokenTracker.init(cipher: hiveCipher);
    } catch (e) {
      if (kDebugMode) debugPrint('TokenTracker init failed: $e');
    }

    final memoryService = MemoryService();
    try {
      await memoryService.init(cipher: hiveCipher);
      await memoryService.decayStaleMemories();
    } catch (e) {
      if (kDebugMode) debugPrint('MemoryService init failed: $e');
    }

    final notificationService = NotificationService();
    try {
      await notificationService.init();
    } catch (e) {
      if (kDebugMode) debugPrint('Notification init skipped: $e');
    }

    // 6. Restore morning briefing & Google Calendar auth
    try {
      final settingsBox = Hive.box<dynamic>('settingsBox');
      final briefingEnabled =
          settingsBox.get('morningBriefingEnabled', defaultValue: false)
              as bool;
      final briefingHour =
          settingsBox.get('morningBriefingHour', defaultValue: 8) as int;
      final briefingMinute =
          settingsBox.get('morningBriefingMinute', defaultValue: 0) as int;
      if (briefingEnabled) {
        await notificationService.scheduleMorningBriefing(
          hour: briefingHour,
          minute: briefingMinute,
          body: 'Good morning! Tap to review your plan for the day.',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Morning briefing restore failed: $e');
    }

    final googleAuthService = GoogleAuthService();
    await googleAuthService.tryRestoreSession();
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

    // 9. Offline AI Queue
    try {
      final offlineAIQueue = container.read(offlineAIQueueProvider);
      await offlineAIQueue.init();
    } catch (e) {
      if (kDebugMode) debugPrint('OfflineAIQueue init failed: $e');
    }

    return container;
  }

  /// Opens a Hive box; if the file is corrupt or has an unreadable encryption header,
  /// creates a timestamped backup copy and safely reinitializes the box.
  static Future<Box<T>> openBoxSafe<T>(
    String name,
    HiveAesCipher cipher,
  ) async {
    try {
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    } catch (e) {
      final eStr = e.toString();

      // 1. Filesystem / Storage problems
      if (e is FileSystemException || eStr.contains('FileSystemException')) {
        if (kDebugMode) debugPrint('Filesystem error opening box "$name": $e');
        rethrow;
      }

      // 2. Programming / Configuration errors
      if (eStr.contains('is already open') ||
          eStr.contains('registered') ||
          eStr.contains('TypeAdapter')) {
        if (kDebugMode) debugPrint('Programming error opening box "$name": $e');
        rethrow;
      }

      // 3. Corruption or Encryption Mismatch
      if (kDebugMode) {
        debugPrint(
          'Hive box "$name" failed to open (possibly corrupt/wrong key). Backing up: $e',
        );
      }

      try {
        final directory = await getApplicationDocumentsDirectory();
        final hiveFile = File('${directory.path}/$name.hive');

        if (await hiveFile.exists()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final backupPath = '${directory.path}/$name.corrupt.$timestamp.bak';
          await hiveFile.copy(backupPath);
          if (kDebugMode)
            debugPrint('Backed up corrupt box $name to $backupPath');
        }
      } catch (backupError) {
        if (kDebugMode)
          debugPrint('Failed to backup corrupt box $name: $backupError');
        rethrow;
      }

      // Original file safely backed up (if it existed), now reset the box on disk
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<T>(name, encryptionCipher: cipher);
    }
  }
}
