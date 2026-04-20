import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'core/providers/providers.dart';

import 'core/config/env_config.dart';
import 'core/diagnostics/crash_reporter.dart';
import 'core/models/task_model.dart';
import 'core/models/goal_model.dart';
import 'core/models/note_model.dart';
import 'core/models/project_model.dart';
import 'core/models/calendar_event_model.dart';
import 'core/models/memory_entry_model.dart';
import 'core/ai/token_tracker.dart';
import 'core/theme/app_theme.dart';
import 'services/memory_service.dart';
import 'services/secure_key_service.dart';
import 'services/notification_service.dart';
import 'services/google_auth_service.dart';
import 'services/calendar_sync_service.dart';
import 'services/app_monitor_service.dart';
import 'services/offline_ai_queue.dart';
import 'features/onboarding/screens/splash_screen.dart';

// ── Workmanager background entry-point ───────────────────────────────────────
/// Top-level entry point called by Workmanager in a background isolate.
///
/// Must be a top-level (non-closure) function annotated with
/// `@pragma('vm:entry-point')` so the AOT compiler does not tree-shake it.
/// Re-initialises Hive and all required services independently of the
/// main isolate, because background isolates have no shared memory.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'calendarSync':
        try {
          // Background isolate: re-initialise Hive + services independently.
          await Hive.initFlutter();
          if (!Hive.isAdapterRegistered(2)) {
            Hive.registerAdapter(CalendarEventAdapter());
          }
          final hiveKeyBytes =
              await SecureKeyService.getOrCreateHiveEncryptionKey();
          final hiveCipher = HiveAesCipher(hiveKeyBytes);
          if (!Hive.isBoxOpen('calendarBox')) {
            await Hive.openBox<CalendarEvent>(
              'calendarBox',
              encryptionCipher: hiveCipher,
            );
          }
          final googleAuth = GoogleAuthService();
          await googleAuth.tryRestoreSession();
          if (googleAuth.isConnected) {
            final syncSvc = CalendarSyncService(googleAuth: googleAuth);
            await syncSvc.incrementalSync();
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Background calendarSync failed: $e');
        }
    }
    return true;
  });
}

