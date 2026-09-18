import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ui_kit.dart';
import '../../../services/routine_service.dart';

class EveningShutdownSheet extends ConsumerStatefulWidget {
  const EveningShutdownSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(140),
      builder: (_) => const EveningShutdownSheet(),
    );
  }

  @override
  ConsumerState<EveningShutdownSheet> createState() =>
      _EveningShutdownSheetState();
}

enum _TriageAction { rollover, backlog, discard }

class _EveningShutdownSheetState extends ConsumerState<EveningShutdownSheet> {
  late final EveningReview _review;
  final Map<String, _TriageAction> _triageSelections = {};
  final TextEditingController _reflectionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _review = ref.read(routineServiceProvider).generateEveningReview();
    for (final task in _review.pendingTasks) {
      _triageSelections[task.id] = _TriageAction.rollover;
    }
  }

  @override
  void dispose() {
    _reflectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeShutdown() async {
    HapticFeedback.heavyImpact();
    final rollovers = <String>[];
    final backlogs = <String>[];
    final discards = <String>[];

    _triageSelections.forEach((id, action) {
      switch (action) {
        case _TriageAction.rollover:
          rollovers.add(id);
          break;
        case _TriageAction.backlog:
          backlogs.add(id);
          break;
        case _TriageAction.discard:
          discards.add(id);
          break;
      }
    });

    await ref
        .read(routineServiceProvider)
        .executeEveningShutdown(
          rolloverTaskIds: rollovers,
          backlogTaskIds: backlogs,
          discardTaskIds: discards,
          reflectionNote: _reflectionCtrl.text.trim(),
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.bedtime_rounded, color: kCyan),
              SizedBox(width: 8),
              Text(
                'Shutdown Complete! +50 XP Earned 🌙 Sleep well!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF131028),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark
                  ? const Color(0xFF0A0915).withAlpha(245)
                  : Colors.white.withAlpha(248),
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Starry Twilight Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: kGradientMidnightGlow,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: kIndigo.withAlpha(80),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kIndigo.withAlpha(70),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bedtime_rounded,
                              color: kNeonCyan,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _review.headline,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_review.completedTasks}/${_review.totalTasks} tasks completed · ${_review.totalFocusMinutes} mins in flow state today.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Score Overview
                  Row(
                    children: [
                      _ScoreCard(
                        title: 'Completion',
                        value: '${(_review.completionRate * 100).toInt()}%',
                        color: kUltraEmerald,
                      ),
                      const SizedBox(width: 10),
                      _ScoreCard(
                        title: 'Flow Time',
                        value: '${_review.totalFocusMinutes}m',
                        color: kCyan,
                      ),
                      const SizedBox(width: 10),
                      _ScoreCard(
                        title: 'Pending',
                        value: '${_review.pendingTasks.length}',
                        color: kCoral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Reflection Note
                  const SectionLabel(
                    icon: Icons.psychology_rounded,
                    label: 'EVENING REFLECTION',
                    color: kNeonCyan,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(12)
                          : Colors.black.withAlpha(6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black12,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _reflectionCtrl,
                      style: TextStyle(
                        color: isDark ? Colors.white : kDark0,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: _review.reflectionPrompt,
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Incomplete Tasks Triage
                  if (_review.pendingTasks.isNotEmpty) ...[
                    const SectionLabel(
                      icon: Icons.alt_route_rounded,
                      label: 'TRIAGE INCOMPLETE TASKS',
                      color: kElectricAmber,
                    ),
                    const SizedBox(height: 12),
                    ..._review.pendingTasks.map((task) {
                      final currentAction =
                          _triageSelections[task.id] ?? _TriageAction.rollover;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withAlpha(10)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withAlpha(18)
                                  : Colors.black12,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : kDark0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _TriageChip(
                                    label: 'Tomorrow',
                                    icon: Icons.arrow_forward_rounded,
                                    selected:
                                        currentAction == _TriageAction.rollover,
                                    color: kUltraEmerald,
                                    onTap: () {
                                      setState(() {
                                        _triageSelections[task.id] =
                                            _TriageAction.rollover;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _TriageChip(
                                    label: 'Backlog',
                                    icon: Icons.inventory_2_outlined,
                                    selected:
                                        currentAction == _TriageAction.backlog,
                                    color: kElectricAmber,
                                    onTap: () {
                                      setState(() {
                                        _triageSelections[task.id] =
                                            _TriageAction.backlog;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _TriageChip(
                                    label: 'Discard',
                                    icon: Icons.delete_outline_rounded,
                                    selected:
                                        currentAction == _TriageAction.discard,
                                    color: kCoral,
                                    onTap: () {
                                      setState(() {
                                        _triageSelections[task.id] =
                                            _TriageAction.discard;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                  // Shutdown Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: kGradientCyberCyan,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: kNeonCyan.withAlpha(80),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _completeShutdown,
                        icon: const Icon(
                          Icons.done_all_rounded,
                          color: Color(0xFF0A0915),
                        ),
                        label: const Text(
                          'Complete Shutdown (+50 XP)',
                          style: TextStyle(
                            color: Color(0xFF0A0915),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _ScoreCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(10) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withAlpha(isDark ? 60 : 40),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriageChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TriageChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(40) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.grey.withAlpha(60),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
