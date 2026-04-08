import 'package:hive/hive.dart';

part 'firefighter.g.dart';

@HiveType(typeId: 1)
class Firefighter extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String firstName;

  @HiveField(2)
  String lastName;

  @HiveField(3)
  String rank;

  @HiveField(4, defaultValue: false)
  bool isDriver;

  @HiveField(5, defaultValue: false)
  bool isCommander;

  @HiveField(6, defaultValue: false)
  bool isKPP;

  Firefighter({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.rank,
    this.isDriver = false,
    this.isCommander = false,
    this.isKPP = false,
  });

  String get fullName => '$firstName $lastName';
  String get fullNameWithRank => '$fullName, $rank';

  @override
  String toString() => fullName;

  Firefighter copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? rank,
    bool? isDriver,
    bool? isCommander,
    bool? isKPP,
  }) {
    return Firefighter(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      rank: rank ?? this.rank,
      isDriver: isDriver ?? this.isDriver,
      isCommander: isCommander ?? this.isCommander,
      isKPP: isKPP ?? this.isKPP,
    );
  }
}
