import 'package:hive/hive.dart';

part 'equipment.g.dart';

/// Rodzaje paliwa sprzętu z własnym silnikiem.
class EquipmentFuel {
  EquipmentFuel._();

  static const String petrol = 'Benzyna';

  /// Benzyna z olejem do silników dwusuwowych (pilarki, część pomp).
  static const String mix = 'Mieszanka';
  static const String diesel = 'ON';

  static const List<String> all = [petrol, mix, diesel];
}

/// Sprzęt jednostki: agregat, pilarka, motopompa, autopompa…
///
/// Ustalenia z Dawidem po rozmowie z Deringiem (listopad 2026): każde
/// urządzenie z własnym silnikiem ma w gminie osobną kartę pracy, a karta
/// drogowa wozu liczy w kolumnie 10 i pozycji 5 rozliczenia tylko sprzęt
/// zasilany z wozu — normą autopompy z nagłówka. Wcześniej była stała lista
/// nazw wspólna dla wszystkich wozów, a karta wozu liczyła minuty pilarki
/// normą autopompy.
///
/// Listę prowadzi administrator, jak listę pojazdów.
@HiveType(typeId: 9)
class Equipment extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// Wóz, na którym sprzęt jest na stałe; `null` — nieprzypisany (albo wóz
  /// usunięto).
  @HiveField(2)
  String? vehicleId;

  /// Napędzany silnikiem wozu (autopompa, wyciągarka): paliwo z baku wozu,
  /// minuty na karcie drogowej. Inaczej — własny silnik i własna karta.
  @HiveField(3, defaultValue: false)
  bool poweredByVehicle;

  /// Jedno z [EquipmentFuel.all] albo puste — tylko sprzęt z własnym
  /// silnikiem.
  @HiveField(4, defaultValue: '')
  String fuelType;

  /// Norma zużycia paliwa na godzinę pracy (litry) — sprzęt z własnym
  /// silnikiem. Sprzęt zasilany z wozu liczy się normą autopompy wozu.
  @HiveField(5)
  double? fuelPerHour;

  /// Typ albo model, np. „Stihl MS 462".
  @HiveField(6, defaultValue: '')
  String model;

  /// Numer fabryczny albo inwentarzowy.
  @HiveField(7, defaultValue: '')
  String serialNumber;

  /// Ostatnia zmiana wpisu — rozstrzyga przy synchronizacji.
  @HiveField(8)
  DateTime? updatedAt;

  Equipment({
    required this.id,
    required this.name,
    this.vehicleId,
    this.poweredByVehicle = false,
    this.fuelType = '',
    this.fuelPerHour,
    this.model = '',
    this.serialNumber = '',
    this.updatedAt,
  });

  @override
  String toString() => name;
}