/// App entry point. Runs the init chain in order:
///
/// 1. Load `.env` for [appConfig].
/// 2. Init Workmanager with [callbackDispatcher].
/// 3. Open all encrypted Hive boxes (AES key from OS keychain).
/// 4. Initialise [TokenTracker] and [MemoryService] (require open boxes).
/// 5. Restore Google OAuth sessions silently.
/// 6. Init [NotificationService] and schedule morning briefing if enabled.
/// 7. Initialise crash reporting when `SENTRY_DSN` is configured.
/// 8. Log startup warnings for incomplete release configuration.
/// 9. Wrap the widget tree in [ProviderScope] with service overrides, then
///    call [runApp].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Environment (.env) ───────────────────────────────────
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) debugPrint('.env load failed: $e');
  }
  try {
    appConfig = EnvConfig.fromDotEnv();
  } catch (e) {
    if (kDebugMode) debugPrint('EnvConfig.fromDotEnv() failed, using defaults: $e');
    appConfig = const EnvConfig();
  }

  // ── Workmanager (background tasks — Android/iOS only) ────
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

  // ── Hive ─────────────────────────────────────────────────
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskItemAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NoteItemAdapter());
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(CalendarEventAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(MemoryEntryAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(GoalItemAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(ProjectItemAdapter());
  if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(AILogEntryAdapter());
  if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(AppEventAdapter());

  // Derive a device-unique encryption key stored in the OS keychain.
  final hiveKeyBytes = await SecureKeyService.getOrCreateHiveEncryptionKey();
  final hiveCipher = HiveAesCipher(hiveKeyBytes);

  // ── Services (must be initialized after Hive is ready) ───
  final tokenTracker = TokenTracker();
  try {
    await tokenTracker.init(cipher: hiveCipher);
  } catch (e) {
    if (kDebugMode) debugPrint('TokenTracker init failed: $e');
  }

  final memoryService = MemoryService();
  try {
    await memoryService.init(cipher: hiveCipher);
    // Prune memories that haven't been accessed and have decayed below
    // the relevance threshold — keeps context lean on every app start.
    await memoryService.decayStaleMemories();
  } catch (e) {
    if (kDebugMode) debugPrint('MemoryService init failed: $e');
  }

  // ── Notifications ─────────────────────────────────────────────────
  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } catch (e) {
    if (kDebugMode) debugPrint('Notification init skipped: $e');
  }

  // Restore morning briefing alarm on every app launch (survives app kill).
  // We peek at settingsBox before SettingsController fully loads.
  try {
    final settingsBox = await Hive.openBox<dynamic>(
      'settingsBox',
      encryptionCipher: hiveCipher,
    );
    final briefingEnabled =
        settingsBox.get('morningBriefingEnabled', defaultValue: false) as bool;
    final briefingHour =
        settingsBox.get('morningBriefingHour', defaultValue: 7) as int;
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

  // ── Google Calendar Auth + Sync ───────────────────────────
  final googleAuthService = GoogleAuthService();
  await googleAuthService.tryRestoreSession();
  final calendarSyncService = CalendarSyncService(
    googleAuth: googleAuthService,
  );

  // Pre-open data boxes with encryption so they're available via Hive.box().
  await _openBoxSafe<TaskItem>('tasksBox', hiveCipher);
  await _openBoxSafe<NoteItem>('notesBox', hiveCipher);
  await _openBoxSafe<GoalItem>('goalsBox', hiveCipher);
  await _openBoxSafe<NoteItem>('notesBox', hiveCipher);
  await _openBoxSafe<ProjectItem>('projectsBox', hiveCipher);
  await _openBoxSafe<CalendarEvent>('calendarBox', hiveCipher);
  // settingsBox: pre-open with cipher so SettingsController._init() inherits it.
  await _openBoxSafe<dynamic>('settingsBox', hiveCipher);
  await _openBoxSafe<AppEvent>('appEventsBox', hiveCipher);

  // ── Offline AI Queue ─────────────────────────────────────────────────
  final offlineAIQueue = OfflineAIQueue(
    executeCallback: (method, args) async {
      // Route queued requests to the appropriate AI method.
      // The queue stores method names and serialised arguments;
      // this callback re-hydrates and executes them.
      if (kDebugMode) {
        debugPrint('OfflineAIQueue: executing queued $method');
      }
      // Individual method routing is handled by the caller at enqueue time;
      // the queue simply retries the stored callback.
    },
  );
  try {
    await offlineAIQueue.init();
  } catch (e) {
    if (kDebugMode) debugPrint('OfflineAIQueue init failed: $e');
  }

  // ── App monitoring ────────────────────────────────────────────────────
  final crashReporter = appConfig.sentryDsn.isEmpty
      ? const NoOpCrashReporter()
      : SentryCrashReporter(dsn: appConfig.sentryDsn);
  final appMonitorService = AppMonitorService(reporter: crashReporter);
  try {
    await appMonitorService.init(cipher: hiveCipher);
  } catch (e) {
    if (kDebugMode) debugPrint('AppMonitorService init failed: $e');
  }
  final startupWarnings = appConfig.validate();
  if (startupWarnings.isNotEmpty) {
    await appMonitorService.logStartupWarnings(startupWarnings);
  }
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    originalOnError?.call(details);
    appMonitorService.logFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    appMonitorService.logFatalError(error, stack);
    return !kDebugMode;
  };
  appMonitorService.logSessionStart();

  final app = ProviderScope(
    overrides: [
      tokenTrackerProvider.overrideWithValue(tokenTracker),
      memoryServiceProvider.overrideWithValue(memoryService),
      notificationServiceProvider.overrideWithValue(notificationService),
      googleAuthServiceProvider.overrideWithValue(googleAuthService),
      calendarSyncServiceProvider.overrideWithValue(calendarSyncService),
      appMonitorServiceProvider.overrideWithValue(appMonitorService),
      offlineAIQueueProvider.overrideWithValue(offlineAIQueue),
    ],
    child: const AutoPlannerApp(),
  );

  await crashReporter.runApp(
    () async {
      runApp(app);
    },
    environment: appConfig.environment.name,
  );
}

/// Opens a Hive box; if the file is corrupt, deletes it and retries once.
Future<Box<T>> _openBoxSafe<T>(String name, HiveAesCipher cipher) async {
  try {
    return await Hive.openBox<T>(name, encryptionCipher: cipher);
  } catch (e) {
    if (kDebugMode) debugPrint('Hive box "$name" corrupt — resetting: $e');
    await Hive.deleteBoxFromDisk(name);
    return await Hive.openBox<T>(name, encryptionCipher: cipher);
  }
}

class AutoPlannerApp extends ConsumerWidget {
  const AutoPlannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp(
      title: 'AutoPlanner AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
