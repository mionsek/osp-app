// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'property_handover.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PropertyHandoverAdapter extends TypeAdapter<PropertyHandover> {
  @override
  final int typeId = 6;

  @override
  PropertyHandover read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PropertyHandover(
      id: fields[0] as String,
      reportId: fields[1] as String?,
      eventLocation: fields[2] as String,
      eventDate: fields[3] as DateTime,
      eventTime: fields[4] as DateTime,
      recipientType: fields[5] as String,
      recipientTypeOther: fields[6] as String?,
      recipientName: fields[7] as String,
      recipientAddress: fields[8] as String,
      recipientPhone: fields[9] as String,
      propertyDescription: fields[10] as String,
      notes: fields[11] as String?,
      handoverFirefighterId: fields[12] as String?,
      signLocality: fields[13] as String,
      signDate: fields[14] as DateTime,
      createdAt: fields[15] as DateTime,
      updatedAt: fields[16] as DateTime,
      createdBy: fields[17] as String,
      syncStatus: fields[18] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PropertyHandover obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.reportId)
      ..writeByte(2)
      ..write(obj.eventLocation)
      ..writeByte(3)
      ..write(obj.eventDate)
      ..writeByte(4)
      ..write(obj.eventTime)
      ..writeByte(5)
      ..write(obj.recipientType)
      ..writeByte(6)
      ..write(obj.recipientTypeOther)
      ..writeByte(7)
      ..write(obj.recipientName)
      ..writeByte(8)
      ..write(obj.recipientAddress)
      ..writeByte(9)
      ..write(obj.recipientPhone)
      ..writeByte(10)
      ..write(obj.propertyDescription)
      ..writeByte(11)
      ..write(obj.notes)
      ..writeByte(12)
      ..write(obj.handoverFirefighterId)
      ..writeByte(13)
      ..write(obj.signLocality)
      ..writeByte(14)
      ..write(obj.signDate)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.updatedAt)
      ..writeByte(17)
      ..write(obj.createdBy)
      ..writeByte(18)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyHandoverAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
