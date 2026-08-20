import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/threat_types.dart';
import '../models/models.dart';
import 'trip_from_report.dart';
import 'trip_odometer.dart';

class DatabaseService {
  static const String _vehiclesBox = 'vehicles';
  static const String _firefightersBox = 'firefighters';
  static const String _reportsBox = 'reports';
  static const String _configBox = 'config';
  static const String _threatsBox = 'threats';
  static const String _settingsBox = 'settings';
  static const String _handoversBox = 'property_handovers';
  static const String _tripsBox = 'vehicle_trips';

  static Future<void> initialize() async {
    await Hive.initFlutter();

    Hive.registerAdapter(VehicleAdapter());
    Hive.registerAdapter(FirefighterAdapter());
    Hive.registerAdapter(CrewAssignmentAdapter());
    Hive.registerAdapter(ThreatEntryAdapter());
    Hive.registerAdapter(ReportAdapter());
    Hive.registerAdapter(UnitConfigAdapter());
    Hive.registerAdapter(PropertyHandoverAdapter());
    Hive.registerAdapter(VehicleTripAdapter());
    Hive.registerAdapter(TripEquipmentUseAdapter());

    await Future.wait([
      Hive.openBox<Vehicle>(_vehiclesBox),
      Hive.openBox<Firefighter>(_firefightersBox),
      Hive.openBox<Report>(_reportsBox),
      Hive.openBox<UnitConfig>(_configBox),
      Hive.openBox<ThreatEntry>(_threatsBox),
      Hive.openBox<dynamic>(_settingsBox),
      Hive.openBox<PropertyHandover>(_handoversBox),
      Hive.openBox<VehicleTrip>(_tripsBox),
    ]);
  }

  // --- Config ---

  Box<UnitConfig> get configBox => Hive.box<UnitConfig>(_configBox);

  /// General-purpose key-value box for app settings (booleans, strings, etc.).
  Box<dynamic> get settingsBox => Hive.box<dynamic>(_settingsBox);

  UnitConfig getConfig() {
    return configBox.get('main') ?? UnitConfig();
  }

  Future<void> saveConfig(UnitConfig config) async {
    await configBox.put('main', config);
  }

  bool get isOnboardingCompleted => getConfig().onboardingCompleted;

  // --- Podpowiedź „Pierwsze kroki" na ekranie głównym ---
  //
  // Trzymana lokalnie (settingsBox), a nie w UnitConfig, bo to preferencja
  // widoku konkretnego telefonu — nie ma powodu, żeby zamknięcie karty na
  // jednym urządzeniu synchronizowało się przez Dysk na wszystkie inne.
  static const String _gettingStartedDismissedKey = 'gettingStartedDismissed';

  bool get isGettingStartedDismissed =>
      settingsBox.get(_gettingStartedDismissedKey) as bool? ?? false;

  Future<void> dismissGettingStarted() =>
      settingsBox.put(_gettingStartedDismissedKey, true);

  // --- Administratorzy jednostki (kopia lokalna) ---
  //
  // Źródłem prawdy jest `config/admins.json` na Dysku, ale trzymamy też
  // kopię lokalnie: bez niej po restarcie aplikacji — a zwłaszcza bez
  // zasięgu — nikt nie byłby administratorem i własna jednostka stałaby
  // się nieedytowalna.
  static const String _adminEmailsKey = 'adminEmails';

  List<String> get cachedAdminEmails =>
      (settingsBox.get(_adminEmailsKey) as List?)
          ?.map((e) => e.toString())
          .toList() ??
      const [];

  Future<void> cacheAdminEmails(List<String> emails) =>
      settingsBox.put(_adminEmailsKey, emails);

  // --- Vehicles ---

  Box<Vehicle> get vehiclesBox => Hive.box<Vehicle>(_vehiclesBox);

  List<Vehicle> getAllVehicles() => vehiclesBox.values.toList();

  Future<void> addVehicle(Vehicle vehicle) async {
    await vehiclesBox.put(vehicle.id, vehicle);
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    await vehiclesBox.put(vehicle.id, vehicle);
  }

  Future<void> deleteVehicle(String id) async {
    await vehiclesBox.delete(id);
  }

  Vehicle? getVehicle(String id) => vehiclesBox.get(id);

  // --- Firefighters ---

  Box<Firefighter> get firefightersBox =>
      Hive.box<Firefighter>(_firefightersBox);

  List<Firefighter> getAllFirefighters() => firefightersBox.values.toList();

