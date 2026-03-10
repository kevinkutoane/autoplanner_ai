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
      isCompleted: (fields[5] as bool?) ?? false,
      priority: (fields[6] as int?) ?? 1,
      tags: (fields[7] as List?)?.cast<String>() ?? [],
      linkedNoteIds: (fields[8] as List?)?.cast<String>() ?? [],
      recurrence: fields[9] as String?,
      recurrenceDays: (fields[10] as List?)?.cast<int>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, TaskItem obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.linkedNoteIds)
      ..writeByte(9)
      ..write(obj.recurrence)
      ..writeByte(10)
      ..write(obj.recurrenceDays);
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
