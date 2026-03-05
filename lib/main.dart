import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/env_config.dart';
import 'core/models/task_model.dart';
import 'core/models/note_model.dart';
import 'core/models/calendar_event_model.dart';
import 'core/models/memory_entry_model.dart';
import 'core/ai/token_tracker.dart';
import 'core/theme/app_theme.dart';
import 'app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Environment ──────────────────────────────────────────
  appConfig = EnvConfig.fromEnvironment();

  // ── Hive ─────────────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(TaskItemAdapter());
  Hive.registerAdapter(NoteItemAdapter());
  Hive.registerAdapter(CalendarEventAdapter());
  Hive.registerAdapter(MemoryEntryAdapter());
  Hive.registerAdapter(AILogEntryAdapter());

  runApp(const ProviderScope(child: AutoPlannerApp()));
}

class AutoPlannerApp extends StatelessWidget {
  const AutoPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoPlanner AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
