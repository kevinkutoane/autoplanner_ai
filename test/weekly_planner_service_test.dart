import 'package:flutter_test/flutter_test.dart';

import 'package:autoplanner_ai/core/models/calendar_event_model.dart';
import 'package:autoplanner_ai/core/models/task_model.dart';
import 'package:autoplanner_ai/services/weekly_planner_service.dart';

void main() {
  late WeeklyPlannerService service;
  final monday = DateTime(2026, 10, 5); // A Monday

  setUp(() {
    service = WeeklyPlannerService();
  });

  group('WeeklyPlannerService Multi-Day Capacity Balancing', () {
    test('distributes tasks across 5-day work week evenly', () {
      final tasks = List.generate(
        10,
        (i) => TaskItem(
          id: 'task_$i',
          title: 'General Task $i',
          startTime: monday,
          endTime: monday.add(const Duration(minutes: 60)),
        ),
      );

      final result = service.planWeek(
        tasks: tasks,
        weekStart: monday,
        daysCount: 5,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      expect(result.allScheduledTasks.length, 10);
      expect(result.unplacedTasks, isEmpty);

      // Verify tasks are spread across multiple days rather than stacked on Monday
      final daysWithTasks = result.dayAllocations.values
          .where((list) => list.isNotEmpty)
          .length;
      expect(daysWithTasks, greaterThanOrEqualTo(3));
      expect(result.balanceScore, greaterThan(60.0));
    });

    test('routes deep work tasks to light-meeting days and shallow tasks to meeting-heavy days', () {
      final tuesday = monday.add(const Duration(days: 1));

      // Tuesday is meeting-heavy (4.5 hours of meetings)
      final tuesdayMeeting = CalendarEvent(
        id: 'meeting_tue',
        title: 'Executive Strategic Planning',
        startTime: DateTime(tuesday.year, tuesday.month, tuesday.day, 9, 30),
        endTime: DateTime(tuesday.year, tuesday.month, tuesday.day, 14, 0),
      );

      final deepWorkTask = TaskItem(
        id: 'deep_1',
        title: 'Refactor Core Architecture Engine',
        startTime: monday,
        endTime: monday.add(const Duration(minutes: 180)),
        priority: 3,
        energyLevel: 'high',
        tags: ['architecture', 'coding'],
      );

      final shallowTask = TaskItem(
        id: 'shallow_1',
        title: 'Submit Expense Receipts and Triage Email',
        startTime: monday,
        endTime: monday.add(const Duration(minutes: 45)),
        priority: 0,
        energyLevel: 'low',
        tags: ['admin', 'email'],
      );

      final result = service.planWeek(
        tasks: [deepWorkTask, shallowTask],
        weekStart: monday,
        daysCount: 5,
        workStartHour: 9,
        workHoursPerDay: 8,
        calendarEvents: [tuesdayMeeting],
      );

      // Deep work should be placed on a day OTHER than Tuesday
      final tuesdayTasks = result.dayAllocations[tuesday] ?? [];
      final hasDeepWorkOnTuesday =
          tuesdayTasks.any((t) => t.id == 'deep_1');
      expect(hasDeepWorkOnTuesday, isFalse);

      // Notice should flag Tuesday as meeting-heavy
      final hasNotice = result.notices.any(
        (n) => n.type == 'meeting_heavy' && n.date == tuesday,
      );
      expect(hasNotice, isTrue);
    });

    test('strictly respects task deadlines across days', () {
      final wednesday = monday.add(const Duration(days: 2));

      final urgentTask = TaskItem(
        id: 'urgent_deadline',
        title: 'Submit Compliance Report',
        startTime: monday,
        endTime: monday.add(const Duration(minutes: 60)),
        deadline: DateTime(wednesday.year, wednesday.month, wednesday.day, 17, 0),
        priority: 3,
      );

      final result = service.planWeek(
        tasks: [urgentTask],
        weekStart: monday,
        daysCount: 5,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final scheduled = result.allScheduledTasks.firstWhere(
        (t) => t.id == 'urgent_deadline',
      );
      final scheduledDay = DateTime(
        scheduled.startTime.year,
        scheduled.startTime.month,
        scheduled.startTime.day,
      );

      // Must be scheduled on or before Wednesday
      expect(scheduledDay.isAfter(wednesday), isFalse);
    });

    test('preserves DAG dependencies across multiple days', () {
      final prereqTask = TaskItem(
        id: 'prereq',
        title: 'Write API Specification',
        startTime: monday,
        endTime: monday.add(const Duration(minutes: 120)),
        isFixed: true, // Fixed on Monday
      );

      final dependentTask = TaskItem(
        id: 'dependent',
        title: 'Implement Client Consumer',
        startTime: monday,
        endTime: monday.add(const Duration(minutes: 120)),
        dependsOnTaskIds: ['prereq'],
      );

      final result = service.planWeek(
        tasks: [prereqTask, dependentTask],
        weekStart: monday,
        daysCount: 5,
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final schedPrereq = result.allScheduledTasks.firstWhere((t) => t.id == 'prereq');
      final schedDep = result.allScheduledTasks.firstWhere((t) => t.id == 'dependent');

      expect(schedDep.startTime.isBefore(schedPrereq.endTime!), isFalse);
    });
  });

  group('WeeklyPlannerService Mid-Week Recovery (replanWeek)', () {
    test('rebalances uncompleted tasks from past days into remaining days of the week', () {
      final wednesday = monday.add(const Duration(days: 2));

      // Slipped task from Monday
      final missedMondayTask = TaskItem(
        id: 'missed_mon',
        title: 'Review System Metrics',
        startTime: DateTime(monday.year, monday.month, monday.day, 10, 0),
        endTime: DateTime(monday.year, monday.month, monday.day, 11, 0),
        isCompleted: false,
      );

      // Task scheduled for Thursday
      final thursdayTask = TaskItem(
        id: 'thurs_task',
        title: 'Client Demo',
        startTime: DateTime(monday.year, monday.month, monday.day + 3, 14, 0),
        endTime: DateTime(monday.year, monday.month, monday.day + 3, 15, 0),
        isCompleted: false,
      );

      final result = service.replanWeek(
        allTasks: [missedMondayTask, thursdayTask],
        currentDay: wednesday,
        daysCount: 4, // Wed, Thu, Fri, Sat
        workStartHour: 9,
        workHoursPerDay: 8,
      );

      final replannedMissed = result.allScheduledTasks.firstWhere(
        (t) => t.id == 'missed_mon',
      );
      final replannedDay = DateTime(
        replannedMissed.startTime.year,
        replannedMissed.startTime.month,
        replannedMissed.startTime.day,
      );

      // Missed task is now rescheduled on or after Wednesday
      expect(replannedDay.isBefore(wednesday), isFalse);

      // Mid-week recovery notice is present
      expect(
        result.notices.any((n) => n.type == 'midweek_recovery'),
        isTrue,
      );
    });
  });

  group('WeeklyPlannerService Planning Debt Diagnostics', () {
    test('detects overdue and zombie tasks and computes debt index', () {
      final now = DateTime(2026, 10, 15);

      final overdueTask = TaskItem(
        id: 'overdue_1',
        title: 'Submit Taxes',
        startTime: now.subtract(const Duration(days: 3)),
        endTime: now.subtract(const Duration(days: 3, hours: -1)),
        deadline: now.subtract(const Duration(days: 1)),
        isCompleted: false,
      );

      final zombieTask = TaskItem(
        id: 'zombie_1',
        title: 'Organize Digital Files',
        startTime: now.subtract(const Duration(days: 10)),
        endTime: now.subtract(const Duration(days: 10, hours: -1)),
        isCompleted: false,
      );

      final freshTask = TaskItem(
        id: 'fresh_1',
        title: 'Today Task',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        isCompleted: false,
      );

      final report = service.calculatePlanningDebt(
        tasks: [overdueTask, zombieTask, freshTask],
        currentTime: now,
      );

      expect(report.overdueTasks.length, 1);
      expect(report.zombieTasks.length, 1);
      expect(report.debtIndex, greaterThan(25.0));
      expect(report.recommendations, isNotEmpty);
    });
  });

  group('WeeklyPlannerService Capacity Summaries', () {
    test('accurately calculates meeting vs task minutes and capacity status', () {
      final meeting = CalendarEvent(
        id: 'm1',
        title: 'Sprint Planning',
        startTime: DateTime(monday.year, monday.month, monday.day, 9, 0),
        endTime: DateTime(monday.year, monday.month, monday.day, 12, 0), // 180 min
      );

      final task = TaskItem(
        id: 't1',
        title: 'Write Tests',
        startTime: DateTime(monday.year, monday.month, monday.day, 13, 0),
        endTime: DateTime(monday.year, monday.month, monday.day, 15, 0), // 120 min
      );

      final summaries = service.getWeeklyCapacitySummaries(
        tasks: [task],
        weekStart: monday,
        daysCount: 1,
        workStartHour: 9,
        workHoursPerDay: 8, // 480 min
        calendarEvents: [meeting],
      );

      final daySummary = summaries.first;
      expect(daySummary.calendarEventsMinutes, 180);
      expect(daySummary.scheduledTasksMinutes, 120);
      expect(daySummary.totalAllocatedMinutes, 300);
      expect(daySummary.freeMinutes, 180);
      expect(daySummary.capacityRatio, closeTo(300 / 480, 0.01));
      expect(daySummary.status, DailyCapacityStatus.optimal);
    });
  });
}
