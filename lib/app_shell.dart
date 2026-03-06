import 'dart:ui';
import 'package:flutter/material.dart';
import 'core/theme/ui_kit.dart';
import 'features/brain_dump/brain_dump_sheet.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/planner/screens/planner_screen.dart';
import 'features/notes/screens/notes_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/memory/screens/memory_screen.dart';
import 'features/settings/screens/settings_screen.dart';

// ── Nav item descriptor ──────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final List<Color> gradient;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.gradient,
  });
}

const _navItems = [
  _NavItem(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    label: 'Home',
    gradient: [kIndigo, Color(0xFF9D97FF)],
  ),
  _NavItem(
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note_rounded,
    label: 'Plan',
    gradient: [kCyan, Color(0xFF00B894)],
  ),
  _NavItem(
    icon: Icons.note_alt_outlined,
    activeIcon: Icons.note_alt_rounded,
    label: 'Notes',
    gradient: [kCoral, Color(0xFFFF8E8E)],
  ),
  _NavItem(
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Calendar',
    gradient: [Color(0xFF9B59B6), kIndigo],
  ),
  _NavItem(
    icon: Icons.psychology_outlined,
    activeIcon: Icons.psychology_rounded,
    label: 'Memory',
    gradient: [kAmber, Color(0xFFFFB347)],
  ),
  _NavItem(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    label: 'Settings',
    gradient: [Color(0xFF636E72), Color(0xFFB2BEC3)],
  ),
];

// ── Shell ────────────────────────────────────────────────────────────────────
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            onNavigateTo: (i) => setState(() => _currentIndex = i),
          ),
          const PlannerScreen(),
          const NotesScreen(),
          const CalendarScreen(),
          const MemoryScreen(),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: _BrainDumpFab(),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterFloat,
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Floating glass nav bar ───────────────────────────────────────────────────
class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _GlassNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad + 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(18)
                  : Colors.white.withAlpha(180),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(30)
                    : Colors.white.withAlpha(200),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 30),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: kIndigo.withAlpha(isDark ? 30 : 15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                return _NavButton(
                  item: _navItems[i],
                  isSelected: currentIndex == i,
                  onTap: () => onTap(i),
                  isDark: isDark,
                );
              }),
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
      end: 1.15,
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
            child: SizedBox(
              width: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // glow pill behind icon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (widget.isSelected)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 40,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: widget.item.gradient
                                  .map(
                                    (c) => c.withAlpha(
                                      (50 * _glowAnim.value).round(),
                                    ),
                                  )
                                  .toList(),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.item.gradient.first.withAlpha(
                                  (80 * _glowAnim.value).round(),
                                ),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      widget.isSelected
                          ? ShaderMask(
                              shaderCallback: (b) => LinearGradient(
                                colors: widget.item.gradient,
                              ).createShader(b),
                              child: Icon(
                                widget.item.activeIcon,
                                color: Colors.white,
                                size: 22,
                              ),
                            )
                          : Icon(
                              widget.item.icon,
                              color: widget.isDark
                                  ? Colors.white.withAlpha(120)
                                  : Colors.black.withAlpha(90),
                              size: 22,
                            ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: widget.isSelected
                          ? widget.item.gradient.first
                          : (widget.isDark
                                ? Colors.white.withAlpha(100)
                                : Colors.black.withAlpha(80)),
                    ),
                    child: Text(widget.item.label),
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

// ── Brain Dump FAB ───────────────────────────────────────────────────────────
class _BrainDumpFab extends StatefulWidget {
  const _BrainDumpFab();

  @override
  State<_BrainDumpFab> createState() => _BrainDumpFabState();
}

class _BrainDumpFabState extends State<_BrainDumpFab>
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
      builder: (_, __) => GestureDetector(
        onTap: () => showBrainDump(context),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [kIndigo, kCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kIndigo.withAlpha((80 + 80 * _glowAnim.value).round()),
                blurRadius: 16 + 10 * _glowAnim.value,
                spreadRadius: 1 + _glowAnim.value,
              ),
            ],
          ),
          child: const Icon(
            Icons.electric_bolt_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
