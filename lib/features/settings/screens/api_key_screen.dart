import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ui_kit.dart';
import '../../../core/providers/providers.dart';
import '../controllers/settings_controller.dart';

class ApiKeyScreen extends ConsumerStatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  ConsumerState<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends ConsumerState<ApiKeyScreen> {
  late final TextEditingController _keyCtrl;
  bool _testing = false;
  bool? _testResult;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _keyCtrl = TextEditingController(text: settings.geminiApiKey);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            // ── Header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: GradientHeader(
                gradient: const LinearGradient(
                  colors: [kDark0, Color(0xFF0D1A35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        ShaderMask(
                          shaderCallback: (b) => kGradientMain.createShader(b),
                          child: const Icon(
                            Icons.key_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Gemini API Key',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connect your own AI key for personalised insights.',
                      style: TextStyle(
                        color: Colors.white.withAlpha(130),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ─────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── How AutoPlanner uses AI ──
                  _SectionTitle(
                    icon: Icons.auto_awesome_rounded,
                    title: 'How AutoPlanner uses AI',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FeatureRow(
                          icon: Icons.lightbulb_outline_rounded,
                          color: kAmber,
                          title: 'Daily Insights',
                          desc: 'A personalised morning briefing based on your tasks, goals, and habits.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        _FeatureRow(
                          icon: Icons.event_note_rounded,
                          color: kCyan,
                          title: 'Smart Task Parsing',
                          desc: 'Describe tasks in natural language and AI converts them into structured, scheduled items.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        _FeatureRow(
                          icon: Icons.psychology_rounded,
                          color: kIndigo,
                          title: 'Memory-Aware Suggestions',
                          desc: 'AI draws on your interaction history to make context-rich recommendations.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        _FeatureRow(
                          icon: Icons.schedule_rounded,
                          color: kCoral,
                          title: 'Reschedule Proposals',
                          desc: 'When tasks go overdue, AI suggests optimal new times considering your calendar and goals.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          color: isDark
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Your key is stored in the device keychain and only sent directly to Google\'s Gemini API — never to any other server.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Get your free API key ──
                  _SectionTitle(
                    icon: Icons.open_in_new_rounded,
                    title: 'Get your free API key',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StepRow(
                          step: 1,
                          text: 'Visit Google AI Studio:',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                              const ClipboardData(
                                text: 'https://aistudio.google.com/apikey',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('URL copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: kIndigo.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kIndigo.withAlpha(60)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'aistudio.google.com/apikey',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: kIndigo,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 16,
                                  color: kIndigo.withAlpha(160),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _StepRow(
                          step: 2,
                          text: 'Sign in with your Google account.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _StepRow(
                          step: 3,
                          text: 'Click "Create API Key" and copy it.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _StepRow(
                          step: 4,
                          text: 'Paste the key below and hit Save.',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Your Key ──
                  _SectionTitle(
                    icon: Icons.vpn_key_outlined,
                    title: 'Your Key',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (settings.useMockAI) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: kAmber.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kAmber.withAlpha(100)),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: kAmber,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Mock AI is ON — disable it in AI Settings to use your key.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: kAmber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        GlassField(
                          controller: _keyCtrl,
                          label: 'API Key',
                          icon: Icons.vpn_key_outlined,
                          hintText: 'AIza...',
                          keyboardType: TextInputType.text,
                        ),
                        if (_testResult != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _testResult!
                                  ? kCyan.withAlpha(30)
                                  : kCoral.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _testResult!
                                    ? kCyan.withAlpha(100)
                                    : kCoral.withAlpha(100),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _testResult!
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.error_outline_rounded,
                                  color: _testResult! ? kCyan : kCoral,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _testResult!
                                        ? 'Connection successful!'
                                        : 'Connection failed — check your key.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _testResult! ? kCyan : kCoral,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (settings.geminiApiKey.isNotEmpty) ...[
                              GhostBtn(
                                label: 'Clear',
                                onTap: _saving ? null : () => _clear(ctrl),
                              ),
                              const SizedBox(width: 8),
                            ],
                            GhostBtn(
                              label: _testing ? '…' : 'Test',
                              onTap: (_saving || _testing) ? null : _test,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GradBtn(
                                label: _saving ? '…' : 'Save',
                                icon: _saving ? null : Icons.check_rounded,
                                gradient: kGradientMain,
                                onTap: _saving ? null : () => _save(ctrl),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await ref.read(aiServiceProvider).generateDailyInsight([], []);
      if (mounted)
        setState(() {
          _testing = false;
          _testResult = true;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _testing = false;
          _testResult = false;
        });
    }
  }

  Future<void> _save(SettingsController ctrl) async {
    setState(() => _saving = true);
    try {
      await ctrl.updateGeminiApiKey(_keyCtrl.text);
      if (mounted) {
        final msg = _keyCtrl.text.trim().isEmpty
            ? 'API key cleared.'
            : 'API key saved successfully.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save key: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    }
  }

  Future<void> _clear(SettingsController ctrl) async {
    setState(() => _saving = true);
    try {
      await ctrl.updateGeminiApiKey('');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key cleared.'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear key: $e'),
            backgroundColor: kCoral,
          ),
        );
      }
    }
  }
}

// ── Private helper widgets ─────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback: (b) => kGradientMain.createShader(b),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : kDark0,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final bool isDark;
  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : kDark0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int step;
  final String text;
  final bool isDark;
  const _StepRow({
    required this.step,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: kGradientMain,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
