import 'package:hive/hive.dart';
import 'trip_equipment_use.dart';

part 'vehicle_trip.g.dart';

/// Rodzaje przejazdów wpisywanych do ewidencji.
///
/// Odpowiadają kolumnie „Cel jazdy" na papierowej karcie drogowej, ale są
/// zamkniętą listą, żeby dało się po nich filtrować i liczyć statystyki.
/// [inny] zostawia miejsce na wszystko, czego nie przewidzieliśmy — opis
/// trafia wtedy do [VehicleTrip.purpose].
class TripPurposes {
  static const String alarm = 'Wyjazd alarmowy';
  static const String economic = 'Wyjazd gospodarczy';
  static const String refuelling = 'Tankowanie';
  static const String training = 'Ćwiczenia';
  static const String service = 'Przegląd / naprawa';
  static const String other = 'Inny';

  static const List<String> all = [
    alarm,
    economic,
    refuelling,
    training,
    service,
    other,
  ];
}

/// Jeden przejazd pojazdu — jeden wiersz miesięcznej karty drogowej.
///
/// Karta to nie osobny byt, tylko widok: para *pojazd + miesiąc* nad zbiorem
/// przejazdów. Dzięki temu nie trzeba niczego „zakładać" na początku miesiąca
/// ani „zamykać" na końcu.
///
/// Na papierze jeden wiersz obejmuje odjazd (godzina + licznik) i przyjazd
/// (godzina + licznik), czyli **całą jazdę tam i z powrotem**, a nie jedną
/// stronę trasy — potwierdzone na drukach z trzech gmin.
@HiveType(typeId: 7)
class VehicleTrip extends HiveObject {
  @HiveField(0)
  String id;

  /// Pojazd, którego dotyczy przejazd (Vehicle.id). Wyznacza kartę.
  @HiveField(1)
  String vehicleId;

  /// Data przejazdu — kolumna 1. Wyznacza miesiąc karty.
  @HiveField(2)
  DateTime date;

  /// Nazwisko dysponenta — kolumna 2. Osoba, która zadysponowała pojazd.
  @HiveField(3)
  String dispatcherName;

  /// Trasa „skąd" — pierwsza połowa kolumny 3. Domyślnie siedziba jednostki.
  @HiveField(4)
  String routeFrom;

  /// Trasa „dokąd" — druga połowa kolumny 3.
  @HiveField(5)
  String routeTo;

  /// Cel jazdy — kolumna 4. Jedna z [TripPurposes.all].
  @HiveField(6)
  String purpose;

  /// Kierowca — kolumna 5. Trzymamy nazwisko, a nie tylko id ratownika, bo
  /// karta bywa wypełniana za kogoś spoza kartoteki, a druk i tak wymaga
  /// wpisanego nazwiska.
  @HiveField(7)
  String driverName;

  /// Powiązanie z kartoteką ratowników, gdy kierowca z niej pochodzi.
  @HiveField(8)
  String? driverId;

  /// Godzina odjazdu — kolumna 6 (pełna data i godzina).
  @HiveField(9)
  DateTime departureTime;

  /// Godzina przyjazdu — kolumna 8. `null`, gdy pojazd jeszcze nie wrócił.
  @HiveField(10)
  DateTime? returnTime;

  /// Stan licznika przy odjeździe — kolumna 7.
  ///
  /// Normalnie **nie jest wpisywany ręcznie**: to stan po poprzednim
  /// przejeździe tego pojazdu, podstawiany przez [odometerStartFor].
  /// Kierowca oddaje kartę często w środku akcji, więc licznik notuje dopiero
  /// po powrocie do jednostki — i ten stan staje się stanem przed następnym
  /// wyjazdem.
  @HiveField(11)
  int? odometerStart;

  /// Stan licznika przy przyjeździe — kolumna 9. Jedyna liczba, o którą
  /// aplikacja pyta przy zwykłym przejeździe.
  @HiveField(12)
  int? odometerEnd;

  /// Czy [odometerStart] został wpisany ręcznie, zamiast wynikać z łańcucha.
  ///
  /// Potrzebne, bo jeden pominięty przejazd rozjeżdża licznik do końca
  /// miesiąca — musi istnieć sposób, żeby wpisać stan faktyczny i nie dać
  /// aplikacji nadpisać go z powrotem.
  @HiveField(13)
  bool odometerStartManual;

  /// Minuty pracy urządzeń specjalnych (autopompa, agregat) — kolumna 10.
  @HiveField(14)
  int? specialEquipmentMinutes;

  /// Uwagi własne — nie mają odpowiednika na druku.
  @HiveField(15)
  String? notes;

