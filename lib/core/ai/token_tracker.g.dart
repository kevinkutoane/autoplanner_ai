// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_tracker.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AILogEntryAdapter extends TypeAdapter<AILogEntry> {
  @override
  final int typeId = 10;

  @override
  AILogEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AILogEntry(
      id: fields[0] as String,
      model: fields[1] as String,
      action: fields[2] as String,
      promptTokens: fields[3] as int,
      completionTokens: fields[4] as int,
      latencyMs: fields[5] as int,
      timestamp: fields[6] as DateTime,
      success: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AILogEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.model)
      ..writeByte(2)
      ..write(obj.action)
      ..writeByte(3)
      ..write(obj.promptTokens)
      ..writeByte(4)
      ..write(obj.completionTokens)
      ..writeByte(5)
      ..write(obj.latencyMs)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.success);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AILogEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
