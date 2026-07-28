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

  @HiveField(4, defaultValue: '')
  String ownerEmail;

  /// Adres MAC sparowanej drukarki termicznej Bluetooth (eksperymentalne).
  @HiveField(5)
  String? btPrinterMac;

  /// Nazwa sparowanej drukarki Bluetooth, do wyświetlenia w ustawieniach.
  @HiveField(6)
  String? btPrinterName;

  /// Pełna nazwa jednostki wpisana ręcznie, np. „Ochotnicza Straż Pożarna
  /// w Kielnie". Wprowadzona, bo sklejanie prefiksu z miejscownikiem dawało
  /// niepoprawne gramatycznie „Ochotnicza Straż Pożarna Kielno" — polska
  /// odmiana nazw miejscowości nie da się sensownie zautomatyzować.
  ///
  /// Puste/`null` oznacza starą konfigurację — wtedy nazwę składamy po
  /// staremu z [namePrefix] i [locality].
  @HiveField(7)
  String? unitFullName;

  UnitConfig({
    this.namePrefix = 'Ochotnicza Straż Pożarna',
    this.locality = '',
    this.onboardingCompleted = false,
    this.isAdmin = true,
    this.ownerEmail = '',
    this.btPrinterMac,
    this.btPrinterName,
    this.unitFullName,
  });

  String get fullName {
    final custom = unitFullName?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    if (locality.isEmpty) return namePrefix;
    return '$namePrefix $locality';
  }

  UnitConfig copyWith({
    String? namePrefix,
    String? locality,
    bool? onboardingCompleted,
    bool? isAdmin,
    String? ownerEmail,
    String? btPrinterMac,
    String? btPrinterName,
    String? unitFullName,
  }) {
    return UnitConfig(
      namePrefix: namePrefix ?? this.namePrefix,
      locality: locality ?? this.locality,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isAdmin: isAdmin ?? this.isAdmin,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      btPrinterMac: btPrinterMac ?? this.btPrinterMac,
      btPrinterName: btPrinterName ?? this.btPrinterName,
      unitFullName: unitFullName ?? this.unitFullName,
    );
  }
}
