// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'robot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RobotAdapter extends TypeAdapter<Robot> {
  @override
  final int typeId = 0;

  @override
  Robot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Robot(
      id: fields[0] as String,
      name: fields[1] as String,
      floor: fields[2] as String,
      enabled: fields[3] as bool,
      selectedForToday: fields[4] as bool,
      createdAt: fields[5] as DateTime?,
      note: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Robot obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.floor)
      ..writeByte(3)
      ..write(obj.enabled)
      ..writeByte(4)
      ..write(obj.selectedForToday)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RobotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
