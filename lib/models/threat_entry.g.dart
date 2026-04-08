// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'threat_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ThreatEntryAdapter extends TypeAdapter<ThreatEntry> {
  @override
  final int typeId = 3;

  @override
  ThreatEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ThreatEntry(
      category: fields[0] as String,
      subtypes: (fields[1] as List?)?.cast<String>(),
      isCustom: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ThreatEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.category)
      ..writeByte(1)
      ..write(obj.subtypes)
      ..writeByte(2)
      ..write(obj.isCustom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreatEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
