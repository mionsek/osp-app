import '../models/models.dart';

/// Tworzenie wpisów ewidencji przejazdów z zapisanego wyjazdu alarmowego.
///
/// Ustalenie z rozmowy: karta drogowa obejmuje **wszystkie** wyjazdy, także
/// alarmowe, i „im więcej wypełni się samo, tym lepiej". Z raportu da się
/// odtworzyć 7 z 11 kolumn druku — zostaje licznik, dysponent i minuty pracy
/// urządzeń specjalnych.
///
/// Jeden raport może obejmować kilka pojazdów, a każdy pojazd ma własną kartę,
/// więc powstaje tyle przejazdów, ile zastępów wyjechało.
class TripFromReport {
  const TripFromReport._();

  /// Buduje przejazdy dla wszystkich zastępów z [report].
  ///
  /// [existingTripReportIds] chroni przed dopisaniem tego samego wyjazdu drugi
  /// raz przy edycji raportu — bez tego każde otwarcie i zapisanie raportu
  /// mnożyłoby wiersze w karcie.
  static List<VehicleTrip> build({
    required Report report,
    required String stationAddress,
    required String Function(String firefighterId)? resolveDriverName,
    required Set<String> existingVehicleIdsForReport,
    String createdBy = '',
    DateTime? timestamp,
  }) {
    final trips = <VehicleTrip>[];
    // Przy uzupełnianiu historii podajemy znacznik z raportu, a nie „teraz".
    // Dzięki temu każde urządzenie wygeneruje identyczny rekord i Dysk nie
    // wpadnie w pętlę „mój wpis jest nowszy" przy każdej synchronizacji.
    final now = timestamp ?? DateTime.now();

    for (final crew in report.crewAssignments) {
      if (crew.vehicleId.isEmpty) continue;
      if (existingVehicleIdsForReport.contains(crew.vehicleId)) continue;

      final driverId = crew.driverId;
      final driverName = (driverId != null && resolveDriverName != null)
          ? resolveDriverName(driverId)
          : '';

      trips.add(VehicleTrip(
        // Identyfikator wyprowadzony z raportu i pojazdu, żeby ponowny zapis
        // tego samego raportu trafiał w ten sam wpis, a nie tworzył kolejny.
        id: 'trip_${report.id}_${crew.vehicleId}',
        vehicleId: crew.vehicleId,
        date: report.date,
        routeFrom: stationAddress,
        routeTo: _destination(report),
        purpose: TripPurposes.alarm,
        driverName: driverName,
        driverId: driverId,
        departureTime: report.departureTime,
        returnTime: report.returnTime,
        reportId: report.id,
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
      ));
    }

    return trips;
  }

  /// Odświeża w istniejącym przejeździe te kolumny, których źródłem jest
  /// raport. Zwraca `true`, gdy cokolwiek się zmieniło.
  ///
  /// Potrzebne, bo dopisanie godziny powrotu w wyjeździe nie trafiało do
  /// ewidencji — przejazd powstawał raz i już nigdy się nie aktualizował.
  ///
  /// Świadomie **nie ruszamy** licznika, dysponenta, minut pracy urządzeń,
  /// uwag ani pola „skąd": to dane wpisywane w ewidencji, o których raport nic
  /// nie wie. Nadpisanie ich kasowałoby pracę kierowcy.
  ///
  /// Z tego samego powodu pomijamy grupy z [VehicleTrip.overriddenFields] —
  /// poprawione ręcznie w ewidencji. Wyjątkiem jest [force]: grupy, które
  /// ktoś właśnie zmienił w samym raporcie. Wtedy wygrywa ostatnia edycja,
  /// a ochrona z przejazdu zostaje zdjęta.
  static bool applyReportFields(
    VehicleTrip trip,
    Report report, {
    String Function(String firefighterId)? resolveDriverName,
    Set<String> force = const {},
  }) {
    final v = _reportValues(trip, report, resolveDriverName);
    bool applies(String group) =>
        force.contains(group) || !trip.overriddenFields.contains(group);

    var changed = false;

    if (applies(ReportLinkedField.departure) &&
        (trip.date != v.date || trip.departureTime != v.departureTime)) {
      trip.date = v.date;
      trip.departureTime = v.departureTime;
      changed = true;
    }
    if (applies(ReportLinkedField.returnTime) &&
        trip.returnTime != v.returnTime) {
      trip.returnTime = v.returnTime;
      changed = true;
    }
    if (applies(ReportLinkedField.routeTo) && trip.routeTo != v.routeTo) {
      trip.routeTo = v.routeTo;
      changed = true;
    }
    if (applies(ReportLinkedField.driver) &&
        (trip.driverId != v.driverId || trip.driverName != v.driverName)) {
      trip.driverId = v.driverId;
      trip.driverName = v.driverName;
      changed = true;
    }

    if (force.isNotEmpty &&
        trip.overriddenFields.any(force.contains)) {
      trip.overriddenFields =
          trip.overriddenFields.where((f) => !force.contains(f)).toList();
      changed = true;
    }

    // Nie „teraz": uzgadnianie biegnie w tle na każdym telefonie. Stempel
    // „teraz" robił z automatycznej zmiany wersję nowszą od prawdziwej
    // edycji z innego telefonu, więc ta przepadała przy synchronizacji.
    // Stempel raportu jest wszędzie ten sam, a przy zapisie raportu w
    // kreatorze i tak równa się „teraz".
    if (changed && report.updatedAt.isAfter(trip.updatedAt)) {
      trip.updatedAt = report.updatedAt;
    }
    return changed;
  }

