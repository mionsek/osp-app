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

  // ── Dane z nagłówka miesięcznej karty drogowej ──────────────────────────
  //
  // Wszystkie pola są opcjonalne i mają domyślnie pustą wartość: pojazdy
  // wprowadzone przed tą zmianą mają je puste, a karta drukuje wtedy pustą
  // kratkę do wypełnienia długopisem — tak jak papierowy druk.

  /// Marka, np. „MITSUBISHI".
  @HiveField(3, defaultValue: '')
  String make;

  /// Typ, np. „L200".
  @HiveField(4, defaultValue: '')
  String model;

  /// Rodzaj pojazdu w nomenklaturze pożarniczej, np. „SLRr", „GBA".
  @HiveField(5, defaultValue: '')
  String kind;

  /// Numer rejestracyjny, np. „GWE 2998X".
  @HiveField(6, defaultValue: '')
  String plate;

  /// Numer operacyjny nadany przez KP PSP.
  @HiveField(7, defaultValue: '')
  String operationalNumber;

  /// Rodzaj paliwa — na druku kolumny rozliczenia to ON i ET.
  @HiveField(8, defaultValue: '')
  String fuelType;

  /// Norma zużycia paliwa na 100 km przebiegu (litry), np. 9.5.
  @HiveField(9)
  double? fuelPer100Km;

  /// Norma zużycia paliwa autopompy na godzinę pracy (litry).
  @HiveField(10)
  double? pumpFuelPerHour;

  /// Zużycie przy pracy silnika na postoju (litry na minutę), np. 0.05.
  @HiveField(11)
  double? idleFuelPerMinute;

  /// Norma na rozruch silnika — na druku „Rozruch silnika 1/m-c",
  /// czyli litry doliczane raz na miesiąc.
  @HiveField(12)
  double? startupFuelPerMonth;

  Vehicle({
    required this.id,
    required this.name,
    required this.seats,
    this.make = '',
    this.model = '',
    this.kind = '',
    this.plate = '',
    this.operationalNumber = '',
    this.fuelType = '',
    this.fuelPer100Km,
    this.pumpFuelPerHour,
    this.idleFuelPerMinute,
    this.startupFuelPerMonth,
  });

  @override
  String toString() => '$name ($seats miejsc)';

  /// Czy pojazd ma uzupełnione dane potrzebne w nagłówku karty drogowej.
  ///
  /// Służy tylko do podpowiedzi w interfejsie — brak danych nie blokuje
  /// wydruku, bo kartę można oddać uzupełnioną ręcznie.
  bool get hasCardData =>
      make.isNotEmpty || plate.isNotEmpty || fuelPer100Km != null;

  Vehicle copyWith({
    String? id,
    String? name,
    int? seats,
    String? make,
    String? model,
    String? kind,
    String? plate,
    String? operationalNumber,
    String? fuelType,
    double? fuelPer100Km,
    double? pumpFuelPerHour,
    double? idleFuelPerMinute,
    double? startupFuelPerMonth,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      seats: seats ?? this.seats,
      make: make ?? this.make,
      model: model ?? this.model,
      kind: kind ?? this.kind,
      plate: plate ?? this.plate,
      operationalNumber: operationalNumber ?? this.operationalNumber,
      fuelType: fuelType ?? this.fuelType,
      fuelPer100Km: fuelPer100Km ?? this.fuelPer100Km,
      pumpFuelPerHour: pumpFuelPerHour ?? this.pumpFuelPerHour,
      idleFuelPerMinute: idleFuelPerMinute ?? this.idleFuelPerMinute,
      startupFuelPerMonth: startupFuelPerMonth ?? this.startupFuelPerMonth,
    );
  }
}
