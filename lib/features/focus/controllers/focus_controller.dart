import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/features/focus/models/focus_state.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';
import 'package:autoplanner_ai/services/gamification_service.dart';

/// Manages active Focus Mode sessions, countdown ticks, distraction logs,
/// and actual duration persistence upon task completion.
class FocusController extends Notifier<FocusSessionState> {
  Timer? _ticker;

  @override
  FocusSessionState build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return FocusSessionState.initial;
  }

  /// Start a deep focus session for [task].
  ///
  /// [targetMinutes] overrides the task's scheduled duration if specified.
  void startSession(TaskItem task, {int? targetMinutes}) {
    _ticker?.cancel();
    final plannedMinutes = targetMinutes ?? task.durationMinutes;
    final totalSecs = (plannedMinutes > 0 ? plannedMinutes : 25) * 60;

    HapticFeedback.mediumImpact();
    state = FocusSessionState(
      task: task,
      targetSeconds: totalSecs,
      elapsedSeconds: 0,
      isRunning: true,
      isPaused: false,
      isFinished: false,
      startedAt: DateTime.now(),
      distractionNotes: [],
      pausesCount: 0,
    );

    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isRunning && !state.isPaused) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);

        // Tactile alert when countdown reaches zero
        if (state.elapsedSeconds == state.targetSeconds) {
          HapticFeedback.vibrate();
        }
      }
    });
  }

  /// Pause current session.
  void pause() {
    if (!state.isRunning || state.isPaused) return;
    _ticker?.cancel();
    HapticFeedback.selectionClick();
    state = state.copyWith(
      isRunning: false,
      isPaused: true,
      pausesCount: state.pausesCount + 1,
    );
  }

  /// Resume paused session.
  void resume() {
    if (!state.isPaused) return;
    HapticFeedback.selectionClick();
    state = state.copyWith(isRunning: true, isPaused: false);
    _startTicker();
  }

  /// Extend session by [minutes].
  void addMinutes(int minutes) {
    if (minutes <= 0) return;
    HapticFeedback.lightImpact();
    state = state.copyWith(targetSeconds: state.targetSeconds + (minutes * 60));
  }

  /// Log a quick distraction thought without leaving deep focus.
  void logDistraction(String note) {
    final clean = note.trim();
    if (clean.isEmpty) return;
    HapticFeedback.lightImpact();
    state = state.copyWith(
      distractionNotes: [...state.distractionNotes, clean],
    );
  }

  /// Complete the current focus session, persist actual duration,
  /// and mark the underlying task as completed.
  TaskItem? completeSession() {
    final currentTask = state.task;
    if (currentTask == null) return null;

    _ticker?.cancel();
    HapticFeedback.heavyImpact();

    final actualMins = state.elapsedMinutes > 0 ? state.elapsedMinutes : 1;
    final updatedTask = currentTask.copyWith(
      isCompleted: true,
      actualDurationMinutes: actualMins,
      completedAt: DateTime.now(),
      focusSessionsCount: currentTask.focusSessionsCount + 1,
    );

    // Persist via TaskController
    ref.read(taskControllerProvider.notifier).updateTask(updatedTask);
    ref
        .read(gamificationServiceProvider.notifier)
        .awardFocusMinutes(actualMins);

    state = state.copyWith(
      task: updatedTask,
      isRunning: false,
      isPaused: false,
      isFinished: true,
    );

    return updatedTask;
  }

  /// Discard or abort the active session.
  void cancelSession() {
    _ticker?.cancel();
    HapticFeedback.selectionClick();
    state = FocusSessionState.initial;
  }
}

final focusControllerProvider =
    NotifierProvider<FocusController, FocusSessionState>(FocusController.new);
