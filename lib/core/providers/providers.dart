// Centralized Riverpod providers for the entire app.
// Single source of truth for all shared services and controllers.
// Every feature imports from here — no more duplicate providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/ai_provider.dart';
import '../ai/gemini_provider.dart';
import '../ai/mock_ai_provider.dart';
import '../ai/token_tracker.dart';
import '../config/env_config.dart';
import '../data/hive_repository.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';
import '../models/calendar_event_model.dart';
import '../models/memory_entry_model.dart';
import '../../services/ai_service.dart';
import '../../services/memory_service.dart';
import '../../features/settings/models/app_settings_model.dart';
import '../../features/settings/controllers/settings_controller.dart';

// ── AI Layer ──────────────────────────────────────────────────────────

final aiProviderProvider = Provider<AIProvider>((ref) {
  if (appConfig.useMockAI) return MockAIProvider();
  return GeminiProvider();
});

final tokenTrackerProvider = Provider<TokenTracker>((ref) {
  return TokenTracker();
});

final aiServiceProvider = Provider<AIService>((ref) {
  return AIService(
    provider: ref.watch(aiProviderProvider),
    tracker: ref.watch(tokenTrackerProvider),
  );
});

// ── Repositories ──────────────────────────────────────────────────────

final taskRepositoryProvider = Provider<HiveRepository<TaskItem>>((ref) {
  return HiveRepository<TaskItem>('tasksBox');
});

final noteRepositoryProvider = Provider<HiveRepository<NoteItem>>((ref) {
  return HiveRepository<NoteItem>('notesBox');
});

final calendarRepositoryProvider = Provider<HiveRepository<CalendarEvent>>((
  ref,
) {
  return HiveRepository<CalendarEvent>('calendarBox');
});

final memoryRepositoryProvider = Provider<HiveRepository<MemoryEntry>>((ref) {
  return HiveRepository<MemoryEntry>('memoryBox');
});

// ── Services ──────────────────────────────────────────────────────────

final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService();
});
// ── Settings & Profile ────────────────────────────────────────────

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>(
  (ref) => SettingsController(),
);
