import 'package:hive/hive.dart';
import 'crew_assignment.dart';

part 'report.g.dart';

@HiveType(typeId: 4)
class Report extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String reportNumber;

  @HiveField(2)
  int year;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  DateTime departureTime;

  @HiveField(5)
  DateTime? returnTime;

  @HiveField(6)
  String addressLocality;

  @HiveField(7)
  String addressStreet;

  @HiveField(17, defaultValue: '')
  String addressDescription;

  @HiveField(8)
  String threatCategory;

  @HiveField(9)
  String? threatSubtype;

  @HiveField(10)
  List<CrewAssignment> crewAssignments;

  @HiveField(11)
  String? operationCommanderId;

  @HiveField(12)
  String? notes;

  @HiveField(13)
  DateTime createdAt;

  @HiveField(14)
  DateTime updatedAt;

  @HiveField(15)
  String createdBy;

  /// Sync status: 'local', 'queued', 'sent'.
  @HiveField(16)
  String syncStatus;

  Report({
    required this.id,
    required this.reportNumber,
    required this.year,
    required this.date,
    required this.departureTime,
    this.returnTime,
    required this.addressLocality,
    this.addressStreet = '',
    this.addressDescription = '',
    required this.threatCategory,
    this.threatSubtype,
    List<CrewAssignment>? crewAssignments,
    this.operationCommanderId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.syncStatus = 'local',
  }) : crewAssignments = crewAssignments ?? [];

  int get vehicleCount => crewAssignments.length;

  int get totalFirefighters {
    final ids = <String>{};
    for (final crew in crewAssignments) {
      ids.addAll(crew.allAssignedIds);
    }
    return ids.length;
  }
}
