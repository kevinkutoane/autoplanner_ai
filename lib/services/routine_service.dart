import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/models/memory_entry_model.dart';
import '../core/models/task_model.dart';
import '../core/providers/providers.dart';
import '../core/utils/date_utils.dart';
import '../features/calendar/controllers/calendar_controller.dart';
import '../features/memory/controllers/memory_controller.dart';
import '../features/planner/controllers/task_controller.dart';
import '../services/gamification_service.dart';

const _uuid = Uuid();

class MorningBriefing {
  final String headline;
  final String message;
  final List<TaskItem> big3;
  final int meetingsCount;
  final double availableFocusHours;
  final int rolloverCount;

  const MorningBriefing({
    required this.headline,
    required this.message,
    required this.big3,
    required this.meetingsCount,
    required this.availableFocusHours,
    required this.rolloverCount,
  });
}

class EveningReview {
  final String headline;
  final String reflectionPrompt;
  final int completedTasks;
  final int totalTasks;
  final double completionRate;
  final int totalFocusMinutes;
  final List<TaskItem> pendingTasks;

  const EveningReview({
    required this.headline,
    required this.reflectionPrompt,
    required this.completedTasks,
    required this.totalTasks,
    required this.completionRate,
    required this.totalFocusMinutes,
    required this.pendingTasks,
  });
}

class RoutineService {
  final Ref _ref;

  RoutineService(this._ref);

  /// Generates the dynamic morning briefing, evaluating yesterday's incomplete
  /// tasks, today's calendar commitments, and picking the top 3 high-impact tasks.
  Future<MorningBriefing> generateMorningBriefing() async {
    final now = DateTime.now();
    final tasks = _ref.read(taskControllerProvider);
    final events = _ref.read(calendarControllerProvider);
    final settings = _ref.read(settingsProvider);

    // 1. Today's events
    final todayEvents =
        events.where((e) => isSameDay(e.startTime, now)).toList();

    // 2. Rollover tasks (tasks from before today that were never completed)
    final rolloverTasks = tasks.where((t) {
      if (t.isCompleted) return false;
      final tDate = DateTime(t.startTime.year, t.startTime.month, t.startTime.day);
      final todayDate = DateTime(now.year, now.month, now.day);
      return tDate.isBefore(todayDate);
    }).toList();

    // 3. Today's tasks
    final todayTasks = tasks.where((t) => isSameDay(t.startTime, now)).toList();

    // Combine pool of candidates
    final candidatePool = [...todayTasks, ...rolloverTasks];

    // Rank candidates by priority (High first), then deadline, then creation
    candidatePool.sort((a, b) {
      final pDiff = b.priority.compareTo(a.priority);
      if (pDiff != 0) return pDiff;
      if (a.deadline != null && b.deadline != null) {
        return a.deadline!.compareTo(b.deadline!);
      }
      return a.startTime.compareTo(b.startTime);
    });

    // The Big 3: unique top 3 tasks
    final seenIds = <String>{};
    final big3 = <TaskItem>[];
    for (final task in candidatePool) {
      if (!seenIds.contains(task.id) && !task.isCompleted) {
        seenIds.add(task.id);
        big3.add(task);
        if (big3.length == 3) break;
      }
    }

    // Available focus hours calculation
    final meetingMinutes = todayEvents.fold<int>(
      0,
      (sum, e) => sum + e.endTime.difference(e.startTime).inMinutes,
    );
    final totalWorkMinutes = settings.workHoursPerDay * 60;
    final availableMinutes = (totalWorkMinutes - meetingMinutes).clamp(0, totalWorkMinutes);
    final availableHours = availableMinutes / 60.0;

    // AI or heuristic briefing
    String headline = 'Rise & Conquer! ⚡';
    String message =
        'You have ${todayEvents.length} calendar events and ${availableHours.toStringAsFixed(1)}h of open focus time.';

    try {
      final aiService = _ref.read(aiServiceProvider);
      final prompt =
          'User morning briefing: ${todayEvents.length} meetings today, ${rolloverTasks.length} rollover tasks. '
          'The Big 3 priorities are: ${big3.map((t) => t.title).join(", ")}. '
          'Generate an inspiring, sharp 2-sentence morning greeting and focus recommendation.';
      final aiGreeting = await aiService.chatWithCoach(prompt, const []);
      if (aiGreeting.trim().isNotEmpty) {
        message = aiGreeting.trim();
      }
    } catch (_) {
      // Graceful fallback to deterministic high-vibrancy message
      if (todayEvents.length > 3) {
        headline = 'Heavy Meeting Day 📅';
        message =
            'Defend your focus blocks between ${todayEvents.length} meetings. Attack your Big 3 early!';
      } else if (big3.isNotEmpty) {
        headline = 'Prime Focus Day 🚀';
        message =
            'Light meeting schedule ahead with ${availableHours.toStringAsFixed(1)}h of flow time. Knock out ${big3.first.title} first.';
      }
    }

    return MorningBriefing(
      headline: headline,
      message: message,
      big3: big3,
      meetingsCount: todayEvents.length,
      availableFocusHours: availableHours,
      rolloverCount: rolloverTasks.length,
    );
  }

