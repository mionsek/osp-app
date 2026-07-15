import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/threat_types.dart';
import '../models/models.dart';

class DatabaseService {
  static const String _vehiclesBox = 'vehicles';
  static const String _firefightersBox = 'firefighters';
  static const String _reportsBox = 'reports';
  static const String _configBox = 'config';
  static const String _threatsBox = 'threats';
  static const String _settingsBox = 'settings';

  static Future<void> initialize() async {
    await Hive.initFlutter();

    Hive.registerAdapter(VehicleAdapter());
    Hive.registerAdapter(FirefighterAdapter());
    Hive.registerAdapter(CrewAssignmentAdapter());
    Hive.registerAdapter(ThreatEntryAdapter());
    Hive.registerAdapter(ReportAdapter());
    Hive.registerAdapter(UnitConfigAdapter());

    await Future.wait([
      Hive.openBox<Vehicle>(_vehiclesBox),
      Hive.openBox<Firefighter>(_firefightersBox),
      Hive.openBox<Report>(_reportsBox),
      Hive.openBox<UnitConfig>(_configBox),
      Hive.openBox<ThreatEntry>(_threatsBox),
      Hive.openBox<dynamic>(_settingsBox),
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
        .where((f) => f.fullName.toLowerCase().contains(lower))
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
