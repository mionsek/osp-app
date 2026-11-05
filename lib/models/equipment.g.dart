// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EquipmentAdapter extends TypeAdapter<Equipment> {
  @override
  final int typeId = 9;

  @override
  Equipment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Equipment(
      id: fields[0] as String,
      name: fields[1] as String,
      vehicleId: fields[2] as String?,
      poweredByVehicle: fields[3] == null ? false : fields[3] as bool,
      fuelType: fields[4] == null ? '' : fields[4] as String,
      fuelPerHour: fields[5] as double?,
      model: fields[6] == null ? '' : fields[6] as String,
      serialNumber: fields[7] == null ? '' : fields[7] as String,
      updatedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Equipment obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.vehicleId)
      ..writeByte(3)
      ..write(obj.poweredByVehicle)
      ..writeByte(4)
      ..write(obj.fuelType)
      ..writeByte(5)
      ..write(obj.fuelPerHour)
      ..writeByte(6)
      ..write(obj.model)
      ..writeByte(7)
      ..write(obj.serialNumber)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
