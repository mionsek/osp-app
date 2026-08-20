// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VehicleAdapter extends TypeAdapter<Vehicle> {
  @override
  final int typeId = 0;

  @override
  Vehicle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Vehicle(
      id: fields[0] as String,
      name: fields[1] as String,
      seats: fields[2] as int,
      make: fields[3] == null ? '' : fields[3] as String,
      model: fields[4] == null ? '' : fields[4] as String,
      kind: fields[5] == null ? '' : fields[5] as String,
      plate: fields[6] == null ? '' : fields[6] as String,
      operationalNumber: fields[7] == null ? '' : fields[7] as String,
      fuelType: fields[8] == null ? '' : fields[8] as String,
      fuelPer100Km: fields[9] as double?,
      pumpFuelPerHour: fields[10] as double?,
      idleFuelPerMinute: fields[11] as double?,
      startupFuelPerMonth: fields[12] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Vehicle obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.seats)
      ..writeByte(3)
      ..write(obj.make)
      ..writeByte(4)
      ..write(obj.model)
      ..writeByte(5)
      ..write(obj.kind)
      ..writeByte(6)
      ..write(obj.plate)
      ..writeByte(7)
      ..write(obj.operationalNumber)
      ..writeByte(8)
      ..write(obj.fuelType)
      ..writeByte(9)
      ..write(obj.fuelPer100Km)
      ..writeByte(10)
      ..write(obj.pumpFuelPerHour)
      ..writeByte(11)
      ..write(obj.idleFuelPerMinute)
      ..writeByte(12)
      ..write(obj.startupFuelPerMonth);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