  /// Activates the morning plan: schedules any unassigned Big 3 tasks to today
  /// and awards morning routine XP.
  Future<void> activateMorningPlan(List<TaskItem> big3) async {
    final taskCtrl = _ref.read(taskControllerProvider.notifier);
    final now = DateTime.now();

    for (var i = 0; i < big3.length; i++) {
      final task = big3[i];
      // If task was from previous day, pull to today starting from 9am + offset
      if (!isSameDay(task.startTime, now)) {
        final newStart = DateTime(now.year, now.month, now.day, 9 + (i * 2), 0);
        final newEnd = newStart.add(Duration(minutes: task.durationMinutes > 0 ? task.durationMinutes : 60));
        taskCtrl.updateTask(task.copyWith(
          startTime: newStart,
          endTime: newEnd,
        ));
      }
    }

    // Award +50 XP and unlock morning warrior badge
    await _ref.read(gamificationServiceProvider.notifier).awardMorningRitual();
  }

  /// Evaluates today's productivity for the evening shutdown.
  EveningReview generateEveningReview() {
    final now = DateTime.now();
    final tasks = _ref.read(taskControllerProvider);
    final todayTasks = tasks.where((t) => isSameDay(t.startTime, now)).toList();

    final completed = todayTasks.where((t) => t.isCompleted).toList();
    final pending = todayTasks.where((t) => !t.isCompleted).toList();
    final totalFocus = completed.fold<int>(
      0,
      (sum, t) => sum + (t.actualDurationMinutes ?? t.durationMinutes),
    );

    final rate = todayTasks.isEmpty ? 1.0 : completed.length / todayTasks.length;

    String headline = 'Daily Shutdown 🌙';
    if (rate >= 0.8) {
      headline = 'Outstanding Day! 🌟';
    } else if (completed.isNotEmpty) {
      headline = 'Solid Momentum! ⚡';
    } else {
      headline = 'Rest & Recharge 🧘';
    }

    const reflectionPrompt = 'What was your single biggest win or learning today?';

    return EveningReview(
      headline: headline,
      reflectionPrompt: reflectionPrompt,
      completedTasks: completed.length,
      totalTasks: todayTasks.length,
      completionRate: rate,
      totalFocusMinutes: totalFocus,
      pendingTasks: pending,
    );
  }

  /// Executes daily shutdown: rolls over or backlogs unfinished tasks, saves
  /// reflection memory, and awards evening shutdown XP.
  Future<void> executeEveningShutdown({
    required List<String> rolloverTaskIds,
    required List<String> backlogTaskIds,
    required List<String> discardTaskIds,
    String? reflectionNote,
  }) async {
    final taskCtrl = _ref.read(taskControllerProvider.notifier);
    final tasks = _ref.read(taskControllerProvider);
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    // 1. Rollover tasks to tomorrow 9:00 AM
    for (final id in rolloverTaskIds) {
      final matches = tasks.where((t) => t.id == id);
      if (matches.isNotEmpty) {
        final task = matches.first;
        final newStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
        final newEnd = newStart.add(Duration(minutes: task.durationMinutes > 0 ? task.durationMinutes : 60));
        taskCtrl.updateTask(task.copyWith(startTime: newStart, endTime: newEnd));
      }
    }

    // 2. Move to Backlog (push far out / clear schedule)
    for (final id in backlogTaskIds) {
      final matches = tasks.where((t) => t.id == id);
      if (matches.isNotEmpty) {
        final task = matches.first;
        final backlogDate = DateTime(2099, 1, 1);
        taskCtrl.updateTask(task.copyWith(startTime: backlogDate, endTime: backlogDate));
      }
    }

    // 3. Discard tasks
    for (final id in discardTaskIds) {
      taskCtrl.removeTask(id);
    }

    // 4. Record reflection in MemoryService
    if (reflectionNote != null && reflectionNote.trim().isNotEmpty) {
      final memoryCtrl = _ref.read(memoryControllerProvider.notifier);
      memoryCtrl.addMemory(
        MemoryEntry(
          id: _uuid.v4(),
          content: 'Daily Reflection: ${reflectionNote.trim()}',
          createdAt: DateTime.now(),
          tags: ['reflection', 'daily_shutdown', 'routine'],
          sourceType: 'routine',
          sourceId: 'evening_shutdown',
        ),
      );
    }

    // 5. Award +50 XP and unlock zen master badge
    await _ref.read(gamificationServiceProvider.notifier).awardEveningRitual();
  }
}

final routineServiceProvider = Provider<RoutineService>((ref) {
  return RoutineService(ref);
});
