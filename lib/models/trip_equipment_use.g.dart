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
    );
  }

  @override
  void write(BinaryWriter writer, TripEquipmentUse obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.minutes);
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
