import 'package:hive/hive.dart';

part 'vehicle.g.dart';

@HiveType(typeId: 0)
class Vehicle extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int seats;

  Vehicle({
    required this.id,
    required this.name,
    required this.seats,
  });

  @override
  String toString() => '$name ($seats miejsc)';

  Vehicle copyWith({String? id, String? name, int? seats}) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      seats: seats ?? this.seats,
    );
  }
}
