import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'core/models/calendar_event_model.dart';
import 'core/theme/ui_kit.dart';
import 'core/providers/providers.dart';
import 'features/brain_dump/brain_dump_sheet.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/planner/screens/planner_screen.dart';
import 'features/goals/screens/goals_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/memory/screens/memory_screen.dart';
import 'features/notes/screens/notes_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/planner/controllers/task_controller.dart';
import 'features/goals/controllers/goal_controller.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/projects/screens/projects_screen.dart';
import 'features/coach/screens/ai_coach_screen.dart';
import 'features/focus/screens/focus_hub_screen.dart';
import 'package:flutter/services.dart';
import 'features/commands/widgets/command_palette_modal.dart';

// ── Nav item descriptor ──────────────────────────────────────────────────────
class _NavItem {
  final int screenIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final List<Color> gradient;
  const _NavItem({
    required this.screenIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.gradient,
  });
}

// Primary nav items shown on the left of the center Brain Dump button
const _primaryNavLeft = [
  _NavItem(
    screenIndex: 0,
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    label: 'Home',
    gradient: [kIndigo, Color(0xFF9D97FF)],
  ),
  _NavItem(
    screenIndex: 1,
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note_rounded,
    label: 'Plan',
    gradient: [kCyan, Color(0xFF00B894)],
  ),
];

// Primary nav items shown on the right of the center Brain Dump button
const _primaryNavRight = [
  _NavItem(
    screenIndex: 3,
    icon: Icons.smart_toy_outlined,
    activeIcon: Icons.smart_toy_rounded,
    label: 'AI Coach',
    gradient: [Color(0xFF9B59B6), kIndigo],
  ),
];

// Overflow items revealed in the "More" glass sheet (organized in 4x2 grid)
const _overflowNavItems = [
  _NavItem(
    screenIndex: 2,
    icon: Icons.flash_on_outlined,
    activeIcon: Icons.flash_on_rounded,
    label: 'Focus',
    gradient: [kCoral, Color(0xFFFF8E8E)],
  ),
  _NavItem(
    screenIndex: 4,
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Calendar',
    gradient: [Color(0xFF9B59B6), kIndigo],
  ),
  _NavItem(
    screenIndex: 5,
    icon: Icons.flag_outlined,
    activeIcon: Icons.flag_rounded,
    label: 'Goals',
    gradient: [kCoral, Color(0xFFFF8E8E)],
  ),
  _NavItem(
    screenIndex: 8,
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder_rounded,
    label: 'Projects',
    gradient: [kCyan, Color(0xFF0984E3)],
  ),
  _NavItem(
    screenIndex: 6,
    icon: Icons.psychology_outlined,
    activeIcon: Icons.psychology_rounded,
    label: 'Memory',
    gradient: [kAmber, Color(0xFFFFB347)],
  ),
  _NavItem(
    screenIndex: 7,
    icon: Icons.sticky_note_2_outlined,
    activeIcon: Icons.sticky_note_2_rounded,
    label: 'Notes',
    gradient: [Color(0xFF00B894), kCyan],
  ),
  _NavItem(
    screenIndex: 9,
    icon: Icons.insights_outlined,
    activeIcon: Icons.insights_rounded,
    label: 'Insights',
    gradient: [Color(0xFF9B59B6), Color(0xFFE056A0)],
  ),
  _NavItem(
    screenIndex: 10,
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    label: 'Settings',
    gradient: [Color(0xFF636E72), Color(0xFFB2BEC3)],
  ),
];

class _CommandPaletteIntent extends Intent {
  const _CommandPaletteIntent();
}

// ── Shell ────────────────────────────────────────────────────────────────────
class AppShell extends ConsumerStatefulWidget {
  final bool startLocked;