  Future<void> addFirefighter(Firefighter firefighter) async {
    await firefightersBox.put(firefighter.id, firefighter);
  }

  Future<void> updateFirefighter(Firefighter firefighter) async {
    await firefightersBox.put(firefighter.id, firefighter);
  }

  Future<void> deleteFirefighter(String id) async {
    await firefightersBox.delete(id);
  }

  Firefighter? getFirefighter(String id) => firefightersBox.get(id);

  List<Firefighter> searchFirefighters(String query) {
    if (query.isEmpty) return getAllFirefighters();
    final lower = query.toLowerCase();
    return getAllFirefighters()
        .where((f) =>
            f.lastNameFirst.toLowerCase().contains(lower) ||
            f.fullName.toLowerCase().contains(lower))
        .toList();
  }

  // --- Reports ---

  Box<Report> get reportsBox => Hive.box<Report>(_reportsBox);

  List<Report> getAllReports() {
    final reports = reportsBox.values.toList();
    reports.sort((a, b) => b.date.compareTo(a.date));
    return reports;
  }

  Future<void> addReport(Report report) async {
    await reportsBox.put(report.id, report);
  }

  Future<void> updateReport(Report report) async {
    await reportsBox.put(report.id, report);
  }

  Future<void> deleteReport(String id) async {
    await reportsBox.delete(id);
  }

  Report? getReport(String id) => reportsBox.get(id);

  String getNextReportNumber() {
    final year = DateTime.now().year;
    final reportsThisYear = reportsBox.values
        .where((r) => r.year == year)
        .toList();
    int maxNum = 0;
    for (final r in reportsThisYear) {
      final parts = r.reportNumber.split('/');
      final num = int.tryParse(parts.first) ?? 0;
      if (num > maxNum) maxNum = num;
    }
    return '${(maxNum + 1).toString().padLeft(4, '0')}/$year';
  }

  /// Returns a list of report numbers that appear more than once in the given
  /// year (or current year if not specified). Used after sync to detect conflicts.
  List<String> findDuplicateReportNumbers({int? year}) {
    final y = year ?? DateTime.now().year;
    final reportsThisYear = reportsBox.values
        .where((r) => r.year == y)
        .toList();
    final counts = <String, int>{};
    for (final r in reportsThisYear) {
      counts[r.reportNumber] = (counts[r.reportNumber] ?? 0) + 1;
    }
    return counts.entries.where((e) => e.value > 1).map((e) => e.key).toList();
  }

  // --- Property handovers (przekazanie mienia) ---

  Box<PropertyHandover> get handoversBox =>
      Hive.box<PropertyHandover>(_handoversBox);

  List<PropertyHandover> getAllHandovers() {
    final handovers = handoversBox.values.toList();
    handovers.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return handovers;
  }

  Future<void> addHandover(PropertyHandover handover) async {
    await handoversBox.put(handover.id, handover);
  }

  Future<void> updateHandover(PropertyHandover handover) async {
    await handoversBox.put(handover.id, handover);
  }

  Future<void> deleteHandover(String id) async {
    await handoversBox.delete(id);
  }

  PropertyHandover? getHandover(String id) => handoversBox.get(id);

  // --- Ewidencja przejazdów pojazdu (karta drogowa) ---

  Box<VehicleTrip> get tripsBox => Hive.box<VehicleTrip>(_tripsBox);

  /// Wszystkie przejazdy, najnowsze pierwsze.
  List<VehicleTrip> getAllTrips() {
    final trips = tripsBox.values.toList();
    trips.sort((a, b) => b.departureTime.compareTo(a.departureTime));
    return trips;
  }

  /// Przejazdy jednego pojazdu w danym miesiącu — zawartość jednej karty.
  ///
  /// W kolejności chronologicznej, bo tak wygląda druk: pierwszy wiersz to
  /// pierwszy przejazd miesiąca.
  List<VehicleTrip> getTripsForCard({
    required String vehicleId,
    required int year,
    required int month,
  }) {
    final ofCard = tripsBox.values.where(
      (t) => t.vehicleId == vehicleId && t.year == year && t.month == month,
    );
    return TripOdometer.inChainOrder(ofCard);
  }

  /// Miesiące, w których pojazd ma jakiekolwiek przejazdy — do listy kart.
  /// Najnowsze pierwsze.
  List<({int year, int month})> getMonthsWithTrips(String vehicleId) {
    final seen = <String, ({int year, int month})>{};
    for (final t in tripsBox.values) {
      if (t.vehicleId != vehicleId) continue;
      seen['${t.year}-${t.month}'] = (year: t.year, month: t.month);
    }
    final months = seen.values.toList()
      ..sort((a, b) {
        final byYear = b.year.compareTo(a.year);
        return byYear != 0 ? byYear : b.month.compareTo(a.month);
      });
    return months;
  }

