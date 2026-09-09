// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskItemAdapter extends TypeAdapter<TaskItem> {
  @override
  final int typeId = 0;

  @override
  TaskItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskItem(
      id: fields[0] as String,
      title: fields[1] as String,
      startTime: fields[2] as DateTime,
      endTime: fields[3] as DateTime?,
      note: fields[4] as String?,
      isCompleted: fields[5] as bool? ?? false,
      priority: fields[6] as int? ?? 1,
      tags: (fields[7] as List?)?.cast<String>() ?? const [],
      linkedNoteIds: (fields[8] as List?)?.cast<String>() ?? const [],
      recurrence: fields[9] as String?,
      recurrenceDays: (fields[10] as List?)?.cast<int>() ?? const [],
      linkedGoalId: fields[11] as String?,
      deadline: fields[12] as DateTime?,
      earliestStart: fields[13] as DateTime?,
      latestFinish: fields[14] as DateTime?,
      isFixed: fields[15] as bool? ?? false,
      energyLevel: fields[16] as String?,
      preferredTimeOfDay: fields[17] as String?,
      splittable: fields[18] as bool? ?? false,
      preferredBlockMinutes: fields[19] as int?,
      dependsOnTaskIds: (fields[20] as List?)?.cast<String>() ?? const [],
      linkedProjectId: fields[21] as String?,
      parentTaskId: fields[22] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskItem obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.tags)
      ..writeByte(8)
      // ignore: deprecated_member_use_from_same_package
      ..write(obj.linkedNoteIds)
      ..writeByte(9)
      ..write(obj.recurrence)
      ..writeByte(10)
      ..write(obj.recurrenceDays)
      ..writeByte(11)
      ..write(obj.linkedGoalId)
      ..writeByte(12)
      ..write(obj.deadline)
      ..writeByte(13)
      ..write(obj.earliestStart)
      ..writeByte(14)
      ..write(obj.latestFinish)
      ..writeByte(15)
      ..write(obj.isFixed)
      ..writeByte(16)
      ..write(obj.energyLevel)
      ..writeByte(17)
      ..write(obj.preferredTimeOfDay)
      ..writeByte(18)
      ..write(obj.splittable)
      ..writeByte(19)
      ..write(obj.preferredBlockMinutes)
      ..writeByte(20)
      ..write(obj.dependsOnTaskIds)
      ..writeByte(21)
      ..write(obj.linkedProjectId)
      ..writeByte(22)
      ..write(obj.parentTaskId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