  const AppShell({super.key, this.startLocked = false});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  // True once the app has gone to background; cleared after successful unlock.
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    _locked = widget.startLocked;
    WidgetsBinding.instance.addObserver(this);
    // Run the first overdue check after the first frame so all providers
    // are fully initialised.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appMonitorServiceProvider).logSessionStart();
      _checkReschedule();
      if (widget.startLocked) {
        _triggerUnlock();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final requireBiometrics = ref.read(settingsProvider).requireBiometrics;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background — arm the lock and end the session.
      ref.read(appMonitorServiceProvider).logSessionEnd();
      if (requireBiometrics && mounted) setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed) {
      ref.read(appMonitorServiceProvider).logSessionStart();
      if (requireBiometrics && _locked) _triggerUnlock();
      // Check for overdue tasks whenever the user returns to the app.
      _checkReschedule();
    }
  }

  Future<void> _checkReschedule() async {
    // Skip if a suggestion is already showing.
    if (ref.read(rescheduleSuggestionProvider) != null) return;
    try {
      final service = ref.read(rescheduleServiceProvider);
      final tasks = ref.read(taskControllerProvider);
      final calendarEvents = Hive.isBoxOpen('calendarBox')
          ? Hive.box<CalendarEvent>('calendarBox').values.toList()
          : <CalendarEvent>[];
      final memories = ref.read(memoryServiceProvider).contextMemories();
      final settings = ref.read(settingsProvider);
      final goals = ref.read(goalControllerProvider);
      final suggestion = await service.checkOverdue(
        tasks: tasks,
        calendarEvents: calendarEvents,
        memories: memories,
        settings: settings,
        goals: goals,
      );
      if (mounted && suggestion != null) {
        ref.read(rescheduleSuggestionProvider.notifier).set(suggestion);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('RescheduleService: checkOverdue failed — $e');
    }
  }

  Future<void> _triggerUnlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final biometric = ref.read(biometricServiceProvider);
    final ok = await biometric.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (ok) _locked = false;
      // If authentication failed/cancelled, keep locked.
    });
  }

  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(80),
      builder: (ctx) => _GlassMoreSheet(
        currentIndex: _currentIndex,
        onTap: (i) {
          Navigator.pop(ctx);
          setState(() => _currentIndex = i);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      // canPop:false prevents Android back from bypassing the lock screen.
      return PopScope(
        canPop: false,
        child: _LockOverlay(
          authenticating: _authenticating,
          onRetry: _triggerUnlock,
        ),
      );
    }
    // canPop:false absorbs Android back on every main tab so the app is never
    // accidentally closed via the system back gesture.
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
            const _CommandPaletteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const _CommandPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CommandPaletteIntent: CallbackAction<_CommandPaletteIntent>(
            onInvoke: (intent) => showCommandPalette(context),
          ),
        },
        child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: false,
          child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const _ConnectivityBanner(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  TickerMode(
                    enabled: _currentIndex == 0,
                    child: DashboardScreen(
                      onNavigateTo: (i) => setState(() => _currentIndex = i),
                    ),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 1,
                    child: const PlannerScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 2,
                    child: const FocusHubScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 3,
                    child: const AiCoachScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 4,
                    child: const CalendarScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 5,
                    child: const GoalsScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 6,
                    child: const MemoryScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 7,
                    child: const NotesScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 8,
                    child: const ProjectsScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 9,
                    child: const AnalyticsScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 10,
                    child: const SettingsScreen(),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _GlassNavBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          onMoreTap: _showMoreSheet,
        ),
      ),
    ),
  ),
),
);
  }
}

