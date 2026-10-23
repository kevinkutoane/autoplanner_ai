import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:autoplanner_ai/core/config/env_config.dart';
import 'package:autoplanner_ai/core/ai/mock_ai_provider.dart';
import 'package:autoplanner_ai/core/ai/gemini_provider.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/providers/providers.dart';
import 'package:autoplanner_ai/features/dashboard/widgets/schedule_drift_card.dart';
import 'package:autoplanner_ai/features/settings/controllers/settings_controller.dart';
import 'package:autoplanner_ai/features/settings/models/app_settings_model.dart';
import 'package:autoplanner_ai/features/settings/widgets/ai_engine_card.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    appConfig = const EnvConfig();
    tempDir = await Directory.systemTemp.createTemp(
      'autoplanner_ai_drift_test_',
    );
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SettingsController AI Gateway & Drift State', () {
    late Box<dynamic> box;

    setUp(() async {
      if (Hive.isBoxOpen(AppSettings.boxName)) {
        box = Hive.box<dynamic>(AppSettings.boxName);
      } else {
        box = await Hive.openBox<dynamic>(AppSettings.boxName);
      }
      await box.clear();
    });

    test('updates aiConnectionMode, cloudGatewayUrl, autoRippleDrift, and driftGraceMinutes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      await ctrl.ensureInitialized();

      expect(
        container.read(settingsProvider).aiConnectionMode,
        'direct_gemini',
      );

      await ctrl.updateAIConnectionMode('offline_mock');
      expect(container.read(settingsProvider).aiConnectionMode, 'offline_mock');
      expect(box.get(AppSettings.kAiConnectionMode), 'offline_mock');

      await ctrl.updateCloudGatewayUrl('http://192.168.1.100:8000');
      expect(
        container.read(settingsProvider).cloudGatewayUrl,
        'http://192.168.1.100:8000',
      );
      expect(
        box.get(AppSettings.kCloudGatewayUrl),
        'http://192.168.1.100:8000',
      );

      await ctrl.updateAutoRippleDrift(false);
      expect(container.read(settingsProvider).autoRippleDrift, isFalse);
      expect(box.get(AppSettings.kAutoRippleDrift), isFalse);

      await ctrl.updateDriftGraceMinutes(25);
      expect(container.read(settingsProvider).driftGraceMinutes, 25);
      expect(box.get(AppSettings.kDriftGraceMinutes), 25);
    });
  });

  group('aiProviderProvider dynamic switching', () {
    test(
      'routes to CloudAIProvider when aiConnectionMode is cloud_gateway',
      () {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              () => _MockSettingsController(
                AppSettings.defaults().copyWith(
                  aiConnectionMode: 'cloud_gateway',
                  cloudGatewayUrl: 'http://127.0.0.1:8000',
                  useMockAI: false,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final provider = container.read(aiProviderProvider);
        expect(provider, isA<CloudAIProvider>());
        final cloudProvider = provider as CloudAIProvider;
        expect(
          cloudProvider.gatewayBaseUrl.toString(),
          'http://127.0.0.1:8000',
        );
      },
    );

    test('routes to MockAIProvider when aiConnectionMode is offline_mock', () {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(
            () => _MockSettingsController(
              AppSettings.defaults().copyWith(aiConnectionMode: 'offline_mock'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = container.read(aiProviderProvider);
      expect(provider, isA<MockAIProvider>());
    });

    test(
      'routes to GeminiProvider when direct_gemini is selected with API key',
      () {
        final container = ProviderContainer(
          overrides: [
            settingsProvider.overrideWith(
              () => _MockSettingsController(
                AppSettings.defaults().copyWith(
                  aiConnectionMode: 'direct_gemini',
                  geminiApiKey: 'test-direct-key-12345',
                  useMockAI: false,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final provider = container.read(aiProviderProvider);
        expect(provider, isA<GeminiProvider>());
        final gemini = provider as GeminiProvider;
        expect(gemini.modelName, 'gemini-1.5-flash');
      },
    );
  });

  group('ScheduleDriftCard Widget Tests', () {
    testWidgets('renders nothing when no schedule drift is detected', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scheduleDriftProvider.overrideWithValue(ScheduleDrift.none()),
          ],
          child: const MaterialApp(home: Scaffold(body: ScheduleDriftCard())),
        ),
      );

      expect(find.byType(ScheduleDriftCard), findsOneWidget);
      expect(find.text('Schedule Drift Detected'), findsNothing);
    });

    testWidgets(
      'renders drift warning and Auto-Ripple button when drift is present',
      (tester) async {
        final baseDate = DateTime(2026, 10, 2, 9, 0);
        final driftedTask = TaskItem(
          id: 'task-1',
          title: 'Review System Architecture',
          startTime: baseDate,
          endTime: baseDate.add(const Duration(minutes: 60)),
          isCompleted: false,
        );

        final activeDrift = ScheduleDrift(
          hasDrift: true,
          driftMinutes: 35,
          overdueTasks: [driftedTask],
          impactedTasks: [],
          summary: 'Schedule is running 35 min behind.',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [scheduleDriftProvider.overrideWithValue(activeDrift)],
            child: const MaterialApp(home: Scaffold(body: ScheduleDriftCard())),
          ),
        );

        expect(find.text('Schedule Drift Detected'), findsOneWidget);
        expect(find.text('+35m'), findsOneWidget);
        expect(find.text('Auto-Ripple Schedule'), findsOneWidget);
        expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

        // Expand task list
        await tester.tap(find.byTooltip('View drifted tasks'));
        await tester.pumpAndSettle();

        expect(find.text('Review System Architecture'), findsOneWidget);
      },
    );

    testWidgets(
      'renders cleanly without overflow in 320px viewport with large text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final baseDate = DateTime(2026, 10, 2, 9, 0);
        final driftedTask = TaskItem(
          id: 'task-1',
          title: 'Review System Architecture with Distributed Teams',
          startTime: baseDate,
          endTime: baseDate.add(const Duration(minutes: 60)),
          isCompleted: false,
        );

        final activeDrift = ScheduleDrift(
          hasDrift: true,
          driftMinutes: 35,
          overdueTasks: [driftedTask],
          impactedTasks: [],
          summary: 'Schedule is running 35 min behind.',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [scheduleDriftProvider.overrideWithValue(activeDrift)],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 800),
                  textScaler: TextScaler.linear(1.5),
                ),
                child: const Scaffold(
                  body: SingleChildScrollView(child: ScheduleDriftCard()),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(ScheduleDriftCard), findsOneWidget);
        expect(find.text('Auto-Ripple Schedule'), findsOneWidget);

        // Expand task list
        await tester.tap(find.byTooltip('View drifted tasks'));
        await tester.pumpAndSettle();

        expect(
          find.text('Review System Architecture with Distributed Teams'),
          findsOneWidget,
        );
      },
    );
  });

  group('AIEngineCard Widget Tests', () {
    testWidgets('displays connection mode tabs and gateway base url', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(settingsProvider.notifier);
      final settings = AppSettings.defaults().copyWith(
        aiConnectionMode: 'cloud_gateway',
        cloudGatewayUrl: 'http://127.0.0.1:8000',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AIEngineCard(settings: settings, ctrl: ctrl),
              ),
            ),
          ),
        ),
      );

      expect(find.text('AI Assistant Connection'), findsOneWidget);
      expect(find.text('Gemini Key'), findsOneWidget);
      expect(find.text('Demo Mode'), findsOneWidget);
      expect(find.textContaining('Custom Gateway'), findsOneWidget);
      expect(find.text('Automatic Schedule Catch-Up'), findsOneWidget);

      // Expand Advanced Settings section
      await tester.tap(find.text('AI Telemetry & Token Safeguards'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Gateway Server (Self-Hosted)'), findsOneWidget);
      expect(find.text('Gateway URL'), findsOneWidget);
      expect(find.text('Ping'), findsOneWidget);
    });
  });
}

class _MockSettingsController extends SettingsController {
  final AppSettings _initial;
  _MockSettingsController(this._initial);

  @override
  AppSettings build() => _initial;
}
