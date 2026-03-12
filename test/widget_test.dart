import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autoplanner_ai/core/theme/ui_kit.dart';

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
}
