import 'package:hive/hive.dart';

part 'calendar_event_model.g.dart';

@HiveType(typeId: 2)
class CalendarEvent extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime startTime;

  @HiveField(4)
  DateTime endTime;

  @HiveField(5)
  String source; // 'local', 'google', 'outlook'

  @HiveField(6)
  String? linkedTaskId;

  @HiveField(7)
  int colorValue;

  @HiveField(8)
  bool isAllDay;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.source = 'local',
    this.linkedTaskId,
    this.colorValue = 0xFF4CAF50,
    this.isAllDay = false,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? source,
    String? linkedTaskId,
    int? colorValue,
    bool? isAllDay,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      source: source ?? this.source,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      colorValue: colorValue ?? this.colorValue,
      isAllDay: isAllDay ?? this.isAllDay,
    );
  }
}
