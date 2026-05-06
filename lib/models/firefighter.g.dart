// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firefighter.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FirefighterAdapter extends TypeAdapter<Firefighter> {
  @override
  final int typeId = 1;

  @override
  Firefighter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Firefighter(
      id: fields[0] as String,
      firstName: fields[1] as String,
      lastName: fields[2] as String,
      rank: fields[3] as String,
      isDriver: fields[4] == null ? false : fields[4] as bool,
      isCommander: fields[5] == null ? false : fields[5] as bool,
      isKPP: fields[6] == null ? false : fields[6] as bool,
      medicalExamExpiry: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Firefighter obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.firstName)
      ..writeByte(2)
      ..write(obj.lastName)
      ..writeByte(3)
      ..write(obj.rank)
      ..writeByte(4)
      ..write(obj.isDriver)
      ..writeByte(5)
      ..write(obj.isCommander)
      ..writeByte(6)
      ..write(obj.isKPP)
      ..writeByte(7)
      ..write(obj.medicalExamExpiry);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirefighterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
