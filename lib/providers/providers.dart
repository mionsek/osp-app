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
  return SyncService(
    ref.watch(databaseServiceProvider),
    ref.watch(googleAuthServiceProvider),
    ref.watch(googleDriveServiceProvider),
  );
});

final syncStateProvider = StateNotifierProvider<SyncStateNotifier, SyncState>((
  ref,
) {
  final syncService = ref.watch(syncServiceProvider);
  return SyncStateNotifier(syncService);
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
    }
  }

  Future<bool> signIn() async {
    final success = await _syncService.authService.signIn();
    if (success) {
      state = state.copyWith(userEmail: _syncService.authService.userEmail);
    }
    return success;
  }

  Future<String> createUnit(String unitName) async {
    final code = await _syncService.createUnit(unitName);
    state = _syncService.state;
    _syncService.startAutoSync();
    return code;
  }

  Future<bool> joinUnit(String code) async {
    final success = await _syncService.joinUnit(code);
    if (success) {
      state = _syncService.state;
      _syncService.startAutoSync();
    }
    return success;
  }

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
}

// --- Config ---

final unitConfigProvider =
    StateNotifierProvider<UnitConfigNotifier, UnitConfig>((ref) {
      return UnitConfigNotifier(ref.watch(databaseServiceProvider));
    });

class UnitConfigNotifier extends StateNotifier<UnitConfig> {
  final DatabaseService _db;
  UnitConfigNotifier(this._db) : super(_db.getConfig());

  Future<void> save(UnitConfig config) async {
    await _db.saveConfig(config);
    state = config;
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
    return VehiclesNotifier(ref.watch(databaseServiceProvider));
  },
);

class VehiclesNotifier extends StateNotifier<List<Vehicle>> {
  final DatabaseService _db;
  VehiclesNotifier(this._db) : super(_db.getAllVehicles());

  Future<void> add(Vehicle vehicle) async {
    await _db.addVehicle(vehicle);
    state = _db.getAllVehicles();
  }

  Future<void> update(Vehicle vehicle) async {
    await _db.updateVehicle(vehicle);
    state = _db.getAllVehicles();
  }

  Future<void> delete(String id) async {
    await _db.deleteVehicle(id);
    state = _db.getAllVehicles();
  }

  void refresh() {
    state = _db.getAllVehicles();
  }
}

// --- Firefighters ---

final firefightersProvider =
    StateNotifierProvider<FirefightersNotifier, List<Firefighter>>((ref) {
      return FirefightersNotifier(ref.watch(databaseServiceProvider));
    });

class FirefightersNotifier extends StateNotifier<List<Firefighter>> {
  final DatabaseService _db;
  FirefightersNotifier(this._db) : super(_db.getAllFirefighters());

  Future<void> add(Firefighter firefighter) async {
    await _db.addFirefighter(firefighter);
    state = _db.getAllFirefighters();
  }

  Future<void> update(Firefighter firefighter) async {
    await _db.updateFirefighter(firefighter);
    state = _db.getAllFirefighters();
  }

  Future<void> delete(String id) async {
    await _db.deleteFirefighter(id);
    state = _db.getAllFirefighters();
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
  return ReportsNotifier(ref.watch(databaseServiceProvider));
});

class ReportsNotifier extends StateNotifier<List<Report>> {
  final DatabaseService _db;
  ReportsNotifier(this._db) : super(_db.getAllReports());

  Future<void> add(Report report) async {
    await _db.addReport(report);
    state = _db.getAllReports();
  }

  Future<void> update(Report report) async {
    await _db.updateReport(report);
    state = _db.getAllReports();
  }

  Future<void> delete(String id) async {
    await _db.deleteReport(id);
    state = _db.getAllReports();
  }

  String getNextNumber() => _db.getNextReportNumber();

  void refresh() {
    state = _db.getAllReports();
  }
}

// --- Property handovers (przekazanie mienia) ---

final handoversProvider =
    StateNotifierProvider<HandoversNotifier, List<PropertyHandover>>((ref) {
      return HandoversNotifier(ref.watch(databaseServiceProvider));
    });

class HandoversNotifier extends StateNotifier<List<PropertyHandover>> {
  final DatabaseService _db;
  HandoversNotifier(this._db) : super(_db.getAllHandovers());

  Future<void> add(PropertyHandover handover) async {
    await _db.addHandover(handover);
    state = _db.getAllHandovers();
  }

  Future<void> update(PropertyHandover handover) async {
    await _db.updateHandover(handover);
    state = _db.getAllHandovers();
  }

  Future<void> delete(String id) async {
    await _db.deleteHandover(id);
    state = _db.getAllHandovers();
  }

  void refresh() {
    state = _db.getAllHandovers();
  }
}

// --- Ewidencja przejazdów pojazdu (karta drogowa) ---

final vehicleTripsProvider =
    StateNotifierProvider<VehicleTripsNotifier, List<VehicleTrip>>((ref) {
      return VehicleTripsNotifier(ref.watch(databaseServiceProvider));
    });

class VehicleTripsNotifier extends StateNotifier<List<VehicleTrip>> {
  final DatabaseService _db;
  VehicleTripsNotifier(this._db) : super(_db.getAllTrips());

  Future<void> add(VehicleTrip trip) async {
    await _db.addTrip(trip);
    state = _db.getAllTrips();
  }

  Future<void> update(VehicleTrip trip) async {
    await _db.updateTrip(trip);
    state = _db.getAllTrips();
  }

  Future<void> delete(String id) async {
    await _db.deleteTrip(id);
    state = _db.getAllTrips();
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
      return ThreatsNotifier(ref.watch(databaseServiceProvider));
    });

class ThreatsNotifier extends StateNotifier<List<ThreatEntry>> {
  final DatabaseService _db;
  ThreatsNotifier(this._db) : super(_db.getAllThreats());

  Future<void> addCustomSubtype(String category, String subtype) async {
    final existing = _db.threatsBox.get(category);
    if (existing != null && !existing.subtypes.contains(subtype)) {
      existing.subtypes.add(subtype);
      await _db.addThreat(existing);
      state = _db.getAllThreats();
    }
  }

  void refresh() {
    state = _db.getAllThreats();
  }
}
