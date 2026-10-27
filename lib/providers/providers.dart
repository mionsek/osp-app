import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../models/sync_state.dart';
import '../services/database_service.dart';
import '../services/google_auth_service.dart';
import '../services/google_drive_service.dart';
import '../services/sync_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// --- Google / Sync ---

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService(ref.watch(googleAuthServiceProvider));
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    ref.watch(databaseServiceProvider),
    ref.watch(googleAuthServiceProvider),
    ref.watch(googleDriveServiceProvider),
  );
  service.onDataPulled = () {
    ref.read(reportsProvider.notifier).refresh();
    ref.read(handoversProvider.notifier).refresh();
    ref.read(vehicleTripsProvider.notifier).refresh();
    ref.read(firefightersProvider.notifier).refresh();
    ref.read(vehiclesProvider.notifier).refresh();
    ref.read(threatsProvider.notifier).refresh();
    ref.read(unitConfigProvider.notifier).refresh();
  };
  return service;
});

final syncStateProvider = StateNotifierProvider<SyncStateNotifier, SyncState>((
  ref,
) {
  final syncService = ref.watch(syncServiceProvider);
  return SyncStateNotifier(syncService);
});

/// Zapis na telefonie, który ma od razu pójść na Dysk jednostki.
void Function() _sendSoon(Ref ref) =>
    () => ref.read(syncServiceProvider).notifyLocalChange();

/// Wyjazdy, których obecnej wersji nie ma jeszcze na Dysku jednostki.
/// Bez połączenia z jednostką — pusty: nie ma dokąd wysyłać.
final reportsAwaitingUploadProvider = Provider<Set<String>>((ref) {
  final sync = ref.watch(syncStateProvider);
  final reports = ref.watch(reportsProvider);
  if (!sync.isConnected || sync.unitFolderId == null) return const {};
  return ref.read(syncServiceProvider).reportsAwaitingUpload(reports);
});

/// Przekazania mienia, których obecnej wersji nie ma jeszcze na Dysku.
final handoversAwaitingUploadProvider = Provider<Set<String>>((ref) {
  final sync = ref.watch(syncStateProvider);
  final handovers = ref.watch(handoversProvider);
  if (!sync.isConnected || sync.unitFolderId == null) return const {};
  return ref.read(syncServiceProvider).handoversAwaitingUpload(handovers);
});

/// Czy zalogowana osoba może zarządzać jednostką — dodawać pojazdy,
/// ratowników i nadawać uprawnienia.
///
/// Praca bez jednostki (tryb offline) to własne, lokalne dane, więc wtedy
/// wszystko jest dozwolone.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(syncStateProvider).isCurrentUserAdmin;
});

class SyncStateNotifier extends StateNotifier<SyncState> {
  final SyncService _syncService;

  SyncStateNotifier(this._syncService) : super(const SyncState()) {
    _syncService.onStateChanged = (newState) {
      if (mounted) state = newState;
    };
  }

  Future<void> initialize() async {
    await _syncService.restoreState();
    state = _syncService.state;
    if (state.isConnected) {
      _syncService.startAutoSync();
      // Od razu po uruchomieniu — zmiany z innych telefonów i to, co nie
      // wyszło z tego przed zamknięciem aplikacji.
      _syncService.syncIfOnline();
    }
  }

  Future<bool> signIn() async {
    final success = await _syncService.signIn();
    state = _syncService.state;
    if (state.isConnected) _syncService.startAutoSync();
    return success;
  }

  /// Wybór innego konta Google. `false` — nie wybrano żadnego.
  Future<bool> switchAccount() async {
    final success = await _syncService.switchAccount();
    _afterAccountChange();
    return success;
  }

  /// Przejście z konta jednostki na prywatne konto tej samej osoby.
  Future<AccountSwitchResult> switchToPersonalAccount(String email) async {
    final result = await _syncService.switchToPersonalAccount(email);
    _afterAccountChange();
    return result;
  }

  /// Nowe konto z dostępem do jednostki synchronizuje od razu; bez dostępu
  /// nie ponawiamy co 5 minut tego samego błędu.
  void _afterAccountChange() {
    state = _syncService.state;
    if (state.status == SyncStatus.idle && state.unitFolderId != null) {
      _syncService.startAutoSync();
      syncNow();
    }
  }

  /// Imię i nazwisko z zalogowanego konta Google.
  String? get displayName => _syncService.authService.displayName;

