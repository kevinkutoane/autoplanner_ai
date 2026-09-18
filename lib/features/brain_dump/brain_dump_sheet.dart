import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

import '../../core/theme/ui_kit.dart';
import '../../core/providers/providers.dart';
import '../../core/models/task_model.dart';
import '../../core/models/goal_model.dart';
import '../../core/models/note_model.dart';
import '../../core/models/memory_entry_model.dart';
import '../../core/ai/ai_guard.dart';
import '../../core/utils/date_utils.dart';
import '../../services/ai_service.dart';
import '../../services/gamification_service.dart';
import '../planner/controllers/task_controller.dart';
import '../goals/controllers/goal_controller.dart';
import '../memory/controllers/memory_controller.dart';
import '../calendar/controllers/calendar_controller.dart';
import 'widgets/audio_waveform_visualizer.dart';
import 'widgets/brain_dump_task_tile.dart';
import 'widgets/brain_dump_note_tile.dart';

const _uuid = Uuid();

// ── Launch helper ─────────────────────────────────────────────────────────────
void showBrainDump(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(175),
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

  bool _processing = false;
  int _processingStep = 0;
  bool _saved = false;
  bool _listening = false;
  bool _speechAvailable = false;
  double _soundLevel = 0.0;

  late final AnimationController _pulseAC;
  late final Animation<double> _pulse;
  late final AnimationController _successAC;
  late final Animation<double> _successScale;

  // Extracted entities
  List<TaskItem> _tasks = [];
  List<BrainGoal> _goals = [];
  List<NoteItem> _notes = [];
  List<String> _memories = [];
  Map<int, String> _taskGoalLinks = {};

  // Selection states
  List<bool> _taskSel = [];
  List<bool> _goalSel = [];
  List<bool> _noteSel = [];
  List<bool> _memorySel = [];

  // Smart schedule metadata
  final Map<int, String> _scheduleMessages = {};
  final Map<int, bool> _scheduleClashes = {};

  String _filterTab = 'all'; // all, tasks, notes, goals, memories

  static const _examples = [
    'Call dentist Tuesday, finish Q3 slides, idea: gamify savings streaks',
    'Team sync Friday 2pm, buy coffee beans, write blog draft on focus states',
    'Feeling scattered — prep tax invoices, meditate 10m, review user testing',
    'Project brainstorm: automated morning briefing and circadian energy cards',
  ];

  @override
  void initState() {
    super.initState();
    _pulseAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _pulseAC, curve: Curves.easeInOut));

    _successAC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _successScale = CurvedAnimation(
      parent: _successAC,
      curve: Curves.elasticOut,
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    // 1. Explicitly request microphone permission
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      _showPermissionDeniedDialog(permanently: true);
      return;
    }
    if (!status.isGranted) {
      if (!mounted) return;
      _showPermissionDeniedDialog(permanently: false);
      return;
    }

    // 2. Initialize speech-to-text
    if (!_speechAvailable) {
      try {
        final ok = await _speech.initialize(
          onError: (_) {
            if (mounted) setState(() => _listening = false);
          },
          onStatus: (st) {
            if (st == 'done' || st == 'notListening') {
              if (mounted) setState(() => _listening = false);
            }
          },
        );
        if (!ok) {
          if (!mounted) return;
          _showSpeechUnavailableDialog();
          return;
        }
        if (mounted) setState(() => _speechAvailable = true);
      } catch (_) {
        if (!mounted) return;
        _showSpeechUnavailableDialog();
        return;
      }
    }

    // 3. Start listening
    try {
      setState(() => _listening = true);
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _ctrl.text = result.recognizedWords;
              _ctrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _ctrl.text.length),
              );
            });
          }
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() => _soundLevel = level);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenFor: const Duration(seconds: 90),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
        _showSpeechUnavailableDialog();
      }
    }
  }

  void _showPermissionDeniedDialog({required bool permanently}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic_off_rounded, color: kCoral),
            SizedBox(width: 8),
            Text('Microphone Required'),
          ],
        ),
        content: Text(
          permanently
              ? 'Microphone permission was permanently denied. Please enable microphone access in your system settings to dictate voice thoughts.'
              : 'AutoPlanner needs microphone access to transcribe your spoken thoughts into tasks and notes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (permanently)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            )
          else
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _toggleListen();
              },
              child: const Text('Grant Access'),
            ),
        ],
      ),
    );
  }

  void _showSpeechUnavailableDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.record_voice_over_rounded, color: kNeonCyan),
            SizedBox(width: 8),
            Text('Voice Dictation'),
          ],
        ),
        content: const Text(
          'Speech recognition service is not available on this device or emulator.\n\nWould you like to simulate a spoken voice note to test the full Brain Dump workflow?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Simulate Spoken Note'),
            onPressed: () {
              Navigator.pop(ctx);
              _simulateVoiceDictation();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _simulateVoiceDictation() async {
    const sampleText =
        'Sync with team tomorrow at 10am, finish quarterly budget review by 3pm, buy coffee beans, idea: build AI streak multipliers, remember to block time for deep focus on Friday';

    setState(() {
      _listening = true;
      _soundLevel = 3.5;
    });

    final words = sampleText.split(' ');
    var accumulated = '';

    for (var i = 0; i < words.length; i++) {
      if (!mounted || !_listening) break;
      await Future.delayed(const Duration(milliseconds: 140));
      accumulated += (i == 0 ? '' : ' ') + words[i];
      if (mounted) {
        setState(() {
          _ctrl.text = accumulated;
          _ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: accumulated.length),
          );
          _soundLevel = (i % 3 == 0) ? 5.2 : ((i % 2 == 0) ? 2.1 : 4.4);
        });
      }
    }

    if (mounted) {
      setState(() {
        _listening = false;
        _soundLevel = 0.0;
      });
    }
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

  void _initSelections() {
    _taskSel = List.filled(_tasks.length, true);
    _noteSel = List.filled(_notes.length, true);
    _goalSel = List.filled(_goals.length, true);
    _memorySel = List.filled(_memories.length, true);
  }

  /// Calculates gap-aware, clash-free schedule slots for extracted tasks.
  void _scheduleExtractedTasks() {
    final now = DateTime.now();
    final events = ref.read(calendarControllerProvider);
    final existingTasks = ref.read(taskControllerProvider);

    // Collect today's busy intervals
    final busyWindows = <_BusyInterval>[];

    // 1. Calendar events today
    for (final e in events) {
      if (isSameDay(e.startTime, now) && e.endTime.isAfter(now)) {
        busyWindows.add(_BusyInterval(
          start: e.startTime.isBefore(now) ? now : e.startTime,
          end: e.endTime,
          label: e.title,
        ));
      }
    }

    // 2. Existing tasks scheduled today after now
    for (final t in existingTasks) {
      final tEnd = t.endTime ?? t.startTime.add(Duration(minutes: t.durationMinutes > 0 ? t.durationMinutes : 30));
      if (!t.isCompleted &&
          isSameDay(t.startTime, now) &&
          tEnd.isAfter(now)) {
        busyWindows.add(_BusyInterval(
          start: t.startTime.isBefore(now) ? now : t.startTime,
          end: tEnd,
          label: t.title,
        ));
      }
    }

    busyWindows.sort((a, b) => a.start.compareTo(b.start));

    // Earliest start: next 5-minute boundary after now
    var cursor = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      ((now.minute / 5).ceil() * 5),
    );
    if (cursor.isBefore(now)) cursor = now.add(const Duration(minutes: 5));

    _scheduleMessages.clear();
    _scheduleClashes.clear();

    final updatedTasks = <TaskItem>[];

    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      final duration = task.durationMinutes > 0 ? task.durationMinutes : 30;

      // Find an open gap >= duration starting at or after cursor
      DateTime taskStart = cursor;
      DateTime taskEnd = taskStart.add(Duration(minutes: duration));
      String? fitLabel;
      bool isClash = false;

      var searchLimit = 0;
      while (searchLimit < 30) {
        searchLimit++;
        _BusyInterval? conflict;
        for (final b in busyWindows) {
          // Check overlap
          if (taskStart.isBefore(b.end) && taskEnd.isAfter(b.start)) {
            conflict = b;
            break;
          }
        }

        if (conflict == null) {
          // Found free window!
          if (taskStart.hour >= 21) {
            fitLabel = '⚠️ Late evening slot (${_formatTime(taskStart)})';
            isClash = true;
          } else {
            fitLabel = '✓ Scheduled for ${_formatTime(taskStart)}';
          }
          break;
        } else {
          // Advance cursor past the conflict
          taskStart = conflict.end.add(const Duration(minutes: 5));
          taskEnd = taskStart.add(Duration(minutes: duration));
        }
      }

      // Add this scheduled task to busyWindows so subsequent tasks won't overlap
      busyWindows.add(_BusyInterval(
        start: taskStart,
        end: taskEnd,
        label: task.title,
      ));
      busyWindows.sort((a, b) => a.start.compareTo(b.start));

      cursor = taskEnd.add(const Duration(minutes: 5));

      _scheduleMessages[i] = fitLabel ?? '✓ Scheduled for ${_formatTime(taskStart)}';
      _scheduleClashes[i] = isClash;

      updatedTasks.add(task.copyWith(
        startTime: taskStart,
        endTime: taskEnd,
      ));
    }

    _tasks = updatedTasks;
  }

  Future<void> _process() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
    }

    setState(() {
      _processing = true;
      _processingStep = 0;
      _saved = false;
    });

    try {
      final ai = ref.read(aiServiceProvider);

      // Simulated progressive steps for delightful perception of intelligent computation
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && _processing) setState(() => _processingStep = 1);
      });
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted && _processing) setState(() => _processingStep = 2);
      });

      final result = await ai.brainDump(text);

      if (mounted) {
        setState(() {
          _tasks = List.from(result.tasks);
          _goals = List.from(result.goals);
          _notes = List.from(result.notes);
          _memories = List.from(result.memories);
          _taskGoalLinks = Map.from(result.taskGoalLinks);

          _scheduleExtractedTasks();
          _initSelections();
          _processing = false;
        });
      }
    } on ContentPolicyException catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.reason),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on CallFrequencyException catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete brain dump. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onTaskDurationChanged(int index, int minutes) {
    setState(() {
      final task = _tasks[index];
      final newEnd = task.startTime.add(Duration(minutes: minutes));
      _tasks[index] = task.copyWith(
        endTime: newEnd,
      );
      _scheduleExtractedTasks();
    });
  }

  void _onTaskPriorityChanged(int index, int priority) {
    setState(() {
      _tasks[index] = _tasks[index].copyWith(priority: priority);
    });
  }

  void _convertTaskToNote(int index) {
    setState(() {
      final task = _tasks.removeAt(index);
      _taskSel.removeAt(index);

      final now = DateTime.now();
      _notes.add(NoteItem(
        id: _uuid.v4(),
        title: task.title,
        content: task.title,
        tags: [...task.tags, 'braindump'],
        createdAt: now,
        updatedAt: now,
      ));
      _noteSel.add(true);

      _scheduleExtractedTasks();
    });
  }

  void _convertNoteToTask(int index) {
    setState(() {
      final note = _notes.removeAt(index);
      _noteSel.removeAt(index);

      final now = DateTime.now();
      _tasks.add(TaskItem(
        id: _uuid.v4(),
        title: note.title,
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        priority: 1,
        tags: note.tags.where((t) => t != 'braindump').toList(),
      ));
      _taskSel.add(true);

      _scheduleExtractedTasks();
    });
  }

  Future<void> _saveAll() async {
    final taskCtrl = ref.read(taskControllerProvider.notifier);
    final goalCtrl = ref.read(goalControllerProvider.notifier);
    final noteCtrl = ref.read(noteControllerProvider.notifier);
    final memoryCtrl = ref.read(memoryControllerProvider.notifier);
    final gamificationCtrl = ref.read(gamificationServiceProvider.notifier);

    var totalSaved = 0;

    // 1. Save selected tasks
    for (var i = 0; i < _tasks.length; i++) {
      if (_taskSel[i]) {
        taskCtrl.addTask(_tasks[i]);
        totalSaved++;
      }
    }

    // 2. Save selected notes
    for (var i = 0; i < _notes.length; i++) {
      if (_noteSel[i]) {
        noteCtrl.addNote(_notes[i]);
        totalSaved++;
      }
    }

    // 3. Save selected goals
    final now = DateTime.now();
    final goalTitleToId = <String, String>{};
    for (var i = 0; i < _goals.length; i++) {
      if (_goalSel[i]) {
        final goalId = _uuid.v4();
        goalCtrl.addGoal(
          GoalItem(
            id: goalId,
            title: _goals[i].title,
            description: _goals[i].description,
            createdAt: now,
            updatedAt: now,
          ),
        );
        goalTitleToId[_goals[i].title.toLowerCase()] = goalId;
        totalSaved++;
      }
    }

    // 4. Auto-link tasks to goals
    for (final entry in _taskGoalLinks.entries) {
      final taskIndex = entry.key;
      if (taskIndex >= _tasks.length || !_taskSel[taskIndex]) continue;
      final goalId = goalTitleToId[entry.value.toLowerCase()];
      if (goalId == null) continue;

      final task = _tasks[taskIndex];
      taskCtrl.linkGoal(task.id, goalId);
      goalCtrl.linkTask(goalId, task.id);
    }

    // 5. Save selected memories
    for (var i = 0; i < _memories.length; i++) {
      if (_memorySel[i]) {
        memoryCtrl.addMemory(
          MemoryEntry(
            id: _uuid.v4(),
            content: _memories[i],
            sourceType: 'brain_dump',
            tags: ['brain-dump'],
            createdAt: now,
            relevanceScore: 0.8,
          ),
        );
        totalSaved++;
      }
    }

    // 6. Award Gamification XP for Mental Declutter
    if (totalSaved > 0) {
      await gamificationCtrl.addXp(50, reason: 'Mental Declutter (Brain Dump)');
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
    final hasResults = _tasks.isNotEmpty || _notes.isNotEmpty || _goals.isNotEmpty || _memories.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: screenH * 0.94),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF141427), const Color(0xFF0C0C18)]
                : [Colors.white, const Color(0xFFF6F6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(25) : kNeonViolet.withAlpha(40),
          ),
          boxShadow: [
            BoxShadow(
              color: kNeonViolet.withAlpha(isDark ? 80 : 40),
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isDark, hasResults),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!hasResults && !_processing) ...[
                        _buildInputArea(isDark),
                        const SizedBox(height: 16),
                        _buildThoughtStarters(isDark),
                        const SizedBox(height: 24),
                        _buildProcessButton(isDark),
                      ] else if (_processing) ...[
                        _buildProcessingIndicator(isDark),
                      ] else if (hasResults) ...[
                        _buildResultsView(isDark),
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

  Widget _buildHeader(bool isDark, bool hasResults) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
          ),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(50) : Colors.black.withAlpha(25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              // Glowing Brain Aura Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [kNeonViolet, kNeonCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kNeonViolet.withAlpha(140),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Brain Dump',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [kNeonViolet, kNeonCyan],
                            ),
                          ),
                          child: const Text(
                            'AI 2.0',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasResults
                          ? 'Review & adjust your clarified thoughts'
                          : 'Speak or type anything — AI sorts it into action',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasResults)
                IconButton(
                  tooltip: 'Start Over',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => setState(() {
                    _tasks.clear();
                    _notes.clear();
                    _goals.clear();
                    _memories.clear();
                    _saved = false;
                  }),
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                color: isDark ? Colors.white60 : Colors.black45,
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
            color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _listening
                  ? kNeonCyan
                  : (isDark ? Colors.white.withAlpha(20) : kNeonViolet.withAlpha(40)),
              width: _listening ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            minLines: 5,
            maxLines: 9,
            autofocus: true,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText:
                  'Dump everything on your mind…\n\nTasks to do, fleeting ideas, meeting notes, project deadlines — let it all out.',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26,
                fontSize: 14,
                height: 1.55,
              ),
              contentPadding: const EdgeInsets.all(18),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Live Audio Waveform & Dictation Equalizer
        AudioWaveformVisualizer(
          isListening: _listening,
          soundLevel: _soundLevel,
          onToggle: _toggleListen,
        ),
      ],
    );
  }

  // ── Thought starter chips ─────────────────────────────────────────────────

  Widget _buildThoughtStarters(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_rounded, size: 14, color: kElectricAmber),
            const SizedBox(width: 6),
            Text(
              'THOUGHT STARTERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _examples.map((example) {
            return GestureDetector(
              onTap: () {
                _ctrl.text = example;
                _ctrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: example.length),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: kNeonViolet.withAlpha(isDark ? 30 : 15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: kNeonViolet.withAlpha(isDark ? 60 : 40),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 13,
                      color: kNeonViolet.withAlpha(180),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      example.length > 34 ? '${example.substring(0, 34)}…' : example,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
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
        label: 'Clarify & Organize with AI',
        child: GestureDetector(
          onTap: _process,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kNeonViolet, kNeonCyan],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: kNeonViolet.withAlpha(140),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Clarify & Organize with AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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

  // ── Stepped Processing indicator ──────────────────────────────────────────

  Widget _buildProcessingIndicator(bool isDark) {
    final steps = [
      'Decoding thoughts & speech stream…',
      'Classifying into tasks, notes & goals…',
      'Fitting seamlessly into calendar gaps…',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          // Glowing orb
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [kNeonViolet, kNeonCyan, kSunsetRose, kNeonViolet],
              ),
              boxShadow: [
                BoxShadow(
                  color: kNeonViolet.withAlpha(160),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF141427) : Colors.white,
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: kNeonCyan,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Organizing Mind…',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              steps[_processingStep % steps.length],
              key: ValueKey<int>(_processingStep),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kNeonCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Results View ──────────────────────────────────────────────────────────

  Widget _buildResultsView(bool isDark) {
    final totalExtracted = _tasks.length + _notes.length + _goals.length + _memories.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Cognitive Clarity Score Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                kNeonViolet.withAlpha(isDark ? 40 : 25),
                kNeonCyan.withAlpha(isDark ? 40 : 25),
              ],
            ),
            border: Border.all(
              color: kNeonCyan.withAlpha(isDark ? 90 : 60),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: kNeonCyan, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLARITY ACHIEVED • $totalExtracted THOUGHTS',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kNeonCyan,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Tasks auto-placed in upcoming gaps without clashes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kElectricAmber.withAlpha(isDark ? 50 : 30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: kElectricAmber),
                    SizedBox(width: 2),
                    Text(
                      '+50 XP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kElectricAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('all', 'All ($totalExtracted)', isDark),
              if (_tasks.isNotEmpty)
                _buildFilterChip('tasks', 'Tasks (${_tasks.length})', isDark),
              if (_notes.isNotEmpty)
                _buildFilterChip('notes', 'Notes (${_notes.length})', isDark),
              if (_goals.isNotEmpty)
                _buildFilterChip('goals', 'Goals (${_goals.length})', isDark),
              if (_memories.isNotEmpty)
                _buildFilterChip('memories', 'Memories (${_memories.length})', isDark),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 1. Tasks section
        if ((_filterTab == 'all' || _filterTab == 'tasks') && _tasks.isNotEmpty) ...[
          _buildCategoryHeader(
            icon: Icons.task_alt_rounded,
            title: 'Actionable Tasks',
            count: _tasks.length,
            color: kNeonCyan,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          ...List.generate(_tasks.length, (i) {
            return BrainDumpTaskTile(
              task: _tasks[i],
              selected: _taskSel[i],
              onSelectedChanged: (v) => setState(() => _taskSel[i] = v),
              onDurationChanged: (mins) => _onTaskDurationChanged(i, mins),
              onPriorityChanged: (p) => _onTaskPriorityChanged(i, p),
              onConvertToNote: () => _convertTaskToNote(i),
              scheduleFitMessage: _scheduleMessages[i],
              isClash: _scheduleClashes[i] ?? false,
            );
          }),
          const SizedBox(height: 14),
        ],

        // 2. Notes section
        if ((_filterTab == 'all' || _filterTab == 'notes') && _notes.isNotEmpty) ...[
          _buildCategoryHeader(
            icon: Icons.note_alt_rounded,
            title: 'Fleeting Thoughts & Ideas',
            count: _notes.length,
            color: kElectricAmber,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          ...List.generate(_notes.length, (i) {
            return BrainDumpNoteTile(
              note: _notes[i],
              selected: _noteSel[i],
              onSelectedChanged: (v) => setState(() => _noteSel[i] = v),
              onConvertToTask: () => _convertNoteToTask(i),
            );
          }),
          const SizedBox(height: 14),
        ],

        // 3. Goals section
        if ((_filterTab == 'all' || _filterTab == 'goals') && _goals.isNotEmpty) ...[
          _buildCategoryHeader(
            icon: Icons.flag_rounded,
            title: 'Aspirational Goals',
            count: _goals.length,
            color: kSunsetRose,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          ...List.generate(_goals.length, (i) {
            return _buildSimpleItemTile(
              selected: _goalSel[i],
              onChanged: (v) => setState(() => _goalSel[i] = v),
              title: _goals[i].title,
              subtitle: _goals[i].description.isNotEmpty
                  ? _goals[i].description
                  : 'Long-term outcome',
              color: kSunsetRose,
              isDark: isDark,
            );
          }),
          const SizedBox(height: 14),
        ],

        // 4. Memories section
        if ((_filterTab == 'all' || _filterTab == 'memories') && _memories.isNotEmpty) ...[
          _buildCategoryHeader(
            icon: Icons.psychology_rounded,
            title: 'Behavioral Preferences & Rules',
            count: _memories.length,
            color: kNeonViolet,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          ...List.generate(_memories.length, (i) {
            return _buildSimpleItemTile(
              selected: _memorySel[i],
              onChanged: (v) => setState(() => _memorySel[i] = v),
              title: _memories[i],
              subtitle: 'Stored into long-term AI memory context',
              color: kNeonViolet,
              isDark: isDark,
            );
          }),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String tab, String label, bool isDark) {
    final isActive = _filterTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _filterTab = tab),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive
              ? kNeonCyan
              : (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(6)),
          border: Border.all(
            color: isActive
                ? kNeonCyan
                : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive
                ? const Color(0xFF0F0F1E)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color.withAlpha(isDark ? 40 : 25),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color.withAlpha(isDark ? 50 : 30),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleItemTile({
    required bool selected,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? color.withAlpha(isDark ? 30 : 15)
              : (isDark ? Colors.white.withAlpha(6) : Colors.black.withAlpha(4)),
          border: Border.all(
            color: selected
                ? color.withAlpha(isDark ? 80 : 60)
                : (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2, right: 10),
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
                      color: selected
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.black38),
                      decoration: selected ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? (isDark ? Colors.white60 : Colors.black54)
                            : (isDark ? Colors.white24 : Colors.black26),
                      ),
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

  // ── Save button ───────────────────────────────────────────────────────────

  Widget _buildSaveButton(bool isDark) {
    final selCount = (_taskSel.where((b) => b).length) +
        (_noteSel.where((b) => b).length) +
        (_goalSel.where((b) => b).length) +
        (_memorySel.where((b) => b).length);

    if (_saved) {
      return ScaleTransition(
        scale: _successScale,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kNeonCyan, kNeonViolet],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: kNeonCyan.withAlpha(140),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text(
                'Mind Decluttered! +50 XP ⚡',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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
          ? 'Save $selCount item${selCount == 1 ? '' : 's'} to Schedule & Memory'
          : 'Select items to save',
      child: GestureDetector(
        onTap: selCount > 0 ? _saveAll : null,
        child: AnimatedOpacity(
          opacity: selCount > 0 ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: selCount > 0
                  ? const LinearGradient(
                      colors: [kNeonViolet, kNeonCyan],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: selCount == 0
                  ? (isDark ? Colors.white24 : Colors.black12)
                  : null,
              borderRadius: BorderRadius.circular(18),
              boxShadow: selCount > 0
                  ? [
                      BoxShadow(
                        color: kNeonViolet.withAlpha(140),
                        blurRadius: 22,
                        offset: const Offset(0, 6),
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
                      ? 'Commit $selCount Item${selCount == 1 ? '' : 's'} (+50 XP)'
                      : 'Select items to commit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _BusyInterval {
  final DateTime start;
  final DateTime end;
  final String label;
  const _BusyInterval({required this.start, required this.end, required this.label});
}
