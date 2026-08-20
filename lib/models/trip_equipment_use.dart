import 'package:hive/hive.dart';

part 'trip_equipment_use.g.dart';

/// Stała lista urządzeń specjalnych.
///
/// Świadomie zamknięta i wspólna dla wszystkich pojazdów, mimo że nie każdy
/// wóz ma autopompę. Lista per pojazd jest w backlogu i wymaga ustaleń
/// z Deringiem — a bez żadnej listy pole było **bezużyteczne**: Wojtek
/// zgłosił, że musiał pomijać rubrykę i wpisywać „autopompa 2h" w uwagach.
/// Zamknięta lista rozwiązuje to dziś, a „Inne" zostawia furtkę na resztę.
class SpecialEquipment {
  static const String pump = 'Autopompa';
  static const String generator = 'Agregat prądotwórczy';
  static const String saw = 'Piła spalinowa';
  static const String winch = 'Wyciągarka';
  static const String fan = 'Wentylator oddymiający';
  static const String other = 'Inne';

  static const List<String> all = [pump, generator, saw, winch, fan, other];
}

/// Jedno urządzenie i czas jego pracy w ramach jednego przejazdu.
///
/// Kolumna 10 karty drogowej („Minuty pracy urządzeń specjalistycznych")
/// to jedna liczba, więc na wydruk idzie suma. Rozbicie trzymamy, bo
/// rozliczenie paliwa liczy autopompę osobną normą — i bo bez niego nie da
/// się odtworzyć, co właściwie pracowało.
@HiveType(typeId: 8)
class TripEquipmentUse extends HiveObject {
  /// Nazwa urządzenia — jedna z [SpecialEquipment.all] albo tekst własny,
  /// gdy wybrano „Inne".
  @HiveField(0)
  String name;

  @HiveField(1)
  int minutes;

  TripEquipmentUse({required this.name, required this.minutes});

  @override
  String toString() => '$name $minutes min';
}
