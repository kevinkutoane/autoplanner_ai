import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autoplanner_ai/features/focus/controllers/focus_controller.dart';
import 'package:autoplanner_ai/features/focus/models/focus_recommendation.dart';
import 'package:autoplanner_ai/features/planner/controllers/task_controller.dart';

/// Evaluates current wall-clock time, active focus sessions, task start/end times,
/// priorities, deadlines, and energy levels to recommend the single optimal next task.
final focusRecommendationProvider = Provider<FocusRecommendation?>((ref) {
  final focusState = ref.watch(focusControllerProvider);
  final allTasks = ref.watch(taskControllerProvider);

  // 1. If a focus session is already running/paused, keep that task recommended
  if (focusState.task != null && !focusState.isFinished) {
    return FocusRecommendation(
      task: focusState.task!,
      type: RecommendationType.activeNow,
      title: focusState.task!.title,
      subtitle: focusState.isPaused
          ? 'Focus session paused (${focusState.remainingSeconds ~/ 60}m remaining)'
          : 'Focus session in progress (${focusState.remainingSeconds ~/ 60}m remaining)',
    );
  }

  final now = clock.now();

  // Filter tasks for today that are not completed
  final todayPending = allTasks.where((t) {
    if (t.isCompleted) return false;
    return t.startTime.year == now.year &&
        t.startTime.month == now.month &&
        t.startTime.day == now.day;
  }).toList();

  if (todayPending.isEmpty) {
    // Check if there are any pending tasks at all in the system
    final generalPending = allTasks.where((t) => !t.isCompleted).toList();
    if (generalPending.isEmpty) return null;

    generalPending.sort((a, b) => b.priority.compareTo(a.priority));
    final top = generalPending.first;
    return FocusRecommendation(
      task: top,
      type: RecommendationType.highestPriority,
      title: top.title,
      subtitle: 'Priority ${top.priorityLabel} • Ready to schedule or execute',
    );
  }

  // 2. Check if a task is scheduled right now (now is between start and end)
  final currentlyActive = todayPending.where((t) {
    final start = t.startTime;
    final end = t.endTime ?? start.add(Duration(minutes: t.durationMinutes));
    return now.isAfter(start.subtract(const Duration(minutes: 5))) &&
        now.isBefore(end);
  }).toList();

  if (currentlyActive.isNotEmpty) {
    // If multiple, pick highest priority
    currentlyActive.sort((a, b) => b.priority.compareTo(a.priority));
    final active = currentlyActive.first;
    final endStr = active.endTime != null
        ? '${active.endTime!.hour.toString().padLeft(2, '0')}:${active.endTime!.minute.toString().padLeft(2, '0')}'
        : '';
    return FocusRecommendation(
      task: active,
      type: RecommendationType.activeNow,
      title: active.title,
      subtitle: endStr.isNotEmpty
          ? 'Scheduled until $endStr (${active.durationMinutes}m focus)'
          : 'Scheduled for now (${active.durationMinutes}m focus)',
    );
  }

  // 3. Check for upcoming task starting within next 45 minutes
  final upcoming = todayPending.where((t) {
    final diff = t.startTime.difference(now).inMinutes;
    return diff >= 0 && diff <= 45;
  }).toList();

  if (upcoming.isNotEmpty) {
    upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
    final next = upcoming.first;
    final minsUntil = next.startTime.difference(now).inMinutes;
    return FocusRecommendation(
      task: next,
      type: RecommendationType.upcomingSoon,
      title: next.title,
      subtitle: minsUntil == 0
          ? 'Starting now (${next.durationMinutes}m)'
          : 'Starts in $minsUntil mins (${next.durationMinutes}m block)',
      minutesUntilStart: minsUntil,
    );
  }

  // 4. Energy level matching for current time of day
  // Morning (before 12:00) -> High energy
  // Afternoon (12:00 - 17:00) -> Medium energy
  // Evening (after 17:00) -> Low energy
  final String targetEnergy = now.hour < 12
      ? 'high'
      : now.hour < 17
          ? 'medium'
          : 'low';

  final energyMatches = todayPending
      .where((t) => t.energyLevel?.toLowerCase() == targetEnergy)
      .toList();

  if (energyMatches.isNotEmpty) {
    energyMatches.sort((a, b) => b.priority.compareTo(a.priority));
    final match = energyMatches.first;
    return FocusRecommendation(
      task: match,
      type: RecommendationType.energyMatch,
      title: match.title,
      subtitle: 'Optimal for your $targetEnergy energy window (${match.durationMinutes}m)',
    );
  }

  // 5. Fallback: highest priority pending task for today
  todayPending.sort((a, b) {
    final pComp = b.priority.compareTo(a.priority);
    if (pComp != 0) return pComp;
    return a.startTime.compareTo(b.startTime);
  });

  final fallback = todayPending.first;
  return FocusRecommendation(
    task: fallback,
    type: RecommendationType.highestPriority,
    title: fallback.title,
    subtitle: 'Priority ${fallback.priorityLabel} • ${fallback.durationMinutes}m scheduled',
  );
});
