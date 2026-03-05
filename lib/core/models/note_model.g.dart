// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_model.dart';

class NoteItemAdapter extends TypeAdapter<NoteItem> {
  @override
  final int typeId = 1;

  @override
  NoteItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NoteItem(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      summary: fields[3] as String?,
      tags: (fields[4] as List?)?.cast<String>() ?? [],
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      linkedTaskIds: (fields[7] as List?)?.cast<String>() ?? [],
      isPinned: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, NoteItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.summary)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.linkedTaskIds)
      ..writeByte(8)
      ..write(obj.isPinned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
