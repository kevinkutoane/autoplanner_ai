import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/ai/mock_ai_provider.dart';
import 'package:autoplanner_ai/core/ai/ai_guard.dart';
import 'package:autoplanner_ai/core/ai/token_tracker.dart';
import 'package:autoplanner_ai/services/ai_service.dart';
import 'package:autoplanner_ai/services/gamification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(envString: 'ENABLE_TOKEN_TRACKING=false');
    appConfig = EnvConfig.fromDotEnv();
  });

  setUp(() {
    AIGuard.instance.resetFrequencyWindow();
  });

  group('Brain Dump 2.0 Feature Tests', () {
    test('BrainDumpResult model aggregates 4 pillars (tasks, notes, goals, memories)', () {
      const result = BrainDumpResult(
        tasks: [],
        goals: [],
        notes: [],
        memories: [],
      );
      expect(result.isEmpty, isTrue);
      expect(result.totalCount, equals(0));
    });

    test('AIService.brainDump parses rich tasks, notes, goals, and memories with MockAIProvider', () async {
      final aiService = AIService(
        provider: MockAIProvider(),
        tracker: TokenTracker(),
      );

      final result = await aiService.brainDump('Review action items, project ideas for gamification, launch MVP');

      expect(result.isEmpty, isFalse);
      expect(result.tasks.length, greaterThanOrEqualTo(1));
      expect(result.notes.length, greaterThanOrEqualTo(1));
      expect(result.goals.length, greaterThanOrEqualTo(1));
      expect(result.memories.length, greaterThanOrEqualTo(1));

      // Validate rich task properties
      final firstTask = result.tasks.first;
      expect(firstTask.title, equals('Review action items'));
      expect(firstTask.priority, equals(1));
      expect(firstTask.energyLevel, equals('medium'));

      // Validate extracted note
      final firstNote = result.notes.first;
      expect(firstNote.title, equals('Project ideas'));
      expect(firstNote.content, contains('gamifying'));
      expect(firstNote.tags, contains('idea'));

      // Validate extracted goal
      final firstGoal = result.goals.first;
      expect(firstGoal.title, equals('Launch MVP'));

      // Validate memory
      expect(result.memories.first, contains('focused work blocks'));
    });

    test('Gamification awards +50 XP for mental decluttering on brain dump save', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gamificationServiceProvider.notifier);
      final initialXp = container.read(gamificationServiceProvider).totalXp;

      await notifier.awardBrainDump();

      final updatedProfile = container.read(gamificationServiceProvider);
      expect(updatedProfile.totalXp, equals(initialXp + 50));
    });
  });
}
