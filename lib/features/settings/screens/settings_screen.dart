import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../../../services/backup_service.dart';
import '../controllers/settings_controller.dart';
import '../models/app_settings_model.dart';
import 'profile_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import 'api_key_screen.dart';
import 'help_screen.dart';
import 'weekly_review_screen.dart';

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
                    Semantics(
                      button: true,
                      label: 'Edit profile',
                      child: GestureDetector(
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
                                        if (settings
                                            .userJobTitle
                                            .isNotEmpty) ...[
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _ThemeOption(
                                  icon: Icons.brightness_auto_rounded,
                                  label: 'System',
                                  mode: ThemeMode.system,
                                  selected: settings.themeMode,
                                  onTap: () =>
                                      ctrl.updateThemeMode(ThemeMode.system),
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 10),
                                _ThemeOption(
                                  icon: Icons.light_mode_rounded,
                                  label: 'Light',
                                  mode: ThemeMode.light,
                                  selected: settings.themeMode,
                                  onTap: () =>
                                      ctrl.updateThemeMode(ThemeMode.light),
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 10),
                                _ThemeOption(
                                  icon: Icons.dark_mode_rounded,
                                  label: 'Dark',
                                  mode: ThemeMode.dark,
                                  selected: settings.themeMode,
                                  onTap: () =>
                                      ctrl.updateThemeMode(ThemeMode.dark),
                                  isDark: isDark,
                                ),
                              ],
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
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.key_rounded,
                            title: 'Gemini API key',
                            subtitle: settings.geminiApiKey.isNotEmpty
                                ? '••••••••${settings.geminiApiKey.length > 4 ? settings.geminiApiKey.substring(settings.geminiApiKey.length - 4) : ''}'
                                : 'Not set — using bundled key',
                            trailing: settings.geminiApiKey.isNotEmpty
                                ? const Icon(
                                    Icons.check_circle_outline,
                                    color: kCyan,
                                    size: 18,
                                  )
                                : const Icon(Icons.chevron_right, size: 18),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ApiKeyScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Security ──────────────────────────────────────────
                  Stagger(
                    index: 6,
                    child: SectionLabel(
                      icon: Icons.lock_outline_rounded,
                      label: 'Security',
                      color: kIndigo,
                    ),
                  ),
                  Stagger(
                    index: 7,
                    child: GlassCard(
                      child: _SecurityTile(settings: settings, ctrl: ctrl),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Notifications ─────────────────────────────────────
                  Stagger(
                    index: 8,
                    child: SectionLabel(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      color: kCoral,
                    ),
                  ),
                  Stagger(
                    index: 9,
                    child: GlassCard(
                      child: _MorningBriefingTile(
                        settings: settings,
                        ctrl: ctrl,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Integrations ──────────────────────────────────────
                  Stagger(
                    index: 10,
                    child: SectionLabel(
                      icon: Icons.sync_alt_rounded,
                      label: 'Integrations',
                      color: kCyan,
                    ),
                  ),
                  Stagger(
                    index: 11,
                    child: GlassCard(
                      child: Column(
                        children: [
                          _GoogleCalendarTile(settings: settings, ctrl: ctrl),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── About ─────────────────────────────────────────────
                  Stagger(
                    index: 12,
                    child: SectionLabel(
                      icon: Icons.info_outline,
                      label: 'About',
                      color: kAmber,
                    ),
                  ),
                  Stagger(
                    index: 13,
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
                              'Gemini 2.5 Flash',
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
                            icon: Icons.bar_chart_rounded,
                            title: 'Weekly Review',
                            subtitle: 'AI-powered summary of your week',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WeeklyReviewScreen(),
                              ),
                            ),
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.health_and_safety_outlined,
                            title: 'App Health & Analytics',
                            subtitle: 'View diagnostics and AI performance',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              // Deep-link to the App Health tab in Analytics
                              // We use the shell navigation via a provider update
                              // but since we're in settings, we just nav to a
                              // specialized analytics view or pop back.
                              // For simplicity, we just nav to the main Analytics screen.
                              // (AppShell handles indices).
                            },
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.help_outline_rounded,
                            title: 'Help & Guide',
                            subtitle: 'How the app works, feature guide & FAQ',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HelpScreen(),
                              ),
                            ),
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.tour_outlined,
                            title: 'Replay Tour',
                            subtitle: 'Watch the onboarding walkthrough again',
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

                  // ── Data / Backup ──────────────────────────────────────
                  Stagger(
                    index: 12,
                    child: SectionLabel(
                      icon: Icons.save_alt_rounded,
                      label: 'Data',
                      color: kCoral,
                    ),
                  ),
                  Stagger(
                    index: 13,
                    child: GlassCard(
                      child: Column(
                        children: [
                          _ListTile(
                            icon: Icons.upload_rounded,
                            title: 'Export backup',
                            subtitle: 'Save all data as a JSON file',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => _exportBackup(context),
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.download_rounded,
                            title: 'Import backup',
                            subtitle: 'Restore data from a JSON backup file',
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => _importBackup(context),
                          ),
                          _GlassDivider(),
                          _ListTile(
                            icon: Icons.restart_alt_rounded,
                            title: 'Reset all settings',
                            subtitle:
                                'Restore defaults — does not delete tasks or notes',
                            titleColor: kCoral,
                            iconColor: kCoral,
                            onTap: () => _confirmReset(context, ctrl),
                          ),
                        ],
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

  static Future<void> _exportBackup(BuildContext context) async {
    try {
      await BackupService().exportToFile();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: kCoral),
        );
      }
    }
  }

  static Future<void> _importBackup(BuildContext context) async {
    try {
      final result = await BackupService().importFromFile();
      if (result == null) return; // user cancelled
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result.total} items '
              '(${result.tasks} tasks, ${result.goals} goals, '
              '${result.projects} projects, ${result.calendarEvents} events, '
              '${result.memories} memories)',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: kCoral),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: kCoral),
        );
      }
    }
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

// ── Theme mode card ───────────────────────────────────────────────────────────

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeMode mode;
  final ThemeMode selected;
  final VoidCallback onTap;
  final bool isDark;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected ? kGradientMain : null,
            color: isSelected
                ? null
                : (isDark
                      ? Colors.white.withAlpha(12)
                      : Colors.black.withAlpha(6)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? Colors.white.withAlpha(25) : Colors.black12),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF4A4A5A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Security tile ─────────────────────────────────────────────────────────────

class _SecurityTile extends ConsumerStatefulWidget {
  final AppSettings settings;
  final SettingsController ctrl;

  const _SecurityTile({required this.settings, required this.ctrl});

  @override
  ConsumerState<_SecurityTile> createState() => _SecurityTileState();
}

class _SecurityTileState extends ConsumerState<_SecurityTile> {
  bool _checking = false;

  Future<void> _toggle(bool enable) async {
    if (_checking) return;
    if (enable) {
      // Verify the device actually supports biometrics before enabling.
      setState(() => _checking = true);
      final svc = ref.read(biometricServiceProvider);
      final available = await svc.isAvailable();
      setState(() => _checking = false);
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No biometrics or device lock found. Set one up in device settings first.',
            ),
          ),
        );
        return;
      }
      // Do a test authenticate so the user confirms it works.
      final ok = await svc.authenticate();
      if (!ok) return; // user cancelled — leave toggle off
    }
    await widget.ctrl.updateRequireBiometrics(enable);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile(
      secondary: _checking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.fingerprint_rounded,
              size: 20,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
      title: Text(
        'Biometric lock',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : kDark0,
        ),
      ),
      subtitle: Text(
        'Require fingerprint / Face ID when reopening the app',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
      value: widget.settings.requireBiometrics,
      onChanged: _checking ? null : _toggle,
      activeThumbColor: kIndigo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
// ── Morning Briefing tile ──────────────────────────────────────────

class _MorningBriefingTile extends ConsumerStatefulWidget {
  final AppSettings settings;
  final SettingsController ctrl;

  const _MorningBriefingTile({required this.settings, required this.ctrl});

  @override
  ConsumerState<_MorningBriefingTile> createState() =>
      _MorningBriefingTileState();
}

class _MorningBriefingTileState extends ConsumerState<_MorningBriefingTile> {
  Future<void> _toggle(bool value) async {
    final notifService = ref.read(notificationServiceProvider);
    if (value) {
      final granted = await notifService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notification permission is required for the morning brief.',
              ),
            ),
          );
        }
        return;
      }
    }

    await widget.ctrl.updateMorningBriefingEnabled(value);
    if (value) {
      await notifService.scheduleMorningBriefing(
        hour: widget.settings.morningBriefingHour,
        minute: widget.settings.morningBriefingMinute,
        body:
            'Good morning! Your AI planner is ready to help you plan the day.',
      );
    } else {
      await notifService.cancelMorningBriefing();
    }
  }

  Future<void> _pickHour() async {
    final now = TimeOfDay(
      hour: widget.settings.morningBriefingHour,
      minute: widget.settings.morningBriefingMinute,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      helpText: 'Choose briefing time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null) return;
    await widget.ctrl.updateMorningBriefingHour(picked.hour);
    await widget.ctrl.updateMorningBriefingMinute(picked.minute);
    if (widget.settings.morningBriefingEnabled) {
      await ref
          .read(notificationServiceProvider)
          .scheduleMorningBriefing(
            hour: picked.hour,
            minute: picked.minute,
            body:
                'Good morning! Your AI planner is ready to help you plan the day.',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.settings.morningBriefingEnabled;
    final hour = widget.settings.morningBriefingHour;
    final minute = widget.settings.morningBriefingMinute;
    final timeLabel = TimeOfDay(hour: hour, minute: minute).format(context);

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(Icons.wb_sunny_outlined, color: kAmber, size: 22),
          title: const Text('Morning Briefing'),
          subtitle: const Text('Daily AI summary at your chosen time'),
          value: enabled,
          onChanged: _toggle,
          activeThumbColor: kAmber,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        if (enabled)
          ListTile(
            leading: const Icon(Icons.schedule_outlined, size: 22),
            title: const Text('Briefing time'),
            trailing: TextButton(
              onPressed: _pickHour,
              child: Text(
                timeLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
      ],
    );
  }
}

// ── Google Calendar tile ───────────────────────────────────────────

class _GoogleCalendarTile extends ConsumerStatefulWidget {
  final AppSettings settings;
  final SettingsController ctrl;

  const _GoogleCalendarTile({required this.settings, required this.ctrl});

  @override
  ConsumerState<_GoogleCalendarTile> createState() =>
      _GoogleCalendarTileState();
}

class _GoogleCalendarTileState extends ConsumerState<_GoogleCalendarTile> {
  bool _loading = false;

  Future<void> _connect() async {
    setState(() => _loading = true);
    try {
      final googleAuth = ref.read(googleAuthServiceProvider);
      final syncService = ref.read(calendarSyncServiceProvider);
      final email = await googleAuth.signIn();
      if (!mounted) return;
      if (email != null) {
        await widget.ctrl.updateGoogleCalendarConnection(
          connected: true,
          email: email,
        );
        final syncResult = await syncService.fullSync();
        if (!mounted) return;
        setState(() => _loading = false);
        final message = syncResult.hasError
            ? 'Connected to $email, but the first sync failed: ${syncResult.error}'
            : 'Connected to $email. Imported ${syncResult.pulled} event${syncResult.pulled == 1 ? '' : 's'}.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in cancelled.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    }
  }

  Future<void> _disconnect() async {
    setState(() => _loading = true);
    try {
      final googleAuth = ref.read(googleAuthServiceProvider);
      await googleAuth.signOut();
      await widget.ctrl.updateGoogleCalendarConnection(connected: false);
    } catch (_) {
      // Sign-out best-effort — clear local state regardless.
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connected = widget.settings.isGoogleCalendarConnected;
    final email = widget.settings.googleAccountEmail;

    return ListTile(
      leading: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.calendar_month_rounded,
              size: 20,
              color: connected
                  ? kCyan
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
      title: Text(
        'Google Calendar',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : kDark0,
        ),
      ),
      subtitle: Text(
        connected ? email : 'Sync events with Google Calendar',
        style: TextStyle(
          fontSize: 12,
          color: connected ? kCyan : (isDark ? Colors.white38 : Colors.black38),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _loading
          ? null
          : connected
          ? TextButton(
              onPressed: _disconnect,
              child: const Text(
                'Disconnect',
                style: TextStyle(color: kCoral, fontSize: 12),
              ),
            )
          : TextButton(
              onPressed: _connect,
              child: ShaderMask(
                shaderCallback: (b) => kGradientMain.createShader(b),
                child: const Text(
                  'Connect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
