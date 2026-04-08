// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crew_assignment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CrewAssignmentAdapter extends TypeAdapter<CrewAssignment> {
  @override
  final int typeId = 2;

  @override
  CrewAssignment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CrewAssignment(
      vehicleId: fields[0] as String,
      vehicleName: fields[1] as String,
      driverId: fields[2] as String?,
      commanderId: fields[3] as String?,
      crewMemberIds: (fields[4] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, CrewAssignment obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.vehicleId)
      ..writeByte(1)
      ..write(obj.vehicleName)
      ..writeByte(2)
      ..write(obj.driverId)
      ..writeByte(3)
      ..write(obj.commanderId)
      ..writeByte(4)
      ..write(obj.crewMemberIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrewAssignmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
