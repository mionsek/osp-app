import 'package:hive/hive.dart';

part 'equipment_work.g.dart';

/// Praca sprzętu poza przejazdem — wiersz karty pracy sprzętu silnikowego,
/// który nie wynika z żadnego przejazdu wozu.
///
/// Najczęściej rozruch kontrolny: według Deringa (listopad 2026) wpisuje się
/// na kartę „rozruch 15 min" albo czas pracy przy akcji. Praca przy akcji
/// przychodzi z przejazdów ([TripEquipmentUse]), rozruch dzieje się w remizie
/// — bez wyjazdu, więc nie miał gdzie się zapisać.
@HiveType(typeId: 10)
class EquipmentWork extends HiveObject {
  @HiveField(0)
  String id;

  /// Urządzenie z listy sprzętu ([Equipment.id]) — wyznacza kartę.
  @HiveField(1)
  String equipmentId;

  /// Kopia nazwy z chwili wpisu — po usunięciu sprzętu z listy wpis nadal
  /// mówi, czego dotyczył.
  @HiveField(2)
  String equipmentName;

  /// Dzień pracy — rubryka „Data". Wyznacza miesiąc karty.
  @HiveField(3)
  DateTime date;

  @HiveField(4)
  int minutes;

  /// Rozruch kontrolny: liczy się w pozycji 6 rozliczenia („zużyto na
  /// rozruchy i kontrole"), a nie w pozycjach 4–5 („przepracowano").
  @HiveField(5)
  bool isStartup;

  /// Rubryka „Cel użycia"; przy rozruchu [startupPurpose].
  @HiveField(6)
  String purpose;

  @HiveField(7)
  String operatorName;

  @HiveField(8)
  String? operatorId;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  /// E-mail autora — edytować może autor albo administrator.
  @HiveField(11)
  String createdBy;

  static const String startupPurpose = 'Rozruch kontrolny';

  /// Czas rozruchu kontrolnego z karty pracy.
  static const int startupMinutes = 15;

  EquipmentWork({
    required this.id,
    required this.equipmentId,
    this.equipmentName = '',
    required this.date,
    required this.minutes,
    this.isStartup = false,
    this.purpose = '',
    this.operatorName = '',
    this.operatorId,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
  });
}
