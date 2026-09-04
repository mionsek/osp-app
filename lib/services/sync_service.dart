import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../models/sync_state.dart';
import 'database_service.dart';
import 'google_auth_service.dart';
import 'google_drive_service.dart';
import '../core/utils/file_names.dart';

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
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
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

    _updateState(
      _state.copyWith(
        status: SyncStatus.idle,
        userEmail: authService.userEmail,
        unitFolderId: folderId,
        unitInviteCode: inviteCode,
        // Zakładający jednostkę jest jej stałym administratorem.
        founderEmail: authService.userEmail,
        adminEmails: const [],
      ),
    );

    // Save Drive folder ID to local config
    await _saveDriveConfig(folderId, inviteCode);

    // Set ownerEmail on local config for the unit creator
    final config = _db.getConfig();
    await _db.saveConfig(
      config.copyWith(ownerEmail: authService.userEmail ?? ''),
    );

    // Push all local data to Drive
    await _pushAllData();

    return inviteCode;
  }

  /// Join an existing unit by invite code.
  Future<bool> joinUnit(String code) async {
    final folderId = await _driveService.findUnitByInviteCode(
      code.trim().toUpperCase(),
    );
    if (folderId == null) return false;

    _updateState(
      _state.copyWith(
        status: SyncStatus.idle,
        userEmail: authService.userEmail,
        unitFolderId: folderId,
        unitInviteCode: code.trim().toUpperCase(),
      ),
    );

    await _saveDriveConfig(folderId, code.trim().toUpperCase());

    // Pull remote data to local
    await _pullAllData();

    return true;
  }

  // ── Dostęp do jednostki i uprawnienia ────────────────────────────────
  //
  // Samo podanie kodu zaproszenia nie wystarcza, żeby dołączyć: kolega
  // musi mieć dostęp do folderu jednostki na Dysku, bo wyszukiwanie po
  // kodzie przegląda wyłącznie pliki widoczne dla jego konta. Dlatego
  // administrator najpierw udostępnia folder, a dopiero potem przekazuje
  // kod.

  /// Udostępnia folder jednostki koledze — po tym może dołączyć kodem.
  Future<void> inviteMember(String email) async {
    final folderId = _state.unitFolderId;
    if (folderId == null) {
      throw StateError('Brak połączenia z jednostką.');
    }
    await _driveService.shareFolderWithUser(folderId, email.trim());
  }

  /// Osoby mające dostęp do folderu jednostki.
  Future<List<UnitMemberAccess>> listMembers() async {
    final folderId = _state.unitFolderId;
    if (folderId == null) return const [];
    return _driveService.listFolderMembers(folderId);
  }

  /// Odbiera koledze dostęp do jednostki (i uprawnienia administratora).
  Future<void> revokeMember(UnitMemberAccess member) async {
    final folderId = _state.unitFolderId;
    if (folderId == null) return;
    await _driveService.revokeFolderAccess(folderId, member.permissionId);
    if (_isAdminEmail(member.email)) {
      await revokeAdmin(member.email);
    }
  }

  bool _isAdminEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return _state.adminEmails
        .any((e) => e.trim().toLowerCase() == normalized);
  }

  /// Nadaje uprawnienia administratora.
  Future<void> grantAdmin(String email) async {
    if (_isAdminEmail(email) || _state.isFounder(email)) return;
    await _writeAdmins([..._state.adminEmails, email.trim()]);
  }

  /// Odbiera uprawnienia administratora.
  ///
  /// Założyciela pomijamy — bez niego jednostka mogłaby zostać bez
  /// żadnego administratora i nikt nie mógłby już nic zmienić.
  Future<void> revokeAdmin(String email) async {
    if (_state.isFounder(email)) return;
    final normalized = email.trim().toLowerCase();
    await _writeAdmins(_state.adminEmails
        .where((e) => e.trim().toLowerCase() != normalized)
        .toList());
  }

  Future<void> _writeAdmins(List<String> admins) async {
    final folderId = _state.unitFolderId;
    if (folderId == null) return;
    var configFolderId = await _driveService.findConfigFolder(folderId);
    configFolderId ??= await _driveService.createSubfolder(folderId, 'config');
    await _driveService.writeJsonFile(configFolderId, 'admins.json', {
      'admins': admins,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _db.cacheAdminEmails(admins);
    _updateState(_state.copyWith(adminEmails: admins));
  }

  /// Disconnect from the unit (keep local data).
  Future<void> disconnectUnit() async {
    stopAutoSync();
    final config = _db.getConfig();
    await _db.saveConfig(
      UnitConfig(
        namePrefix: config.namePrefix,
        locality: config.locality,
        onboardingCompleted: config.onboardingCompleted,
        isAdmin: config.isAdmin,
        ownerEmail: '',
      ),
    );
    _updateState(const SyncState());
  }

  // â”€â”€ Full sync â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Run a full bidirectional sync.
  /// Returns the number of duplicate report numbers detected after pull.
  Future<int> syncAll() async {
    if (_isSyncing || !_state.isConnected || _state.unitFolderId == null) {
      return 0;
    }

    _isSyncing = true;
    _updateState(_state.copyWith(status: SyncStatus.syncing));

    try {
      await _pushAllData();
      await _pullAllData();

      final duplicates = _db.findDuplicateReportNumbers();

      _updateState(
        _state.copyWith(
          status: SyncStatus.idle,
          lastSyncTime: DateTime.now(),
          errorMessage: null,
          duplicateReportNumbers: duplicates,
        ),
      );
      return duplicates.length;
    } catch (e) {
      debugPrint('Sync error: $e');
      _updateState(
        _state.copyWith(status: SyncStatus.error, errorMessage: e.toString()),
      );
      return 0;
    } finally {
      _isSyncing = false;
    }
  }

  /// Pull only reports from Drive (lightweight — used before creating a new report).
  /// Returns true if pull succeeded.
  Future<bool> pullReportsOnly() async {
    if (!_state.isConnected || _state.unitFolderId == null) return false;
    try {
      final folderId = _state.unitFolderId!;
      final reportsFolderId = await _driveService.findReportsFolder(folderId);
      if (reportsFolderId == null) return true;

      final yearFolders = await _driveService.listSubfolders(reportsFolderId);
      for (final yearFolder in yearFolders) {
        final reportFiles = await _driveService.listJsonFiles(yearFolder.id!);
        for (final file in reportFiles) {
          final data = await _driveService.readJsonFile(file.id!);
          if (data != null) {
            final report = reportFromJson(data);
            final local = _db.getReport(report.id);
            if (local == null || report.updatedAt.isAfter(local.updatedAt)) {
              await _db.addReport(report);
            }
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('pullReportsOnly error: $e');
      return false;
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
      'data': vehicles.map(vehicleToJson).toList(),
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
      'unitName': config.fullName,
      // Adres remizy jest wspólny dla całej jednostki — kolega, który
      // dołącza kodem, ma dostać podpowiedź „Skąd” bez wpisywania jej u siebie.
      'locality': config.locality,
      'unitStreet': config.unitStreet,
      'inviteCode': _state.unitInviteCode,
      'updatedAt': DateTime.now().toIso8601String(),
      // Założyciela ustala pierwszy zapis — potem go nie nadpisujemy,
      // bo to on jest stałym administratorem jednostki.
      'createdBy': _state.founderEmail ?? _state.userEmail,
    });

    // Push reports to reports/{year}/
    final reportsFolderId = await _driveService.findReportsFolder(folderId);
    if (reportsFolderId != null) {
      final reports = _db.getAllReports();
      for (final report in reports) {
        final yearFolderId = await _driveService.findOrCreateYearFolder(
          reportsFolderId,
          report.year,
        );
        await _driveService.writeJsonFile(
          yearFolderId,
          _buildReportFileName(report),
          reportToJson(report),
          legacyFileName: _buildReportFileName(report, legacy: true),
        );
      }
    }

    // Push property handovers to handovers/
    var handoversFolderId = await _driveService.findHandoversFolder(folderId);
    handoversFolderId ??= await _driveService.createSubfolder(
      folderId,
      'handovers',
    );
    final handovers = _db.getAllHandovers();
    for (final handover in handovers) {
      await _driveService.writeJsonFile(
        handoversFolderId,
        _buildHandoverFileName(handover),
        handoverToJson(handover),
        legacyFileName: _buildHandoverFileName(handover, legacy: true),
      );
    }

    // Push ewidencji przejazdów pojazdów do trips/
    var tripsFolderId = await _findTripsFolder(folderId);
    tripsFolderId ??= await _driveService.createSubfolder(folderId, 'trips');
    for (final trip in _db.getAllTrips()) {
      await _driveService.writeJsonFile(
        tripsFolderId,
        _buildTripFileName(trip),
        tripToJson(trip),
        legacyFileName: _buildTripFileName(trip, legacy: true),
      );
    }
  }

  /// Podfolder `trips/` z ewidencją przejazdów.
  Future<String?> _findTripsFolder(String unitFolderId) async {
    final subfolders = await _driveService.listSubfolders(unitFolderId);
    for (final f in subfolders) {
      if (f.name == 'trips') return f.id;
    }
    return null;
  }

  // â”€â”€ Pull Drive â†’ local â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pullAllData() async {
    final folderId = _state.unitFolderId!;

    // Find config folder (try new structure, fallback to root)
    final configFolderId = await _driveService.findConfigFolder(folderId);
    final dataFolderId = configFolderId ?? folderId;

    // Pull firefighters
    final ffData = await _driveService.readJsonFileByName(
      dataFolderId,
      'firefighters.json',
    );
    if (ffData != null && ffData['data'] is List) {
      for (final item in ffData['data'] as List) {
        final ff = _firefighterFromJson(item as Map<String, dynamic>);
        await _db.addFirefighter(ff);
      }
    }

    // Pull vehicles
    final vData = await _driveService.readJsonFileByName(
      dataFolderId,
      'vehicles.json',
    );
    if (vData != null && vData['data'] is List) {
      for (final item in vData['data'] as List) {
        final v = vehicleFromJson(item as Map<String, dynamic>);
        await _db.addVehicle(v);
      }
    }

    // Pull threat types (new name: threat_types.json, fallback: threats.json)
    var tData = await _driveService.readJsonFileByName(
      dataFolderId,
      'threat_types.json',
    );
    tData ??= await _driveService.readJsonFileByName(
      dataFolderId,
      'threats.json',
    );
    if (tData != null && tData['data'] is List) {
      for (final item in tData['data'] as List) {
        final t = _threatFromJson(item as Map<String, dynamic>);
        await _db.addThreat(t);
      }
      // Dane z Drive mogą pochodzić ze starszej wersji aplikacji —
      // uzgodnij słownik ze stałymi listami kategorii.
      await _db.ensureDefaultThreats();
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
            final report = reportFromJson(data);
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
          final report = reportFromJson(data);
          final local = _db.getReport(report.id);
          if (local == null || report.updatedAt.isAfter(local.updatedAt)) {
            await _db.addReport(report);
          }
        }
      }
    }

    // Pull property handovers from handovers/
    final handoversFolderId = await _driveService.findHandoversFolder(
      folderId,
    );
    if (handoversFolderId != null) {
      final handoverFiles = await _driveService.listJsonFiles(
        handoversFolderId,
      );
      for (final file in handoverFiles) {
        final data = await _driveService.readJsonFile(file.id!);
        if (data != null) {
          final handover = handoverFromJson(data);
          final local = _db.getHandover(handover.id);
          if (local == null || handover.updatedAt.isAfter(local.updatedAt)) {
            await _db.addHandover(handover);
          }
        }
      }
    }

    // Pull ewidencji przejazdów z trips/
    final tripsFolderId = await _findTripsFolder(folderId);
    if (tripsFolderId != null) {
      final tripFiles = await _driveService.listJsonFiles(tripsFolderId);
      for (final file in tripFiles) {
        final data = await _driveService.readJsonFile(file.id!);
        if (data == null) continue;
        final trip = tripFromJson(data);
        final local = _db.getTrip(trip.id);
        if (local == null || trip.updatedAt.isAfter(local.updatedAt)) {
          await _db.addTrip(trip);
        }
      }
    }

    // Pull unit config
    final configData = await _driveService.readJsonFileByName(
      dataFolderId,
      'unit_config.json',
    );
    if (configData != null && configData['unitName'] != null) {
      // Nazwę bierzemy w całości. Wcześniej była rozbijana po spacjach
      // („ostatni wyraz to miejscowość"), co przy nazwach w rodzaju
      // „Ochotnicza Straż Pożarna w Kielnie" dawało bezsens — a widziałby
      // to każdy, kto dołączy do jednostki.
      final unitName = (configData['unitName'] as String).trim();
      final config = _db.getConfig();
      // Adresu z Dysku nie wymuszamy na pustkę: starsze jednostki nie mają go
      // jeszcze zapisanego, a nadpisanie skasowałoby to, co ktoś wpisał lokalnie.
      final remoteLocality = (configData['locality'] as String? ?? '').trim();
      final remoteStreet = (configData['unitStreet'] as String? ?? '').trim();
      await _db.saveConfig(
        config.copyWith(
          unitFullName: unitName.isEmpty ? null : unitName,
          locality: remoteLocality.isEmpty ? null : remoteLocality,
          unitStreet: remoteStreet.isEmpty ? null : remoteStreet,
          ownerEmail: configData['createdBy'] as String? ?? '',
        ),
      );
    }

    // Lista administratorów jednostki
    final adminsData = await _driveService.readJsonFileByName(
      dataFolderId,
      'admins.json',
    );
    final admins = (adminsData?['admins'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    await _db.cacheAdminEmails(admins);
    _updateState(_state.copyWith(
      founderEmail: configData?['createdBy'] as String?,
      adminEmails: admins,
    ));

    // Raporty ściągnięte przed chwilą mogą pochodzić sprzed wprowadzenia
    // ewidencji — wtedy nie mają swojego wiersza w karcie. Uzupełniamy je
    // tak samo jak przy starcie aplikacji.
    await _db.backfillTripsFromReports(
      stationAddress: _db.getConfig().stationAddress,
    );
    // Raport mógł przyjechać z Dysku nowszy niż powiązany z nim przejazd —
    // np. kolega dopisał godzinę powrotu u siebie.
    await _db.reconcileTripsWithReports();
    await _db.fillMissingRouteFrom(_db.getConfig().stationAddress);
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
      _updateState(
        SyncState(
          status: SyncStatus.disconnected,
          userEmail: authService.userEmail,
        ),
      );
      return;
    }

    // driveConfig stores folderId in namePrefix, inviteCode in locality
    _updateState(
      SyncState(
        status: SyncStatus.idle,
        userEmail: authService.userEmail,
        unitFolderId: driveConfig.namePrefix, // we repurpose this field
        unitInviteCode: driveConfig.locality,
        // Uprawnienia z ostatniej synchronizacji — inaczej po restarcie
        // aplikacji (albo bez zasięgu) nikt nie byłby administratorem.
        founderEmail: _db.getConfig().ownerEmail.isEmpty
            ? null
            : _db.getConfig().ownerEmail,
        adminEmails: _db.cachedAdminEmails,
      ),
    );
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _saveDriveConfig(String folderId, String inviteCode) async {
    // Store Drive sync info using a separate config key
    await _db.configBox.put(
      'driveSync',
      UnitConfig(
        namePrefix: folderId, // repurpose: stores folder ID
        locality: inviteCode, // repurpose: stores invite code
      ),
    );
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
  /// [legacy] buduje nazwę wedle reguły sprzed transliteracji polskich znaków —
  /// służy tylko do odnalezienia pliku zapisanego starszą wersją aplikacji,
  /// żeby zmienić mu nazwę zamiast utworzyć obok duplikat.
  String _buildReportFileName(Report report, {bool legacy = false}) {
    final number = report.reportNumber.replaceAll('/', '_');
    final threat = legacy
        ? FileNames.sanitizeLegacy(report.threatCategory)
        : FileNames.sanitize(report.threatCategory);
    return '${number}_$threat.json';
  }

  /// Build descriptive handover file name: 2026-07-20_Kielno_`id-prefix`.json
  String _buildHandoverFileName(PropertyHandover handover,
      {bool legacy = false}) {
    final dateStr = FileNames.date(handover.eventDate);
    final locality = legacy
        ? FileNames.sanitizeLegacy(handover.eventLocation)
        : FileNames.sanitize(handover.eventLocation);
    final idPrefix = handover.id.length >= 8
        ? handover.id.substring(0, 8)
        : handover.id;
    return '${dateStr}_${locality}_$idPrefix.json';
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

  /// Serializacja pojazdu na Dysk.
  ///
  /// Publiczna i statyczna, żeby dało się ją przetestować bez budowania
  /// całego `SyncService`. To najbardziej krucha część synchronizacji:
  /// przy każdym dodaniu pola do modelu trzeba pamiętać o dopisaniu go tutaj
  /// **i** w mapowaniu odwrotnym, a nic tego nie wymusza.
  @visibleForTesting
  static Map<String, dynamic> vehicleToJson(Vehicle v) => {
    'id': v.id,
    'name': v.name,
    'seats': v.seats,
    // Dane z nagłówka karty drogowej — wspólne dla całej jednostki,
    // więc kolega, który dołączy kodem, dostaje je bez przepisywania.
    'make': v.make,
    'model': v.model,
    'kind': v.kind,
    'plate': v.plate,
    'operationalNumber': v.operationalNumber,
    'fuelType': v.fuelType,
    'fuelPer100Km': v.fuelPer100Km,
    'pumpFuelPerHour': v.pumpFuelPerHour,
    'idleFuelPerMinute': v.idleFuelPerMinute,
    'startupFuelPerMonth': v.startupFuelPerMonth,
  };

  @visibleForTesting
  static Vehicle vehicleFromJson(Map<String, dynamic> j) => Vehicle(
    id: j['id'] as String,
    name: j['name'] as String,
    seats: j['seats'] as int,
    make: j['make'] as String? ?? '',
    model: j['model'] as String? ?? '',
    kind: j['kind'] as String? ?? '',
    plate: j['plate'] as String? ?? '',
    operationalNumber: j['operationalNumber'] as String? ?? '',
    fuelType: j['fuelType'] as String? ?? '',
    fuelPer100Km: (j['fuelPer100Km'] as num?)?.toDouble(),
    pumpFuelPerHour: (j['pumpFuelPerHour'] as num?)?.toDouble(),
    idleFuelPerMinute: (j['idleFuelPerMinute'] as num?)?.toDouble(),
    startupFuelPerMonth: (j['startupFuelPerMonth'] as num?)?.toDouble(),
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

  /// Serializacja raportu na Dysk — patrz uwaga przy [vehicleToJson].
  @visibleForTesting
  static Map<String, dynamic> reportToJson(Report r) => {
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
    'crewAssignments': r.crewAssignments.map(crewToJson).toList(),
    'operationCommanderId': r.operationCommanderId,
    'notes': r.notes,
    'createdAt': r.createdAt.toIso8601String(),
    'updatedAt': r.updatedAt.toIso8601String(),
    'createdBy': r.createdBy,
    'syncStatus': 'synced',
  };

  @visibleForTesting
  static Report reportFromJson(Map<String, dynamic> j) => Report(
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
    crewAssignments:
        (j['crewAssignments'] as List?)
            ?.map((c) => crewFromJson(c as Map<String, dynamic>))
            .toList() ??
        [],
    operationCommanderId: j['operationCommanderId'] as String?,
    notes: j['notes'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    createdBy: j['createdBy'] as String? ?? '',
    syncStatus: 'synced',
  );

  /// Nazwa pliku przejazdu: 2026-08-10_GBA_`id-prefix`.json
  ///
  /// Data i pojazd w nazwie, żeby zawartość folderu dała się przejrzeć na
  /// Dysku bez otwierania każdego pliku — kartę czyta się po miesiącach.
  String _buildTripFileName(VehicleTrip t, {bool legacy = false}) {
    final date = FileNames.date(t.date);
    final name = _db.getVehicle(t.vehicleId)?.name ?? t.vehicleId;
    final vehicle =
        legacy ? FileNames.sanitizeLegacy(name) : FileNames.sanitize(name);
    final idPrefix = t.id.length >= 8 ? t.id.substring(0, 8) : t.id;
    return '${date}_${vehicle}_$idPrefix.json';
  }

  /// Serializacja przejazdu na Dysk — patrz uwaga przy [vehicleToJson].
  @visibleForTesting
  static Map<String, dynamic> tripToJson(VehicleTrip t) => {
    'id': t.id,
    'vehicleId': t.vehicleId,
    'date': t.date.toIso8601String(),
    'dispatcherName': t.dispatcherName,
    'routeFrom': t.routeFrom,
    'routeTo': t.routeTo,
    'purpose': t.purpose,
    'driverName': t.driverName,
    'driverId': t.driverId,
    'departureTime': t.departureTime.toIso8601String(),
    'returnTime': t.returnTime?.toIso8601String(),
    'odometerStart': t.odometerStart,
    'odometerEnd': t.odometerEnd,
    'odometerStartManual': t.odometerStartManual,
    'specialEquipmentMinutes': t.specialEquipmentMinutes,
    'equipmentUse': [
      for (final e in t.equipmentUse) {'name': e.name, 'minutes': e.minutes},
    ],
    'idleMinutes': t.idleMinutes,
    'extras': t.extras,
    'notes': t.notes,
    'reportId': t.reportId,
    'createdAt': t.createdAt.toIso8601String(),
    'updatedAt': t.updatedAt.toIso8601String(),
    'createdBy': t.createdBy,
    'syncStatus': 'synced',
  };

  @visibleForTesting
  static VehicleTrip tripFromJson(Map<String, dynamic> j) => VehicleTrip(
    id: j['id'] as String,
    vehicleId: j['vehicleId'] as String? ?? '',
    date: DateTime.parse(j['date'] as String),
    dispatcherName: j['dispatcherName'] as String? ?? '',
    routeFrom: j['routeFrom'] as String? ?? '',
    routeTo: j['routeTo'] as String? ?? '',
    purpose: j['purpose'] as String? ?? TripPurposes.economic,
    driverName: j['driverName'] as String? ?? '',
    driverId: j['driverId'] as String?,
    departureTime: DateTime.parse(j['departureTime'] as String),
    returnTime: j['returnTime'] == null
        ? null
        : DateTime.parse(j['returnTime'] as String),
    odometerStart: (j['odometerStart'] as num?)?.toInt(),
    odometerEnd: (j['odometerEnd'] as num?)?.toInt(),
    odometerStartManual: j['odometerStartManual'] as bool? ?? false,
    specialEquipmentMinutes: (j['specialEquipmentMinutes'] as num?)?.toInt(),
    idleMinutes: (j['idleMinutes'] as num?)?.toInt(),
    equipmentUse: [
      for (final e in (j['equipmentUse'] as List? ?? const []))
        TripEquipmentUse(
          name: (e as Map)['name'] as String? ?? '',
          minutes: (e['minutes'] as num?)?.toInt() ?? 0,
        ),
    ],
    extras: j['extras'] as String? ?? '',
    notes: j['notes'] as String?,
    reportId: j['reportId'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    createdBy: j['createdBy'] as String? ?? '',
    syncStatus: 'synced',
  );

  /// Serializacja przekazania mienia na Dysk — patrz uwaga przy [vehicleToJson].
  @visibleForTesting
  static Map<String, dynamic> handoverToJson(PropertyHandover h) => {
    'id': h.id,
    'reportId': h.reportId,
    'eventLocation': h.eventLocation,
    'eventDate': h.eventDate.toIso8601String(),
    'eventTime': h.eventTime.toIso8601String(),
    'recipientType': h.recipientType,
    'recipientTypeOther': h.recipientTypeOther,
    'recipientName': h.recipientName,
    'recipientAddress': h.recipientAddress,
    'recipientPhone': h.recipientPhone,
    'propertyDescription': h.propertyDescription,
    'propertyKind': h.propertyKind,
    'notes': h.notes,
    'handoverFirefighterId': h.handoverFirefighterId,
    'signLocality': h.signLocality,
    'signDate': h.signDate.toIso8601String(),
    'createdAt': h.createdAt.toIso8601String(),
    'updatedAt': h.updatedAt.toIso8601String(),
    'createdBy': h.createdBy,
    'syncStatus': 'synced',
  };

  @visibleForTesting
  static PropertyHandover handoverFromJson(Map<String, dynamic> j) =>
      PropertyHandover(
        id: j['id'] as String,
        reportId: j['reportId'] as String?,
        eventLocation: j['eventLocation'] as String? ?? '',
        eventDate: DateTime.parse(j['eventDate'] as String),
        eventTime: DateTime.parse(j['eventTime'] as String),
        recipientType: j['recipientType'] as String?,
        recipientTypeOther: j['recipientTypeOther'] as String?,
        recipientName: j['recipientName'] as String? ?? '',
        recipientAddress: j['recipientAddress'] as String? ?? '',
        recipientPhone: j['recipientPhone'] as String? ?? '',
        propertyDescription: j['propertyDescription'] as String? ?? '',
        propertyKind: j['propertyKind'] as String?,
        notes: j['notes'] as String?,
        handoverFirefighterId: j['handoverFirefighterId'] as String?,
        signLocality: j['signLocality'] as String? ?? '',
        signDate: DateTime.parse(j['signDate'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        createdBy: j['createdBy'] as String? ?? '',
        syncStatus: 'synced',
      );

  /// Skład zastępu — część raportu, więc musi być testowalny razem z nim.
  @visibleForTesting
  static Map<String, dynamic> crewToJson(CrewAssignment c) => {
    'vehicleId': c.vehicleId,
    'vehicleName': c.vehicleName,
    'driverId': c.driverId,
    'commanderId': c.commanderId,
    'crewMemberIds': c.crewMemberIds,
  };

  @visibleForTesting
  static CrewAssignment crewFromJson(Map<String, dynamic> j) => CrewAssignment(
    vehicleId: j['vehicleId'] as String,
    vehicleName: j['vehicleName'] as String,
    driverId: j['driverId'] as String?,
    commanderId: j['commanderId'] as String?,
    crewMemberIds: (j['crewMemberIds'] as List?)?.cast<String>() ?? [],
  );
}