  /// Powiązanie z wyjazdem alarmowym (Report.id), gdy przejazd powstał
  /// automatycznie po zapisaniu raportu.
  @HiveField(16)
  String? reportId;

  @HiveField(17)
  DateTime createdAt;

  @HiveField(18)
  DateTime updatedAt;

  /// E-mail autora wpisu — decyduje, kto może go edytować (autor lub admin).
  @HiveField(19)
  String createdBy;

  /// Status synchronizacji: 'local', 'queued', 'sent'.
  @HiveField(20)
  String syncStatus;

  /// Kolumna „Dodatki*" z druku karty drogowej.
  ///
  /// Na papierze to wolna rubryka na dopiski wpływające na rozliczenie
  /// (np. dodatek zimowy). Trzymamy ją jako tekst, bo druk nie narzuca
  /// formatu, a zgadywanie reguły naliczania byłoby wróżeniem.
  @HiveField(21, defaultValue: '')
  String extras;

  /// Kolumna „Praca silnika na postoju min." — osobna od minut pracy
  /// urządzeń specjalistycznych, bo w rozliczeniu ma własną normę
  /// (litry na minutę) i własną pozycję.
  @HiveField(22)
  int? idleMinutes;

  /// Rozbicie pracy urządzeń specjalnych na poszczególne urządzenia.
  ///
  /// Zastępuje samo [specialEquipmentMinutes], które pozwalało wpisać liczbę
  /// minut, ale nie **czego** dotyczy — przez co rubryka była w praktyce
  /// nie do użycia i ludzie wpisywali „autopompa 2h" w uwagach.
  @HiveField(23, defaultValue: <TripEquipmentUse>[])
  List<TripEquipmentUse> equipmentUse;

  VehicleTrip({
    required this.id,
    required this.vehicleId,
    required this.date,
    this.dispatcherName = '',
    this.routeFrom = '',
    this.routeTo = '',
    this.purpose = TripPurposes.economic,
    this.driverName = '',
    this.driverId,
    required this.departureTime,
    this.returnTime,
    this.odometerStart,
    this.odometerEnd,
    this.odometerStartManual = false,
    this.specialEquipmentMinutes,
    this.notes,
    this.reportId,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy = '',
    this.syncStatus = 'local',
    this.extras = '',
    this.idleMinutes,
    List<TripEquipmentUse>? equipmentUse,
  }) : equipmentUse = equipmentUse ?? <TripEquipmentUse>[];

  /// Rok i miesiąc, do którego przejazd należy — klucz karty.
  int get year => date.year;
  int get month => date.month;

  /// Przejechane kilometry, gdy znane są oba stany licznika.
  ///
  /// `null` zamiast 0, żeby „jeszcze nie wiadomo" nie wyglądało jak
  /// „przejechano zero kilometrów" w podsumowaniu miesiąca.
  int? get distance {
    final start = odometerStart;
    final end = odometerEnd;
    if (start == null || end == null) return null;
    return end - start;
  }

  /// Czy przejazd jest domknięty — wrócił i ma zapisany licznik.
  bool get isClosed => returnTime != null && odometerEnd != null;

  /// Czy dane licznika są wewnętrznie sprzeczne (stan po < stan przed).
  ///
  /// Nie blokujemy zapisu takiego przejazdu — ostrzegamy. Papierowa karta
  /// jest dokumentem źródłowym i czasem trzeba w aplikacji odwzorować to,
  /// co ktoś już wpisał długopisem.
  bool get hasOdometerConflict {
    final d = distance;
    return d != null && d < 0;
  }

  /// Łączny czas pracy urządzeń specjalnych — kolumna 10 karty drogowej.
  ///
  /// Na druku jest jedna liczba, więc sumujemy rozbicie. Gdy rozbicia nie ma,
  /// bierzemy starą wartość [specialEquipmentMinutes] — przejazdy zapisane
  /// przed wprowadzeniem listy urządzeń mają tylko ją i nie mogą przez to
  /// zniknąć z wydruku.
  int get totalEquipmentMinutes {
    if (equipmentUse.isEmpty) return specialEquipmentMinutes ?? 0;
    return equipmentUse.fold(0, (sum, e) => sum + e.minutes);
  }

  /// Opis pracy urządzeń do pokazania na liście: „Autopompa 120 min".
  String get equipmentLabel =>
      equipmentUse.map((e) => '${e.name} ${e.minutes} min').join(', ');

  /// Trasa w formacie z druku: „skąd – dokąd".
  String get routeLabel {
    final from = routeFrom.trim();
    final to = routeTo.trim();
    if (from.isEmpty && to.isEmpty) return '';
    if (from.isEmpty) return to;
    if (to.isEmpty) return from;
    return '$from – $to';
  }
}
