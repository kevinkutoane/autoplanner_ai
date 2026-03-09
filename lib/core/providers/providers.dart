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
import '../../services/outlook_auth_service.dart';
import '../../features/settings/models/app_settings_model.dart';
import '../../features/settings/controllers/settings_controller.dart';

// ── Settings & Profile ────────────────────────────────────────────
// Declared first so other providers can watch it without forward-reference issues.

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>(
  (ref) => SettingsController(),
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
  );
});

// ── Services ──────────────────────────────────────────────────────────

/// Overridden in main() with an already-initialized MemoryService instance.
final memoryServiceProvider = Provider<MemoryService>((_) => MemoryService());

final schedulerServiceProvider = Provider<SchedulerService>(
  (_) => SchedulerService(),
);

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

/// Overridden in main() with the initialized OutlookAuthService instance.
final outlookAuthServiceProvider = Provider<OutlookAuthService>(
  (_) => OutlookAuthService(),
);
