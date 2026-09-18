import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/core/theme/ui_kit.dart';
import 'package:autoplanner_ai/features/focus/controllers/focus_controller.dart';
import 'package:autoplanner_ai/features/focus/widgets/celebration_overlay.dart';

/// Immersive, distraction-free execution screen with radial countdown,
/// flow-state extensions, distraction notes, and celebration animations.
class FocusModeScreen extends ConsumerStatefulWidget {
  final TaskItem task;

  const FocusModeScreen({super.key, required this.task});

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _distractionController = TextEditingController();
  bool _showCelebration = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _distractionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _openDistractionSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bubble_chart_outlined,
                    color: kAmber,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Log Distraction Note',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Offload random thoughts here to preserve your focus flow.',
                style: TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _distractionController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Reply to Marcus, check server disk space...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(90)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    ref
                        .read(focusControllerProvider.notifier)
                        .logDistraction(val);
                    _distractionController.clear();
                    Navigator.of(ctx).pop();
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kAmber,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final text = _distractionController.text;
                    if (text.trim().isNotEmpty) {
                      ref
                          .read(focusControllerProvider.notifier)
                          .logDistraction(text);
                      _distractionController.clear();
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text(
                    'Save Note & Resume Focus',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmExit() {
    final session = ref.read(focusControllerProvider);
    if (!session.isRunning && session.elapsedSeconds == 0) {
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Leave Focus Session?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'You have ${session.elapsedMinutes}m of deep work logged. Would you like to pause or exit?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(focusControllerProvider.notifier).cancelSession();
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kIndigo),
            onPressed: () {
              ref.read(focusControllerProvider.notifier).pause();
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Keep Paused & Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(focusControllerProvider);
    final focusCtrl = ref.read(focusControllerProvider.notifier);

    // Format remaining time MM:SS
    final remSecs = session.remainingSeconds;
    final mins = remSecs ~/ 60;
    final secs = remSecs % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F18),
        body: Stack(
          children: [
            // Ambient Radial Glow
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.2),
                        radius: 0.85 + (_pulseController.value * 0.15),
                        colors: [
                          kIndigo.withAlpha(
                            session.isPaused
                                ? 20
                                : (40 + (_pulseController.value * 25).toInt()),
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Top navigation & close
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: _confirmExit,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: session.isPaused
                                      ? kAmber
                                      : const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                session.isPaused ? 'PAUSED' : 'DEEP WORK',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.bubble_chart_outlined,
                            color: kAmber,
                            size: 24,
                          ),
                          tooltip: 'Log distraction',
                          onPressed: _openDistractionSheet,
                        ),
                      ],
                    ),
                  ),

                  // Task Header Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Text(
                          widget.task.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (widget.task.tags.isNotEmpty) ...[
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            children: widget.task.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Radial Timer Indicator
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background track
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: 10,
                            color: Colors.white.withAlpha(15),
                          ),
                        ),
                        // Active progress
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: CircularProgressIndicator(
                            value: session.progress,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                            color: session.isOvertime ? kRose : kIndigo,
                          ),
                        ),
                        // Inner content
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 52,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              session.isOvertime
                                  ? '+${session.overtimeSeconds ~/ 60}m OVERTIME'
                                  : '${session.elapsedMinutes}m elapsed of ${session.targetSeconds ~/ 60}m',
                              style: TextStyle(
                                color: session.isOvertime
                                    ? kRose
                                    : Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Quick Flow Extension Chips (+5m, +15m)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.white70,
                          ),
                          label: const Text('+5 min'),
                          backgroundColor: Colors.white.withAlpha(15),
                          labelStyle: const TextStyle(color: Colors.white70),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onPressed: () => focusCtrl.addMinutes(5),
                        ),
                        const SizedBox(width: 12),
                        ActionChip(
                          avatar: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.white70,
                          ),
                          label: const Text('+15 min'),
                          backgroundColor: Colors.white.withAlpha(15),
                          labelStyle: const TextStyle(color: Colors.white70),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onPressed: () => focusCtrl.addMinutes(15),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom Controls Bar (Pause / Resume, Complete)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        // Pause / Resume Button
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withAlpha(40),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: Icon(
                              session.isPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              size: 24,
                            ),
                            label: Text(
                              session.isPaused ? 'Resume' : 'Pause',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              if (session.isPaused) {
                                focusCtrl.resume();
                              } else {
                                focusCtrl.pause();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Finish & Complete Button
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(
                              Icons.check_circle_rounded,
                              size: 22,
                            ),
                            label: const Text(
                              'Finish & Done',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              final doneTask = focusCtrl.completeSession();
                              if (doneTask != null) {
                                setState(() {
                                  _showCelebration = true;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Confetti Celebration Overlay
            if (_showCelebration)
              CelebrationOverlay(
                title: 'Task Completed! 🏆',
                subtitle:
                    'Logged ${session.elapsedMinutes}m of focused deep work.',
                onDismiss: () {
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
