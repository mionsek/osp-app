import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class DatabaseService {
  static const String _vehiclesBox = 'vehicles';
  static const String _firefightersBox = 'firefighters';
  static const String _reportsBox = 'reports';
  static const String _configBox = 'config';
  static const String _threatsBox = 'threats';

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
    ]);
  }

  // --- Config ---

  Box<UnitConfig> get configBox => Hive.box<UnitConfig>(_configBox);

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
    final reportsThisYear =
        reportsBox.values.where((r) => r.year == year).toList();
    final nextNum = reportsThisYear.length + 1;
    return '${nextNum.toString().padLeft(4, '0')}/$year';
  }

  // --- Threats ---

  Box<ThreatEntry> get threatsBox => Hive.box<ThreatEntry>(_threatsBox);

  List<ThreatEntry> getAllThreats() => threatsBox.values.toList();

  Future<void> addThreat(ThreatEntry threat) async {
    await threatsBox.put(threat.category, threat);
  }

  Future<void> initializeDefaultThreats() async {
    // Reseed if old keys exist (lowercase names from previous version)
    final needsReseed = threatsBox.isEmpty ||
        threatsBox.containsKey('Pożar') && !threatsBox.containsKey('Miejscowe Zagrożenie') ||
        threatsBox.containsKey('Miejscowe zagrożenie') ||
        threatsBox.containsKey('Fałszywy alarm');
    if (!needsReseed) return;
    await threatsBox.clear();
    final defaults = {
      'Miejscowe Zagrożenie': [
        'Kolizja',
        'Wypadek',
        'Plama oleju',
        'Zalanie mieszkania',
        'Powalone drzewo',
        'Uwięzienie zwierzęcia',
      ],
      'Pożar': [
        'Pożar budynku',
        'Pożar traw',
        'Pożar lasu',
        'Pożar samochodu',
        'Pożar śmietnika',
      ],
      'Fałszywy Alarm': <String>[],
    };
    for (final entry in defaults.entries) {
      await threatsBox.put(
        entry.key,
        ThreatEntry(category: entry.key, subtypes: entry.value),
      );
    }
  }
}
