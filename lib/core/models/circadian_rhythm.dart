import 'dart:math' as math;

import 'task_model.dart';

/// Available biological chronotypes supported by the AutoPlanner personal OS.
enum Chronotype {
  earlyBird('early_bird', 'Early Bird (Lion)', 'Peak energy 07:00 - 11:30. Early riser with steep afternoon drop.'),
  balanced('balanced', 'Balanced (Bear)', 'Peak energy 09:30 - 13:00 and afternoon resurgence 16:00 - 18:30.'),
  nightOwl('night_owl', 'Night Owl (Wolf)', 'Peak energy 17:00 - 23:00. Slow morning ramp with late evening golden hours.');

  final String id;
  final String label;
  final String description;

  const Chronotype(this.id, this.label, this.description);

  static Chronotype fromId(String? id) {
    if (id == null) return Chronotype.earlyBird;
    return Chronotype.values.firstWhere(
      (c) => c.id == id.toLowerCase().trim(),
      orElse: () => Chronotype.earlyBird,
    );
  }
}

/// The biological energy phase corresponding to a circadian capacity level.
enum CircadianPhase {
  peakFocus('Peak Focus', 'High-intensity cognitive capacity. Prime deep work window.', 0.80),
  steadyWork('Steady Work', 'Balanced focus suitable for problem solving and collaboration.', 0.60),
  recoveryDip('Recovery Dip', 'Lower alertness. Ideal for admin, routine chores, or restorative breaks.', 0.35),
  windDown('Wind-down', 'Mental deceleration phase. Wrap-up and planning.', 0.20),
  rest('Rest', 'Biological rest window. Avoid scheduling high-effort tasks.', 0.0);

  final String label;
  final String description;
  final double minimumCapacity;

  const CircadianPhase(this.label, this.description, this.minimumCapacity);

  static CircadianPhase fromCapacity(double capacity) {
    if (capacity >= peakFocus.minimumCapacity) return peakFocus;
    if (capacity >= steadyWork.minimumCapacity) return steadyWork;
    if (capacity >= recoveryDip.minimumCapacity) return recoveryDip;
    if (capacity >= windDown.minimumCapacity) return windDown;
    return rest;
  }
}

/// Cognitive demand classification for task-circadian matching.
enum CognitiveDemand {
  deepWork('Deep Work', 3),
  moderate('Moderate Focus', 2),
  shallow('Shallow / Admin', 1);

  final String label;
  final int weight;

  const CognitiveDemand(this.label, this.weight);
}

/// Mathematical model of circadian energy capacity and cognitive alignment.
class CircadianRhythm {
  const CircadianRhythm._();

  static const _deepWorkTags = {
    'deep_work',
    'deepwork',
    'coding',
    'code',
    'programming',
    'architecture',
    'strategy',
    'analysis',
    'study',
    'studying',
    'writing',
    'design',
    'research',
    'math',
    'complex',
  };

  static const _shallowTags = {
    'admin',
    'email',
    'inbox',
    'errands',
    'errand',
    'chores',
    'chore',
    'slack',
    'calls',
    'call',
    'routine',
    'filing',
    'logistics',
    'paperwork',
    'quick',
  };

  /// Computes the normalized biological energy capacity [0.0, 1.0] at [time]
  /// for the specified [chronotypeId].
  static double energyCapacityAt(DateTime time, {String chronotypeId = 'early_bird'}) {
    final decimalHour = time.hour + (time.minute / 60.0);
    return energyCapacityAtHour(decimalHour, chronotypeId: chronotypeId);
  }

  /// Calculates biological energy capacity at decimal hour [0.0 - 24.0).
  static double energyCapacityAtHour(double hour, {String chronotypeId = 'early_bird'}) {
    final chronotype = Chronotype.fromId(chronotypeId);
    final normalizedHour = ((hour % 24.0) + 24.0) % 24.0;

    switch (chronotype) {
      case Chronotype.earlyBird:
        return _earlyBirdCapacity(normalizedHour);
      case Chronotype.balanced:
        return _balancedCapacity(normalizedHour);
      case Chronotype.nightOwl:
        return _nightOwlCapacity(normalizedHour);
    }
  }

  /// Returns the [CircadianPhase] at [time] for [chronotypeId].
  static CircadianPhase phaseAt(DateTime time, {String chronotypeId = 'early_bird'}) {
    final capacity = energyCapacityAt(time, chronotypeId: chronotypeId);
    return CircadianPhase.fromCapacity(capacity);
  }

