import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'core/providers/providers.dart';

import 'core/config/env_config.dart';
import 'core/models/task_model.dart';
import 'core/models/note_model.dart';
import 'core/models/calendar_event_model.dart';
import 'core/models/memory_entry_model.dart';
import 'core/ai/token_tracker.dart';
import 'core/theme/app_theme.dart';
import 'services/memory_service.dart';
import 'services/secure_key_service.dart';
import 'services/notification_service.dart';
import 'services/google_auth_service.dart';
import 'services/calendar_sync_service.dart';
import 'features/onboarding/screens/splash_screen.dart';

// ── Workmanager background entry-point ───────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Background tasks run in an isolate — heavy work (API calls, Hive I/O)
    // should be re-initialised here when needed.
    switch (task) {
      case 'calendarSync':
        // Incremental calendar sync handled by CalendarSyncService.
        // Full initialisation omitted for brevity; extend as needed.
        break;
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Environment (.env) ───────────────────────────────────
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) debugPrint('.env load failed: $e');
  }
  appConfig = EnvConfig.fromDotEnv();

  // ── Firebase (optional — requires google-services.json / GoogleService-Info.plist) ──
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) debugPrint('Firebase init skipped: $e');
  }

  // ── Workmanager (background tasks — Android/iOS only) ────
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
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
  if (!Hive.isAdapterRegistered(2))
  if(!Hive.registerAdapter(CalendarEventAdapter()));
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(MemoryEntryAdapter());
  if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(AILogEntryAdapter());

  // Derive a device-unique encryption key stored in the OS keychain.
  final hiveKeyBytes = await SecureKeyService.getOrCreateHiveEncryptionKey();
  final hiveCipher = HiveAesCipher(hiveKeyBytes);

  // ── Services (must be initialized after Hive is ready) ───
  final tokenTracker = TokenTracker();
  await tokenTracker.init(cipher: hiveCipher);

  final memoryService = MemoryService();
  try {
    await memoryService.init(cipher: hiveCipher);
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

  // ── Google Calendar Auth + Sync ───────────────────────────
  final googleAuthService = GoogleAuthService();
  await googleAuthService.tryRestoreSession();
  final calendarSyncService = CalendarSyncService(
    googleAuth: googleAuthService,
  );

  // Pre-open data boxes with encryption so they're available via Hive.box().
  await Hive.openBox<TaskItem>('tasksBox', encryptionCipher: hiveCipher);
  await Hive.openBox<NoteItem>('notesBox', encryptionCipher: hiveCipher);
  await Hive.openBox<CalendarEvent>(
    'calendarBox',
    encryptionCipher: hiveCipher,
  );
  // settingsBox: pre-open with cipher so SettingsController._init() inherits it.
  await Hive.openBox<dynamic>('settingsBox', encryptionCipher: hiveCipher);

  runApp(
    ProviderScope(
      overrides: [
        tokenTrackerProvider.overrideWithValue(tokenTracker),
        memoryServiceProvider.overrideWithValue(memoryService),
        notificationServiceProvider.overrideWithValue(notificationService),
        googleAuthServiceProvider.overrideWithValue(googleAuthService),
        calendarSyncServiceProvider.overrideWithValue(calendarSyncService),
      ],
      child: const AutoPlannerApp(),
    ),
  );
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
