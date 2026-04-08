// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UnitConfigAdapter extends TypeAdapter<UnitConfig> {
  @override
  final int typeId = 5;

  @override
  UnitConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UnitConfig(
      namePrefix: fields[0] as String,
      locality: fields[1] as String,
      onboardingCompleted: fields[2] as bool,
      isAdmin: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UnitConfig obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.namePrefix)
      ..writeByte(1)
      ..write(obj.locality)
      ..writeByte(2)
      ..write(obj.onboardingCompleted)
      ..writeByte(3)
      ..write(obj.isAdmin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