  VehicleTrip? getTrip(String id) => tripsBox.get(id);

  /// Przejazd powiązany z danym raportem, jeśli już powstał.
  /// Chroni przed dopisaniem tego samego wyjazdu alarmowego dwa razy.
  VehicleTrip? getTripForReport(String reportId) {
    for (final t in tripsBox.values) {
      if (t.reportId == reportId) return t;
    }
    return null;
  }

  Future<void> addTrip(VehicleTrip trip) async {
    await tripsBox.put(trip.id, trip);
    await _rechainVehicle(trip.vehicleId);
  }

  Future<void> updateTrip(VehicleTrip trip) async {
    trip.updatedAt = DateTime.now();
    await tripsBox.put(trip.id, trip);
    await _rechainVehicle(trip.vehicleId);
  }

  Future<void> deleteTrip(String id) async {
    final trip = tripsBox.get(id);
    await tripsBox.delete(id);
    if (trip != null) await _rechainVehicle(trip.vehicleId);
  }

  /// Przelicza łańcuch licznika po każdej zmianie i zapisuje to, co się
  /// przesunęło.
  ///
  /// Konieczne, bo wpis dodany wstecz zmienia stan początkowy wszystkich
  /// późniejszych przejazdów tego pojazdu.
  Future<void> _rechainVehicle(String vehicleId) async {
    final changed = TripOdometer.rechain(
      tripsBox.values,
      vehicleId: vehicleId,
    );
    for (final trip in changed) {
      await tripsBox.put(trip.id, trip);
    }
  }

  /// Jednorazowe uzupełnienie ewidencji o wyjazdy sprzed jej wprowadzenia.
  ///
  /// Przejazd powstaje w chwili zapisania raportu, więc wyjazdy zapisane
  /// zanim ewidencja istniała nie mają swojego wiersza w karcie. Ta migracja
  /// domyka tę lukę — jednorazowo, bo od tego momentu nowe wyjazdy dopisują
  /// się same.
  ///
  /// Bezpieczna do powtórzenia: identyfikator przejazdu jest wyprowadzony
  /// z raportu i pojazdu, więc ponowne przejście trafia w istniejące wpisy
  /// zamiast tworzyć nowe.
  ///
  /// Zwraca liczbę dopisanych przejazdów.
  Future<int> backfillTripsFromReports({
    required String stationAddress,
  }) async {
    final processed = _backfilledReportIds;
    final existingIds = tripsBox.keys.map((k) => k.toString()).toSet();
    final affectedVehicles = <String>{};
    var added = 0;

    for (final report in reportsBox.values) {
      // Raport przerabiamy raz. Gdybyśmy przechodzili po wszystkich przy
      // każdym starcie, przejazd skasowany ręcznie wracałby po restarcie.
      if (processed.contains(report.id)) continue;
      processed.add(report.id);

      final trips = TripFromReport.build(
        report: report,
        stationAddress: stationAddress,
        resolveDriverName: (id) => getFirefighter(id)?.lastNameFirst ?? '',
        existingVehicleIdsForReport: const {},
        createdBy: report.createdBy,
        // Znacznik z raportu, nie „teraz" — patrz komentarz w TripFromReport.
        timestamp: report.updatedAt,
      );

      for (final trip in trips) {
        if (existingIds.contains(trip.id)) continue;
        await tripsBox.put(trip.id, trip);
        affectedVehicles.add(trip.vehicleId);
        added++;
      }
    }

    for (final vehicleId in affectedVehicles) {
      await _rechainVehicle(vehicleId);
    }

    await settingsBox.put(_backfilledReportIdsKey, processed.toList());
    return added;
  }

