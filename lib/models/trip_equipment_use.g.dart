// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_equipment_use.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TripEquipmentUseAdapter extends TypeAdapter<TripEquipmentUse> {
  @override
  final int typeId = 8;

  @override
  TripEquipmentUse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TripEquipmentUse(
      name: fields[0] as String,
      minutes: fields[1] as int,
      equipmentId: fields[2] as String?,
      operatorName: fields[3] == null ? '' : fields[3] as String,
      operatorId: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TripEquipmentUse obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.minutes)
      ..writeByte(2)
      ..write(obj.equipmentId)
      ..writeByte(3)
      ..write(obj.operatorName)
      ..writeByte(4)
      ..write(obj.operatorId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripEquipmentUseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
