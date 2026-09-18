import 'package:autoplanner_ai/core/models/task_model.dart';

enum RecommendationType {
  activeNow,
  upcomingSoon,
  highestPriority,
  energyMatch,
}

/// Structured recommendation for the "What Should I Do Now?" smart action hero.
class FocusRecommendation {
  final TaskItem task;
  final RecommendationType type;
  final String title;
  final String subtitle;
  final int? minutesUntilStart;

  const FocusRecommendation({
    required this.task,
    required this.type,
    required this.title,
    required this.subtitle,
    this.minutesUntilStart,
  });

  String get typeBadge {
    switch (type) {
      case RecommendationType.activeNow:
        return 'CURRENT TASK';
      case RecommendationType.upcomingSoon:
        return 'UPCOMING SOON';
      case RecommendationType.highestPriority:
        return 'PRIORITY PICK';
      case RecommendationType.energyMatch:
        return 'ENERGY MATCH';
    }
  }
}
