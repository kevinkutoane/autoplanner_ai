import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/ui_kit.dart';

/// A vibrant, reactive 9-bar audio waveform frequency visualizer.
/// Reacts to microphone [soundLevel] with smooth spring physics and
/// falls back to a gentle breathing ripple when idle or when decibels
/// are unavailable.
class AudioWaveformVisualizer extends StatefulWidget {
  final bool isListening;
  final double soundLevel;
  final VoidCallback? onToggle;

  const AudioWaveformVisualizer({
    super.key,
    required this.isListening,
    this.soundLevel = 0.0,
    this.onToggle,
  });

  @override
  State<AudioWaveformVisualizer> createState() =>
      _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Normalize sound level from STT (-2.0 .. 10.0+ into 0.0 .. 1.0)
    final normalizedLevel = ((widget.soundLevel + 2.0) / 10.0).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.isListening
                ? kNeonViolet.withAlpha(isDark ? 25 : 15)
                : (isDark
                      ? Colors.white.withAlpha(8)
                      : Colors.black.withAlpha(5)),
            border: Border.all(
              color: widget.isListening
                  ? kNeonCyan.withAlpha(isDark ? 120 : 90)
                  : (isDark
                        ? Colors.white.withAlpha(15)
                        : Colors.black.withAlpha(10)),
              width: widget.isListening ? 1.5 : 1,
            ),
            boxShadow: widget.isListening
                ? [
                    BoxShadow(
                      color: kNeonViolet.withAlpha(isDark ? 60 : 40),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tap to toggle mic button
              GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isListening
                        ? const LinearGradient(
                            colors: [kSunsetRose, kNeonViolet],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: widget.isListening
                        ? null
                        : (isDark
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(10)),
                    boxShadow: widget.isListening
                        ? [
                            BoxShadow(
                              color: kSunsetRose.withAlpha(100),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 20,
                    color: widget.isListening
                        ? Colors.white
                        : (isDark ? kNeonCyan : kNeonViolet),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Multi-bar equalizer
              SizedBox(
                height: 32,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(9, (index) {
                    // Phase offset for wave effect
                    final phase = (index / 9) * 2 * math.pi;
                    final sine =
                        (math.sin(_waveController.value * 2 * math.pi + phase) +
                            1) /
                        2;

                    double barHeight;
                    if (widget.isListening) {
                      // Height responsive to sound level + harmonic wave
                      final base = 8.0 + (sine * 10.0);
                      final reactive =
                          normalizedLevel *
                          14.0 *
                          (1.0 - (index - 4).abs() / 5.0);
                      barHeight = (base + reactive).clamp(6.0, 30.0);
                    } else {
                      // Low idle ripple
                      barHeight = 4.0 + (sine * 4.0);
                    }

                    final colors = [
                      kNeonViolet,
                      kNeonCyan,
                      kUltraEmerald,
                      kElectricAmber,
                      kSunsetRose,
                      kElectricAmber,
                      kUltraEmerald,
                      kNeonCyan,
                      kNeonViolet,
                    ];

                    return Container(
                      width: 3.5,
                      height: barHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: widget.isListening
                            ? colors[index]
                            : (isDark
                                  ? Colors.white.withAlpha(60)
                                  : Colors.black26),
                        boxShadow: widget.isListening
                            ? [
                                BoxShadow(
                                  color: colors[index].withAlpha(140),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(width: 14),

              // Status text
              Text(
                widget.isListening
                    ? 'Listening… speak freely'
                    : 'Tap mic to dictate',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isListening
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white54 : Colors.black45),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
