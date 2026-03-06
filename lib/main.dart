import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/providers/providers.dart';

import 'core/config/env_config.dart';
import 'core/models/task_model.dart';
import 'core/models/note_model.dart';
import 'core/models/calendar_event_model.dart';
import 'core/models/memory_entry_model.dart';
import 'core/ai/token_tracker.dart';
import 'core/theme/app_theme.dart';
import 'services/memory_service.dart';
import 'features/onboarding/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Environment (.env) ───────────────────────────────────
  await dotenv.load(fileName: '.env');
  appConfig = EnvConfig.fromDotEnv();

  // ── Hive ─────────────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(TaskItemAdapter());
  Hive.registerAdapter(NoteItemAdapter());
  Hive.registerAdapter(CalendarEventAdapter());
  Hive.registerAdapter(MemoryEntryAdapter());
  Hive.registerAdapter(AILogEntryAdapter());

  // ── Services (must be initialized after Hive is ready) ───
  final tokenTracker = TokenTracker();
  await tokenTracker.init();

  final memoryService = MemoryService();
  await memoryService.init();

  // Pre-open data boxes so they're available synchronously via Hive.box()
  await Hive.openBox<TaskItem>('tasksBox');
  await Hive.openBox<NoteItem>('notesBox');
  await Hive.openBox<CalendarEvent>('calendarBox');

  runApp(
    ProviderScope(
      overrides: [
        tokenTrackerProvider.overrideWithValue(tokenTracker),
        memoryServiceProvider.overrideWithValue(memoryService),
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
