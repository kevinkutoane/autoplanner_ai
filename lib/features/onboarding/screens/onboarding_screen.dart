import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../../app_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final bool isReplay;
  const OnboardingScreen({super.key, this.isReplay = false});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  late final AnimationController _orbAC;
  late final AnimationController _dotAC;

  static const _pages = [
    _PageData(
      gradient: LinearGradient(
        colors: [Color(0xFF0A0A1A), Color(0xFF1A1040), Color(0xFF0D2040)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.auto_awesome_rounded,
      iconGradient: kGradientMain,
      title: 'AI-Powered Planning',
      subtitle: 'Describe your day in plain English. AutoPlanner turns it into a perfectly timed schedule — automatically.',
      bullets: [
        'Natural language task input',
        'Smart scheduling & priorities',
        'Auto-blocks your work hours',
      ],
    ),
    _PageData(
      gradient: LinearGradient(
        colors: [Color(0xFF0A0A1A), Color(0xFF0A1A2E), Color(0xFF0E2020)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.psychology_rounded,
      iconGradient: kGradientTeal,
      title: 'Living Memory',
      subtitle: 'AutoPlanner learns from your tasks, notes, and events. Ask it anything and it knows your context.',
      bullets: [
        'Remembers your patterns',
        'Contextual daily insights',
        'Smart note summarisation',
      ],
    ),
    _PageData(
      gradient: LinearGradient(
        colors: [Color(0xFF0A0A1A), Color(0xFF1A0A20), Color(0xFF2A1010)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.calendar_month_rounded,
      iconGradient: kGradientWarm,
      title: 'Unified Calendar',
      subtitle: 'All your tasks, events, and goals in one beautifully organised view — always in sync.',
      bullets: [
        'Task + event integration',
        'Visual weekly overview',
        'Never miss a deadline',
      ],
    ),
    _PageData(
      gradient: LinearGradient(
        colors: [Color(0xFF0A0A1A), Color(0xFF1A1040), Color(0xFF001A10)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.rocket_launch_rounded,
      iconGradient: kGradientMain,
      title: "You're All Set",
      subtitle: "AutoPlanner is ready to make every day your most productive. Let's get started!",
      bullets: [
        'Personalised to your schedule',
        'Offline-first with AI on demand',
        'Your data stays on-device',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _orbAC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _dotAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _orbAC.dispose();
    _dotAC.dispose();
    super.dispose();
  }

  // Total virtual pages = static pages + API key page
  int get _totalPages => _pages.length + 1;

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (widget.isReplay) {
      // Replay mode — just pop back to wherever the user came from (Settings,
      // HelpScreen, etc.). Do not touch onboarding state or the nav stack.
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await ref.read(settingsProvider.notifier).completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, a, _) => const AppShell(),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark0,
      body: Stack(
        children: [
          // Per-page orb background
          AnimatedBuilder(
            animation: _orbAC,
            builder: (_, _) => CustomPaint(
              painter: _OnboardOrbPainter(_orbAC.value, _currentPage),
              child: const SizedBox.expand(),
            ),
          ),

          // Subtle grid
          Opacity(
            opacity: 0.035,
            child: CustomPaint(
              painter: _GridPainter(),
              child: const SizedBox.expand(),
            ),
          ),

          // Page content
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _totalPages,
            itemBuilder: (ctx, i) {
              if (i < _pages.length) return _PageContent(page: _pages[i]);
              return const _ApiKeyPage();
            },
          ),

          // Bottom nav
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_totalPages, (i) {
                        final active = _currentPage == i;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: active ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            gradient: active ? kGradientMain : null,
                            color: active ? null : Colors.white.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    // Next / Finish button
                    Row(
                      children: [
                        if (widget.isReplay || _currentPage < _totalPages - 1)
                          Expanded(
                            child: GhostBtn(label: 'Skip', onTap: _finish),
                          )
                        else
                          const Spacer(),
                        if (widget.isReplay || _currentPage < _totalPages - 1)
                          const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GradBtn(
                            label: _currentPage == _totalPages - 1
                                ? "Let's Go!"
                                : 'Next',
                            icon: _currentPage == _totalPages - 1
                                ? Icons.rocket_launch_rounded
                                : Icons.arrow_forward_rounded,
                            gradient: kGradientMain,
                            onTap: _next,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── API Key page ──────────────────────────────────────────────────────────────
class _ApiKeyPage extends ConsumerStatefulWidget {
  const _ApiKeyPage();
  @override
  ConsumerState<_ApiKeyPage> createState() => _ApiKeyPageState();
}

class _ApiKeyPageState extends ConsumerState<_ApiKeyPage>
    with SingleTickerProviderStateMixin {
  final _keyCtrl = TextEditingController();
  late final AnimationController _ac;
  late final Animation<double> _iconScale;
  late final Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _iconScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _contentFade = CurvedAnimation(
      parent: _ac,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );
    _ac.forward();
    // Pre-fill if already set
    final existing = ref.read(settingsProvider).geminiApiKey;
    if (existing.isNotEmpty) _keyCtrl.text = existing;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _ac.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _keyCtrl.text = data!.text!.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _iconScale,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: kGradientMain,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: kIndigo.withAlpha(100),
                    blurRadius: 50,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.key_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 36),
          FadeTransition(
            opacity: _contentFade,
            child: Column(
              children: [
                const Text(
                  'Add Your API Key',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'AutoPlanner\'s AI features — Brain Dump, smart scheduling, daily insights, and proactive rescheduling — run on Google\'s Gemini AI. Gemini is a cloud service (not on-device), so the app needs a key to call the API on your behalf.\n\nThe free tier is genuinely free: no credit card, no expiry. Your key is stored only on this device and never shared.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withAlpha(25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _keyCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                  obscureText: true,
                                  scrollPadding: const EdgeInsets.only(
                                    bottom: 160,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'AIza...',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withAlpha(60),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withAlpha(10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white.withAlpha(30),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white.withAlpha(30),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: kCyan.withAlpha(200),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (v) {
                                    final key = v.trim();
                                    if (key.isNotEmpty) {
                                      ref
                                          .read(settingsProvider.notifier)
                                          .updateGeminiApiKey(key);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () async {
                                  await _paste();
                                  final key = _keyCtrl.text.trim();
                                  if (key.isNotEmpty) {
                                    await ref
                                        .read(settingsProvider.notifier)
                                        .updateGeminiApiKey(key);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: kGradientMain,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Paste',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: 13,
                                color: kCyan.withAlpha(180),
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Stored in your device keychain — never leaves your phone.',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    // Just copy the URL as hint — no navigation needed
                    Clipboard.setData(
                      const ClipboardData(text: 'https://aistudio.google.com'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'aistudio.google.com copied — open in your browser to get a free key',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: kCyan.withAlpha(180),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Get a free key at aistudio.google.com',
                          style: TextStyle(
                            color: kCyan.withAlpha(200),
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: kCyan.withAlpha(120),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page content ─────────────────────────────────────────────────────────────
class _PageContent extends StatefulWidget {
  final _PageData page;
  const _PageContent({required this.page});
  @override
  State<_PageContent> createState() => _PageContentState();
}

class _PageContentState extends State<_PageContent>
    with TickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _iconScale;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _iconScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _contentFade = CurvedAnimation(
      parent: _ac,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _ac,
            curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
          ),
        );
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  ScaleTransition(
                    scale: _iconScale,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: page.iconGradient,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: (page.iconGradient.colors.first).withAlpha(
                              100,
                            ),
                            blurRadius: 50,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(page.icon, color: Colors.white, size: 52),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Title + subtitle
                  SlideTransition(
                    position: _contentSlide,
                    child: FadeTransition(
                      opacity: _contentFade,
                      child: Column(
                        children: [
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            page.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 15.5,
                              height: 1.55,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Bullet points in glass card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(14),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(25),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: page.bullets
                                      .map(
                                        (b) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
                                          child: Row(
                                            children: [
                                              ShaderMask(
                                                shaderCallback: (rect) => page
                                                    .iconGradient
                                                    .createShader(rect),
                                                child: const Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 18,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  b,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────
class _PageData {
  final LinearGradient gradient;
  final IconData icon;
  final LinearGradient iconGradient;
  final String title;
  final String subtitle;
  final List<String> bullets;

  const _PageData({
    required this.gradient,
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });
}

// ── Orb painter ───────────────────────────────────────────────────────────────
class _OnboardOrbPainter extends CustomPainter {
  final double t;
  final int pageIndex;
  _OnboardOrbPainter(this.t, this.pageIndex);

  static const _configs = [
    [kIndigo, kCyan, kDark1],
    [kCyan, kIndigo, kDark0],
    [kCoral, kAmber, kDark1],
    [kIndigo, kCyan, kDark0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _configs[pageIndex % _configs.length];
    final bg = RadialGradient(colors: [const Color(0xFF13102A), kDark0]);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = bg.createShader(Offset.zero & size),
    );

    void orb(double cx, double cy, double r, Color c, double phase) {
      final x =
          size.width * cx +
          size.width * 0.1 * math.sin(2 * math.pi * t + phase);
      final y =
          size.height * cy +
          size.height * 0.08 * math.cos(2 * math.pi * t + phase);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90)
          ..color = c.withAlpha(50),
      );
    }

    orb(0.15, 0.2, size.width * 0.5, colors[0], 0.0);
    orb(0.85, 0.55, size.width * 0.45, colors[1], 2.5);
    orb(0.5, 0.85, size.width * 0.40, colors[2], 5.0);
  }

  @override
  bool shouldRepaint(_OnboardOrbPainter old) =>
      old.t != t || old.pageIndex != pageIndex;
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