  Future<String> createUnit(String unitName) async {
    final code = await _syncService.createUnit(unitName);
    state = _syncService.state;
    _syncService.startAutoSync();
    return code;
  }

  /// Wyszukanie jednostki po kodzie — przed dołączeniem ekran pokazuje,
  /// czyj to folder.
  Future<UnitLookup> lookupUnit(String code) => _syncService.lookupUnit(code);

  Future<void> joinFoundUnit(UnitCandidate unit, String code) async {
    await _syncService.joinFoundUnit(unit, code);
    state = _syncService.state;
    _syncService.startAutoSync();
  }

  /// Ratownicy i pojazdy z telefonu spoza list jednostki — przed dołączeniem
  /// ekran ostrzega, że zastąpi je lista jednostki.
  Future<LocalListEntries> localOnlyListEntries(String unitFolderId) =>
      _syncService.localOnlyListEntries(unitFolderId);

  /// Jednostki już założone na zalogowanym koncie.
  Future<List<UnitCandidate>> ownUnits() => _syncService.ownUnits();

  /// Runs full sync. Returns number of duplicate report numbers detected.
  Future<int> syncNow() async {
    final duplicates = await _syncService.syncAll();
    state = _syncService.state;
    return duplicates;
  }

  /// Pulls only reports from Drive (lightweight, used before creating a new report).
  Future<void> pullReportsOnly() async {
    await _syncService.pullReportsOnly();
  }

  /// Powrót do aplikacji z tła.
  void onAppResumed() => _syncService.syncIfOnline();

  /// Otwarcie listy — pobranie zmian kolegów, jeśli dawno nie było.
  Future<void> syncIfStale() => _syncService.syncIfStale();

  /// Komunikaty o nowych numerach wyjazdów zostały pokazane.
  void clearRenumberNotes() => _syncService.clearRenumberNotes();

  Future<void> disconnect() async {
    await _syncService.disconnectUnit();
    state = const SyncState();
  }

  Future<void> signOut() async {
    _syncService.stopAutoSync();
    await _syncService.authService.signOut();
    await _syncService.disconnectUnit();
    state = const SyncState();
  }

  /// Wylogowanie razem z usunięciem danych jednostki z telefonu. Ekran
  /// najpierw synchronizuje, żeby zmiany z tego telefonu nie przepadły.
  Future<void> signOutAndWipe() async {
    await signOut();
    await _syncService.wipeLocalUnitData();
    state = _syncService.state;
  }
}

// --- Config ---

final unitConfigProvider =
    StateNotifierProvider<UnitConfigNotifier, UnitConfig>((ref) {
      return UnitConfigNotifier(
        ref.watch(databaseServiceProvider),
        onChanged: _sendSoon(ref),
      );
    });

class UnitConfigNotifier extends StateNotifier<UnitConfig> {
  final DatabaseService _db;
  final void Function() _onChanged;
  UnitConfigNotifier(this._db, {void Function()? onChanged})
      : _onChanged = onChanged ?? _noop,
        super(_db.getConfig());

  Future<void> save(UnitConfig config) async {
    // Porównanie z zapisaną konfiguracją, nie ze stanem ekranu: po dołączeniu
    // do jednostki zapis ma już dane z Dysku i nie jest to edycja.
    final before = _db.getConfig();
    final edited = before.fullName != config.fullName ||
        before.locality != config.locality ||
        before.unitStreet != config.unitStreet;
    if (edited) await _db.markUnitConfigEdited();
    await _db.saveConfig(config);
    state = config;
    // Drukarka i ustawienia telefonu nie idą na Dysk.
    if (edited) _onChanged();
  }

  void refresh() {
    state = _db.getConfig();
  }

  /// [fullName] to pełna nazwa wpisana przez użytkownika, np.
  /// „Ochotnicza Straż Pożarna w Kielnie" — trzymamy ją w całości, bo
  /// sklejanie prefiksu z miejscownikiem dawało błędne gramatycznie
  /// „Ochotnicza Straż Pożarna Kielno".
  Future<void> completeOnboarding(
    String fullName, {
    String locality = '',
    String street = '',
  }) async {
    final config = UnitConfig(
      unitFullName: fullName,
      locality: locality.trim(),
      unitStreet: street.trim(),
      onboardingCompleted: true,
      isAdmin: true,
    );
    await save(config);
  }
}

// --- Vehicles ---

