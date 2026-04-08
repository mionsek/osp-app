                                                                                                                                                                                            import 'package:hive/hive.dart';

part 'crew_assignment.g.dart';

@HiveType(typeId: 2)
class CrewAssignment extends HiveObject {
  @HiveField(0)
  String vehicleId;

  @HiveField(1)
  String vehicleName;

  /// ID of the firefighter assigned as driver (seat 1).
  @HiveField(2)
  String? driverId;

  /// ID of the firefighter assigned as commander (seat 2).
  @HiveField(3)
  String? commanderId;

  /// IDs of remaining crew members (seats 3–N).
  @HiveField(4)
  List<String> crewMemberIds;

  CrewAssignment({
    required this.vehicleId,
    required this.vehicleName,
    this.driverId,
    this.commanderId,
    List<String>? crewMemberIds,
  }) : crewMemberIds = crewMemberIds ?? [];

  /// All firefighter IDs assigned to this vehicle (non-null, non-empty).
  List<String> get allAssignedIds {
    return [
      if (driverId != null && driverId!.isNotEmpty) driverId!,
      if (commanderId != null && commanderId!.isNotEmpty) commanderId!,
      ...crewMemberIds.where((id) => id.isNotEmpty),
    ];
  }

  CrewAssignment copyWith({
    String? vehicleId,
    String? vehicleName,
    String? driverId,
    String? commanderId,
    List<String>? crewMemberIds,
  }) {
    return CrewAssignment(
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      driverId: driverId ?? this.driverId,
      commanderId: commanderId ?? this.commanderId,
      crewMemberIds: crewMemberIds ?? List.from(this.crewMemberIds),
    );
  }
}
