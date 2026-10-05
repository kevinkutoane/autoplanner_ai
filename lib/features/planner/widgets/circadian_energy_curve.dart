import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/circadian_rhythm.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/ui_kit.dart';

/// Ambient interactive circadian energy curve widget.
///
/// Visualizes biological capacity across 24 hours based on the user's
/// chronotype (Lion, Bear, or Wolf), highlights peak focus vs. recovery windows,
/// and provides real-time biological alignment insights.
class CircadianEnergyCurveCard extends ConsumerStatefulWidget {
  const CircadianEnergyCurveCard({super.key});

  @override
  ConsumerState<CircadianEnergyCurveCard> createState() => _CircadianEnergyCurveCardState();
}

class _CircadianEnergyCurveCardState extends ConsumerState<CircadianEnergyCurveCard> {
  bool _isExpanded = true;
  double? _inspectedHour;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final chronotype = Chronotype.fromId(settings.chronotype);

    final now = DateTime.now();
    final currentHour = now.hour + (now.minute / 60.0);
    final activeHour = _inspectedHour ?? currentHour;

    final capacity = CircadianRhythm.energyCapacityAtHour(activeHour, chronotypeId: chronotype.id);
    final phase = CircadianPhase.fromCapacity(capacity);
    final isInspecting = _inspectedHour != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phaseColor = _phaseColor(phase);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141729).withAlpha(220) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: phaseColor.withAlpha(isDark ? 90 : 60),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: phaseColor.withAlpha(isDark ? 30 : 20),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: phaseColor.withAlpha(35),
                          border: Border.all(color: phaseColor.withAlpha(80)),
                        ),
                        child: Icon(
                          _phaseIcon(phase),
                          color: phaseColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _chronotypeEmoji(chronotype),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    chronotype.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: phaseColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${(capacity * 100).round()}% Capacity',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: phaseColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isInspecting
                                  ? 'Inspecting ${_formatHour(activeHour)} • ${phase.label}'
                                  : 'Now: ${phase.label} • ${phase.description}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 20,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        onPressed: () => setState(() => _isExpanded = !_isExpanded),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

              // Animated Curve Body
              AnimatedCrossFade(
                crossFadeState: _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 250),
                secondChild: const SizedBox.shrink(),
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 12, thickness: 0.6),
                      const SizedBox(height: 4),

                      // Interactive Canvas
                      GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final localPos = details.localPosition;
                          final width = box.size.width - 28;
                          if (width > 0) {
                            final fraction = (localPos.dx / width).clamp(0.0, 1.0);
                            setState(() => _inspectedHour = fraction * 24.0);
                          }
                        },
                        onHorizontalDragEnd: (_) {
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted && _inspectedHour != null) {
                              setState(() => _inspectedHour = null);
                            }
                          });
                        },
                        onTapDown: (details) {
                          final RenderBox box = context.findRenderObject() as RenderBox;
                          final localPos = details.localPosition;
                          final width = box.size.width - 28;
                          if (width > 0) {
                            final fraction = (localPos.dx / width).clamp(0.0, 1.0);
                            setState(() => _inspectedHour = fraction * 24.0);
                          }
                        },
                        child: SizedBox(
                          height: 70,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _CircadianCurvePainter(
                              chronotype: chronotype,
                              currentHour: currentHour,
                              inspectedHour: _inspectedHour,
                              accentColor: phaseColor,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),
                      // Timeline Labels (6 AM, 12 PM, 6 PM, 12 AM)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _timeLabel('12 AM', isDark),
                          _timeLabel('6 AM', isDark),
                          _timeLabel('12 PM', isDark),
                          _timeLabel('6 PM', isDark),
                          _timeLabel('11 PM', isDark),
                        ],
                      ),

                      const SizedBox(height: 10),
                      // Actionable Recommendation Pill
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: phaseColor.withAlpha(isDark ? 20 : 15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: phaseColor.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: phaseColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _recommendationText(phase, chronotype),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _timeLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }

  static Color _phaseColor(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.peakFocus:
        return kCyan;
      case CircadianPhase.steadyWork:
        return kIndigo;
      case CircadianPhase.recoveryDip:
        return kAmber;
      case CircadianPhase.windDown:
        return kDeepPurple;
      case CircadianPhase.rest:
        return Colors.blueGrey;
    }
  }

  static IconData _phaseIcon(CircadianPhase phase) {
    switch (phase) {
      case CircadianPhase.peakFocus:
        return Icons.local_fire_department_rounded;
      case CircadianPhase.steadyWork:
        return Icons.work_outline_rounded;
      case CircadianPhase.recoveryDip:
        return Icons.coffee_rounded;
      case CircadianPhase.windDown:
        return Icons.bedtime_outlined;
      case CircadianPhase.rest:
        return Icons.nights_stay_rounded;
    }
  }

  static String _chronotypeEmoji(Chronotype chronotype) {
    switch (chronotype) {
      case Chronotype.earlyBird:
        return '🦁';
      case Chronotype.balanced:
        return '🐻';
      case Chronotype.nightOwl:
        return '🐺';
    }
  }

  static String _formatHour(double hour) {
    final h = hour.floor() % 24;
    final m = ((hour - h) * 60).round();
    final dt = DateTime(2026, 1, 1, h, m);
    return DateFormat('h:mm a').format(dt);
  }

  static String _recommendationText(CircadianPhase phase, Chronotype chronotype) {
    switch (phase) {
      case CircadianPhase.peakFocus:
        return 'Biological Zenith: Perfect for deep focus, complex code, and strategic architecture.';
      case CircadianPhase.steadyWork:
        return 'Steady Focus: Great for iterative execution, reviews, and collaborative problem-solving.';
      case CircadianPhase.recoveryDip:
        return 'Restorative Window: Optimal for administrative tasks, sorting inbox, or a short walk.';
      case CircadianPhase.windDown:
        return 'Deceleration Phase: Wrap up loose ends and plan tomorrow’s primary high-impact goal.';
      case CircadianPhase.rest:
        return 'Biological Rest: Sleep is consolidating learned neural pathways. Rest well.';
    }
  }
}

