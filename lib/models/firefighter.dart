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

  @HiveField(7)
  DateTime? medicalExamExpiry;

  Firefighter({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.rank,
    this.isDriver = false,
    this.isCommander = false,
    this.isKPP = false,
    this.medicalExamExpiry,
  });

  String get fullName => '$firstName $lastName';
  String get fullNameWithRank => '$fullName, $rank';

  bool get hasMedicalExam => medicalExamExpiry != null;
  bool get isMedicalExamExpired =>
      medicalExamExpiry != null && medicalExamExpiry!.isBefore(DateTime.now());
  bool get isMedicalExamExpiringSoon =>
      medicalExamExpiry != null &&
      !isMedicalExamExpired &&
      medicalExamExpiry!.isBefore(DateTime.now().add(const Duration(days: 30)));

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
    DateTime? medicalExamExpiry,
    bool clearMedicalExamExpiry = false,
  }) {
    return Firefighter(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      rank: rank ?? this.rank,
      isDriver: isDriver ?? this.isDriver,
      isCommander: isCommander ?? this.isCommander,
      isKPP: isKPP ?? this.isKPP,
      medicalExamExpiry: clearMedicalExamExpiry
          ? null
          : (medicalExamExpiry ?? this.medicalExamExpiry),
    );
  }
}