  /// Uzgadnia istniejące przejazdy z ich raportami.
  ///
  /// Dane z raportu trafiają do przejazdu w chwili **zapisania raportu**.
  /// Wszystko, co rozjechało się wcześniej — na przykład godzina powrotu
  /// dopisana w wersji sprzed tej synchronizacji — zostawało rozjechane na
  /// zawsze, bo sama aktualizacja aplikacji niczego wstecz nie naprawia.
  /// Ten przebieg to leczy.
  ///
  /// Zmieniamy wyłącznie kolumny, których źródłem jest raport. Licznik,
  /// dysponent, minuty pracy urządzeń, uwagi i „skąd" zostają nietknięte.
  ///
  /// Zwraca liczbę uzgodnionych przejazdów.
  Future<int> reconcileTripsWithReports() async {
    final byReport = <String, Report>{
      for (final r in reportsBox.values) r.id: r,
    };

    final affectedVehicles = <String>{};
    var changed = 0;

    for (final trip in tripsBox.values.toList()) {
      final reportId = trip.reportId;
      if (reportId == null) continue;
      final report = byReport[reportId];
      if (report == null) continue;

      final updated = TripFromReport.applyReportFields(
        trip,
        report,
        resolveDriverName: (id) => getFirefighter(id)?.lastNameFirst ?? '',
      );
      if (!updated) continue;

      await tripsBox.put(trip.id, trip);
      affectedVehicles.add(trip.vehicleId);
      changed++;
    }

    for (final vehicleId in affectedVehicles) {
      await _rechainVehicle(vehicleId);
    }
    return changed;
  }

  /// Uzupełnia „skąd" w przejazdach, które powstały, zanim jednostka miała
  /// zapisany adres remizy.
  ///
  /// Adres jest przepisywany do przejazdu w chwili jego utworzenia, więc
  /// wpisanie go w ustawieniach nie naprawiało wstecz pustej kolumny. Ruszamy
  /// wyłącznie puste pola — trasa wpisana ręcznie zostaje.
  Future<int> fillMissingRouteFrom(String stationAddress) async {
    final address = stationAddress.trim();
    if (address.isEmpty) return 0;

    var changed = 0;
    for (final trip in tripsBox.values.toList()) {
      if (trip.routeFrom.trim().isNotEmpty) continue;
      trip.routeFrom = address;
      await tripsBox.put(trip.id, trip);
      changed++;
    }
    return changed;
  }

  /// Raporty już przepisane do ewidencji.
  ///
  /// Lista, a nie pojedyncza flaga „zrobione": raporty potrafią dojść później
  /// z Dysku i one też muszą trafić do ewidencji, a jednocześnie przejazd
  /// skasowany ręcznie nie może wracać przy każdym uruchomieniu.
  static const String _backfilledReportIdsKey = 'tripsBackfilledReportIds';

  Set<String> get _backfilledReportIds =>
      ((settingsBox.get(_backfilledReportIdsKey) as List?) ?? const [])
          .map((e) => e.toString())
          .toSet();

  /// Stan licznika podpowiadany przy nowym przejeździe pojazdu.
  int? suggestedOdometerStart({
    required String vehicleId,
    required DateTime departureTime,
    String? excludeTripId,
  }) {
    return TripOdometer.previousReading(
      tripsBox.values,
      vehicleId: vehicleId,
      before: departureTime,
      excludeTripId: excludeTripId,
    );
  }

  // --- Threats ---

  Box<ThreatEntry> get threatsBox => Hive.box<ThreatEntry>(_threatsBox);

  List<ThreatEntry> getAllThreats() => threatsBox.values.toList();

  Future<void> addThreat(ThreatEntry threat) async {
    await threatsBox.put(threat.category, threat);
  }

  Future<void> initializeDefaultThreats() => ensureDefaultThreats();

  /// Uzgadnia słownik zagrożeń ze stałą listą [ThreatTypes.defaults]:
  /// - trzy stałe kategorie zawsze istnieją, z domyślnymi podtypami
  ///   w zadanej kolejności,
  /// - podtypy dodane ręcznie przez użytkownika zostają (na końcu listy),
  /// - podtypy z wycofanych list domyślnych i kategorie spoza stałej
  ///   trójki są usuwane.
  Future<void> ensureDefaultThreats() async {
    for (final entry in ThreatTypes.defaults.entries) {
      final existing = threatsBox.get(entry.key);
      final customSubtypes = existing == null
          ? const <String>[]
          : existing.subtypes
                .where(
                  (s) =>
                      !entry.value.contains(s) &&
                      !ThreatTypes.retiredSubtypes.contains(s),
                )
                .toList();
      await threatsBox.put(
        entry.key,
        ThreatEntry(
          category: entry.key,
          subtypes: [...entry.value, ...customSubtypes],
        ),
      );
    }
    final extraCategories = threatsBox.keys
        .where((k) => !ThreatTypes.defaults.containsKey(k))
        .toList();
    if (extraCategories.isNotEmpty) {
      await threatsBox.deleteAll(extraCategories);
    }
  }
}
