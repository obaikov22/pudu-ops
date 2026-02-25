// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TemplateTaskAdapter extends TypeAdapter<TemplateTask> {
  @override
  final int typeId = 4;

  @override
  TemplateTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemplateTask(
      label: fields[0] as String,
      cores: (fields[1] as List).cast<String>(),
      durationMinutes: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TemplateTask obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.label)
      ..writeByte(1)
      ..write(obj.cores)
      ..writeByte(2)
      ..write(obj.durationMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TemplateAdapter extends TypeAdapter<Template> {
  @override
  final int typeId = 3;

  @override
  Template read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Template(
      id: fields[0] as String,
      name: fields[1] as String,
      robotId: fields[2] as String,
      floor: fields[3] as String,
      tasks: (fields[4] as List).cast<TemplateTask>(),
      startMinutes: fields[5] as int,
      enabled: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Template obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.robotId)
      ..writeByte(3)
      ..write(obj.floor)
      ..writeByte(4)
      ..write(obj.tasks)
      ..writeByte(5)
      ..write(obj.startMinutes)
      ..writeByte(6)
      ..write(obj.enabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
