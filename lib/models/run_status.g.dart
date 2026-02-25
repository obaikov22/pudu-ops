// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RunStatusAdapter extends TypeAdapter<RunStatus> {
  @override
  final int typeId = 2;

  @override
  RunStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RunStatus.active;
      case 1:
        return RunStatus.awaitingPickup;
      case 2:
        return RunStatus.completed;
      default:
        return RunStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, RunStatus obj) {
    switch (obj) {
      case RunStatus.active:
        writer.writeByte(0);
        break;
      case RunStatus.awaitingPickup:
        writer.writeByte(1);
        break;
      case RunStatus.completed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
