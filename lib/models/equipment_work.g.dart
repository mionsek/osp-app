// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipment_work.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EquipmentWorkAdapter extends TypeAdapter<EquipmentWork> {
  @override
  final int typeId = 10;

  @override
  EquipmentWork read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EquipmentWork(
      id: fields[0] as String,
      equipmentId: fields[1] as String,
      equipmentName: fields[2] as String,
      date: fields[3] as DateTime,
      minutes: fields[4] as int,
      isStartup: fields[5] as bool,
      purpose: fields[6] as String,
      operatorName: fields[7] as String,
      operatorId: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
      createdBy: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EquipmentWork obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.equipmentId)
      ..writeByte(2)
      ..write(obj.equipmentName)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.minutes)
      ..writeByte(5)
      ..write(obj.isStartup)
      ..writeByte(6)
      ..write(obj.purpose)
      ..writeByte(7)
      ..write(obj.operatorName)
      ..writeByte(8)
      ..write(obj.operatorId)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.createdBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentWorkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
