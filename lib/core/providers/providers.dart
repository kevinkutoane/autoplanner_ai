// Centralized Riverpod providers for the entire app.
// Single source of truth for all shared services and controllers.
// Every feature imports from here — no more duplicate providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/ai_provider.dart';
import '../ai/gemini_provider.dart';
import '../ai/mock_ai_provider.dart';
import '../ai/token_tracker.dart';
import '../../services/ai_service.dart';
import '../../services/memory_service.dart';
import '../../services/scheduler_service.dart';
import '../../services/biometric_service.dart';
import '../../services/notification_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/conflict_detector.dart';
import '../../services/app_monitor_service.dart';
import '../../services/reschedule_service.dart';
import '../../services/offline_ai_queue.dart';
import '../../features/settings/models/app_settings_model.dart';
import '../models/memory_entry_model.dart';
import '../../features/memory/controllers/memory_controller.dart';
import '../../features/settings/controllers/settings_controller.dart';
import '../../features/planner/controllers/task_controller.dart';
// Re-export note controller provider so screens can import from providers.dart
export '../../features/notes/controllers/note_controller.dart' show noteControllerProvider, notesControllerProvider;

// ── Settings & Profile ────────────────────────────────────────────
/// Declared first so other providers can watch it without forward-reference
/// issues. Persists all user preferences across app restarts.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

// ── AI Layer ──────────────────────────────────────────────────────────

final aiProviderProvider = Provider<AIProvider>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.useMockAI) return MockAIProvider();
  // Prefer the user-supplied key from secure storage; fall back to .env.
  final key = settings.geminiApiKey.isNotEmpty ? settings.geminiApiKey : null;
  return GeminiProvider(apiKey: key);
});

/// Overridden in main() with an already-initialized TokenTracker instance.
final tokenTrackerProvider = Provider<TokenTracker>((_) => TokenTracker());

final aiServiceProvider = Provider<AIService>((ref) {
  return AIService(
    provider: ref.watch(aiProviderProvider),
    tracker: ref.watch(tokenTrackerProvider),
    monitor: ref.watch(appMonitorServiceProvider),
  );
});

// ── Services ──────────────────────────────────────────────────────────

/// Overridden in main() with an already-initialized MemoryService instance.
final memoryServiceProvider = Provider<MemoryService>((_) => MemoryService());

/// Singleton deterministic scheduler. Stateless — safe to create inline,
/// but shared here to avoid repeated allocations across the widget tree.
final schedulerServiceProvider = Provider<SchedulerService>(
  (_) => SchedulerService(),
);

/// Wrapper around `local_auth` for fingerprint / Face ID / device-PIN checks.
final biometricServiceProvider = Provider<BiometricService>(
  (_) => BiometricService(),
);

/// Overridden in main() with the initialized NotificationService instance.
final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);

// ── Calendar integrations ─────────────────────────────────────────

/// Overridden in main() with the initialized GoogleAuthService instance.
final googleAuthServiceProvider = Provider<GoogleAuthService>(
  (_) => GoogleAuthService(),
);

/// Overridden in main() with the initialized CalendarSyncService instance.
final calendarSyncServiceProvider = Provider<CalendarSyncService>(
  (_) => CalendarSyncService(googleAuth: GoogleAuthService()),
);

final conflictDetectorProvider = Provider<ConflictDetector>(
  (_) => ConflictDetector(),
);

/// Overridden in main() with the initialized AppMonitorService instance.
final appMonitorServiceProvider = Provider<AppMonitorService>(
  (_) => AppMonitorService(),
);

// ── Proactive re-scheduling ───────────────────────────────────────────────

final rescheduleServiceProvider = Provider<RescheduleService>((ref) {
  return RescheduleService(
    ai: ref.watch(aiServiceProvider),
    scheduler: ref.watch(schedulerServiceProvider),
  );
});

class RescheduleSuggestionNotifier extends Notifier<RescheduleSuggestion?> {
  @override
  RescheduleSuggestion? build() => null;
  void set(RescheduleSuggestion? value) => state = value;
}

/// Holds the current reschedule suggestion (null = nothing to show).
/// Set by [RescheduleService.checkOverdue] and cleared when accepted/dismissed.
final rescheduleSuggestionProvider =
    NotifierProvider<RescheduleSuggestionNotifier, RescheduleSuggestion?>(
  RescheduleSuggestionNotifier.new,
);

// ── Offline AI Queue ─────────────────────────────────────────────────────

/// Overridden in main() with the initialized OfflineAIQueue instance.
final offlineAIQueueProvider = Provider<OfflineAIQueue>((ref) {
  final queue = OfflineAIQueue(
    executeCallback: (method, args) async {
      final ai = ref.read(aiServiceProvider);
      switch (method) {
        case 'extractMemory':
          final result = await ai.extractMemoryFromContext(
            args['context'] as String,
            args['sourceType'] as String,
          );
          if (result != null && result != 'NONE') {
            final entry = MemoryEntry(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              content: result,
              sourceType: args['sourceType'] as String,
              tags: [],
              createdAt: DateTime.now(),
            );
            ref.read(memoryControllerProvider.notifier).addMemory(entry);
          }
          break;
        default:
          throw UnsupportedError('Method $method is not supported for offline dispatch.');
      }
    },
  );
  // Initialise asynchronously (the caller is responsible for awaiting init before enqueueing,
  // or it will happen lazily). In our case, it's safe because main.dart or AppBootstrapper
  // will call init() immediately after container construction.
  return queue;
});

// ── Planner State ─────────────────────────────────────────────────────────

class PlannerSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

/// Search query for filtering tasks in the planner screen.
final plannerSearchProvider = NotifierProvider<PlannerSearchNotifier, String>(
  PlannerSearchNotifier.new,
);

class PlannerGoalFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? value) => state = value;
}

/// Optional goal-ID filter for the planner task list.
/// When non-null, only tasks linked to this goal are shown.
final plannerGoalFilterProvider =
    NotifierProvider<PlannerGoalFilterNotifier, String?>(
  PlannerGoalFilterNotifier.new,
);

/// Proactive task suggestions for an empty planner day.
/// Auto-disposes and refetches when memory or task state changes.
/// Returns [] when today already has tasks (no suggestions needed).
final taskSuggestionsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final ai = ref.watch(aiServiceProvider);
  final memoryService = ref.watch(memoryServiceProvider);
  final tasks = ref.watch(taskControllerProvider);

  final today = DateTime.now();
  final todayTasks = tasks.where(
    (t) =>
        t.startTime.year == today.year &&
        t.startTime.month == today.month &&
        t.startTime.day == today.day,
  );
  // Only suggest when the day is empty — no point cluttering a busy planner.
  if (todayTasks.isNotEmpty) return [];

  final memories = memoryService.contextMemories(limit: 15);
  return ai.suggestTasks(
    memories: memories,
    date: today,
    recentHistory: tasks.take(20).toList(),
  );
});