class _CircadianCurvePainter extends CustomPainter {
  final Chronotype chronotype;
  final double currentHour;
  final double? inspectedHour;
  final Color accentColor;
  final bool isDark;

  _CircadianCurvePainter({
    required this.chronotype,
    required this.currentHour,
    required this.inspectedHour,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Draw baseline
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(20)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, height * 0.5), Offset(width, height * 0.5), gridPaint);

    final path = Path();
    final fillPath = Path();

    const sampleCount = 96; // 1 sample every 15 minutes
    final points = <Offset>[];

    for (var i = 0; i <= sampleCount; i++) {
      final hour = (i / sampleCount) * 24.0;
      final capacity = CircadianRhythm.energyCapacityAtHour(hour, chronotypeId: chronotype.id);
      final x = (hour / 24.0) * width;
      // High capacity maps to near y = 4 (top), low capacity maps to height - 4 (bottom)
      final y = height - (capacity * (height - 12)) - 6;
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      fillPath.moveTo(points.first.dx, height);
      fillPath.lineTo(points.first.dx, points.first.dy);

      for (var i = 1; i < points.length; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
        fillPath.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }

      final last = points.last;
      path.lineTo(last.dx, last.dy);
      fillPath.lineTo(last.dx, last.dy);
      fillPath.lineTo(width, height);
      fillPath.close();

      // Draw gradient under the curve
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withAlpha(isDark ? 90 : 70),
            accentColor.withAlpha(0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, width, height));

      canvas.drawPath(fillPath, fillPaint);

      // Draw curve outline
      final strokePaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, strokePaint);
    }

    // Draw real-time needle indicator
    final needleHour = inspectedHour ?? currentHour;
    final needleX = (needleHour / 24.0) * width;
    final needleCapacity = CircadianRhythm.energyCapacityAtHour(needleHour, chronotypeId: chronotype.id);
    final needleY = height - (needleCapacity * (height - 12)) - 6;

    final needlePaint = Paint()
      ..color = (inspectedHour != null ? Colors.white : accentColor).withAlpha(180)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(needleX, 0), Offset(needleX, height), needlePaint);

    // Glowing orb at the point
    final orbGlowPaint = Paint()
      ..color = accentColor.withAlpha(120)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(needleX, needleY), 5.5, orbGlowPaint);

    final orbCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(needleX, needleY), 2.8, orbCorePaint);
  }

  @override
  bool shouldRepaint(covariant _CircadianCurvePainter oldDelegate) {
    return oldDelegate.chronotype != chronotype ||
        oldDelegate.currentHour != currentHour ||
        oldDelegate.inspectedHour != inspectedHour ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
