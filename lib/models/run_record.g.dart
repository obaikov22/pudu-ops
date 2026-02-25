// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RunRecordAdapter extends TypeAdapter<RunRecord> {
  @override
  final int typeId = 1;

  @override
  RunRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RunRecord(
      id: fields[0] as String,
      robotId: fields[1] as String,
      startedAt: fields[2] as DateTime,
      finishedAt: fields[3] as DateTime?,
      plannedMinutes: fields[4] as int,
      status: fields[5] as RunStatus,
      createdAt: fields[6] as DateTime,
      templateId: fields[7] as String?,
      stepSummary: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RunRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.robotId)
      ..writeByte(2)
      ..write(obj.startedAt)
      ..writeByte(3)
      ..write(obj.finishedAt)
      ..writeByte(4)
      ..write(obj.plannedMinutes)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.templateId)
      ..writeByte(8)
      ..write(obj.stepSummary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
