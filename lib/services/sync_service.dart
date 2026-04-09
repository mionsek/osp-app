import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../models/sync_state.dart';
import 'database_service.dart';
import 'google_auth_service.dart';
import 'google_drive_service.dart';

/// Orchestrates bidirectional sync between local Hive and Google Drive.
class SyncService {
  final DatabaseService _db;
  final GoogleAuthService authService;
  final GoogleDriveService _driveService;

  Timer? _autoSyncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  /// Callback to notify listeners about sync state changes.
  void Function(SyncState)? onStateChanged;

  SyncState _state = const SyncState();
  SyncState get state => _state;

  SyncService(this._db, this.authService, this._driveService);

  // â”€â”€ Initialization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Start auto-sync: every 5 minutes + on connectivity change.
  void startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncAll(),
    );

    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && _state.isConnected && !_isSyncing) {
        syncAll();
      }
    });
  }

  /// Stop auto-sync.
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  void dispose() {
    stopAutoSync();
  }

  // â”€â”€ Unit creation / joining â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Create a new unit on Google Drive. Returns invite code.
  Future<String> createUnit(String unitName) async {
    final folderId = await _driveService.createUnitFolder(unitName);
    final inviteCode = _generateInviteCode();

    // Write unit config to Drive (in config subfolder)
    var configFolderId = await _driveService.findConfigFolder(folderId);
    configFolderId ??= await _driveService.createSubfolder(folderId, 'config');
    await _driveService.writeJsonFile(configFolderId, 'unit_config.json', {
      'unitName': unitName,
      'inviteCode': inviteCode,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': authService.userEmail,
    });

    _updateState(_state.copyWith(
      status: SyncStatus.idle,
      userEmail: authService.userEmail,
      unitFolderId: folderId,
      unitInviteCode: inviteCode,
    ));

    // Save Drive folder ID to local config
    await _saveDriveConfig(folderId, inviteCode);

    // Push all local data to Drive
    await _pushAllData();

    return inviteCode;
  }

  /// Join an existing unit by invite code.
  Future<bool> joinUnit(String code) async {
    final folderId = await _driveService.findUnitByInviteCode(code.trim().toUpperCase());
    if (folderId == null) return false;

    _updateState(_state.copyWith(
      status: SyncStatus.idle,
      userEmail: authService.userEmail,
      unitFolderId: folderId,
      unitInviteCode: code.trim().toUpperCase(),
    ));

    await _saveDriveConfig(folderId, code.trim().toUpperCase());

    // Pull remote data to local
    await _pullAllData();

    return true;
  }

  /// Disconnect from the unit (keep local data).
  Future<void> disconnectUnit() async {
    stopAutoSync();
    final config = _db.getConfig();
    await _db.saveConfig(UnitConfig(
      namePrefix: config.namePrefix,
      locality: config.locality,
      onboardingCompleted: config.onboardingCompleted,
      isAdmin: config.isAdmin,
    ));
    _updateState(const SyncState());
  }

  // â”€â”€ Full sync â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Run a full bidirectional sync.
  Future<void> syncAll() async {
    if (_isSyncing || !_state.isConnected || _state.unitFolderId == null) return;

    _isSyncing = true;
    _updateState(_state.copyWith(status: SyncStatus.syncing));

    try {
      await _pushAllData();
      await _pullAllData();

      _updateState(_state.copyWith(
        status: SyncStatus.idle,
        lastSyncTime: DateTime.now(),
        errorMessage: null,
      ));
    } catch (e) {
      debugPrint('Sync error: $e');
      _updateState(_state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      ));
    } finally {
      _isSyncing = false;
    }
  }

  // â”€â”€ Push local â†’ Drive â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pushAllData() async {
    final folderId = _state.unitFolderId!;

    // Find or create config folder
    var configFolderId = await _driveService.findConfigFolder(folderId);
    configFolderId ??= await _driveService.createSubfolder(folderId, 'config');

    // Push firefighters to config/
    final firefighters = _db.getAllFirefighters();
    await _driveService.writeJsonFile(configFolderId, 'firefighters.json', {
      'updatedAt': DateTime.now().toIso8601String(),
      'data': firefighters.map(_firefighterToJson).toList(),
    });

    // Push vehicles to config/
    final vehicles = _db.getAllVehicles();
    await _driveService.writeJsonFile(configFolderId, 'vehicles.json', {
      'updatedAt': DateTime.now().toIso8601String(),
      'data': vehicles.map(_vehicleToJson).toList(),
    });

    // Push threat types to config/
    final threats = _db.getAllThreats();
    await _driveService.writeJsonFile(configFolderId, 'threat_types.json', {
      'updatedAt': DateTime.now().toIso8601String(),
      'data': threats.map(_threatToJson).toList(),
    });

    // Push unit config to config/
    final config = _db.getConfig();
    await _driveService.writeJsonFile(configFolderId, 'unit_config.json', {
      'unitName': '${config.namePrefix} ${config.locality}'.trim(),
      'inviteCode': _state.unitInviteCode,
      'updatedAt': DateTime.now().toIso8601String(),
      'createdBy': _state.userEmail,
    });

    // Push reports to reports/{year}/
    final reportsFolderId = await _driveService.findReportsFolder(folderId);
    if (reportsFolderId != null) {
      final reports = _db.getAllReports();
      for (final report in reports) {
        final yearFolderId = await _driveService.findOrCreateYearFolder(
          reportsFolderId, report.year,
        );
        final fileName = _buildReportFileName(report);
        await _driveService.writeJsonFile(
          yearFolderId,
          fileName,
          _reportToJson(report),
        );
      }
    }
  }

  // â”€â”€ Pull Drive â†’ local â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pullAllData() async {
    final folderId = _state.unitFolderId!;

    // Find config folder (try new structure, fallback to root)
    final configFolderId = await _driveService.findConfigFolder(folderId);
    final dataFolderId = configFolderId ?? folderId;

    // Pull firefighters
    final ffData = await _driveService.readJsonFileByName(dataFolderId, 'firefighters.json');
    if (ffData != null && ffData['data'] is List) {
      for (final item in ffData['data'] as List) {
        final ff = _firefighterFromJson(item as Map<String, dynamic>);
        await _db.addFirefighter(ff);
      }
    }

    // Pull vehicles
    final vData = await _driveService.readJsonFileByName(dataFolderId, 'vehicles.json');
    if (vData != null && vData['data'] is List) {
      for (final item in vData['data'] as List) {
        final v = _vehicleFromJson(item as Map<String, dynamic>);
        await _db.addVehicle(v);
      }
    }

    // Pull threat types (new name: threat_types.json, fallback: threats.json)
    var tData = await _driveService.readJsonFileByName(dataFolderId, 'threat_types.json');
    tData ??= await _driveService.readJsonFileByName(dataFolderId, 'threats.json');
    if (tData != null && tData['data'] is List) {
      for (final item in tData['data'] as List) {
        final t = _threatFromJson(item as Map<String, dynamic>);
        await _db.addThreat(t);
      }
    }

    // Pull reports from reports/{year}/ subfolders
    final reportsFolderId = await _driveService.findReportsFolder(folderId);
    if (reportsFolderId != null) {
      // List year subfolders
      final yearFolders = await _driveService.listSubfolders(reportsFolderId);
      for (final yearFolder in yearFolders) {
        final reportFiles = await _driveService.listJsonFiles(yearFolder.id!);
        for (final file in reportFiles) {
          final data = await _driveService.readJsonFile(file.id!);
          if (data != null) {
            final report = _reportFromJson(data);
            final local = _db.getReport(report.id);
            if (local == null || report.updatedAt.isAfter(local.updatedAt)) {
              await _db.addReport(report);
            }
          }
        }
      }
      // Also check for legacy reports directly in reports/ folder
      final legacyFiles = await _driveService.listJsonFiles(reportsFolderId);
      for (final file in legacyFiles) {
        final data = await _driveService.readJsonFile(file.id!);
        if (data != null) {
          final report = _reportFromJson(data);
          final local = _db.getReport(report.id);
          if (local == null || report.updatedAt.isAfter(local.updatedAt)) {
            await _db.addReport(report);
          }
        }
      }
    }

    // Pull unit config
    final configData = await _driveService.readJsonFileByName(dataFolderId, 'unit_config.json');
    if (configData != null && configData['unitName'] != null) {
      final parts = (configData['unitName'] as String).split(' ');
      if (parts.length > 3) {
        final locality = parts.last;
        final prefix = parts.sublist(0, parts.length - 1).join(' ');
        final config = _db.getConfig();
        await _db.saveConfig(UnitConfig(
          namePrefix: prefix,
          locality: locality,
          onboardingCompleted: config.onboardingCompleted,
          isAdmin: config.isAdmin,
        ));
      }
    }
  }

  // â”€â”€ Restore state on app start â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Try to restore sync state from saved config.
  Future<void> restoreState() async {
    if (!authService.isSignedIn) {
      _updateState(const SyncState());
      return;
    }

    // Read stored Drive folder ID from Hive (we store it in configBox)
    final driveConfig = _db.configBox.get('driveSync');
    if (driveConfig == null) {
      _updateState(SyncState(
        status: SyncStatus.disconnected,
        userEmail: authService.userEmail,
      ));
      return;
    }

    // driveConfig stores folderId in namePrefix, inviteCode in locality
    _updateState(SyncState(
      status: SyncStatus.idle,
      userEmail: authService.userEmail,
      unitFolderId: driveConfig.namePrefix, // we repurpose this field
      unitInviteCode: driveConfig.locality,
    ));
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _saveDriveConfig(String folderId, String inviteCode) async {
    // Store Drive sync info using a separate config key
    await _db.configBox.put('driveSync', UnitConfig(
      namePrefix: folderId, // repurpose: stores folder ID
      locality: inviteCode, // repurpose: stores invite code
    ));
  }

  void _updateState(SyncState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Build descriptive report file name: 0001_2026_Pozar.json
  String _buildReportFileName(Report report) {
    final number = report.reportNumber.replaceAll('/', '_');
    final threat = report.threatCategory
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w_]'), '');
    return '${number}_$threat.json';
  }

  // â”€â”€ JSON serialization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Map<String, dynamic> _firefighterToJson(Firefighter ff) => {
        'id': ff.id,
        'firstName': ff.firstName,
        'lastName': ff.lastName,
        'rank': ff.rank,
        'isDriver': ff.isDriver,
        'isCommander': ff.isCommander,
        'isKPP': ff.isKPP,
      };

  Firefighter _firefighterFromJson(Map<String, dynamic> j) => Firefighter(
        id: j['id'] as String,
        firstName: j['firstName'] as String,
        lastName: j['lastName'] as String,
        rank: j['rank'] as String? ?? '',
        isDriver: j['isDriver'] as bool? ?? false,
        isCommander: j['isCommander'] as bool? ?? false,
        isKPP: j['isKPP'] as bool? ?? false,
      );

  Map<String, dynamic> _vehicleToJson(Vehicle v) => {
        'id': v.id,
        'name': v.name,
        'seats': v.seats,
      };

  Vehicle _vehicleFromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as String,
        name: j['name'] as String,
        seats: j['seats'] as int,
      );

  Map<String, dynamic> _threatToJson(ThreatEntry t) => {
        'category': t.category,
        'subtypes': t.subtypes,
        'isCustom': t.isCustom,
      };

  ThreatEntry _threatFromJson(Map<String, dynamic> j) => ThreatEntry(
        category: j['category'] as String,
        subtypes: (j['subtypes'] as List?)?.cast<String>() ?? [],
        isCustom: j['isCustom'] as bool? ?? false,
      );

  Map<String, dynamic> _reportToJson(Report r) => {
        'id': r.id,
        'reportNumber': r.reportNumber,
        'year': r.year,
        'date': r.date.toIso8601String(),
        'departureTime': r.departureTime.toIso8601String(),
        'returnTime': r.returnTime?.toIso8601String(),
        'addressLocality': r.addressLocality,
        'addressStreet': r.addressStreet,
        'addressDescription': r.addressDescription,
        'threatCategory': r.threatCategory,
        'threatSubtype': r.threatSubtype,
        'crewAssignments': r.crewAssignments.map(_crewToJson).toList(),
        'operationCommanderId': r.operationCommanderId,
        'notes': r.notes,
        'createdAt': r.createdAt.toIso8601String(),
        'updatedAt': r.updatedAt.toIso8601String(),
        'createdBy': r.createdBy,
        'syncStatus': 'synced',
      };

  Report _reportFromJson(Map<String, dynamic> j) => Report(
        id: j['id'] as String,
        reportNumber: j['reportNumber'] as String,
        year: j['year'] as int,
        date: DateTime.parse(j['date'] as String),
        departureTime: DateTime.parse(j['departureTime'] as String),
        returnTime: j['returnTime'] != null
            ? DateTime.parse(j['returnTime'] as String)
            : null,
        addressLocality: j['addressLocality'] as String,
        addressStreet: j['addressStreet'] as String? ?? '',
        addressDescription: j['addressDescription'] as String? ?? '',
        threatCategory: j['threatCategory'] as String,
        threatSubtype: j['threatSubtype'] as String?,
        crewAssignments: (j['crewAssignments'] as List?)
                ?.map((c) => _crewFromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        operationCommanderId: j['operationCommanderId'] as String?,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        createdBy: j['createdBy'] as String? ?? '',
        syncStatus: 'synced',
      );

  Map<String, dynamic> _crewToJson(CrewAssignment c) => {
        'vehicleId': c.vehicleId,
        'vehicleName': c.vehicleName,
        'driverId': c.driverId,
        'commanderId': c.commanderId,
        'crewMemberIds': c.crewMemberIds,
      };

  CrewAssignment _crewFromJson(Map<String, dynamic> j) => CrewAssignment(
        vehicleId: j['vehicleId'] as String,
        vehicleName: j['vehicleName'] as String,
        driverId: j['driverId'] as String?,
        commanderId: j['commanderId'] as String?,
        crewMemberIds: (j['crewMemberIds'] as List?)?.cast<String>() ?? [],
      );
}
