import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/models.dart';
import '../models/sync_state.dart';
import '../services/ad_service.dart';
import '../services/database_service.dart';
import '../services/google_auth_service.dart';
import '../services/google_drive_service.dart';
import '../services/purchase_service.dart';
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
  Future<void> completeOnboarding(String fullName) async {
    final config = UnitConfig(
      unitFullName: fullName,
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

// --- Ads & Premium ---

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService(ref.watch(databaseServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Whether the user has purchased the Remove Ads IAP.
final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>((ref) {
  return PremiumNotifier(ref.watch(purchaseServiceProvider));
});

class PremiumNotifier extends StateNotifier<bool> {
  final PurchaseService _purchaseService;

  PremiumNotifier(this._purchaseService) : super(_purchaseService.isPremium) {
    // Listen for purchase stream updates
    final controller = _purchaseService.initialize();
    controller.stream.listen(
      (isPremium) {
        if (mounted) state = isPremium;
      },
      onError: (e) => debugPrint('PremiumNotifier: stream error — $e'),
      cancelOnError: false,
    );
  }

  Future<bool> buyRemoveAds() async {
    return _purchaseService.buyRemoveAds();
  }

  Future<void> restorePurchases() async {
    await _purchaseService.restorePurchases();
    if (mounted) state = _purchaseService.isPremium;
  }

  Future<ProductDetails?> fetchProductDetails() {
    return _purchaseService.fetchProductDetails();
  }
}

/// Returns true if banner ads should be shown.
/// False for the ospkielno unit OR if user purchased premium.
final showAdsProvider = Provider<bool>((ref) {
  final unitConfig = ref.watch(unitConfigProvider);
  final isPremium = ref.watch(premiumProvider);
  return !isPremium && shouldShowAds(unitConfig.ownerEmail);
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