  /// Grupy, w których przejazd różni się od tego, co wynika z raportu.
  ///
  /// Wołane po zapisie przejazdu z formularza: różnica oznacza ręczną
  /// poprawkę, którą uzgadnianie ma odtąd omijać. Pole przywrócone do
  /// wartości z raportu wypada z listy, więc cofnięcie poprawki zdejmuje
  /// ochronę.
  static List<String> overridesAgainst(
    VehicleTrip trip,
    Report report, {
    String Function(String firefighterId)? resolveDriverName,
  }) {
    final v = _reportValues(trip, report, resolveDriverName);
    return [
      if (!_sameDay(trip.date, v.date) || trip.departureTime != v.departureTime)
        ReportLinkedField.departure,
      if (trip.returnTime != v.returnTime) ReportLinkedField.returnTime,
      if (trip.routeTo.trim() != v.routeTo.trim()) ReportLinkedField.routeTo,
      if (trip.driverId != v.driverId ||
          trip.driverName.trim() != v.driverName.trim())
        ReportLinkedField.driver,
    ];
  }

  /// Grupy, które zmieniły się między dwiema wersjami raportu — z punktu
  /// widzenia przejazdu pojazdu [vehicleId].
  ///
  /// Kierowca liczony per pojazd: zmiana kierowcy w jednym zastępie nie
  /// może zdejmować ręcznej poprawki z karty drugiego wozu.
  static Set<String> changedBetween(
    Report before,
    Report after, {
    required String vehicleId,
  }) {
    String? driverOf(Report r) => r.crewAssignments
        .where((c) => c.vehicleId == vehicleId)
        .firstOrNull
        ?.driverId;

    return {
      if (!_sameDay(before.date, after.date) ||
          before.departureTime != after.departureTime)
        ReportLinkedField.departure,
      if (before.returnTime != after.returnTime) ReportLinkedField.returnTime,
      if (_destination(before) != _destination(after))
        ReportLinkedField.routeTo,
      if (driverOf(before) != driverOf(after)) ReportLinkedField.driver,
    };
  }

  /// Godziny raportu wyliczone z przejazdów jego pojazdów: odjazd pierwszego
  /// zastępu i powrót ostatniego — tyle trwały działania jednostki.
  ///
  /// Przy jednym pojeździe to po prostu jego godziny. Brak powrotu we
  /// wszystkich przejazdach daje `null`, a nie zmyśloną godzinę.
  ///
  /// Zwraca `null`, gdy nie ma przejazdów z dnia raportu — nie ma wtedy
  /// z czego liczyć.
  static ({DateTime departure, DateTime? returnTime})? reportTimesFromTrips(
    Iterable<VehicleTrip> linked, {
    required DateTime reportDate,
  }) {
    final sameDay = linked.where((t) => _sameDay(t.date, reportDate)).toList();
    if (sameDay.isEmpty) return null;

    var departure = sameDay.first.departureTime;
    DateTime? returnTime;
    for (final t in sameDay) {
      if (t.departureTime.isBefore(departure)) departure = t.departureTime;
      final r = t.returnTime;
      if (r != null && (returnTime == null || r.isAfter(returnTime))) {
        returnTime = r;
      }
    }
    return (departure: departure, returnTime: returnTime);
  }

  static ({
    DateTime date,
    DateTime departureTime,
    DateTime? returnTime,
    String routeTo,
    String? driverId,
    String driverName,
  }) _reportValues(
    VehicleTrip trip,
    Report report,
    String Function(String firefighterId)? resolveDriverName,
  ) {
    final crew = report.crewAssignments
        .where((c) => c.vehicleId == trip.vehicleId)
        .firstOrNull;
    final driverId = crew?.driverId;
    // Raport bez kierowcy dla tego wozu nie ma czego podpowiedzieć —
    // zostawiamy nazwisko z przejazdu, zamiast je kasować. Tak samo, gdy
    // ratownika usunięto z kartoteki: pusty wynik kasował nazwisko we
    // wszystkich jego dawnych przejazdach i karty drukowały się bez kierowcy.
    final resolved = (driverId != null && resolveDriverName != null)
        ? resolveDriverName(driverId)
        : '';
    final driverName = resolved.isNotEmpty ? resolved : trip.driverName;

    return (
      date: report.date,
      departureTime: report.departureTime,
      returnTime: report.returnTime,
      routeTo: _destination(report),
      driverId: driverId,
      driverName: driverName,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Cel wyjazdu w formacie kolumny „dokąd": ulica z numerem, a gdy jej brak —
  /// sama miejscowość. Opis miejsca pomijamy, bo w kratce karty i tak się nie
  /// mieści.
  static String _destination(Report report) {
    final locality = report.addressLocality.trim();
    final street = report.addressStreet.trim();
    if (street.isEmpty) return locality;
    if (locality.isEmpty) return street;
    return '$locality, $street';
  }
}