final vehiclesProvider = StateNotifierProvider<VehiclesNotifier, List<Vehicle>>(
  (ref) {
    return VehiclesNotifier(
      ref.watch(databaseServiceProvider),
      onChanged: _sendSoon(ref),
    );
  },
);

class VehiclesNotifier extends StateNotifier<List<Vehicle>> {
  final DatabaseService _db;
  final void Function() _onChanged;
  VehiclesNotifier(this._db, {void Function()? onChanged})
      : _onChanged = onChanged ?? _noop,
        super(_db.getAllVehicles());

  Future<void> add(Vehicle vehicle) async {
    vehicle.updatedAt = DateTime.now();
    await _db.addVehicle(vehicle);
    state = _db.getAllVehicles();
    _onChanged();
  }

  Future<void> update(Vehicle vehicle) async {
    // Stempel rozstrzyga przy synchronizacji, czyja wersja wygrywa.
    vehicle.updatedAt = DateTime.now();
    await _db.updateVehicle(vehicle);
    state = _db.getAllVehicles();
    _onChanged();
  }

  Future<void> delete(String id) async {
    await _db.deleteVehicle(id);
    state = _db.getAllVehicles();
    _onChanged();
  }

  void refresh() {
    state = _db.getAllVehicles();
  }
}

// --- Firefighters ---

final firefightersProvider =
    StateNotifierProvider<FirefightersNotifier, List<Firefighter>>((ref) {
      return FirefightersNotifier(
        ref.watch(databaseServiceProvider),
        onChanged: _sendSoon(ref),
      );
    });

class FirefightersNotifier extends StateNotifier<List<Firefighter>> {
  final DatabaseService _db;
  final void Function() _onChanged;
  FirefightersNotifier(this._db, {void Function()? onChanged})
      : _onChanged = onChanged ?? _noop,
        super(_db.getAllFirefighters());

  Future<void> add(Firefighter firefighter) async {
    firefighter.updatedAt = DateTime.now();
    await _db.addFirefighter(firefighter);
    state = _db.getAllFirefighters();
    _onChanged();
  }

  Future<void> update(Firefighter firefighter) async {
    // Stempel rozstrzyga przy synchronizacji, czyja wersja wygrywa.
    firefighter.updatedAt = DateTime.now();
    await _db.updateFirefighter(firefighter);
    state = _db.getAllFirefighters();
    _onChanged();
  }

  Future<void> delete(String id) async {
    await _db.deleteFirefighter(id);
    state = _db.getAllFirefighters();
    _onChanged();
  }

  List<Firefighter> search(String query) => _db.searchFirefighters(query);

  void refresh() {
    state = _db.getAllFirefighters();
  }
}

// --- Reports ---

final reportsProvider = StateNotifierProvider<ReportsNotifier, List<Report>>((
  ref,
) {
  return ReportsNotifier(
    ref.watch(databaseServiceProvider),
    onChanged: _sendSoon(ref),
  );
});

class ReportsNotifier extends StateNotifier<List<Report>> {
  final DatabaseService _db;
  final void Function() _onChanged;
  ReportsNotifier(this._db, {void Function()? onChanged})
      : _onChanged = onChanged ?? _noop,
        super(_db.getAllReports());

  Future<void> add(Report report) async {
    await _db.addReport(report);
    state = _db.getAllReports();
    _onChanged();
  }

  Future<void> update(Report report) async {
    await _db.updateReport(report);
    state = _db.getAllReports();
    _onChanged();
  }

  Future<void> delete(String id) async {
    await _db.deleteReport(id);
    state = _db.getAllReports();
    _onChanged();
  }

  String getNextNumber() => _db.getNextReportNumber();

  /// Nadaje wyjazdowi pierwszy wolny numer w jego roku — gdy ten sam numer
  /// nadały dwa telefony. Zwraca nowy numer.
  Future<String> assignNextNumber(Report report) async {
    final number = _db.nextReportNumberFor(report.reportNumber,
        fallbackYear: report.year);
    report
      ..reportNumber = number
      ..updatedAt = DateTime.now();
    await update(report);
    return number;
  }

  void refresh() {
    state = _db.getAllReports();
  }
}

// --- Property handovers (przekazanie mienia) ---

final handoversProvider =
    StateNotifierProvider<HandoversNotifier, List<PropertyHandover>>((ref) {
      return HandoversNotifier(
        ref.watch(databaseServiceProvider),
        onChanged: _sendSoon(ref),
      );
    });

