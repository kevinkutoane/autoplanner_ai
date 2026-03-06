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
import '../../features/settings/models/app_settings_model.dart';
import '../../features/settings/controllers/settings_controller.dart';

// ── Settings & Profile ────────────────────────────────────────────
// Declared first so other providers can watch it without forward-reference issues.

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>(
  (ref) => SettingsController(),
);

// ── AI Layer ──────────────────────────────────────────────────────────

final aiProviderProvider = Provider<AIProvider>((ref) {
  final useMock = ref.watch(settingsProvider.select((s) => s.useMockAI));
  if (useMock) return MockAIProvider();
  return GeminiProvider();
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
