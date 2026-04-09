import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import '../../core/theme/ui_kit.dart';
import '../../core/providers/providers.dart';
import '../../core/models/goal_model.dart';
import '../../core/models/memory_entry_model.dart';
import '../../services/ai_service.dart';
import '../planner/controllers/task_controller.dart';
import '../goals/controllers/goal_controller.dart';
import '../memory/controllers/memory_controller.dart';

const _uuid = Uuid();

// ── Launch helper ─────────────────────────────────────────────────────────────
void showBrainDump(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(160),
    builder: (_) => const BrainDumpSheet(),
  );
}

// ── Main sheet ────────────────────────────────────────────────────────────────
class BrainDumpSheet extends ConsumerStatefulWidget {
  const BrainDumpSheet({super.key});

  @override
  ConsumerState<BrainDumpSheet> createState() => _BrainDumpSheetState();
}

class _BrainDumpSheetState extends ConsumerState<BrainDumpSheet>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _speech = stt.SpeechToText();

  BrainDumpResult? _result;
  bool _processing = false;
  bool _saved = false;
  bool _listening = false;
  bool _speechAvailable = false;

  late final AnimationController _pulseAC;
  late final Animation<double> _pulse;
  late final AnimationController _successAC;
  late final Animation<double> _successScale;

  // Toggle which individual items are selected for saving
  late List<bool> _taskSel;
  late List<bool> _goalSel;
  late List<bool> _memorySel;

  static const _examples = [
    'Call dentist Tuesday, finish report, idea: gamify savings',
    'Meeting with team Friday 2pm, buy coffee beans, remember to water plants',
    'Feeling scattered — need to prep slides, braindump project ideas',
  ];

  @override
  void initState() {
    super.initState();
    _pulseAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween(
      begin: 0.97,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _pulseAC, curve: Curves.easeInOut));

    _successAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successScale = CurvedAnimation(
      parent: _successAC,
      curve: Curves.elasticOut,
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) => setState(() => _listening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _ctrl.text = result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(partialResults: true),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _pulseAC.dispose();
    _successAC.dispose();
    _speech.stop();
    super.dispose();
  }

  void _initSelections(BrainDumpResult r) {
    _taskSel = List.filled(r.tasks.length, true);
    _goalSel = List.filled(r.goals.length, true);
    _memorySel = List.filled(r.memories.length, true);
  }

  Future<void> _process() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _processing = true;
      _result = null;
      _saved = false;
    });

    final ai = ref.read(aiServiceProvider);
    final result = await ai.brainDump(text);

    if (mounted) {
      setState(() {
        _result = result;
        _processing = false;
        _initSelections(result);
      });
    }
  }

  Future<void> _saveAll() async {
    final r = _result;
    if (r == null) return;

    final taskCtrl = ref.read(taskControllerProvider.notifier);
    final goalCtrl = ref.read(goalControllerProvider.notifier);
    final memoryCtrl = ref.read(memoryControllerProvider.notifier);

    // Save selected tasks
    for (var i = 0; i < r.tasks.length; i++) {
      if (_taskSel[i]) taskCtrl.addTask(r.tasks[i]);
    }

    // Save selected goals and build title→id lookup for auto-linking.
    final now = DateTime.now();
    final goalTitleToId = <String, String>{};
    for (var i = 0; i < r.goals.length; i++) {
      if (_goalSel[i]) {
        final goalId = _uuid.v4();
        goalCtrl.addGoal(
          GoalItem(
            id: goalId,
            title: r.goals[i].title,
            description: r.goals[i].description,
            createdAt: now,
            updatedAt: now,
          ),
        );
        goalTitleToId[r.goals[i].title.toLowerCase()] = goalId;
      }
    }

    // Auto-link tasks to their matching goals (by title from AI output).
    for (final entry in r.taskGoalLinks.entries) {
      final taskIndex = entry.key;
      if (taskIndex >= r.tasks.length || !_taskSel[taskIndex]) continue;
      final goalId = goalTitleToId[entry.value.toLowerCase()];
      if (goalId == null) continue;

      final task = r.tasks[taskIndex];
      taskCtrl.linkGoal(task.id, goalId);
      goalCtrl.linkTask(goalId, task.id);
    }

    // Save selected memories
    for (var i = 0; i < r.memories.length; i++) {
      if (_memorySel[i]) {
        memoryCtrl.addMemory(
          MemoryEntry(
            id: _uuid.v4(),
            content: r.memories[i],
            sourceType: 'brain_dump',
            tags: ['brain-dump'],
            createdAt: now,
            relevanceScore: 0.8,
          ),
        );
      }
    }

    setState(() => _saved = true);
    _successAC.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final screenH = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.92),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF0F0F1E)]
                : [Colors.white, const Color(0xFFF5F5FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(25) : kIndigo.withAlpha(40),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isDark),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_result == null && !_processing) ...[
                        _buildInputArea(isDark),
                        const SizedBox(height: 14),
                        _buildExampleChips(isDark),
                        const SizedBox(height: 20),
                        _buildProcessButton(isDark),
                      ] else if (_processing) ...[
                        _buildProcessingIndicator(isDark),
                      ] else if (_result != null) ...[
                        _buildResults(_result!, isDark),
                        const SizedBox(height: 20),
                        _buildSaveButton(isDark),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(15)
                : Colors.black.withAlpha(10),
          ),
        ),
      ),
      child: Column(
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(50)
                    : Colors.black.withAlpha(30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              // Glowing brain icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [kIndigo, kCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kIndigo.withAlpha(120),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Brain Dump',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Type anything — AI organizes it for you',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              if (_result != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => setState(() {
                    _result = null;
                    _saved = false;
                  }),
                  color: isDark ? Colors.white60 : Colors.black38,
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                color: isDark ? Colors.white60 : Colors.black38,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Input area ────────────────────────────────────────────────────────────

  Widget _buildInputArea(bool isDark) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(10)
                : Colors.black.withAlpha(5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _listening
                  ? kCyan.withAlpha(180)
                  : (isDark
                        ? Colors.white.withAlpha(20)
                        : kIndigo.withAlpha(50)),
              width: _listening ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            minLines: 5,
            maxLines: 10,
            autofocus: true,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: isDark ? Colors.white.withAlpha(222) : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText:
                  'Type or paste anything on your mind...\n\nTasks, ideas, reminders, meeting notes — all at once.',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26,
                fontSize: 14,
                height: 1.55,
              ),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
        if (_speechAvailable) ...[
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: _listening ? 'Stop listening' : 'Speak',
            child: GestureDetector(
              onTap: _toggleListen,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: _listening ? kGradientTeal : null,
                  color: _listening
                      ? null
                      : (isDark
                            ? Colors.white.withAlpha(15)
                            : Colors.black.withAlpha(8)),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _listening
                        ? Colors.transparent
                        : (isDark
                              ? Colors.white.withAlpha(25)
                              : kCyan.withAlpha(80)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _listening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 18,
                      color: _listening
                          ? Colors.white
                          : (isDark ? kCyan : kIndigo),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _listening ? 'Tap to stop' : 'Speak',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _listening
                            ? Colors.white
                            : (isDark ? kCyan : kIndigo),
                      ),
                    ),
                    if (_listening) ...[
                      const SizedBox(width: 8),
                      _VoicePulse(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Example chips ─────────────────────────────────────────────────────────

  Widget _buildExampleChips(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Try an example',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _examples
              .map(
                (e) => GestureDetector(
                  onTap: () {
                    _ctrl.text = e;
                    _ctrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: e.length),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kIndigo.withAlpha(isDark ? 40 : 20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: kIndigo.withAlpha(isDark ? 80 : 60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 12,
                          color: kIndigo.withAlpha(180),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          e.length > 38 ? '${e.substring(0, 38)}…' : e,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? kIndigo.withAlpha(220) : kIndigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ── Process button ────────────────────────────────────────────────────────

  Widget _buildProcessButton(bool isDark) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Transform.scale(scale: _pulse.value, child: child),
      child: Semantics(
        button: true,
        label: 'Process with AI',
        child: GestureDetector(
          onTap: _process,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kIndigo, kCyan],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: kIndigo.withAlpha(120),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Process with AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

  // ── Processing indicator ──────────────────────────────────────────────────

  Widget _buildProcessingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          _SpinningOrb(isDark: isDark),
          const SizedBox(height: 20),
          Text(
            'Thinking…',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Extracting tasks, goals & memories',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults(BrainDumpResult r, bool isDark) {
    if (r.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing actionable found',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adding more detail',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _ResultSectionLabel(
          icon: Icons.task_alt_rounded,
          label: 'Tasks',
          count: r.tasks.length,
          color: kCyan,
          isDark: isDark,
        ),
        if (r.tasks.isEmpty)
          _EmptyCategory(label: 'No tasks found', isDark: isDark)
        else
          ...List.generate(
            r.tasks.length,
            (i) => _CheckableResultTile(
              selected: _taskSel[i],
              onChanged: (v) => setState(() => _taskSel[i] = v),
              title: r.tasks[i].title,
              subtitle:
                  '${_fmt(r.tasks[i].startTime)}  •  ${r.tasks[i].priorityLabel}',
              icon: Icons.check_circle_outline_rounded,
              color: kCyan,
              isDark: isDark,
              tags: r.tasks[i].tags,
            ),
          ),
        const SizedBox(height: 16),
        _ResultSectionLabel(
          icon: Icons.flag_rounded,
          label: 'Goals',
          count: r.goals.length,
          color: kCoral,
          isDark: isDark,
        ),
        if (r.goals.isEmpty)
          _EmptyCategory(label: 'No goals found', isDark: isDark)
        else
          ...List.generate(
            r.goals.length,
            (i) => _CheckableResultTile(
              selected: _goalSel[i],
              onChanged: (v) => setState(() => _goalSel[i] = v),
              title: r.goals[i].title,
              subtitle: r.goals[i].description.isEmpty
                  ? 'Saved as a new goal'
                  : (r.goals[i].description.length > 60
                      ? '${r.goals[i].description.substring(0, 60)}…'
                      : r.goals[i].description),
              icon: Icons.flag_outlined,
              color: kCoral,
              isDark: isDark,
              tags: const [],
            ),
          ),
        const SizedBox(height: 16),
        _ResultSectionLabel(
          icon: Icons.psychology_rounded,
          label: 'Memories',
          count: r.memories.length,
          color: kAmber,
          isDark: isDark,
        ),
        if (r.memories.isEmpty)
          _EmptyCategory(label: 'No memories found', isDark: isDark)
        else
          ...List.generate(
            r.memories.length,
            (i) => _CheckableResultTile(
              selected: _memorySel[i],
              onChanged: (v) => setState(() => _memorySel[i] = v),
              title: r.memories[i],
              subtitle: 'Saved to long-term memory',
              icon: Icons.lightbulb_outline_rounded,
              color: kAmber,
              isDark: isDark,
              tags: const [],
            ),
          ),
      ],
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────

  Widget _buildSaveButton(bool isDark) {
    final selCount =
        (_taskSel.where((b) => b).length) +
        (_goalSel.where((b) => b).length) +
        (_memorySel.where((b) => b).length);

    if (_saved) {
      return ScaleTransition(
        scale: _successScale,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kCyan, kIndigo],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kCyan.withAlpha(100),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text(
                'Saved!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: selCount > 0
          ? 'Save $selCount item${selCount == 1 ? '' : 's'}'
          : 'Select items to save',
      child: GestureDetector(
        onTap: selCount > 0 ? _saveAll : null,
        child: AnimatedOpacity(
          opacity: selCount > 0 ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: selCount > 0
                  ? const LinearGradient(
                      colors: [kIndigo, kCyan],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: selCount == 0
                  ? (isDark ? Colors.white24 : Colors.black12)
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selCount > 0
                  ? [
                      BoxShadow(
                        color: kIndigo.withAlpha(100),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.save_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  selCount > 0
                      ? 'Save $selCount item${selCount == 1 ? '' : 's'}'
                      : 'Select items to save',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _ResultSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool isDark;
  const _ResultSectionLabel({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 50 : 30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 60 : 40),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  final String label;
  final bool isDark;
  const _EmptyCategory({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: isDark ? Colors.white30 : Colors.black.withAlpha(77),
        ),
      ),
    );
  }
}

class _CheckableResultTile extends StatelessWidget {
  final bool selected;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;
  final List<String> tags;

  const _CheckableResultTile({
    required this.selected,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withAlpha(isDark ? 35 : 18)
              : (isDark
                    ? Colors.white.withAlpha(8)
                    : Colors.black.withAlpha(5)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withAlpha(isDark ? 90 : 70)
                : (isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.black.withAlpha(10)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1, right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? color
                      : (isDark ? Colors.white38 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withAlpha(222)
                          : Colors.black87,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withAlpha(115)
                            : Colors.black45,
                      ),
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: tags
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withAlpha(isDark ? 50 : 30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Spinning orb loading animation ────────────────────────────────────────────

class _SpinningOrb extends StatefulWidget {
  final bool isDark;
  const _SpinningOrb({required this.isDark});

  @override
  State<_SpinningOrb> createState() => _SpinningOrbState();
}

class _SpinningOrbState extends State<_SpinningOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) => Transform.rotate(
        angle: _ac.value * 2 * 3.14159,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(colors: [kIndigo, kCyan, kIndigo]),
            boxShadow: [
              BoxShadow(
                color: kIndigo.withAlpha(120),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isDark ? const Color(0xFF1A1A2E) : Colors.white,
            ),
            child: const Icon(
              Icons.electric_bolt_rounded,
              color: kIndigo,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pulsing dot for voice recording indicator ─────────────────────────────────
class _VoicePulse extends StatefulWidget {
  @override
  State<_VoicePulse> createState() => _VoicePulseState();
}

class _VoicePulseState extends State<_VoicePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
