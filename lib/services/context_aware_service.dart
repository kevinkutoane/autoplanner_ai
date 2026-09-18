import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/task_model.dart';
import '../core/utils/date_utils.dart';
import '../features/calendar/controllers/calendar_controller.dart';
import '../features/planner/controllers/task_controller.dart';

enum CircadianEnergyPhase {
  morningDeepWork,
  afternoonOperational,
  eveningCooldown,
}

class ContextualWindow {
  final Duration freeDuration;
  final String nextEventTitle;
  final DateTime nextEventStart;
  final List<TaskItem> fittingTasks;

  const ContextualWindow({
    required this.freeDuration,
    required this.nextEventTitle,
    required this.nextEventStart,
    required this.fittingTasks,
  });
}

class ContextAwareService {
  final Ref _ref;

  ContextAwareService(this._ref);

  /// Determines the current biological circadian focus phase.
  CircadianEnergyPhase get currentPhase {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      return CircadianEnergyPhase.morningDeepWork;
    } else if (hour >= 12 && hour < 17) {
      return CircadianEnergyPhase.afternoonOperational;
    } else {
      return CircadianEnergyPhase.eveningCooldown;
    }
  }

  String get phaseName {
    switch (currentPhase) {
      case CircadianEnergyPhase.morningDeepWork:
        return 'Peak Focus Window ⚡';
      case CircadianEnergyPhase.afternoonOperational:
        return 'Operational Window 💬';
      case CircadianEnergyPhase.eveningCooldown:
        return 'Review & Cooldown 🌙';
    }
  }

  /// Scans today's calendar and tasks to identify open time gaps before upcoming commitments.
  ContextualWindow? findNextMicroWinWindow() {
    final now = DateTime.now();
    final events = _ref.read(calendarControllerProvider);
    final tasks = _ref.read(taskControllerProvider);

    // Filter today's upcoming calendar events
    final todayEvents = events
        .where((e) => isSameDay(e.startTime, now) && e.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (todayEvents.isEmpty) return null;

    final nextEvent = todayEvents.first;
    final diff = nextEvent.startTime.difference(now);

    // We consider an open window between 10 minutes and 60 minutes
    if (diff.inMinutes < 10 || diff.inMinutes > 90) return null;

    final windowMinutes = diff.inMinutes;

    // Find pending tasks that comfortably fit inside this window
    final fittingTasks = tasks.where((t) {
      if (t.isCompleted) return false;
      final dur = t.durationMinutes > 0 ? t.durationMinutes : 25;
      return dur <= windowMinutes;
    }).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    if (fittingTasks.isEmpty) return null;

    return ContextualWindow(
      freeDuration: diff,
      nextEventTitle: nextEvent.title,
      nextEventStart: nextEvent.startTime,
      fittingTasks: fittingTasks.take(2).toList(),
    );
  }

  /// Re-orders task list according to circadian phase preference.
  List<TaskItem> rankTasksByCircadianFit(List<TaskItem> tasks) {
    final phase = currentPhase;
    final sorted = List<TaskItem>.from(tasks);

    sorted.sort((a, b) {
      final aDur = a.durationMinutes > 0 ? a.durationMinutes : 30;
      final bDur = b.durationMinutes > 0 ? b.durationMinutes : 30;

      if (phase == CircadianEnergyPhase.morningDeepWork) {
        // Prefer longer duration and high priority in morning
        final pDiff = b.priority.compareTo(a.priority);
        if (pDiff != 0) return pDiff;
        return bDur.compareTo(aDur);
      } else if (phase == CircadianEnergyPhase.eveningCooldown) {
        // Prefer shorter duration and lower priority in evening
        return aDur.compareTo(bDur);
      } else {
        // Afternoon: priority first
        return b.priority.compareTo(a.priority);
      }
    });

    return sorted;
  }
}

final contextAwareServiceProvider = Provider<ContextAwareService>((ref) {
  return ContextAwareService(ref);
});
