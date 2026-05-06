import 'package:hive/hive.dart';

part 'unit_config.g.dart';

@HiveType(typeId: 5)
class UnitConfig extends HiveObject {
  @HiveField(0)
  String namePrefix;

  @HiveField(1)
  String locality;

  @HiveField(2)
  bool onboardingCompleted;

  @HiveField(3)
  bool isAdmin;

  @HiveField(4)
  String ownerEmail;

  UnitConfig({
    this.namePrefix = 'Ochotnicza Straż Pożarna',
    this.locality = '',
    this.onboardingCompleted = false,
    this.isAdmin = true,
    this.ownerEmail = '',
  });

  String get fullName {
    if (locality.isEmpty) return namePrefix;
    return '$namePrefix $locality';
  }

  UnitConfig copyWith({
    String? namePrefix,
    String? locality,
    bool? onboardingCompleted,
    bool? isAdmin,
    String? ownerEmail,
  }) {
    return UnitConfig(
      namePrefix: namePrefix ?? this.namePrefix,
      locality: locality ?? this.locality,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isAdmin: isAdmin ?? this.isAdmin,
      ownerEmail: ownerEmail ?? this.ownerEmail,
    );
  }
}
