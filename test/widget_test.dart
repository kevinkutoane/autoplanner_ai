import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/theme/ui_kit.dart';
import 'package:autoplanner_ai/features/settings/screens/help_screen.dart';

// Smoke-tests for pure stateless UI components in ui_kit.dart.
// These do not require Hive / dotenv — safe to run in CI without device.

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData.dark(),
  home: Scaffold(backgroundColor: Colors.black, body: child),
);

void main() {
  group('GlassCard', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(
        _wrap(const GlassCard(child: Text('Hello GlassCard'))),
      );
      expect(find.text('Hello GlassCard'), findsOneWidget);
    });

    testWidgets('accepts optional padding', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const GlassCard(padding: EdgeInsets.all(32), child: Text('padded')),
        ),
      );
      expect(find.text('padded'), findsOneWidget);
    });
  });

  group('SectionLabel', () {
    testWidgets('shows label text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SectionLabel(
            icon: Icons.settings,
            label: 'My Section',
            color: Colors.purple,
          ),
        ),
      );
      expect(find.text('MY SECTION'), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('shows message and icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(
            icon: Icons.inbox_rounded,
            message: 'Nothing here yet',
          ),
        ),
      );
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
    });
  });

  group('GradientHeader', () {
    testWidgets('renders child inside header', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GradientHeader(
            gradient: kGradientMain,
            child: const Text('Header child'),
          ),
        ),
      );
      expect(find.text('Header child'), findsOneWidget);
    });
  });

  group('HelpScreen', () {
    testWidgets('renders guide header, daily lifecycle, and capability tiles', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Help & Guide'), findsOneWidget);
      expect(find.text('WHAT IS AUTOPLANNER AI?'), findsOneWidget);
      expect(find.text('THE DAILY LIFECYCLE'), findsOneWidget);
      expect(find.text('FEATURE GUIDE'), findsOneWidget);
      expect(find.text('Brain Dump 2.0 Studio'), findsNWidgets(2));
      expect(find.text('Autonomous Scheduling & DAG Solver'), findsOneWidget);
      expect(
        find.text('Daily Rituals: Morning Kickoff & Shutdown'),
        findsOneWidget,
      );
    });

    testWidgets('expands feature tile on tap to show detailed guide', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      final brainDumpTiles = find.text('Brain Dump 2.0 Studio');
      expect(brainDumpTiles, findsNWidgets(2));

      // Tap the Feature Guide tile (second occurrence) to expand
      await tester.tap(brainDumpTiles.last);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('32-band reactive audio waveform'),
        findsOneWidget,
      );
    });
  });
}
