// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_monitor_service.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppEventAdapter extends TypeAdapter<AppEvent> {
  @override
  final int typeId = 11;

  @override
  AppEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppEvent(
      id: fields[0] as String,
      type: fields[1] as String,
      message: fields[2] as String,
      detail: fields[3] as String,
      timestamp: fields[4] as DateTime,
      durationMs: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AppEvent obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.message)
      ..writeByte(3)
      ..write(obj.detail)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.durationMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
