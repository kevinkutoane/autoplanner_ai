import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/ui_kit.dart';
import '../../onboarding/screens/onboarding_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  colors: [kDark0, Color(0xFF0D1A35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Back',
                          child: GestureDetector(
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
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Help & Guide',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Everything you need to know about AutoPlanner AI.',
                      style: TextStyle(
                        color: Colors.white.withAlpha(130),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── What is AutoPlanner AI? ──────────────────────────
                  _SectionLabel(
                    icon: Icons.auto_awesome_rounded,
                    label: 'What is AutoPlanner AI?',
                    color: kIndigo,
                  ),
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AutoPlanner AI is a personal productivity app that uses '
                            'artificial intelligence to turn your messy to-do list into a '
                            'structured, conflict-free daily schedule — automatically.',
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.6,
                              color: isDark
                                  ? Colors.white.withAlpha(222)
                                  : kDark0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Instead of manually deciding what to do and when, you just '
                            'describe your tasks in plain English. The app parses them, '
                            'assigns priorities and durations, and packs them into your work '
                            'window — leaving you with a ready-to-follow schedule.',
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.6,
                              color: isDark
                                  ? Colors.white.withAlpha(222)
                                  : kDark0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _HighlightBox(
                            icon: Icons.lightbulb_outline_rounded,
                            color: kAmber,
                            text:
                                'Think of it as a smart planner that knows your schedule, learns '
                                'your habits over time, and automatically reschedules anything you miss.',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── How It Works ─────────────────────────────────────
                  _SectionLabel(
                    icon: Icons.route_rounded,
                    label: 'How It Works',
                    color: kCyan,
                  ),
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _FlowStep(
                            step: '1',
                            icon: Icons.record_voice_over_rounded,
                            color: kIndigo,
                            title: 'Brain Dump',
                            body:
                                'Type or speak anything on your mind — tasks, ideas, reminders. '
                                'No formatting needed. The AI parses it into structured tasks and notes.',
                            isDark: isDark,
                          ),
                          _FlowArrow(),
                          _FlowStep(
                            step: '2',
                            icon: Icons.psychology_rounded,
                            color: kCyan,
                            title: 'AI Enrichment',
                            body:
                                'Tap "Plan My Day" and the AI scores each task by priority, '
                                'estimates realistic durations, and re-orders your list before '
                                'the scheduler runs.',
                            isDark: isDark,
                          ),
                          _FlowArrow(),
                          _FlowStep(
                            step: '3',
                            icon: Icons.calendar_today_rounded,
                            color: kCoral,
                            title: 'Automatic Scheduling',
                            body:
                                'A deterministic scheduler packs your tasks into free slots '
                                'within your work window, avoiding conflicts with calendar events '
                                'and leaving 10-minute buffers between tasks.',
                            isDark: isDark,
                          ),
                          _FlowArrow(),
                          _FlowStep(
                            step: '4',
                            icon: Icons.auto_fix_high_rounded,
                            color: kAmber,
                            title: 'Proactive Rescheduling',
                            body:
                                'If you miss a task, the app detects it when you open the planner '
                                'and suggests the next available slot — powered by AI that considers '
                                'your habits and current calendar.',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── AI & the API Key ─────────────────────────────────
                  _SectionLabel(
                    icon: Icons.key_rounded,
                    label: 'AI Features & the API Key',
                    color: kCoral,
                  ),
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HighlightBox(
                            icon: Icons.info_outline_rounded,
                            color: kCyan,
                            text:
                                'AutoPlanner AI uses Google\'s Gemini 2.5 Flash model for all AI '
                                'features. Gemini runs on Google\'s servers, not on your device — '
                                'which means the app needs a key to call the API on your behalf.',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 18),
                          _FaqItem(
                            q: 'Why do I need an API key?',
                            a:
                                'Google Gemini is a cloud AI service. To use it, you need an account '
                                'with Google AI Studio and an API key — similar to how apps use a '
                                'Google Maps key. The key identifies you and tracks your usage against '
                                'your quota.',
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _FaqItem(
                            q: 'Is it free?',
                            a:
                                'Yes — Google AI Studio offers a generous free tier. Gemini 2.5 Flash '
                                'gives you approximately 1,000 requests/day at no cost. For typical '
                                'daily planning use, you will very rarely hit this limit. The app '
                                'also shows your token usage in the Dashboard so you always know '
                                'where you stand.',
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _FaqItem(
                            q: 'Where do I get a key?',
                            a:
                                '1. Open aistudio.google.com in a browser\n'
                                '2. Sign in with your Google account\n'
                                '3. Click "Get API key" → "Create API key"\n'
                                '4. Copy the key (starts with "AIza…")\n'
                                '5. Paste it in Settings → AI Settings → Gemini API key',
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _FaqItem(
                            q: 'Is my key safe?',
                            a:
                                'Your key is stored in your device\'s secure keychain '
                                '(Android Keystore / iOS Secure Enclave). It is never '
                                'written to a file, never sent to our servers, and never '
                                'bundled into the app. Only API calls go to Google — and '
                                'only when you trigger an AI action.',
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _FaqItem(
                            q: 'Can I use the app without a key?',
                            a:
                                'Yes. Go to Settings → AI Settings and enable "Use mock AI". '
                                'The app will respond with canned AI outputs so you can explore '
                                'every feature without making any API calls. Great for trying '
                                'the app before committing your key.',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                const ClipboardData(
                                  text: 'https://aistudio.google.com',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'aistudio.google.com copied — open in your browser',
                                  ),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: kGradientMain,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Copy aistudio.google.com',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
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

                  const SizedBox(height: 16),

                  // ── Feature Guide ─────────────────────────────────────
                  _SectionLabel(
                    icon: Icons.menu_book_rounded,
                    label: 'Feature Guide',
                    color: kIndigo,
                  ),
                  GlassCard(
                    child: Column(
                      children: [
                        _FeatureTile(
                          icon: Icons.record_voice_over_rounded,
                          color: kIndigo,
                          title: 'Brain Dump',
                          summary:
                              'Freeform text or voice → AI-structured tasks, goals & memories',
                          detail:
                              'Open Brain Dump from the floating "+" button on any screen. '
                              'Type or dictate anything — a list, a paragraph, random thoughts. '
                              'The AI streams the response in real time, classifying each item '
                              'as a task (with time + priority), a goal, or a long-term memory. '
                              'Tasks are auto-linked to their matching goals.',
                          isDark: isDark,
                        ),
                        _FeatureDivider(isDark: isDark),
                        _FeatureTile(
                          icon: Icons.today_rounded,
                          color: kCyan,
                          title: 'Plan My Day',
                          summary:
                              'One tap to AI-enrich and schedule your entire day',
                          detail:
                              'Tap the "Plan My Day" button at the top of the Planner. '
                              'The AI re-scores every pending task\'s priority and estimates '
                              'realistic durations based on the task title and your past '
                              'patterns. Then the scheduling engine arranges them into '
                              'your work window with no overlaps. Completed tasks are never '
                              'moved.',
                          isDark: isDark,
                        ),
                        _FeatureDivider(isDark: isDark),
                        _FeatureTile(
                          icon: Icons.auto_fix_high_rounded,
                          color: kCoral,
                          title: 'Proactive Rescheduling',
                          summary:
                              'Missed a task? The app finds a new slot automatically',
                          detail:
                              'Every time you open the planner (or bring the app to the '
                              'foreground), it checks for overdue uncompleted tasks. If it '
                              'finds one, it computes free slots in your remaining work window, '
                              'asks Gemini to pick the best one, and shows you an amber banner. '
                              'Tap Accept to move the task, or Dismiss to skip it for this session.',
                          isDark: isDark,
                        ),
                        _FeatureDivider(isDark: isDark),
                        _FeatureTile(
                          icon: Icons.flag_rounded,
                          color: kCoral,
                          title: 'Goals & Projects',
                          summary:
                              'Set goals, link tasks, and track progress',
                          detail:
                              'Create goals in the Goals tab — each goal can have a description, '
                              'deadline, and emoji. Link tasks to goals from the Planner to track '
                              'progress with completion rings. Brain Dump auto-extracts goals from '
                              'your thoughts and links related tasks automatically. Projects let '
                              'you group work under a parent goal.',
                          isDark: isDark,
                        ),
                        _FeatureDivider(isDark: isDark),
                        _FeatureTile(
                          icon: Icons.psychology_alt_rounded,
                          color: kIndigo,
                          title: 'Memory',
                          summary:
                              'The AI remembers things about you across sessions',
                          detail:
                              'Every time you brain-dump, plan your day, or summarise a note, '
                              'the AI extracts notable facts, patterns, and preferences and '
                              'stores them as memory entries. On future AI calls, the most '
                              'relevant memories are included in the prompt as context — so '
                              'the AI knows your work style, recurring commitments, and habits.',
                          isDark: isDark,
                        ),
                        _FeatureDivider(isDark: isDark),
                        _FeatureTile(
                          icon: Icons.calendar_month_rounded,
                          color: kCyan,
                          title: 'Calendar Sync',
                          summary:
                              'Two-way sync with Google Calendar',
                          detail:
                              'Connect your Google account in Settings → Integrations. '
                              'The app syncs your calendar events and uses them as blocks '
                              'when scheduling tasks — so you\'re never double-booked. '
                              'Changes you make in the app push back to Google Calendar.',
                          isDark: isDark,
                        ),
                        _FeatureDivider(isDark: isDark),
                        _FeatureTile(
                          icon: Icons.insights_rounded,
                          color: kCoral,
                          title: 'Analytics',
                          summary:
                              'Charts, trends, and a weekly AI productivity review',
                          detail:
                              'The Insights tab shows an overview of completed vs. planned '
                              'tasks, tag breakdowns, and completion trends over time. '
                              'Tap "Weekly Review" to get a Gemini-generated markdown report '
                              'summarising your week — what you accomplished, what patterns '
                              'emerged, and suggestions for improvement.',
                          isDark: isDark,
                        ),
                        _FeatureDivider(isDark: isDark),
                        _FeatureTile(
                          icon: Icons.widgets_rounded,
                          color: kAmber,
                          title: 'Home Screen Widget',
                          summary:
                              'Your top 3 tasks + stats without opening the app',
                          detail:
                              'Add the AutoPlanner widget to your Android or iOS home screen. '
                              'It shows your next 3 upcoming tasks and a quick completion '
                              'count for today. The widget updates automatically after each '
                              'Plan My Day or whenever you complete a task.',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── FAQ ───────────────────────────────────────────────
                  _SectionLabel(
                    icon: Icons.quiz_rounded,
                    label: 'FAQ',
                    color: kAmber,
                  ),
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _FaqItem(
                            q: 'Is my data stored in the cloud?',
                            a:
                                'No. All tasks, notes, calendar events, and memories are stored '
                                'locally on your device in an AES-256 encrypted Hive database. '
                                'The only data that leaves your device are the prompts you send '
                                'to the Gemini API (with your API key). Nothing is stored on our servers.',
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _FaqItem(
                            q: 'What does "token" mean and why is there a daily limit?',
                            a:
                                'Tokens are the unit Gemini uses to measure text — roughly 1 token '
                                'per word. Every AI call sends and receives tokens. Google\'s free tier '
                                'gives you a daily quota. The in-app daily token limit (Settings → AI Settings) '
                                'is a safeguard you control — it pauses AI calls once you hit the cap '
                                'so you don\'t accidentally exhaust your quota in one session.',
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _FaqItem(
                            q: 'Why does the scheduler sometimes not fit all my tasks?',
                            a:
                                'The scheduler only places tasks within your configured work window '
                                '(Settings → Work Preferences). If your tasks add up to more hours '
                                'than your work day allows, the overflow tasks are left unscheduled. '
                                'Try reducing task durations or extending your work hours.',
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _FaqItem(
                            q: 'How do recurring tasks work?',
                            a:
                                'When you create a task with a recurrence rule (daily, weekly, monthly), '
                                'the app automatically creates the next occurrence once the current one '
                                'is completed or its date passes. Occurrences appear in the planner on '
                                'their scheduled day.',
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _FaqItem(
                            q: 'Will the app work offline?',
                            a:
                                'Yes — all task management, notes, calendar viewing, and the scheduler '
                                'work fully offline. Only AI features (Brain Dump, Plan My Day, '
                                'summaries, insights, reschedule suggestions) require an internet '
                                'connection to reach the Gemini API. Enable Mock AI in settings '
                                'to use AI-shaped responses offline.',
                            isDark: isDark,
                          ),
                          _Divider(isDark: isDark),
                          _FaqItem(
                            q: 'How do I back up my data?',
                            a:
                                'Go to Settings → Data → Export backup. This saves a JSON snapshot '
                                'of all your tasks, notes, events, and memories to your device storage. '
                                'You can restore it later with Import backup. Keep a copy in cloud '
                                'storage (Drive, iCloud) for safekeeping.',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Replay tour ───────────────────────────────────────
                  GlassCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                      leading: ShaderMask(
                        shaderCallback: (b) => kGradientMain.createShader(b),
                        child: const Icon(
                          Icons.play_circle_outline_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      title: Text(
                        'Replay App Tour',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : kDark0,
                        ),
                      ),
                      subtitle: Text(
                        'Watch the animated onboarding walkthrough again',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const OnboardingScreen(isReplay: true),
                          ),
                        );
                      },
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
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool isDark;
  const _HighlightBox({
    required this.icon,
    required this.color,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 28 : 18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: isDark ? Colors.white.withAlpha(222) : kDark0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String step;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool isDark;
  const _FlowStep({
    required this.step,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(80)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Step $step',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : kDark0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlowArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 0, 8),
      child: Icon(
        Icons.arrow_downward_rounded,
        size: 16,
        color: Colors.white.withAlpha(40),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String q;
  final String a;
  final bool isDark;
  const _FaqItem({required this.q, required this.a, required this.isDark});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: kCyan,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.q,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white : kDark0,
                    ),
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  widget.a,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(color: isDark ? Colors.white12 : Colors.black12, height: 16);
  }
}

class _FeatureTile extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String summary;
  final String detail;
  final bool isDark;
  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.summary,
    required this.detail,
    required this.isDark,
  });

  @override
  State<_FeatureTile> createState() => _FeatureTileState();
}

class _FeatureTileState extends State<_FeatureTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? Colors.white : kDark0,
                        ),
                      ),
                      Text(
                        widget.summary,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withAlpha(widget.isDark ? 20 : 12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.detail,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureDivider extends StatelessWidget {
  final bool isDark;
  const _FeatureDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
      height: 1,
      indent: 16,
      endIndent: 16,
    );
  }
}
