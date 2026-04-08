// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReportAdapter extends TypeAdapter<Report> {
  @override
  final int typeId = 4;

  @override
  Report read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Report(
      id: fields[0] as String,
      reportNumber: fields[1] as String,
      year: fields[2] as int,
      date: fields[3] as DateTime,
      departureTime: fields[4] as DateTime,
      returnTime: fields[5] as DateTime?,
      addressLocality: fields[6] as String,
      addressStreet: fields[7] as String,
      addressDescription: fields[17] == null ? '' : fields[17] as String,
      threatCategory: fields[8] as String,
      threatSubtype: fields[9] as String?,
      crewAssignments: (fields[10] as List?)?.cast<CrewAssignment>(),
      operationCommanderId: fields[11] as String?,
      notes: fields[12] as String?,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime,
      createdBy: fields[15] as String,
      syncStatus: fields[16] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Report obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.reportNumber)
      ..writeByte(2)
      ..write(obj.year)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.departureTime)
      ..writeByte(5)
      ..write(obj.returnTime)
      ..writeByte(6)
      ..write(obj.addressLocality)
      ..writeByte(7)
      ..write(obj.addressStreet)
      ..writeByte(17)
      ..write(obj.addressDescription)
      ..writeByte(8)
      ..write(obj.threatCategory)
      ..writeByte(9)
      ..write(obj.threatSubtype)
      ..writeByte(10)
      ..write(obj.crewAssignments)
      ..writeByte(11)
      ..write(obj.operationCommanderId)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.createdBy)
      ..writeByte(16)
      ..write(obj.syncStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