  /// Infers [CognitiveDemand] of a [TaskItem] based on its tags, energy level,
  /// and priority.
  static CognitiveDemand inferCognitiveDemand(TaskItem task) {
    final normalizedTags = task.tags.map((t) => t.trim().toLowerCase()).toSet();

    // 1. Explicit shallow tags or low energy
    if (normalizedTags.any(_shallowTags.contains) || task.energyLevel == 'low') {
      return CognitiveDemand.shallow;
    }

    // 2. Explicit deep work tags or high energy
    if (normalizedTags.any(_deepWorkTags.contains) || task.energyLevel == 'high') {
      return CognitiveDemand.deepWork;
    }

    // 3. Fallback to priority heuristic: High priority (2 or 3) defaults to deep work
    if (task.priority >= 2) {
      return CognitiveDemand.deepWork;
    }

    return CognitiveDemand.moderate;
  }

  /// Evaluates the circadian fit score and rationale for placing [task] in [slotStart, slotEnd].
  ///
  /// Returns a record with:
  /// - `score`: positive bonus or negative penalty to combine into scheduler multi-factor score.
  /// - `rationale`: human-readable biological rationale to attach to explainability.
  static ({double score, String rationale}) evaluateFit({
    required TaskItem task,
    required DateTime slotStart,
    required DateTime slotEnd,
    String chronotypeId = 'early_bird',
  }) {
    final midPoint = slotStart.add(slotEnd.difference(slotStart) ~/ 2);
    final capacity = energyCapacityAt(midPoint, chronotypeId: chronotypeId);
    final phase = CircadianPhase.fromCapacity(capacity);
    final demand = inferCognitiveDemand(task);
    final chronotype = Chronotype.fromId(chronotypeId);

    final percentDisplay = '${(capacity * 100).round()}%';
    final timeStr = _formatHourMinute(slotStart);

    switch (demand) {
      case CognitiveDemand.deepWork:
        if (phase == CircadianPhase.peakFocus) {
          final bonus = 14.0 * capacity;
          return (
            score: bonus,
            rationale: 'Deep work aligned to $timeStr ${chronotype.label} peak focus ($percentDisplay capacity, +${bonus.toStringAsFixed(1)})',
          );
        } else if (phase == CircadianPhase.steadyWork) {
          final bonus = 7.0 * capacity;
          return (
            score: bonus,
            rationale: 'Deep work in ${chronotype.label} steady work window at $timeStr ($percentDisplay capacity, +${bonus.toStringAsFixed(1)})',
          );
        } else if (phase == CircadianPhase.recoveryDip) {
          return (
            score: -8.0,
            rationale: 'High-cognitive task scheduled during ${chronotype.label} recovery dip ($percentDisplay capacity, -8.0)',
          );
        } else {
          return (
            score: -12.0,
            rationale: 'High-cognitive task scheduled during ${chronotype.label} wind-down / rest period ($percentDisplay capacity, -12.0)',
          );
        }

      case CognitiveDemand.shallow:
        if (phase == CircadianPhase.recoveryDip) {
          // Rewarded for protecting peak hours and placing admin in dips
          return (
            score: 10.0,
            rationale: 'Administrative task scheduled in ${chronotype.label} recovery dip at $timeStr (preserves peak focus, +10.0)',
          );
        } else if (phase == CircadianPhase.peakFocus) {
          // Penalized for wasting peak focus on shallow work
          return (
            score: -6.0,
            rationale: 'Shallow task placed during ${chronotype.label} peak circadian focus window (-6.0)',
          );
        } else {
          return (
            score: 4.0,
            rationale: 'Administrative task scheduled in ${chronotype.label} non-peak slot at $timeStr (+4.0)',
          );
        }

      case CognitiveDemand.moderate:
        if (phase == CircadianPhase.peakFocus || phase == CircadianPhase.steadyWork) {
          final bonus = 6.0 * capacity;
          return (
            score: bonus,
            rationale: 'Standard task scheduled in ${chronotype.label} productive window at $timeStr ($percentDisplay capacity, +${bonus.toStringAsFixed(1)})',
          );
        } else if (phase == CircadianPhase.recoveryDip) {
          return (
            score: 2.0,
            rationale: 'Standard task scheduled during ${chronotype.label} post-lunch dip at $timeStr (+2.0)',
          );
        } else {
          return (
            score: -4.0,
            rationale: 'Standard task scheduled during ${chronotype.label} wind-down/rest window (-4.0)',
          );
        }
    }
  }