class HandoversNotifier extends StateNotifier<List<PropertyHandover>> {
  final DatabaseService _db;
  final void Function() _onChanged;
  HandoversNotifier(this._db, {void Function()? onChanged})
      : _onChanged = onChanged ?? _noop,
        super(_db.getAllHandovers());

  Future<void> add(PropertyHandover handover) async {
    await _db.addHandover(handover);
    state = _db.getAllHandovers();
    _onChanged();
  }

  Future<void> update(PropertyHandover handover) async {
    await _db.updateHandover(handover);
    state = _db.getAllHandovers();
    _onChanged();
  }

  Future<void> delete(String id) async {
    await _db.deleteHandover(id);
    state = _db.getAllHandovers();
    _onChanged();
  }

  void refresh() {
    state = _db.getAllHandovers();
  }
}

// --- Ewidencja przejazdów pojazdu (karta drogowa) ---

final vehicleTripsProvider =
    StateNotifierProvider<VehicleTripsNotifier, List<VehicleTrip>>((ref) {
      return VehicleTripsNotifier(
        ref.watch(databaseServiceProvider),
        onChanged: _sendSoon(ref),
      );
    });

class VehicleTripsNotifier extends StateNotifier<List<VehicleTrip>> {
  final DatabaseService _db;
  final void Function() _onChanged;
  VehicleTripsNotifier(this._db, {void Function()? onChanged})
      : _onChanged = onChanged ?? _noop,
        super(_db.getAllTrips());

  Future<void> add(VehicleTrip trip) async {
    await _db.addTrip(trip);
    state = _db.getAllTrips();
    _onChanged();
  }

  Future<void> update(VehicleTrip trip) async {
    await _db.updateTrip(trip);
    state = _db.getAllTrips();
    _onChanged();
  }

  Future<void> delete(String id) async {
    await _db.deleteTrip(id);
    state = _db.getAllTrips();
    _onChanged();
  }

  /// Przejazd poprawiony w formularzu razem z godzinami powiązanego wyjazdu.
  /// Zwraca wyjazd, jeśli też się zmienił.
  Future<Report?> saveEditedByUser(
    VehicleTrip trip, {
    required Set<String> touched,
    required bool canEditReport,
  }) async {
    final report = await _db.saveTripEditedByUser(
      trip,
      touched: touched,
      canEditReport: canEditReport,
    );
    state = _db.getAllTrips();
    _onChanged();
    return report;
  }

  void refresh() {
    state = _db.getAllTrips();
  }
}

/// Przejazdy jednej karty: pojazd + miesiąc, w kolejności chronologicznej.
final tripsForCardProvider = Provider.family<List<VehicleTrip>,
    ({String vehicleId, int year, int month})>((ref, key) {
  // Zależność od listy przejazdów, żeby karta odświeżała się po każdej zmianie.
  ref.watch(vehicleTripsProvider);
  return ref
      .watch(databaseServiceProvider)
      .getTripsForCard(
        vehicleId: key.vehicleId,
        year: key.year,
        month: key.month,
      );
});

/// Miesiące, w których dany pojazd ma przejazdy — lista kart do wyboru.
final tripMonthsProvider =
    Provider.family<List<({int year, int month})>, String>((ref, vehicleId) {
  ref.watch(vehicleTripsProvider);
  return ref.watch(databaseServiceProvider).getMonthsWithTrips(vehicleId);
});

// --- Threats ---

final threatsProvider =
    StateNotifierProvider<ThreatsNotifier, List<ThreatEntry>>((ref) {
      return ThreatsNotifier(
        ref.watch(databaseServiceProvider),
        onChanged: _sendSoon(ref),
      );
    });

class ThreatsNotifier extends StateNotifier<List<ThreatEntry>> {
  final DatabaseService _db;
  final void Function() _onChanged;
  ThreatsNotifier(this._db, {void Function()? onChanged})
      : _onChanged = onChanged ?? _noop,
        super(_db.getAllThreats());

  Future<void> addCustomSubtype(String category, String subtype) async {
    final existing = _db.threatsBox.get(category);
    if (existing != null && !existing.subtypes.contains(subtype)) {
      existing.subtypes.add(subtype);
      await _db.addThreat(existing);
      state = _db.getAllThreats();
      _onChanged();
    }
  }

  void refresh() {
    state = _db.getAllThreats();
  }
}

void _noop() {}
