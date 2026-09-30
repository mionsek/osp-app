import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../models/models.dart';
import '../models/sync_state.dart';
import 'database_service.dart';
import 'google_auth_service.dart';
import 'google_drive_service.dart';
import 'sync_json.dart';
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

  /// Wołane po zapisaniu danych pobranych z Dysku.
  ///
  /// Listy na ekranach trzymają migawkę z chwili utworzenia, więc bez
  /// odświeżenia raport dodany przez kolegę pojawiał się dopiero po
  /// ponownym uruchomieniu aplikacji.
  void Function()? onDataPulled;

  SyncState _state = const SyncState();
  SyncState get state => _state;

  SyncService(this._db, this.authService, this._driveService);

  // ── Initialization ─────────────────────────────────────────────

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

  // ── Unit creation / joining ────────────────────────────────────

  /// Create a new unit on Google Drive. Returns invite code.
  Future<String> createUnit(String unitName) async {
    await _resetUnitState();
    final folderId = await _driveService.createUnitFolder(unitName);
    final inviteCode = _generateInviteCode();

    // Write unit config to Drive (in config subfolder)
    var configFolderId = await _driveService.findConfigFolder(folderId);
    configFolderId ??= await _driveService.createSubfolder(folderId, 'config');
    final unitConfig = {
      'unitName': unitName,
      'inviteCode': inviteCode,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': authService.userEmail,
      'syncFormat': syncFormat,
    };
    await _driveService.writeJsonFile(
        configFolderId, 'unit_config.json', unitConfig);
    _remoteUnitConfig = unitConfig;

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
    await _resetUnitState();

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
    // copyWith, nie nowy obiekt: budowanie od zera gubiło pełną nazwę
    // jednostki, ulicę remizy i sparowaną drukarkę.
    await _db.saveConfig(_db.getConfig().copyWith(ownerEmail: ''));
    // Bez tego po restarcie aplikacja sama łączyła się z powrotem ze starą
    // jednostką — także po zalogowaniu innym kontem.
    await _db.configBox.delete('driveSync');
    await _db.cacheAdminEmails(const []);
    await _resetUnitState();
    _updateState(const SyncState());
  }

  /// Zapomina wszystko, co dotyczyło plików poprzedniej jednostki — inaczej
  /// zapis w nowej trafiałby do plików starej.
  Future<void> _resetUnitState() async {
    _remoteDocs.clear();
    _remoteConfigHashes.clear();
    _remoteUnitConfig = null;
    _remoteSyncFormat = 1;
    _reportsFolderId = null;
    _yearFolderIds.clear();
    _handoversFolderId = null;
    _tripsFolderId = null;
    await _db.settingsBox.delete(_fileCacheKey);
  }

  // ── Full sync ──────────────────────────────────────────────────
  /// Run a full bidirectional sync.
  /// Returns the number of duplicate report numbers detected after pull.
  ///
  /// Kolejność: najpierw pobieramy, potem wysyłamy — i wysyłamy tylko to,
  /// co różni się od Dysku. Rozstrzyga stempel `updatedAt` każdego rekordu
  /// (także ratownika i pojazdu), a usunięcia jeżdżą jako znaczniki, więc
  /// nie wracają przy następnej synchronizacji.
  Future<int> syncAll() async {
    if (_isSyncing || !_state.isConnected || _state.unitFolderId == null) {
      return 0;
    }

    _isSyncing = true;
    _skippedFiles = 0;
    _updateState(_state.copyWith(status: SyncStatus.syncing));

    try {
      await _withAuthRetry(() async {
        await _pullConfig();
        await _pullDocuments();
        await _afterPull();
        await _pushConfig();
        await _pushDocuments();
      });

      final duplicates = _db.findDuplicateReportNumbers();

      _updateState(
        _state.copyWith(
          status: SyncStatus.idle,
          lastSyncTime: DateTime.now(),
          clearError: true,
          duplicateReportNumbers: duplicates,
          skippedFiles: _skippedFiles,
        ),
      );
      return duplicates.length;
    } on SyncFormatTooNewException {
      _updateState(_state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Jednostka używa nowszej wersji aplikacji. '
            'Zaktualizuj aplikację, żeby synchronizować dane.',
      ));
      return 0;
    } catch (e) {
      debugPrint('Sync error: $e');
      _updateState(
        _state.copyWith(status: SyncStatus.error, errorMessage: e.toString()),
      );
      return 0;
    } finally {
      _isSyncing = false;
      // Także po błędzie w połowie — część danych mogła już się zapisać.
      onDataPulled?.call();
    }
  }

  /// Pull only reports from Drive (lightweight — used before creating a new report).
  /// Returns true if pull succeeded.
  Future<bool> pullReportsOnly() async {
    if (!_state.isConnected || _state.unitFolderId == null) return false;
    // Pełna synchronizacja i tak pobiera raporty, a dwa przebiegi naraz
    // zapisywałyby te same rekordy z dwóch miejsc.
    if (_isSyncing) return true;
    _isSyncing = true;
    try {
      await _withAuthRetry(
          () => _pullDocuments(kinds: const {SyncKind.report}));
      // Raport mógł przyjść z nowymi godzinami — ewidencja ma je dostać od
      // razu, a nie dopiero przy następnym pełnym przebiegu.
      await _db.fixOvernightReturnTimes();
      await _db.reconcileTripsWithReports();
      return true;
    } catch (e) {
      debugPrint('pullReportsOnly error: $e');
      return false;
    } finally {
      _isSyncing = false;
      onDataPulled?.call();
    }
  }

  /// Świeży token przed pracą z Dyskiem, a przy odmowie (401) jeszcze jedna
  /// próba z tokenem wymuszonym na nowo.
  Future<void> _withAuthRetry(Future<void> Function() body) async {
    await authService.refreshAuth();
    try {
      await body();
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status != 401) rethrow;
      await authService.refreshAuth(force: true);
      await body();
    }
  }

  // ── Stan jednego przebiegu ─────────────────────────────────────────

  /// Pliki dokumentów na Dysku: "rodzaj:id" → plik, w którym leży rekord.
  /// Budowane przy pobieraniu, używane przy wysyłce — dzięki temu wysyłka
  /// nie szuka plików po nazwie i nie wysyła tego, co już tam jest.
  final Map<String, _RemoteDoc> _remoteDocs = {};

  /// Skróty treści plików konfiguracji na Dysku — do decyzji, czy wysyłać.
  final Map<String, String> _remoteConfigHashes = {};
  Map<String, dynamic>? _remoteUnitConfig;
  int _remoteSyncFormat = 1;

  int _skippedFiles = 0;

  String? _reportsFolderId;
  final Map<int, String> _yearFolderIds = {};
  String? _handoversFolderId;
  String? _tripsFolderId;

  /// Wersja formatu danych na Dysku, którą ta aplikacja rozumie.
  ///
  /// 2 — znaczniki usunięcia i stemple ratowników i pojazdów. Jednostka
  /// z wyższą wersją (nowsza aplikacja u kolegi) blokuje synchronizację
  /// z komunikatem „zaktualizuj", zamiast pozwolić staremu telefonowi
  /// nadpisać dane w formacie, którego nie rozumie.
  static const int syncFormat = 2;

  // ── Pamięć plików Dysku ────────────────────────────────────────────
  //
  // Dla każdego pliku: chwila modyfikacji i skrót treści. Plik, który od
  // poprzedniej synchronizacji się nie zmienił, nie jest czytany ponownie —
  // wcześniej każdy telefon co 5 minut pobierał treść wszystkich plików.

  static const String _fileCacheKey = 'driveFileCache';

  Map<String, Map<String, dynamic>> _loadFileCache() {
    final raw = _db.settingsBox.get(_fileCacheKey);
    if (raw is! String) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as Map<String, dynamic>));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveFileCache(Map<String, Map<String, dynamic>> cache) =>
      _db.settingsBox.put(_fileCacheKey, jsonEncode(cache));

  // ── Konfiguracja jednostki: pobranie i scalenie ────────────────────

  Future<String> _configFolder() async {
    final folderId = _state.unitFolderId!;
    return await _driveService.findConfigFolder(folderId) ??
        await _driveService.createSubfolder(folderId, 'config');
  }

  /// Pobranie list jednostki, danych jednostki i listy administratorów.
  Future<void> _pullConfig() async {
    final folderId = _state.unitFolderId!;

    // Find config folder (try new structure, fallback to root)
    final configFolderId = await _driveService.findConfigFolder(folderId);
    final dataFolderId = configFolderId ?? folderId;

    final configData = await _driveService.readJsonFileByName(
      dataFolderId,
      'unit_config.json',
    );
    _remoteUnitConfig = configData;
    _remoteSyncFormat = (configData?['syncFormat'] as num?)?.toInt() ?? 1;
    if (_remoteSyncFormat > syncFormat) throw SyncFormatTooNewException();
    if (configData != null) await _mergeUnitConfig(configData);

    final ffData = await _driveService.readJsonFileByName(
      dataFolderId,
      'firefighters.json',
    );
    _remoteConfigHashes['firefighters.json'] =
        await _mergeList(SyncKind.firefighter, ffData?['data']);

    final vData = await _driveService.readJsonFileByName(
      dataFolderId,
      'vehicles.json',
    );
    _remoteConfigHashes['vehicles.json'] =
        await _mergeList(SyncKind.vehicle, vData?['data']);

    // Pull threat types (new name: threat_types.json, fallback: threats.json)
    var tData = await _driveService.readJsonFileByName(
      dataFolderId,
      'threat_types.json',
    );
    tData ??= await _driveService.readJsonFileByName(
      dataFolderId,
      'threats.json',
    );
    _remoteConfigHashes['threat_types.json'] =
        await _mergeThreats(tData?['data']);

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
  }

  /// Dane jednostki z Dysku — chyba że na tym telefonie zmieniono je później.
  Future<void> _mergeUnitConfig(Map<String, dynamic> configData) async {
    final config = _db.getConfig();
    final editedHere = _db.unitConfigEditedAt;
    final remoteAt = SyncJson.stampOf(configData);
    final localIsNewer = editedHere != null &&
        (remoteAt == null || editedHere.isAfter(remoteAt));

    final unitName = (configData['unitName'] as String? ?? '').trim();
    // Adresu z Dysku nie wymuszamy na pustkę: starsze jednostki nie mają go
    // jeszcze zapisanego, a nadpisanie skasowałoby to, co ktoś wpisał lokalnie.
    final remoteLocality = (configData['locality'] as String? ?? '').trim();
    final remoteStreet = (configData['unitStreet'] as String? ?? '').trim();

    await _db.saveConfig(localIsNewer
        ? config.copyWith(ownerEmail: configData['createdBy'] as String? ?? '')
        : config.copyWith(
            // Nazwę bierzemy w całości. Wcześniej była rozbijana po spacjach
            // („ostatni wyraz to miejscowość"), co przy nazwach w rodzaju
            // „Ochotnicza Straż Pożarna w Kielnie" dawało bezsens.
            unitFullName: unitName.isEmpty ? null : unitName,
            locality: remoteLocality.isEmpty ? null : remoteLocality,
            unitStreet: remoteStreet.isEmpty ? null : remoteStreet,
            ownerEmail: configData['createdBy'] as String? ?? '',
          ));
  }

  /// Scala listę ratowników albo pojazdów z Dysku z lokalną — wpis po
  /// wpisie, według stempli. Zwraca skrót treści listy na Dysku.
  ///
  /// Dawniej lista z Dysku zastępowała lokalną w całości, więc wygrywał
  /// telefon, który wysłał ostatni — zmiana administratora mogła zostać
  /// losowo cofnięta przez kolegę ze starszą kopią.
  Future<String> _mergeList(String kind, Object? rawList) async {
    final canonical = <Map<String, dynamic>>[];
    if (rawList is List) {
      for (final item in rawList) {
        try {
          final entry = Map<String, dynamic>.from(item as Map);
          canonical.add(await _mergeListEntry(kind, entry));
        } catch (e) {
          debugPrint('Pominięty wpis ($kind): $e');
          _skippedFiles++;
        }
      }
    }
    return _listHash(canonical);
  }

  Future<Map<String, dynamic>> _mergeListEntry(
      String kind, Map<String, dynamic> entry) async {
    final id = entry['id'] as String;
    final remoteAt = SyncJson.stampOf(entry);
    final localAt = _localStamp(kind, id);
    final exists = _existsLocally(kind, id);

    if (SyncJson.isTombstone(entry)) {
      final newerHere = localAt != null &&
          remoteAt != null &&
          localAt.isAfter(remoteAt);
      if (!newerHere &&
          (exists || _db.tombstoneOf(kind, id) == null)) {
        await _db.applyRemoteDeletion(kind, id, entry);
      }
      return entry;
    }

    final canonical = kind == SyncKind.firefighter
        ? SyncJson.firefighterToJson(SyncJson.firefighterFromJson(entry))
        : SyncJson.vehicleToJson(SyncJson.vehicleFromJson(entry));

    final tomb = _db.tombstoneOf(kind, id);
    final tombAt = tomb == null ? null : SyncJson.stampOf(tomb);
    if (tombAt != null && (remoteAt == null || !remoteAt.isAfter(tombAt))) {
      return canonical; // usunięcie tutaj jest nowsze
    }

    // Wpis bez stempla (sprzed tej wersji) po obu stronach: bierzemy Dysk,
    // jak dawniej. Ze stemplem wygrywa nowszy.
    final takeRemote = !exists ||
        (remoteAt == null && localAt == null) ||
        (remoteAt != null && (localAt == null || remoteAt.isAfter(localAt)));
    if (takeRemote) {
      if (kind == SyncKind.firefighter) {
        await _db.addFirefighter(SyncJson.firefighterFromJson(
          entry,
          local: _db.getFirefighter(id),
        ));
      } else {
        await _db.addVehicle(SyncJson.vehicleFromJson(entry));
      }
      if (tomb != null) await _db.removeTombstone(kind, id);
    }
    return canonical;
  }

  /// Słownik zagrożeń: suma zbiorów. Własnych podtypów nie da się usuwać,
  /// więc łączenie nie wskrzesza niczego, co ktoś skasował.
  Future<String> _mergeThreats(Object? rawList) async {
    final remote = <ThreatEntry>[];
    if (rawList is List) {
      for (final item in rawList) {
        try {
          remote.add(SyncJson.threatFromJson(
              Map<String, dynamic>.from(item as Map)));
        } catch (e) {
          debugPrint('Pominięty wpis słownika: $e');
          _skippedFiles++;
        }
      }
    }
    for (final t in remote) {
      final local =
          _db.getAllThreats().where((l) => l.category == t.category).firstOrNull;
      if (local == null) {
        await _db.addThreat(t);
        continue;
      }
      final missing = t.subtypes.where((s) => !local.subtypes.contains(s));
      if (missing.isEmpty) continue;
      await _db.addThreat(ThreatEntry(
        category: local.category,
        subtypes: [...local.subtypes, ...missing],
        isCustom: local.isCustom,
      ));
    }
    if (remote.isNotEmpty) {
      // Dane z Drive mogą pochodzić ze starszej wersji aplikacji —
      // uzgodnij słownik ze stałymi listami kategorii.
      await _db.ensureDefaultThreats();
    }
    return _threatsHash(remote);
  }

  // ── Konfiguracja jednostki: wysyłka ────────────────────────────────

  Future<void> _pushConfig() async {
    String? configFolderId;
    Future<String> folder() async => configFolderId ??= await _configFolder();

    Future<void> pushList(
        String fileName, List<Map<String, dynamic>> entries) async {
      if (_listHash(entries) == _remoteConfigHashes[fileName]) return;
      await _driveService.writeJsonFile(await folder(), fileName, {
        'updatedAt': DateTime.now().toIso8601String(),
        'data': entries,
      });
      _remoteConfigHashes[fileName] = _listHash(entries);
    }

    await pushList('firefighters.json', [
      ..._db.getAllFirefighters().map(SyncJson.firefighterToJson),
      ..._db.tombstonesOf(SyncKind.firefighter),
    ]);
    await pushList('vehicles.json', [
      ..._db.getAllVehicles().map(SyncJson.vehicleToJson),
      ..._db.tombstonesOf(SyncKind.vehicle),
    ]);

    final threats = _db.getAllThreats();
    if (_threatsHash(threats) != _remoteConfigHashes['threat_types.json']) {
      await _driveService.writeJsonFile(await folder(), 'threat_types.json', {
        'updatedAt': DateTime.now().toIso8601String(),
        'data': threats.map(SyncJson.threatToJson).toList(),
      });
      _remoteConfigHashes['threat_types.json'] = _threatsHash(threats);
    }

    final config = _db.getConfig();
    final content = <String, dynamic>{
      'unitName': config.fullName,
      // Adres remizy jest wspólny dla całej jednostki — kolega, który
      // dołącza kodem, ma dostać podpowiedź „Skąd” bez wpisywania jej u siebie.
      'locality': config.locality,
      'unitStreet': config.unitStreet,
      'inviteCode': _state.unitInviteCode,
      // Założyciela ustala pierwszy zapis — potem go nie nadpisujemy,
      // bo to on jest stałym administratorem jednostki.
      'createdBy': _state.founderEmail ?? _state.userEmail,
      'syncFormat':
          _remoteSyncFormat > syncFormat ? _remoteSyncFormat : syncFormat,
    };
    final remote = _remoteUnitConfig;
    final unchanged = remote != null &&
        content.entries.every((e) => remote[e.key] == e.value);
    if (unchanged) return;
    final written = {
      ...content,
      if (remote?['createdAt'] != null) 'createdAt': remote!['createdAt'],
      'updatedAt':
          (_db.unitConfigEditedAt ?? DateTime.now()).toIso8601String(),
    };
    await _driveService.writeJsonFile(
        await folder(), 'unit_config.json', written);
    _remoteUnitConfig = written;
  }

  // ── Dokumenty: pobranie ────────────────────────────────────────────

  /// Pobranie raportów, przekazań mienia i przejazdów — nowszych niż lokalne.
  ///
  /// [kinds] zawęża do wybranych rodzajów (szybkie pobranie raportów przed
  /// kreatorem).
  Future<void> _pullDocuments({Set<String>? kinds}) async {
    final folderId = _state.unitFolderId!;
    bool wanted(String kind) => kinds == null || kinds.contains(kind);

    final cache = _loadFileCache();
    final seen = <String>{};
    _remoteDocs.removeWhere(
        (key, _) => wanted(key.substring(0, key.indexOf(':'))));

    if (wanted(SyncKind.report)) {
      _reportsFolderId = await _driveService.findReportsFolder(folderId);
      final reportsFolderId = _reportsFolderId;
      if (reportsFolderId != null) {
        for (final yearFolder
            in await _driveService.listSubfolders(reportsFolderId)) {
          final year = int.tryParse(yearFolder.name ?? '');
          if (year != null) _yearFolderIds[year] = yearFolder.id!;
          await _pullFolder(SyncKind.report, yearFolder.id!, cache, seen);
        }
        // Raporty ze starszej struktury — wprost w reports/.
        await _pullFolder(SyncKind.report, reportsFolderId, cache, seen);
      }
    }

    if (wanted(SyncKind.handover)) {
      _handoversFolderId = await _driveService.findHandoversFolder(folderId);
      final id = _handoversFolderId;
      if (id != null) await _pullFolder(SyncKind.handover, id, cache, seen);
    }

    if (wanted(SyncKind.trip)) {
      _tripsFolderId = await _findTripsFolder(folderId);
      final id = _tripsFolderId;
      if (id != null) await _pullFolder(SyncKind.trip, id, cache, seen);
    }

    // Pliki, których już nie ma na Dysku, nie są potrzebne w pamięci.
    cache.removeWhere(
        (fileId, e) => wanted(e['k'] as String? ?? '') && !seen.contains(fileId));
    await _saveFileCache(cache);
  }

  Future<void> _pullFolder(
    String kind,
    String folderId,
    Map<String, Map<String, dynamic>> cache,
    Set<String> seen,
  ) async {
    for (final file in await _driveService.listJsonFiles(folderId)) {
      final fileId = file.id!;
      seen.add(fileId);
      final modified = file.modifiedTime?.toIso8601String();

      var entry = cache[fileId];
      if (entry == null || entry['m'] != modified || entry['k'] != kind) {
        final data = await _driveService.readJsonFile(fileId);
        if (data == null) {
          _skippedFiles++;
          continue;
        }
        try {
          final hash = await _applyRemoteDoc(kind, data);
          entry = {
            'm': modified,
            'k': kind,
            'id': data['id'] as String,
            'h': hash,
            'u': data['updatedAt'],
          };
          cache[fileId] = entry;
        } catch (e) {
          // Jeden uszkodzony plik nie może zatrzymać synchronizacji całej
          // jednostki — pomijamy go i idziemy dalej.
          debugPrint('Pominięty plik $fileId ($kind): $e');
          _skippedFiles++;
          continue;
        }
      }

      final key = '$kind:${entry['id']}';
      final doc = _RemoteDoc(
        fileId: fileId,
        hash: entry['h'] as String,
        updatedAt: DateTime.tryParse(entry['u'] as String? ?? ''),
      );
      // Ten sam rekord w kilku plikach (duplikaty po zmianach nazw) —
      // pracujemy na najnowszym.
      final current = _remoteDocs[key];
      if (current == null || doc.isNewerThan(current)) _remoteDocs[key] = doc;
    }
  }

  /// Nakłada dokument z Dysku na bazę, jeśli jest nowszy. Zwraca skrót
  /// treści pliku (po sprowadzeniu do postaci, jaką zapisałby ten telefon).
  Future<String> _applyRemoteDoc(String kind, Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final remoteAt = SyncJson.stampOf(data) ?? DateTime(2000);

    if (SyncJson.isTombstone(data)) {
      final localAt = _localStamp(kind, id);
      final tombAt = _tombstoneStamp(kind, id);
      final newerHere = localAt != null && localAt.isAfter(remoteAt);
      if (!newerHere &&
          (localAt != null || tombAt == null || tombAt.isBefore(remoteAt))) {
        await _db.applyRemoteDeletion(kind, id, data);
      }
      return SyncJson.contentHash(data);
    }

    final canonical = _canonical(kind, data);
    final tombAt = _tombstoneStamp(kind, id);
    if (tombAt != null && !remoteAt.isAfter(tombAt)) {
      return SyncJson.contentHash(canonical); // usunięcie tutaj jest nowsze
    }

    final localAt = _localStamp(kind, id);
    if (localAt == null || remoteAt.isAfter(localAt)) {
      switch (kind) {
        case SyncKind.report:
          await _db.addReport(SyncJson.reportFromJson(data));
        case SyncKind.handover:
          await _db.addHandover(SyncJson.handoverFromJson(data));
        case SyncKind.trip:
          final trip = SyncJson.tripFromJson(data);
          final local = _db.getTrip(id);
          if (local != null && !data.containsKey('overriddenFields')) {
            keepLocalOverrides(trip, local);
          }
          await _db.addTrip(trip);
      }
      if (tombAt != null) await _db.removeTombstone(kind, id);
    }
    return SyncJson.contentHash(canonical);
  }

  // ── Dokumenty: wysyłka ─────────────────────────────────────────────

  /// Wysyłka raportów, przekazań mienia i przejazdów — tylko tych, które
  /// różnią się od Dysku, oraz znaczników usunięcia.
  Future<void> _pushDocuments() async {
    final folderId = _state.unitFolderId!;
    final cache = _loadFileCache();

    Future<String> yearFolder(int year) async {
      _reportsFolderId ??= await _driveService.findReportsFolder(folderId) ??
          await _driveService.createSubfolder(folderId, 'reports');
      return _yearFolderIds[year] ??= await _driveService
          .findOrCreateYearFolder(_reportsFolderId!, year);
    }

    Future<String> handoversFolder() async => _handoversFolderId ??=
        await _driveService.findHandoversFolder(folderId) ??
            await _driveService.createSubfolder(folderId, 'handovers');

    Future<String> tripsFolder() async => _tripsFolderId ??=
        await _findTripsFolder(folderId) ??
            await _driveService.createSubfolder(folderId, 'trips');

    for (final r in _db.getAllReports()) {
      await _pushDoc(cache, SyncKind.report, r.id, SyncJson.reportToJson(r),
          name: _buildReportFileName(r), folder: () => yearFolder(r.year));
    }
    for (final h in _db.getAllHandovers()) {
      await _pushDoc(
          cache, SyncKind.handover, h.id, SyncJson.handoverToJson(h),
          name: _buildHandoverFileName(h), folder: handoversFolder);
    }
    for (final t in _db.getAllTrips()) {
      await _pushDoc(cache, SyncKind.trip, t.id, SyncJson.tripToJson(t),
          name: _buildTripFileName(t), folder: tripsFolder);
    }

    // Znaczniki usunięcia nadpisują plik rekordu. Gdy pliku nie ma, rekord
    // nigdy nie opuścił telefonu i nie ma czego usuwać z Dysku.
    for (final kind in const [
      SyncKind.report,
      SyncKind.handover,
      SyncKind.trip,
    ]) {
      for (final tomb in _db.tombstonesOf(kind)) {
        final remote = _remoteDocs['$kind:${tomb['id']}'];
        if (remote == null) continue;
        await _pushDoc(cache, kind, tomb['id'] as String, tomb);
      }
    }

    await _saveFileCache(cache);
  }

  /// Zapisuje rekord na Dysk, jeśli różni się od tego, co tam leży.
  ///
  /// Plik rozpoznajemy po identyfikatorze w treści (zebranym przy
  /// pobieraniu), a nie po nazwie — reguły nazw zmieniały się między
  /// wersjami i szukanie po nazwie dawało duplikaty.
  Future<void> _pushDoc(
    Map<String, Map<String, dynamic>> cache,
    String kind,
    String id,
    Map<String, dynamic> json, {
    String? name,
    Future<String> Function()? folder,
  }) async {
    final key = '$kind:$id';
    final hash = SyncJson.contentHash(json);
    final remote = _remoteDocs[key];
    if (remote != null && remote.hash == hash) return;

    final ({String id, DateTime? modifiedTime}) written;
    if (remote != null) {
      written = await _driveService.updateJsonFile(remote.fileId, json,
          fileName: name);
    } else {
      if (folder == null || name == null) return;
      written = await _driveService.createJsonFile(await folder(), name, json);
    }

    cache[written.id] = {
      'm': written.modifiedTime?.toIso8601String(),
      'k': kind,
      'id': id,
      'h': hash,
      'u': json['updatedAt'],
    };
    _remoteDocs[key] = _RemoteDoc(
      fileId: written.id,
      hash: hash,
      updatedAt: SyncJson.stampOf(json),
    );
  }

  /// Podfolder `trips/` z ewidencją przejazdów.
  Future<String?> _findTripsFolder(String unitFolderId) async {
    final subfolders = await _driveService.listSubfolders(unitFolderId);
    for (final f in subfolders) {
      if (f.name == 'trips') return f.id;
    }
    return null;
  }

  // ── Pomocnicze do scalania ─────────────────────────────────────────

  Map<String, dynamic> _canonical(String kind, Map<String, dynamic> data) =>
      switch (kind) {
        SyncKind.report =>
          SyncJson.reportToJson(SyncJson.reportFromJson(data)),
        SyncKind.handover =>
          SyncJson.handoverToJson(SyncJson.handoverFromJson(data)),
        SyncKind.trip => SyncJson.tripToJson(SyncJson.tripFromJson(data)),
        _ => data,
      };

  bool _existsLocally(String kind, String id) => switch (kind) {
        SyncKind.report => _db.getReport(id) != null,
        SyncKind.handover => _db.getHandover(id) != null,
        SyncKind.trip => _db.getTrip(id) != null,
        SyncKind.firefighter => _db.getFirefighter(id) != null,
        SyncKind.vehicle => _db.getVehicle(id) != null,
        _ => false,
      };

  /// Stempel rekordu w telefonie; `null`, gdy go tu nie ma albo (ratownik,
  /// pojazd) pochodzi sprzed stempli.
  DateTime? _localStamp(String kind, String id) => switch (kind) {
        SyncKind.report => _db.getReport(id)?.updatedAt,
        SyncKind.handover => _db.getHandover(id)?.updatedAt,
        SyncKind.trip => _db.getTrip(id)?.updatedAt,
        SyncKind.firefighter => _db.getFirefighter(id)?.updatedAt,
        SyncKind.vehicle => _db.getVehicle(id)?.updatedAt,
        _ => null,
      };

  DateTime? _tombstoneStamp(String kind, String id) {
    final tomb = _db.tombstoneOf(kind, id);
    return tomb == null ? null : SyncJson.stampOf(tomb);
  }

  /// Skrót listy niezależny od kolejności wpisów.
  static String _listHash(List<Map<String, dynamic>> entries) {
    final sorted = [...entries]
      ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    return SyncJson.contentHash(sorted);
  }

  /// Skrót słownika niezależny od kolejności kategorii i podtypów.
  static String _threatsHash(List<ThreatEntry> threats) {
    final canonical = [
      for (final t in threats)
        {
          'category': t.category,
          'subtypes': [...t.subtypes]..sort(),
          'isCustom': t.isCustom,
        },
    ]..sort((a, b) =>
        (a['category'] as String).compareTo(b['category'] as String));
    return SyncJson.contentHash(canonical);
  }

  // ── Pobranie całości (dołączenie do jednostki) ─────────────────────

  Future<void> _pullAllData() async {
    await authService.refreshAuth();
    await _pullConfig();
    await _pullDocuments();
    await _afterPull();
  }

  Future<void> _pushAllData() async {
    await _pushConfig();
    await _pushDocuments();
  }

  /// Porządki po pobraniu dokumentów — te same, co przy starcie aplikacji.
  Future<void> _afterPull() async {
    // Raporty ściągnięte przed chwilą mogą pochodzić sprzed wprowadzenia
    // ewidencji — wtedy nie mają swojego wiersza w karcie. Uzupełniamy je
    // tak samo jak przy starcie aplikacji.
    await _db.fixOvernightReturnTimes();
    await _db.backfillTripsFromReports(
      stationAddress: _db.getConfig().stationAddress,
    );
    // Raport mógł przyjechać z Dysku nowszy niż powiązany z nim przejazd —
    // np. kolega dopisał godzinę powrotu u siebie.
    await _db.reconcileTripsWithReports();
    await _db.fillMissingRouteFrom(_db.getConfig().stationAddress);
  }

  // ── Restore state on app start ─────────────────────────────────────

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

  // ── Helpers ────────────────────────────────────────────────────────

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

  /// Nazwa pliku raportu: 0001_2026_Pozar.json
  String _buildReportFileName(Report report) {
    final number = report.reportNumber.replaceAll('/', '_');
    return '${number}_${FileNames.sanitize(report.threatCategory)}.json';
  }

  /// Nazwa pliku przekazania mienia: 2026-07-20_Kielno_`id-prefix`.json
  String _buildHandoverFileName(PropertyHandover handover) {
    final dateStr = FileNames.date(handover.eventDate);
    final locality = FileNames.sanitize(handover.eventLocation);
    final idPrefix = handover.id.length >= 8
        ? handover.id.substring(0, 8)
        : handover.id;
    return '${dateStr}_${locality}_$idPrefix.json';
  }

  /// Nazwa pliku przejazdu: 2026-08-10_GBA_`skrót id`.json
  ///
  /// Data i pojazd w nazwie, żeby zawartość folderu dała się przejrzeć na
  /// Dysku bez otwierania każdego pliku — kartę czyta się po miesiącach.
  /// Skrót z całego identyfikatora: 8 pierwszych znaków bywało wspólne
  /// dla miesięcy ręcznych wpisów (`trip_<milisekundy>`).
  String _buildTripFileName(VehicleTrip t) {
    final name = _db.getVehicle(t.vehicleId)?.name ?? t.vehicleId;
    return '${FileNames.date(t.date)}_${FileNames.sanitize(name)}'
        '_${FileNames.shortHash(t.id)}.json';
  }

  /// Plik z Dysku zapisany przez starszą wersję aplikacji nie zna ręcznych
  /// poprawek przejazdu ([VehicleTrip.overriddenFields]). Stara wersja
  /// potrafi je też cofnąć swoim uzgadnianiem i wysłać jako nowszą.
  /// Poprawione pola i ich ochronę bierzemy wtedy z telefonu.
  @visibleForTesting
  static void keepLocalOverrides(VehicleTrip remote, VehicleTrip local) {
    final flags = local.overriddenFields;
    if (flags.isEmpty) return;
    if (flags.contains(ReportLinkedField.departure)) {
      remote
        ..date = local.date
        ..departureTime = local.departureTime;
    }
    if (flags.contains(ReportLinkedField.returnTime)) {
      remote.returnTime = local.returnTime;
    }
    if (flags.contains(ReportLinkedField.routeTo)) {
      remote.routeTo = local.routeTo;
    }
    if (flags.contains(ReportLinkedField.driver)) {
      remote
        ..driverId = local.driverId
        ..driverName = local.driverName;
    }
    remote.overriddenFields = List.of(flags);
  }
}

/// Jednostka zapisała dane w formacie nowszym, niż ta wersja aplikacji
/// rozumie.
class SyncFormatTooNewException implements Exception {}

/// Plik dokumentu na Dysku, zebrany przy pobieraniu.
class _RemoteDoc {
  final String fileId;
  final String hash;
  final DateTime? updatedAt;

  const _RemoteDoc({
    required this.fileId,
    required this.hash,
    required this.updatedAt,
  });

  bool isNewerThan(_RemoteDoc other) {
    final a = updatedAt, b = other.updatedAt;
    if (a == null) return false;
    return b == null || a.isAfter(b);
  }
}
