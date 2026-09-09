import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../../app_shell.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orbAC;
  late final AnimationController _entryAC;
  late final AnimationController _pulseAC;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _dotFade;

  @override
  void initState() {
    super.initState();

    _orbAC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _entryAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _logoFade = CurvedAnimation(
      parent: _entryAC,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryAC,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _entryAC,
      curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryAC,
            curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
          ),
        );
    _taglineFade = CurvedAnimation(
      parent: _entryAC,
      curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
    );
    _dotFade = CurvedAnimation(
      parent: _entryAC,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );

    _entryAC.forward();

    Future.wait([
      Future.delayed(const Duration(milliseconds: 2800)),
      ref.read(settingsProvider.notifier).ensureInitialized(),
    ]).then((_) => _navigate());
  }

  Future<void> _navigate() async {
    final settings = ref.read(settingsProvider);
    if (!mounted) return;

    var startLocked = false;

    // If biometric lock is enabled and onboarding is done, authenticate first.
    if (settings.isOnboardingDone && settings.requireBiometrics) {
      final biometric = ref.read(biometricServiceProvider);
      final ok = await biometric.authenticate();
      if (!mounted) return;
      if (!ok) {
        // Keep the shell locked if the user cancels or fails the prompt during
        // a cold start. This avoids bypassing biometric protection.
        startLocked = true;
      }
    }

    final target = settings.isOnboardingDone
        ? AppShell(startLocked: startLocked)
        : const OnboardingScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, _) => target,
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _orbAC.dispose();
    _entryAC.dispose();
    _pulseAC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark0,
      body: Stack(
        children: [
          // Animated orb background
          AnimatedBuilder(
            animation: _orbAC,
            builder: (_, _) {
              return CustomPaint(
                painter: _SplashOrbPainter(_orbAC.value),
                child: const SizedBox.expand(),
              );
            },
          ),

          // Grid overlay
          Opacity(
            opacity: 0.04,
            child: CustomPaint(
              painter: _GridPainter(),
              child: const SizedBox.expand(),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo mark
                  AnimatedBuilder(
                    animation: _entryAC,
                    builder: (_, child) => FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(scale: _logoScale, child: child),
                    ),
                    child: AnimatedBuilder(
                      animation: _pulseAC,
                      builder: (_, child) => Transform.scale(
                        scale: 1.0 + 0.03 * _pulseAC.value,
                        child: child,
                      ),
                      child: _LogoMark(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // App name
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: ShaderMask(
                        shaderCallback: (b) => kGradientMain.createShader(b),
                        child: const Text(
                          'AutoPlanner AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tagline
                  FadeTransition(
                    opacity: _taglineFade,
                    child: const Text(
                      'Your AI-powered life planner',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Loading dots
                  FadeTransition(opacity: _dotFade, child: _LoadingDots()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo mark ──────────────────────────────────────────────────────────────
class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: kIndigo.withAlpha(120),
            blurRadius: 48,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: kCyan.withAlpha(60),
            blurRadius: 72,
            spreadRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.asset(
          'lib/Assets/autoplanner_logo.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ── Loading dots ───────────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i / 3;
        final phase = (_c.value - delay).clamp(0.0, 1.0);
        final scale = 0.6 + 0.4 * math.sin(phase * math.pi);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: kGradientMain,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: kIndigo.withAlpha(100), blurRadius: 8),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );
}

// ── Painters ───────────────────────────────────────────────────────────────
class _SplashOrbPainter extends CustomPainter {
  final double t;
  _SplashOrbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final baseGrad = const RadialGradient(colors: [Color(0xFF1A1040), kDark0]);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = baseGrad.createShader(Offset.zero & size),
    );

    void orb(double cx, double cy, double r, Color c, double phase) {
      final x =
          size.width * cx +
          size.width * 0.12 * math.sin(2 * math.pi * t + phase);
      final y =
          size.height * cy +
          size.height * 0.10 * math.cos(2 * math.pi * t + phase);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
          ..color = c.withAlpha(60),
      );
    }

    orb(0.2, 0.25, size.width * 0.45, kIndigo, 0.0);
    orb(0.8, 0.6, size.width * 0.40, kCyan, 2.1);
    orb(0.5, 0.8, size.width * 0.35, kCoral, 4.2);
  }

  @override
  bool shouldRepaint(_SplashOrbPainter old) => old.t != t;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
