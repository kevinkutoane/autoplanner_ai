import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/goal_model.dart';
import '../../../core/models/memory_entry_model.dart';
import '../../../core/providers/providers.dart';
import '../controllers/settings_controller.dart';
import '../models/app_settings_model.dart';

// ── Profile Screen ────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  _ProfileStats? _stats;

  late final AnimationController _heroCtrl;
  late final AnimationController _orbCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _staggerCtrl;
  late final AnimationController _countCtrl;

  late final List<Animation<double>> _sectionFades;
  late final List<Animation<Offset>> _sectionSlides;

  static const int _sectionCount = 6;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _sectionFades = List.generate(_sectionCount, (i) {
      final start = (i * 0.12).clamp(0.0, 0.88);
      final end = (start + 0.32).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _sectionSlides = List.generate(_sectionCount, (i) {
      final start = (i * 0.12).clamp(0.0, 0.88);
      final end = (start + 0.38).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.18),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _staggerCtrl.forward();
    });

    _loadStats();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _orbCtrl.dispose();
    _pulseCtrl.dispose();
    _staggerCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final tasks = Hive.box<TaskItem>('tasksBox').length;
    final completed = Hive.box<TaskItem>(
      'tasksBox',
    ).values.where((t) => t.isCompleted).length;
    final goals = Hive.box<GoalItem>('goalsBox').length;
    final memories = Hive.box<MemoryEntry>('memoryBox').length;
    if (mounted) {
      setState(() {
        _stats = _ProfileStats(
          totalTasks: tasks,
          completedTasks: completed,
          totalGoals: goals,
          totalMemories: memories,
        );
      });
      _countCtrl.forward(from: 0);
    }
  }

  Widget _stagger(int index, Widget child) {
    return FadeTransition(
      opacity: _sectionFades[index],
      child: SlideTransition(position: _sectionSlides[index], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: _AnimatedBackground(
        orbCtrl: _orbCtrl,
        isDark: isDark,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.blurBackground],
                background: _HeroSection(
                  settings: settings,
                  heroCtrl: _heroCtrl,
                  pulseCtrl: _pulseCtrl,
                  isDark: isDark,
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _stagger(0, _IdentityBlock(settings: settings)),
                  const SizedBox(height: 24),
                  _stagger(1, _StatsRow(stats: _stats, countCtrl: _countCtrl)),
                  const SizedBox(height: 20),
                  _stagger(
                    2,
                    _GlassCard(child: _WorkScheduleContent(settings: settings)),
                  ),
                  const SizedBox(height: 16),
                  _stagger(
                    3,
                    _GlassCard(child: _AIPrefsContent(settings: settings)),
                  ),
                  const SizedBox(height: 28),
                  _stagger(
                    4,
                    _GradientButton(
                      label: 'Edit Profile',
                      icon: Icons.edit_rounded,
                      onTap: () => _showEditDialog(context, settings, ctrl),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _stagger(
                    5,
                    _GhostButton(
                      label: 'Back to Settings',
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    AppSettings settings,
    SettingsController ctrl,
  ) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, _) =>
          ProfileEditDialog(settings: settings, ctrl: ctrl),
    );
  }
}

// ── Animated Background ───────────────────────────────────────────────────────

class _AnimatedBackground extends StatelessWidget {
  final AnimationController orbCtrl;
  final bool isDark;
  final Widget child;

  const _AnimatedBackground({
    required this.orbCtrl,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF0A0A1A), Color(0xFF12122A)]
                  : const [Color(0xFFF0F0FF), Color(0xFFE8F4FD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: orbCtrl,
          builder: (_, _) =>
              CustomPaint(painter: _OrbPainter(orbCtrl.value, isDark)),
        ),
        child,
      ],
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final bool isDark;
  _OrbPainter(this.t, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _OrbData(
        cx: 0.2 + 0.15 * math.sin(t * 2 * math.pi),
        cy: 0.15 + 0.08 * math.cos(t * 2 * math.pi),
        r: 220,
        color: isDark ? const Color(0x256C63FF) : const Color(0x206C63FF),
      ),
      _OrbData(
        cx: 0.8 + 0.1 * math.cos(t * 2 * math.pi + 1.5),
        cy: 0.25 + 0.12 * math.sin(t * 2 * math.pi + 1.5),
        r: 180,
        color: isDark ? const Color(0x1A00D4AA) : const Color(0x1800D4AA),
      ),
      _OrbData(
        cx: 0.5 + 0.2 * math.sin(t * 2 * math.pi + 3.0),
        cy: 0.7 + 0.1 * math.cos(t * 2 * math.pi + 3.0),
        r: 160,
        color: isDark ? const Color(0x20FF6B6B) : const Color(0x15FF6B6B),
      ),
    ];
    for (final orb in orbs) {
      final paint = Paint()
        ..shader = RadialGradient(colors: [orb.color, orb.color.withAlpha(0)])
            .createShader(
              Rect.fromCircle(
                center: Offset(orb.cx * size.width, orb.cy * size.height),
                radius: orb.r,
              ),
            );
      canvas.drawCircle(
        Offset(orb.cx * size.width, orb.cy * size.height),
        orb.r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}

class _OrbData {
  final double cx, cy, r;
  final Color color;
  _OrbData({
    required this.cx,
    required this.cy,
    required this.r,
    required this.color,
  });
}

// ── Hero Section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final AppSettings settings;
  final AnimationController heroCtrl;
  final AnimationController pulseCtrl;
  final bool isDark;

  const _HeroSection({
    required this.settings,
    required this.heroCtrl,
    required this.pulseCtrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withAlpha(isDark ? 200 : 180),
                    const Color(0xFF00D4AA).withAlpha(isDark ? 180 : 160),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter(isDark: isDark)),
        SafeArea(
          bottom: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              _PulseAvatar(
                settings: settings,
                pulseCtrl: pulseCtrl,
                heroCtrl: heroCtrl,
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: heroCtrl,
                  curve: const Interval(0.4, 1.0),
                ),
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: heroCtrl,
                          curve: const Interval(
                            0.4,
                            1.0,
                            curve: Curves.easeOut,
                          ),
                        ),
                      ),
                  child: Text(
                    settings.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (settings.userJobTitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: heroCtrl,
                    curve: const Interval(0.55, 1.0),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withAlpha(60),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      settings.userJobTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 60,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  (isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF0F0FF))
                      .withAlpha(200),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool isDark;
  _GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(isDark ? 15 : 20)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ── Pulsing Avatar ────────────────────────────────────────────────────────────

class _PulseAvatar extends StatelessWidget {
  final AppSettings settings;
  final AnimationController pulseCtrl;
  final AnimationController heroCtrl;

  const _PulseAvatar({
    required this.settings,
    required this.pulseCtrl,
    required this.heroCtrl,
  });

  @override
  Widget build(BuildContext context) {
    const size = 100.0;

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: heroCtrl,
        curve: const Interval(0.0, 0.7),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1.0).animate(
          CurvedAnimation(
            parent: heroCtrl,
            curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
          ),
        ),
        child: AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, child) {
            final pulseVal = Tween<double>(begin: 1.0, end: 1.12).animate(
              CurvedAnimation(parent: pulseCtrl, curve: Curves.easeInOut),
            );
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: pulseVal.value,
                  child: Container(
                    width: size + 20,
                    height: size + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(
                          (60 * (1 - (pulseVal.value - 1.0) / 0.12)).round(),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 1.0 + (pulseVal.value - 1.0) * 1.8,
                  child: Container(
                    width: size + 20,
                    height: size + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha(20),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: AvatarCircle(settings: settings, size: size),
        ),
      ),
    );
  }
}

// ── Identity Block ────────────────────────────────────────────────────────────

class _IdentityBlock extends StatelessWidget {
  final AppSettings settings;
  const _IdentityBlock({required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settings.displayName,
          style: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            letterSpacing: -0.5,
          ),
        ),
        if (settings.userEmail.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.alternate_email_rounded,
                  size: 13,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                settings.userEmail,
                style: tt.bodyMedium?.copyWith(
                  color: isDark
                      ? Colors.white.withAlpha(160)
                      : const Color(0xFF7C7C8A),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Glass Card ────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(12)
                : Colors.white.withAlpha(160),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(25)
                  : Colors.white.withAlpha(200),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final _ProfileStats? stats;
  final AnimationController countCtrl;

  const _StatsRow({required this.stats, required this.countCtrl});

  @override
  Widget build(BuildContext context) {
    final isLoading = stats == null;
    return Row(
      children: [
        _StatCard(
          label: 'Tasks',
          value: isLoading ? 0 : stats!.totalTasks,
          icon: Icons.task_alt_rounded,
          gradient: const [Color(0xFF6C63FF), Color(0xFF9D97FF)],
          countCtrl: countCtrl,
          isLoading: isLoading,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Done',
          value: isLoading ? 0 : stats!.completedTasks,
          icon: Icons.check_circle_rounded,
          gradient: const [Color(0xFF00D4AA), Color(0xFF00B894)],
          countCtrl: countCtrl,
          isLoading: isLoading,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Goals',
          value: isLoading ? 0 : stats!.totalGoals,
          icon: Icons.flag_rounded,
          gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
          countCtrl: countCtrl,
          isLoading: isLoading,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Mems',
          value: isLoading ? 0 : stats!.totalMemories,
          icon: Icons.psychology_rounded,
          gradient: const [Color(0xFFFFD93D), Color(0xFFFFB347)],
          countCtrl: countCtrl,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final List<Color> gradient;
  final AnimationController countCtrl;
  final bool isLoading;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.countCtrl,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradient[0].withAlpha(isDark ? 50 : 35),
                  gradient[1].withAlpha(isDark ? 30 : 20),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: gradient[0].withAlpha(isDark ? 60 : 50),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Icon(icon, size: 22, color: Colors.white),
                ),
                const SizedBox(height: 6),
                isLoading
                    ? _ShimmerBox(width: 30, height: 20, radius: 6)
                    : AnimatedBuilder(
                        animation: countCtrl,
                        builder: (_, _) {
                          final displayed = (value * countCtrl.value).round();
                          return Text(
                            '$displayed',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                              height: 1,
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withAlpha(140)
                        : const Color(0xFF7C7C8A),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shimmer Box ───────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    Colors.white.withAlpha(15),
                    Colors.white.withAlpha(30),
                    Colors.white.withAlpha(15),
                  ]
                : [
                    Colors.black.withAlpha(8),
                    Colors.black.withAlpha(16),
                    Colors.black.withAlpha(8),
                  ],
            stops: [
              (_ctrl.value - 0.3).clamp(0.0, 1.0),
              _ctrl.value.clamp(0.0, 1.0),
              (_ctrl.value + 0.3).clamp(0.0, 1.0),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

// ── Work Schedule Card Content ────────────────────────────────────────────────

class _WorkScheduleContent extends StatelessWidget {
  final AppSettings settings;
  const _WorkScheduleContent({required this.settings});

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardLabel(
          icon: Icons.schedule_rounded,
          label: 'Work Schedule',
          color: const Color(0xFF6C63FF),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _ScheduleStatItem(
              icon: Icons.timer_rounded,
              label: 'Hours / day',
              value: '${settings.workHoursPerDay}h',
              isDark: isDark,
            ),
            _VertDivider(),
            _ScheduleStatItem(
              icon: Icons.alarm_rounded,
              label: 'Start time',
              value: settings.workStartLabel,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'ACTIVE DAYS',
          style: tt.labelSmall?.copyWith(
            color: isDark
                ? Colors.white.withAlpha(100)
                : const Color(0xFF7C7C8A),
            letterSpacing: 1.2,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(7, (i) {
            final active = settings.workDays[i];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 6 ? 5 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: active
                        ? null
                        : (isDark
                              ? Colors.white.withAlpha(10)
                              : Colors.black.withAlpha(8)),
                    borderRadius: BorderRadius.circular(10),
                    border: active
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(15)
                                : Colors.black.withAlpha(12),
                            width: 1,
                          ),
                  ),
                  child: Text(
                    _dayLabels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active
                          ? Colors.white
                          : (isDark
                                ? Colors.white.withAlpha(80)
                                : const Color(0xFF7C7C8A)),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15),
    );
  }
}

class _ScheduleStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _ScheduleStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withAlpha(isDark ? 40 : 25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: const Color(0xFF6C63FF)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.white.withAlpha(120)
                      : const Color(0xFF7C7C8A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── AI Preferences Content ────────────────────────────────────────────────────

class _AIPrefsContent extends StatelessWidget {
  final AppSettings settings;
  const _AIPrefsContent({required this.settings});

  String _formatTokens(int t) {
    if (t >= 1000000) return '${(t / 1000000).toStringAsFixed(1)}M';
    if (t >= 1000) return '${(t / 1000).round()}K';
    return '$t';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardLabel(
          icon: Icons.auto_awesome_rounded,
          label: 'AI Preferences',
          color: const Color(0xFF00D4AA),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _AIChip(
              label: settings.useMockAI ? 'Mock' : 'Live AI',
              icon: settings.useMockAI
                  ? Icons.science_rounded
                  : Icons.auto_awesome_rounded,
              active: !settings.useMockAI,
              activeGradient: const [Color(0xFF6C63FF), Color(0xFF00D4AA)],
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _AIChip(
              label: settings.enableAILogging ? 'Logging' : 'No Log',
              icon: Icons.receipt_long_rounded,
              active: settings.enableAILogging,
              activeGradient: const [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _AIChip(
              label: '${_formatTokens(settings.maxTokensPerDay)}/day',
              icon: Icons.token_rounded,
              active: true,
              activeGradient: const [Color(0xFF00D4AA), Color(0xFF6C63FF)],
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }
}

class _AIChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final List<Color> activeGradient;
  final bool isDark;

  const _AIChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeGradient,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [
                    activeGradient[0].withAlpha(isDark ? 55 : 40),
                    activeGradient[1].withAlpha(isDark ? 35 : 25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active
              ? null
              : (isDark
                    ? Colors.white.withAlpha(8)
                    : Colors.black.withAlpha(6)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? activeGradient[0].withAlpha(isDark ? 80 : 60)
                : (isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.black.withAlpha(12)),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (b) =>
                  (active
                          ? LinearGradient(colors: activeGradient)
                          : LinearGradient(
                              colors: [
                                isDark
                                    ? Colors.white.withAlpha(100)
                                    : Colors.black.withAlpha(80),
                                isDark
                                    ? Colors.white.withAlpha(100)
                                    : Colors.black.withAlpha(80),
                              ],
                            ))
                      .createShader(b),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active
                    ? (isDark ? Colors.white : const Color(0xFF1A1A2E))
                    : (isDark
                          ? Colors.white.withAlpha(100)
                          : const Color(0xFF7C7C8A)),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card Label ────────────────────────────────────────────────────────────────

class _CardLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CardLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 40 : 25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Gradient Button ───────────────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - 0.02 * _ctrl.value, child: child),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withAlpha(70),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ghost Button ──────────────────────────────────────────────────────────────

class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(35)
                : Colors.black.withAlpha(25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isDark
                  ? Colors.white.withAlpha(160)
                  : const Color(0xFF7C7C8A),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withAlpha(160)
                    : const Color(0xFF7C7C8A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared public widgets ─────────────────────────────────────────────────────

/// Circular avatar with gradient fallback and initials / emoji.
class AvatarCircle extends StatelessWidget {
  final AppSettings settings;
  final double size;

  const AvatarCircle({super.key, required this.settings, required this.size});

  @override
  Widget build(BuildContext context) {
    final isDefaultEmoji = settings.avatarEmoji == '🧑‍💻';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFE8E6FF), Color(0xFFB8F5EC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withAlpha(90),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: Center(
        child: isDefaultEmoji
            ? Text(
                settings.initials,
                style: TextStyle(
                  color: const Color(0xFF6C63FF),
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w900,
                ),
              )
            : Text(
                settings.avatarEmoji,
                style: TextStyle(fontSize: size * 0.45),
              ),
      ),
    );
  }
}

// ── Profile Edit Dialog ───────────────────────────────────────────────────────

class ProfileEditDialog extends StatefulWidget {
  final AppSettings settings;
  final SettingsController ctrl;

  const ProfileEditDialog({
    super.key,
    required this.settings,
    required this.ctrl,
  });

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _jobCtrl;
  late String _selectedEmoji;

  static const List<String> _emojiOptions = [
    '🧑‍💻',
    '👩‍💼',
    '👨‍💼',
    '🎯',
    '🚀',
    '💡',
    '🧠',
    '⚡',
    '🌟',
    '📊',
    '🎨',
    '🔥',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.settings.userName);
    _emailCtrl = TextEditingController(text: widget.settings.userEmail);
    _jobCtrl = TextEditingController(text: widget.settings.userJobTitle);
    _selectedEmoji = widget.settings.avatarEmoji;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _jobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF12122A).withAlpha(230)
                  : Colors.white.withAlpha(240),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(25)
                    : Colors.white.withAlpha(200),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withAlpha(15)
                                : Colors.black.withAlpha(8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: isDark
                                ? Colors.white.withAlpha(160)
                                : const Color(0xFF7C7C8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'CHOOSE AVATAR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: isDark
                          ? Colors.white.withAlpha(100)
                          : const Color(0xFF7C7C8A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _emojiOptions.map((emoji) {
                      final selected = _selectedEmoji == emoji;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedEmoji = emoji),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: selected
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF6C63FF),
                                      Color(0xFF00D4AA),
                                    ],
                                  )
                                : null,
                            color: selected
                                ? null
                                : (isDark
                                      ? Colors.white.withAlpha(12)
                                      : Colors.black.withAlpha(6)),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF6C63FF,
                                      ).withAlpha(80),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  _GlassTextField(
                    controller: _nameCtrl,
                    label: 'Display Name',
                    icon: Icons.person_outline_rounded,
                    isDark: isDark,
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  _GlassTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    icon: Icons.alternate_email_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _GlassTextField(
                    controller: _jobCtrl,
                    label: 'Job Title',
                    icon: Icons.work_outline_rounded,
                    isDark: isDark,
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 28),

                  Row(
                    children: [
                      Expanded(
                        child: _GhostButton(
                          label: 'Cancel',
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _GradientButton(
                          label: 'Save Changes',
                          icon: Icons.check_rounded,
                          onTap: () async {
                            await widget.ctrl.saveProfile(
                              name: _nameCtrl.text.trim(),
                              email: _emailCtrl.text.trim(),
                              jobTitle: _jobCtrl.text.trim(),
                              avatarEmoji: _selectedEmoji,
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glass Text Field ──────────────────────────────────────────────────────────

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isDark;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : Colors.black.withAlpha(12),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark
                ? Colors.white.withAlpha(120)
                : const Color(0xFF7C7C8A),
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ── Internal data class ───────────────────────────────────────────────────────

class _ProfileStats {
  final int totalTasks;
  final int completedTasks;
  final int totalGoals;
  final int totalMemories;

  const _ProfileStats({
    required this.totalTasks,
    required this.completedTasks,
    required this.totalGoals,
    required this.totalMemories,
  });
}
