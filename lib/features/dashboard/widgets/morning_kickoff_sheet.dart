import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/ui_kit.dart';
import '../../../services/routine_service.dart';

class MorningKickoffSheet extends ConsumerStatefulWidget {
  const MorningKickoffSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(140),
      builder: (_) => const MorningKickoffSheet(),
    );
  }

  @override
  ConsumerState<MorningKickoffSheet> createState() =>
      _MorningKickoffSheetState();
}

class _MorningKickoffSheetState extends ConsumerState<MorningKickoffSheet> {
  MorningBriefing? _briefing;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBriefing();
  }

  Future<void> _loadBriefing() async {
    final service = ref.read(routineServiceProvider);
    final briefing = await service.generateMorningBriefing();
    if (mounted) {
      setState(() {
        _briefing = briefing;
        _loading = false;
      });
    }
  }

  Future<void> _activate() async {
    if (_briefing == null) return;
    HapticFeedback.heavyImpact();
    await ref
        .read(routineServiceProvider)
        .activateMorningPlan(_briefing!.big3);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.bolt_rounded, color: kElectricAmber),
              SizedBox(width: 8),
              Text(
                'Attack Plan Activated! +50 XP Earned 🌅',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1B38),
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
                  ? const Color(0xFF0C0A1A).withAlpha(245)
                  : Colors.white.withAlpha(248),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: kElectricAmber),
                    )
                  : ListView(
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
                        // Sunrise Hero Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: kGradientNeonSunset,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: kSunsetRose.withAlpha(80),
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
                                    Icons.wb_sunny_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _briefing!.headline,
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
                                _briefing!.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Quick Stats
                        Row(
                          children: [
                            _HeaderStatCard(
                              icon: Icons.calendar_month_rounded,
                              label: 'Meetings',
                              value: '${_briefing!.meetingsCount}',
                              color: kNeonCyan,
                            ),
                            const SizedBox(width: 10),
                            _HeaderStatCard(
                              icon: Icons.hourglass_top_rounded,
                              label: 'Open Flow',
                              value: '${_briefing!.availableFocusHours.toStringAsFixed(1)}h',
                              color: kUltraEmerald,
                            ),
                            const SizedBox(width: 10),
                            _HeaderStatCard(
                              icon: Icons.history_rounded,
                              label: 'Rollover',
                              value: '${_briefing!.rolloverCount}',
                              color: kElectricAmber,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const SectionLabel(
                          icon: Icons.star_rounded,
                          label: 'THE BIG 3 PRIORITIES',
                          color: kElectricAmber,
                        ),
                        const SizedBox(height: 12),
                        if (_briefing!.big3.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: const Text(
                              'No pending tasks found! Add tasks to formulate your Big 3.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ...List.generate(_briefing!.big3.length, (index) {
                            final task = _briefing!.big3[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: VibrantGlassCard(
                                glowColor: index == 0 ? kElectricAmber : kIndigo,
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: index == 0
                                            ? kGradientNeonSunset
                                            : kGradientTeal,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '#${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : kDark0,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${task.durationMinutes > 0 ? task.durationMinutes : 45} mins · Priority ${task.priorityLabel}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black45,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 20),
                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: kGradientNeonSunset,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: kSunsetRose.withAlpha(90),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _activate,
                              icon: const Icon(
                                Icons.rocket_launch_rounded,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Activate Attack Plan (+50 XP)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
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

class _HeaderStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HeaderStatCard({
    required this.icon,
    required this.label,
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
          color: isDark ? Colors.white.withAlpha(12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withAlpha(isDark ? 60 : 40),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : kDark0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
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