// ── Floating glass nav bar ───────────────────────────────────────────────────
class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onMoreTap;
  const _GlassNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    _NavItem? activeOverflowItem;
    for (final item in _overflowNavItems) {
      if (item.screenIndex == currentIndex) {
        activeOverflowItem = item;
        break;
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad + 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(33),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(20)
                  : Colors.white.withAlpha(195),
              borderRadius: BorderRadius.circular(33),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(35)
                    : Colors.white.withAlpha(220),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 25),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: kIndigo.withAlpha(isDark ? 30 : 15),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavButton(
                    item: _primaryNavLeft[0],
                    isSelected: currentIndex == _primaryNavLeft[0].screenIndex,
                    onTap: () => onTap(_primaryNavLeft[0].screenIndex),
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _NavButton(
                    item: _primaryNavLeft[1],
                    isSelected: currentIndex == _primaryNavLeft[1].screenIndex,
                    onTap: () => onTap(_primaryNavLeft[1].screenIndex),
                    isDark: isDark,
                  ),
                ),
                _DockedBrainDumpButton(
                  isDark: isDark,
                  onTap: () => showBrainDump(context),
                ),
                Expanded(
                  child: _NavButton(
                    item: _primaryNavRight[0],
                    isSelected: currentIndex == _primaryNavRight[0].screenIndex,
                    onTap: () => onTap(_primaryNavRight[0].screenIndex),
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _MoreNavButton(
                    isSelected: activeOverflowItem != null,
                    activeItem: activeOverflowItem,
                    onTap: onMoreTap,
                    isDark: isDark,
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

// ── Individual nav button ────────────────────────────────────────────────────
class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.10,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.elasticOut));
    _glowAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));

    if (widget.isSelected) _ac.forward();
  }

  @override
  void didUpdateWidget(_NavButton old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      if (widget.isSelected) {
        _ac.forward();
      } else {
        _ac.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (_, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.isSelected)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 40,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: widget.item.gradient
                                  .map(
                                    (c) => c.withAlpha(
                                      (45 * _glowAnim.value).round(),
                                    ),
                                  )
                                  .toList(),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.item.gradient.first.withAlpha(
                                  (70 * _glowAnim.value).round(),
                                ),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      widget.isSelected
                          ? ShaderMask(
                              shaderCallback: (b) =>
                                  LinearGradient(colors: widget.item.gradient)
                                      .createShader(b),
                              child: Icon(
                                widget.item.activeIcon,
                                color: Colors.white,
                                size: 22,
                              ),
                            )
                          : Icon(
                              widget.item.icon,
                              color: widget.isDark
                                  ? Colors.white.withAlpha(140)
                                  : Colors.black.withAlpha(110),
                              size: 22,
                            ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: widget.isSelected
                          ? widget.item.gradient.first
                          : (widget.isDark
                                ? Colors.white.withAlpha(120)
                                : Colors.black.withAlpha(100)),
                    ),
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── More nav button (shows active overflow item or generic "More") ────────────
class _MoreNavButton extends StatefulWidget {
  final bool isSelected;
  final _NavItem? activeItem;
  final VoidCallback onTap;
  final bool isDark;

  const _MoreNavButton({
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.activeItem,
  });

  @override
  State<_MoreNavButton> createState() => _MoreNavButtonState();
}

class _MoreNavButtonState extends State<_MoreNavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.10,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.elasticOut));
    _glowAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    if (widget.isSelected) _ac.forward();
  }

  @override
  void didUpdateWidget(_MoreNavButton old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      widget.isSelected ? _ac.forward() : _ac.reverse();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient =
        widget.activeItem?.gradient ??
        [const Color(0xFF636E72), const Color(0xFFB2BEC3)];
    final activeIcon =
        widget.activeItem?.activeIcon ?? Icons.more_horiz_rounded;
    final inactiveIcon = widget.activeItem?.icon ?? Icons.more_horiz_rounded;
    final label = widget.activeItem?.label ?? 'More';

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (_, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.isSelected)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 40,
                          height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: gradient
                                  .map(
                                    (c) => c.withAlpha(
                                      (45 * _glowAnim.value).round(),
                                    ),
                                  )
                                  .toList(),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gradient.first.withAlpha(
                                  (70 * _glowAnim.value).round(),
                                ),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      widget.isSelected
                          ? ShaderMask(
                              shaderCallback: (b) =>
                                  LinearGradient(colors: gradient)
                                      .createShader(b),
                              child: Icon(
                                activeIcon,
                                color: Colors.white,
                                size: 22,
                              ),
                            )
                          : Icon(
                              inactiveIcon,
                              color: widget.isDark
                                  ? Colors.white.withAlpha(140)
                                  : Colors.black.withAlpha(110),
                              size: 22,
                            ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: widget.isSelected
                          ? gradient.first
                          : (widget.isDark
                                ? Colors.white.withAlpha(120)
                                : Colors.black.withAlpha(100)),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Docked Brain Dump Center Action Button ────────────────────────────────────
class _DockedBrainDumpButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _DockedBrainDumpButton({
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_DockedBrainDumpButton> createState() => _DockedBrainDumpButtonState();
}

class _DockedBrainDumpButtonState extends State<_DockedBrainDumpButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glow, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) => GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Tooltip(
            message: 'Brain Dump 2.0 (Instant AI Capture)',
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [kNeonViolet, kNeonCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kNeonViolet.withAlpha((100 + 80 * _glowAnim.value).round()),
                    blurRadius: 14 + 6 * _glowAnim.value,
                    spreadRadius: 0.8 + 0.8 * _glowAnim.value,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Lock overlay ─────────────────────────────────────────────────────────────

class _LockOverlay extends StatelessWidget {
  final bool authenticating;
  final VoidCallback onRetry;

  const _LockOverlay({required this.authenticating, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark0,
      body: Stack(
        children: [
          // Blurred orb backdrop
          const OrbBackground(subtle: false, child: SizedBox.expand()),
          // Frosted glass centre card
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withAlpha(35)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => kGradientMain.createShader(b),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'AutoPlanner AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unlock to continue',
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (authenticating)
                        const CircularProgressIndicator(color: kIndigo)
                      else
                        GradBtn(
                          label: 'Unlock',
                          icon: Icons.fingerprint_rounded,
                          gradient: kGradientMain,
                          onTap: onRetry,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── "More" glass bottom sheet ─────────────────────────────────────────────────
class _GlassMoreSheet extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlassMoreSheet({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1B1D24).withAlpha(240)
                  : Colors.white.withAlpha(240),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(35)
                    : Colors.white.withAlpha(220),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 90 : 35),
                  blurRadius: 32,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(70)
                          : Colors.black.withAlpha(40),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
                  child: Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => kGradientMain.createShader(b),
                        child: const Icon(
                          Icons.apps_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'More Features',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : kDark0,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withAlpha(25)
                                : Colors.black.withAlpha(18),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _overflowNavItems.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.92,
                    ),
                    itemBuilder: (ctx, i) {
                      final item = _overflowNavItems[i];
                      final isSelected = currentIndex == item.screenIndex;
                      return _MoreSheetItem(
                        item: item,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: () => onTap(item.screenIndex),
                      );
                    },
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

// ── Single item inside the More sheet ────────────────────────────────────────
class _MoreSheetItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoreSheetItem({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? item.gradient.first.withAlpha(isDark ? 55 : 35)
                : (isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.black.withAlpha(8)),
            border: Border.all(
              color: isSelected
                  ? item.gradient.first.withAlpha(140)
                  : (isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(15)),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isSelected
                        ? item.gradient
                        : item.gradient
                            .map((c) => c.withAlpha(isDark ? 160 : 130))
                            .toList(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: item.gradient.first.withAlpha(90),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : item.gradient.first)
                        : (isDark
                            ? Colors.white.withAlpha(180)
                            : Colors.black.withAlpha(180)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Connectivity banner ─────────────────────────────────────────────────────
class _ConnectivityBanner extends StatefulWidget {
  const _ConnectivityBanner();

  @override
  State<_ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<_ConnectivityBanner> {
  bool _offline = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (mounted) setState(() => _offline = result.isEmpty);
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();
    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      content: const Text(
        'You are offline — some features may be unavailable.',
        style: TextStyle(fontSize: 13),
      ),
      leading: const Icon(Icons.wifi_off_rounded, color: kCoral),
      backgroundColor: kCoral.withAlpha(30),
      actions: [TextButton(onPressed: _check, child: const Text('RETRY'))],
    );
  }
}
