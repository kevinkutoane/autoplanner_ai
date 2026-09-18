import 'package:flutter/foundation.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';

/// Represents the active state of an immersive focus execution session.
@immutable
class FocusSessionState {
  final TaskItem? task;
  final int targetSeconds;
  final int elapsedSeconds;
  final bool isRunning;
  final bool isPaused;
  final bool isFinished;
  final List<String> distractionNotes;
  final DateTime? startedAt;
  final int pausesCount;

  const FocusSessionState({
    this.task,
    this.targetSeconds = 25 * 60,
    this.elapsedSeconds = 0,
    this.isRunning = false,
    this.isPaused = false,
    this.isFinished = false,
    this.distractionNotes = const [],
    this.startedAt,
    this.pausesCount = 0,
  });

  /// Fraction of session completed: [0.0, 1.0].
  double get progress {
    if (targetSeconds <= 0) return 1.0;
    return (elapsedSeconds / targetSeconds).clamp(0.0, 1.0);
  }

  /// Remaining seconds in countdown mode.
  int get remainingSeconds =>
      (targetSeconds - elapsedSeconds).clamp(0, targetSeconds);

  /// Whether the session has exceeded the planned target duration.
  bool get isOvertime => elapsedSeconds > targetSeconds;

  /// Overtime seconds if the user is working past the planned target.
  int get overtimeSeconds =>
      isOvertime ? elapsedSeconds - targetSeconds : 0;

  /// Elapsed focus time rounded to whole minutes (minimum 1 minute if started).
  int get elapsedMinutes {
    if (elapsedSeconds <= 0) return 0;
    return (elapsedSeconds / 60).ceil();
  }

  FocusSessionState copyWith({
    TaskItem? task,
    int? targetSeconds,
    int? elapsedSeconds,
    bool? isRunning,
    bool? isPaused,
    bool? isFinished,
    List<String>? distractionNotes,
    DateTime? startedAt,
    int? pausesCount,
  }) {
    return FocusSessionState(
      task: task ?? this.task,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      isFinished: isFinished ?? this.isFinished,
      distractionNotes: distractionNotes ?? this.distractionNotes,
      startedAt: startedAt ?? this.startedAt,
      pausesCount: pausesCount ?? this.pausesCount,
    );
  }

  static const initial = FocusSessionState();
}
