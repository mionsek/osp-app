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
      ownerEmail: fields[4] == null ? '' : fields[4] as String,
      btPrinterMac: fields[5] as String?,
      btPrinterName: fields[6] as String?,
      unitFullName: fields[7] as String?,
      unitStreet: fields[8] == null ? '' : fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UnitConfig obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.namePrefix)
      ..writeByte(1)
      ..write(obj.locality)
      ..writeByte(2)
      ..write(obj.onboardingCompleted)
      ..writeByte(3)
      ..write(obj.isAdmin)
      ..writeByte(4)
      ..write(obj.ownerEmail)
      ..writeByte(5)
      ..write(obj.btPrinterMac)
      ..writeByte(6)
      ..write(obj.btPrinterName)
      ..writeByte(7)
      ..write(obj.unitFullName)
      ..writeByte(8)
      ..write(obj.unitStreet);
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
