// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_trip.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VehicleTripAdapter extends TypeAdapter<VehicleTrip> {
  @override
  final int typeId = 7;

  @override
  VehicleTrip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VehicleTrip(
      id: fields[0] as String,
      vehicleId: fields[1] as String,
      date: fields[2] as DateTime,
      dispatcherName: fields[3] as String,
      routeFrom: fields[4] as String,
      routeTo: fields[5] as String,
      purpose: fields[6] as String,
      driverName: fields[7] as String,
      driverId: fields[8] as String?,
      departureTime: fields[9] as DateTime,
      returnTime: fields[10] as DateTime?,
      odometerStart: fields[11] as int?,
      odometerEnd: fields[12] as int?,
      odometerStartManual: fields[13] as bool,
      specialEquipmentMinutes: fields[14] as int?,
      notes: fields[15] as String?,
      reportId: fields[16] as String?,
      createdAt: fields[17] as DateTime,
      updatedAt: fields[18] as DateTime,
      createdBy: fields[19] as String,
      syncStatus: fields[20] as String,
      extras: fields[21] == null ? '' : fields[21] as String,
      idleMinutes: fields[22] as int?,
      equipmentUse: fields[23] == null
          ? []
          : (fields[23] as List?)?.cast<TripEquipmentUse>(),
    );
  }

  @override
  void write(BinaryWriter writer, VehicleTrip obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.vehicleId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.dispatcherName)
      ..writeByte(4)
      ..write(obj.routeFrom)
      ..writeByte(5)
      ..write(obj.routeTo)
      ..writeByte(6)
      ..write(obj.purpose)
      ..writeByte(7)
      ..write(obj.driverName)
      ..writeByte(8)
      ..write(obj.driverId)
      ..writeByte(9)
      ..write(obj.departureTime)
      ..writeByte(10)
      ..write(obj.returnTime)
      ..writeByte(11)
      ..write(obj.odometerStart)
      ..writeByte(12)
      ..write(obj.odometerEnd)
      ..writeByte(13)
      ..write(obj.odometerStartManual)
      ..writeByte(14)
      ..write(obj.specialEquipmentMinutes)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.reportId)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt)
      ..writeByte(19)
      ..write(obj.createdBy)
      ..writeByte(20)
      ..write(obj.syncStatus)
      ..writeByte(21)
      ..write(obj.extras)
      ..writeByte(22)
      ..write(obj.idleMinutes)
      ..writeByte(23)
      ..write(obj.equipmentUse);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleTripAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
