import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../controllers/settings_controller.dart';
import '../models/app_settings_model.dart';
import 'profile_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrbBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: GradientHeader(
                gradient: const LinearGradient(
                  colors: [kDark0, Color(0xFF14122A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // profile banner
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(18),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withAlpha(35),
                              ),
                            ),
                            child: Row(
                              children: [
                                AvatarCircle(settings: settings, size: 56),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        settings.displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (settings.userEmail.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          settings.userEmail,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      if (settings.userJobTitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        ShaderMask(
                                          shaderCallback: (b) =>
                                              kGradientTeal.createShader(b),
                                          child: Text(
                                            settings.userJobTitle,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white38,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Appearance ────────────────────────────────────────
                  Stagger(
                    index: 0,
                    child: SectionLabel(
                      icon: Icons.palette_rounded,
                      label: 'Appearance',
                      color: kIndigo,
                    ),
                  ),
                  Stagger(
                    index: 1,
                    child: GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDark ? Colors.white : kDark0,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('System'),
                                  icon: Icon(Icons.brightness_auto_outlined),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                  icon: Icon(Icons.light_mode_outlined),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                  icon: Icon(Icons.dark_mode_outlined),
                                ),
                              ],
                              selected: {settings.themeMode},
                              onSelectionChanged: (v) {
                                if (v.isNotEmpty) ctrl.updateThemeMode(v.first);
                              },
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Work Preferences ──────────────────────────────────
                  Stagger(
                    index: 2,
                    child: SectionLabel(
                      icon: Icons.schedule_rounded,
                      label: 'Work Preferences',
                      color: kCyan,
                    ),
                  ),
                  Stagger(
                    index: 3,
                    child: GlassCard(
                      child: Column(
                        children: [
                          _SliderTile(
                            icon: Icons.timer_outlined,
                            title: 'Work hours / day',
                            subtitle: '${settings.workHoursPerDay} hours',
                            value: settings.workHoursPerDay.toDouble(),
                            min: 1,
                            max: 16,
                            divisions: 15,
                            label: '${settings.workHoursPerDay}h',
                            onChanged: (v) =>
                                ctrl.updateWorkHoursPerDay(v.round()),
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.alarm_outlined,
                            title: 'Work starts at',
                            subtitle: settings.workStartLabel,
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () =>
                                _pickStartTime(context, settings, ctrl),
                          ),
                          _GlassDivider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.date_range_outlined,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Work days',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark ? Colors.white : kDark0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: List.generate(7, (i) {
                                          const labels = [
                                            'Mon',
                                            'Tue',
                                            'Wed',
                                            'Thu',
                                            'Fri',
                                            'Sat',
                                            'Sun',
                                          ];
                                          final active = settings.workDays[i];
                                          return GestureDetector(
                                            onTap: () {
                                              final updated = List<bool>.from(
                                                settings.workDays,
                                              );
                                              updated[i] = !active;
                                              ctrl.updateWorkDays(updated);
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: active
                                                    ? kGradientMain
                                                    : null,
                                                color: active
                                                    ? null
                                                    : (isDark
                                                          ? Colors.white
                                                                .withAlpha(15)
                                                          : Colors.black
                                                                .withAlpha(7)),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: active
                                                      ? Colors.transparent
                                                      : (isDark
                                                            ? Colors.white24
                                                            : Colors.black12),
                                                ),
                                              ),
                                              child: Text(
                                                labels[i],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: active
                                                      ? Colors.white
                                                      : (isDark
                                                            ? Colors.white70
                                                            : const Color(
                                                                0xFF4A4A5A,
                                                              )),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── AI Settings ───────────────────────────────────────
                  Stagger(
                    index: 4,
                    child: SectionLabel(
                      icon: Icons.psychology_rounded,
                      label: 'AI Settings',
                      color: kCoral,
                    ),
                  ),
                  Stagger(
                    index: 5,
                    child: GlassCard(
                      child: Column(
                        children: [
                          _SwitchTile(
                            icon: Icons.science_outlined,
                            title: 'Use mock AI',
                            subtitle: 'Offline mode — no API calls made',
                            value: settings.useMockAI,
                            onChanged: (v) => ctrl.updateUseMockAI(v),
                          ),
                          _GlassDivider(),
                          _SwitchTile(
                            icon: Icons.receipt_long_outlined,
                            title: 'Log AI calls',
                            subtitle: 'Track prompts & responses in memory',
                            value: settings.enableAILogging,
                            onChanged: (v) => ctrl.updateEnableAILogging(v),
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.token_outlined,
                            title: 'Daily token limit',
                            subtitle:
                                '${_formatTokens(settings.maxTokensPerDay)} tokens / day',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () =>
                                _showTokenPicker(context, settings, ctrl),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── About ─────────────────────────────────────────────
                  Stagger(
                    index: 6,
                    child: SectionLabel(
                      icon: Icons.info_outline,
                      label: 'About',
                      color: kAmber,
                    ),
                  ),
                  Stagger(
                    index: 7,
                    child: GlassCard(
                      child: Column(
                        children: [
                          _ListTile(
                            icon: Icons.info_outlined,
                            title: 'Version',
                            trailing: const Text(
                              '1.0.0+1',
                              style: TextStyle(
                                color: kCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.auto_awesome_outlined,
                            title: 'AI Engine',
                            trailing: const Text(
                              'Gemini 2.0 Flash',
                              style: TextStyle(
                                color: kCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.code_outlined,
                            title: 'Built with',
                            trailing: const Text(
                              'Flutter + Riverpod',
                              style: TextStyle(
                                color: kCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.help_outline,
                            title: 'Help & Tour',
                            subtitle: 'Replay the onboarding walkthrough',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const OnboardingScreen(isReplay: true),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Danger zone ───────────────────────────────────────
                  Stagger(
                    index: 8,
                    child: SectionLabel(
                      icon: Icons.warning_amber_rounded,
                      label: 'Data',
                      color: kCoral,
                    ),
                  ),
                  Stagger(
                    index: 9,
                    child: GlassCard(
                      child: _ListTile(
                        icon: Icons.restart_alt_rounded,
                        title: 'Reset all settings',
                        subtitle:
                            'Restore defaults — does not delete tasks or notes',
                        titleColor: kCoral,
                        iconColor: kCoral,
                        onTap: () => _confirmReset(context, ctrl),
                      ),
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

  static String _formatTokens(int t) {
    if (t >= 1000000) return '${(t / 1000000).toStringAsFixed(1)}M';
    if (t >= 1000) return '${(t / 1000).round()}K';
    return '$t';
  }

  static const _tokenOptions = [10000, 50000, 100000, 250000, 500000];

  static Future<void> _pickStartTime(
    BuildContext context,
    AppSettings settings,
    SettingsController ctrl,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.workStartHour, minute: 0),
      helpText: 'Work start time',
    );
    if (picked != null) ctrl.updateWorkStartHour(picked.hour);
  }

  static void _showTokenPicker(
    BuildContext context,
    AppSettings settings,
    SettingsController ctrl,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => kGradientMain.createShader(b),
                        child: const Icon(
                          Icons.token_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Daily Token Limit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: isDark ? Colors.white12 : Colors.black12),
                RadioGroup<int>(
                  groupValue: settings.maxTokensPerDay,
                  onChanged: (v) {
                    if (v != null) {
                      ctrl.updateMaxTokensPerDay(v);
                      Navigator.pop(ctx);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _tokenOptions
                        .map(
                          (t) => RadioListTile<int>(
                            title: Text('${_formatTokens(t)} tokens'),
                            subtitle: t == 100000
                                ? const Text('Recommended')
                                : null,
                            value: t,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _confirmReset(BuildContext context, SettingsController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C1C3A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => kGradientWarm.createShader(b),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Reset settings?'),
            ],
          ),
          content: const Text(
            'Your profile info and preferences will be cleared. '
            'Tasks, notes, and calendar events are unaffected.',
          ),
          actions: [
            GhostBtn(label: 'Cancel', onTap: () => Navigator.pop(ctx)),
            const SizedBox(width: 8),
            GradBtn(
              label: 'Reset',
              icon: Icons.restart_alt_rounded,
              gradient: kGradientWarm,
              onTap: () async {
                await ctrl.resetToDefaults();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }
}

// ── Reusable tile widgets ─────────────────────────────────────────────────────

class _ListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? iconColor;

  const _ListTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: iconColor ?? (isDark ? Colors.white60 : Colors.black54),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: titleColor ?? (isDark ? Colors.white : kDark0),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile(
      secondary: Icon(
        icon,
        size: 20,
        color: isDark ? Colors.white60 : Colors.black54,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : kDark0,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
      activeThumbColor: kIndigo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: isDark ? Colors.white60 : Colors.black54,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : kDark0,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
      trailing: SizedBox(
        width: 140,
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          activeColor: kIndigo,
          onChanged: onChanged,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white12
        : Colors.black.withAlpha(12),
  );
}