  // ── Private Chronotype Curve Equations ─────────────────────────────────────

  /// Early Bird (Lion):
  /// - Awakening 05:30
  /// - Morning Peak: 07:00 - 11:30 (peaks ~09:00 at 0.95-1.0)
  /// - Post-Lunch Dip: 13:00 - 15:00 (~0.40)
  /// - Afternoon Secondary: 15:30 - 17:30 (~0.65)
  /// - Steep Wind-down: > 19:00 (< 0.35)
  static double _earlyBirdCapacity(double h) {
    if (h < 5.0) return _gaussian(h, 2.0, 3.0, 0.10, 0.15);
    if (h >= 5.0 && h < 12.0) {
      // Morning ramp and peak at 9.0
      return _gaussian(h, 9.0, 2.4, 0.40, 1.0);
    }
    if (h >= 12.0 && h < 15.5) {
      // Post-lunch dip centered at 14.0
      return _dip(h, 14.0, 1.5, 0.70, 0.40);
    }
    if (h >= 15.5 && h < 19.0) {
      // Afternoon recovery plateau
      return _gaussian(h, 16.5, 1.8, 0.45, 0.68);
    }
    // Evening decline
    return _gaussian(h, 18.5, 1.8, 0.10, 0.45);
  }

  /// Balanced (Bear):
  /// - Awakening 07:00
  /// - Prime Focus: 09:30 - 13:00 (peaks ~10:45 at 0.95-1.0)
  /// - Midday Slump: 13:30 - 15:30 (~0.42)
  /// - Afternoon Rebound: 16:00 - 18:30 (~0.76)
  /// - Wind-down: > 21:00 (< 0.30)
  static double _balancedCapacity(double h) {
    if (h < 6.5) return _gaussian(h, 3.0, 3.0, 0.10, 0.18);
    if (h >= 6.5 && h < 13.0) {
      // Morning ramp and prime focus peak at 10.75
      return _gaussian(h, 10.75, 2.3, 0.40, 1.0);
    }
    if (h >= 13.0 && h < 16.0) {
      // Slump centered at 14.5
      return _dip(h, 14.5, 1.4, 0.75, 0.42);
    }
    if (h >= 16.0 && h < 20.0) {
      // Afternoon rebound centered at 17.5
      return _gaussian(h, 17.5, 1.8, 0.48, 0.78);
    }
    // Night wind-down
    return _gaussian(h, 20.0, 2.5, 0.15, 0.50);
  }

  /// Night Owl (Wolf):
  /// - Slow wake-up / Sleep Inertia: 08:00 - 11:00 (0.25 - 0.45)
  /// - Midday Base: 11:30 - 14:30 (~0.68)
  /// - Afternoon Ramp: 15:00 - 18:00 (~0.78)
  /// - Golden Evening Peak: 18:30 - 23:30 (peaks ~21:00 at 0.95-1.0)
  /// - Creative Tail: 23:30 - 02:00 (~0.55-0.70)
  static double _nightOwlCapacity(double h) {
    if (h < 8.0) return _gaussian(h, 4.5, 3.0, 0.10, 0.20);
    if (h >= 8.0 && h < 12.0) {
      // Slow morning ramp-up
      final t = (h - 8.0) / 4.0;
      return 0.30 + (0.35 * t);
    }
    if (h >= 12.0 && h < 16.5) {
      // Midday plateau
      return _gaussian(h, 14.0, 2.5, 0.55, 0.72);
    }
    if (h >= 16.5 && h <= 24.0) {
      // Golden evening focus peak at 21.0
      return _gaussian(h, 21.0, 2.5, 0.50, 1.0);
    }
    return 0.20;
  }

  static double _gaussian(double x, double mean, double stdDev, double floor, double ceiling) {
    final diff = x - mean;
    final exp = math.exp(-(diff * diff) / (2 * stdDev * stdDev));
    final result = floor + ((ceiling - floor) * exp);
    return result.clamp(0.0, 1.0);
  }

  static double _dip(double x, double center, double width, double baseline, double dipTrough) {
    final diff = x - center;
    final factor = math.exp(-(diff * diff) / (2 * width * width));
    final result = baseline - ((baseline - dipTrough) * factor);
    return result.clamp(0.0, 1.0);
  }

  static String _formatHourMinute(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
