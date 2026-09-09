import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'core/bootstrap/app_bootstrapper.dart';
import 'core/config/env_config.dart';
import 'core/models/calendar_event_model.dart';
import 'core/providers/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/error_boundary.dart';
import 'features/onboarding/screens/splash_screen.dart';
import 'services/calendar_sync_service.dart';
import 'services/google_auth_service.dart';
import 'services/secure_key_service.dart';

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
            await AppBootstrapper.openBoxSafe<CalendarEvent>(
              'calendarBox',
              hiveCipher,
            );
          }
          if (!Hive.isBoxOpen('settingsBox')) {
            await AppBootstrapper.openBoxSafe<dynamic>(
              'settingsBox',
              hiveCipher,
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

/// App entry point. Delegated to [AppBootstrapper.init].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = await AppBootstrapper.init(
    callbackDispatcher: callbackDispatcher,
  );

  final app = UncontrolledProviderScope(
    container: container,
    child: const ErrorBoundary(child: AutoPlannerApp()),
  );

  await AppBootstrapper.crashReporter.runApp(() async {
    runApp(app);
  }, environment: appConfig.environment.name);
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
