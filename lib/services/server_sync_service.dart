part of 'sync_service.dart';

/// Synchronizacja z serwerem jednostek — Firestore (feature/081,
/// PLAN_BAZA_DANYCH.md).
///
/// Dziedziczy po [SyncService] całe scalanie: stemple `updatedAt`, znaczniki
/// usunięcia, numerację wyjazdów, uzgadnianie przejazdów z raportami
/// i harmonogram synchronizacji. Wymienia tylko „transport” — zamiast plików
/// na Dysku dokumenty w bazie:
///
/// ```
/// units/{u}/reports/{id}  { data: treść jak w pliku na Dysku (SyncJson),
///                           author, deleted, serverAt, by }
/// ```
///
/// Uprawnień pilnuje serwer ([firebase/firestore.rules]), więc znika
/// sprawdzanie, kto zmienił plik (fix/067): zmiany, której aplikacja by nie
/// zrobiła, baza po prostu nie przyjmie.
///
/// `unitFolderId` w [SyncState] to tutaj identyfikator jednostki w bazie.
class ServerSyncService extends SyncService {
  /// Baza w testach; w aplikacji [FirebaseFirestore.instance], pobierana
  /// dopiero przy pierwszym użyciu — bez uruchomionego Firebase (testy
  /// ekranów) sama usługa da się utworzyć.
  FirebaseFirestore? _firestore;
  FirebaseFirestore get _fs => _firestore ??= FirebaseFirestore.instance;

  ServerSyncService(
    super._db,
    ServerAuthService super.authService,
    super._driveService, {
    FirebaseFirestore? firestore,
    super.localChangeDelay,
  }) : _firestore = firestore;

  ServerAuthService get _server => authService as ServerAuthService;

  @override
  bool get onServer => true;

  /// Jak długo czekamy na serwer. Bez limitu zapis przy zerwanym połączeniu
  /// czekałby w nieskończoność, a z nim cała synchronizacja.
  static const serverTimeout = Duration(seconds: 30);

  /// Zapas przy pobieraniu zmian „od ostatniego razu” — zapis, który był
  /// w drodze w chwili poprzedniego pobrania, przyjdzie przy następnym.
  static const sinceOverlap = Duration(minutes: 2);

  /// Najwięcej zapisów w jednej paczce (limit Firestore to 500).
  static const _batchSize = 200;

  /// Jak często telefon odczytuje pełną listę członków (role innych osób).
  /// Własną rolę sprawdza przy każdej synchronizacji.
  static const membersInterval = Duration(hours: 6);

  static const String serverConfigKey = 'serverSync';
  static const String _cacheKey = 'serverCache';

  static const _collections = {
    SyncKind.report: 'reports',
    SyncKind.handover: 'handovers',
    SyncKind.trip: 'trips',
    SyncKind.equipmentWork: 'equipmentWork',
    SyncKind.firefighter: 'firefighters',
    SyncKind.vehicle: 'vehicles',
    SyncKind.equipment: 'equipment',
  };
  static const _docKinds = [
    SyncKind.report,
    SyncKind.handover,
    SyncKind.trip,
    SyncKind.equipmentWork,
  ];
  static const _listKinds = [
    SyncKind.firefighter,
    SyncKind.vehicle,
    SyncKind.equipment,
  ];
  static const _threatKind = 'threat';
  static const _threatsCollection = 'threatTypes';

  // ── Pamięć tego, co jest na serwerze ──────────────────────────────────

  /// „rodzaj:id” → skrót treści na serwerze i autor wpisu.
  final Map<String, ({String h, String a})> _onServer = {};

  /// „rodzaj:id” → skrót wersji z telefonu, której serwer nie przyjął —
  /// nie ponawiamy jej, dopóki ktoś jej tu nie zmieni.
  final Map<String, String> _refused = {};

  /// Kolekcja → najpóźniejszy `serverAt` (ms) z ostatniego pobrania.
  final Map<String, int> _since = {};

  DateTime? _membersReadAt;

  /// Członkowie z ostatniego odczytu: adres (małymi literami) → rekord.
  final Map<String, Map<String, dynamic>> _members = {};

  /// Zaproszeni z ostatniego odczytu (tylko administrator): adres → rekord.
  final Map<String, Map<String, dynamic>> _invites = {};

  void _loadServerCache(String unitId) {
    _onServer.clear();
    _refused.clear();
    _since.clear();
    _membersReadAt = null;
    final raw = _db.settingsBox.get(_cacheKey);
    if (raw is! String) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['unit'] != unitId) return;
      for (final e in (json['docs'] as Map).entries) {
        final v = e.value as Map;
        _onServer[e.key as String] = (h: v['h'] as String, a: v['a'] as String);
      }
      for (final e in (json['refused'] as Map? ?? const {}).entries) {
        _refused[e.key as String] = e.value as String;
      }
      for (final e in (json['since'] as Map).entries) {
        _since[e.key as String] = (e.value as num).toInt();
      }
    } catch (e) {
      debugPrint('Pamięć serwera pominięta: $e');
      _onServer.clear();
      _refused.clear();
      _since.clear();
    }
  }

  Future<void> _saveServerCache() => _db.settingsBox.put(
      _cacheKey,
      jsonEncode({
        'unit': _state.unitFolderId,
        'docs': {
          for (final e in _onServer.entries) e.key: {'h': e.value.h, 'a': e.value.a},
        },
        'refused': _refused,
        'since': _since,
      }));

  /// Skrót niezależny od kolejności kluczy — serwer nie musi oddać pól
  /// w tej kolejności, w jakiej je zapisaliśmy.
  static String _hash(Object? json) => SyncJson.contentHash(_sorted(json) ?? const {});

  static Object? _sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return [for (final e in v) _sorted(e)];
    return v;
  }

  String get _me => (authService.userEmail ?? '').trim().toLowerCase();

  String get _uid {
    final uid = _server.uid;
    if (uid == null) throw StateError('Nie zalogowano na serwer.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _unitRef([String? id]) =>
      _fs.collection('units').doc(id ?? _state.unitFolderId);

  // ── Stan zapisany na telefonie ────────────────────────────────────────

  @override
  Future<void> restoreState() async {
    await _db.slimStoredTombstones();
    await _forgetDriveUnit();
    if (!authService.isSignedIn) {
      _updateState(const SyncState());
      return;
    }
    final saved = _db.configBox.get(serverConfigKey);
    if (saved == null) {
      _updateState(SyncState(
        status: SyncStatus.disconnected,
        userEmail: authService.userEmail,
      ));
      return;
    }
    _loadServerCache(saved.namePrefix);
    final owner = _db.getConfig().ownerEmail;
    _updateState(SyncState(
      status: SyncStatus.idle,
      userEmail: authService.userEmail,
      unitFolderId: saved.namePrefix,
      unitInviteCode: saved.locality,
      founderEmail: owner.isEmpty ? null : owner,
      adminEmails: _db.cachedAdminEmails,
      sharedFounder: _db.cachedSharedFounder,
    ));
  }

  /// Telefon z wersji na Dysku: połączenie z folderem jednostki nie ma już
  /// znaczenia. Dane na telefonie zostają — pójdą do jednostki na serwerze,
  /// gdy telefon ją założy albo do niej dołączy (Dawid, 27.11.2026:
  /// „najwyżej przerzucę wszystko ręcznie").
  Future<void> _forgetDriveUnit() async {
    if (_db.configBox.get(SyncService.driveConfigKey) == null) return;
    await _db.configBox.delete(SyncService.driveConfigKey);
    await _db.settingsBox.delete(SyncService._fileCacheKey);
    await _db.cacheAdminEmails(const []);
    await _db.cacheSharedFounder(false);
    await _db.clearRejectedChanges();
  }

  Future<void> _saveServerConfig(String unitId, String code) =>
      _db.configBox.put(
        serverConfigKey,
        // Jak przy Dysku: pola konfiguracji użyte jako schowek.
        UnitConfig(namePrefix: unitId, locality: code),
      );

  @override
  Future<void> _resetUnitState() async {
    await super._resetUnitState();
    _onServer.clear();
    _refused.clear();
    _since.clear();
    _members.clear();
    _invites.clear();
    _membersReadAt = null;
    await _db.settingsBox.delete(_cacheKey);
  }

  @override
  Future<void> disconnectUnit() async {
    await _db.configBox.delete(serverConfigKey);
    await super.disconnectUnit();
  }

  @override
  Future<void> _withAuthRetry(Future<void> Function() body) async {
    if (!authService.isSignedIn) {
      throw StateError('Nie zalogowano na serwer.');
    }
    await authService.refreshAuth();
    try {
      await body();
    } on FirebaseException catch (e) {
      if (e.code != 'unauthenticated') rethrow;
      await authService.refreshAuth(force: true);
      await body();
    }
  }

  // ── Zakładanie jednostki i dołączanie ─────────────────────────────────

  @override
  Future<String> createUnit(String unitName) async {
    await _resetUnitState();
    final uid = _uid;
    final email = _me;
    final config = _db.getConfig();

    // Kod jest identyfikatorem dokumentu — gdyby wylosował się zajęty,
    // serwer odmówi i losujemy jeszcze raz.
    for (var attempt = 1;; attempt++) {
      final code = _generateInviteCode();
      final unit = _fs.collection('units').doc();
      final batch = _fs.batch()
        ..set(unit, {
          'name': unitName,
          'locality': config.locality,
          'unitStreet': config.unitStreet,
          'inviteCode': code,
          'ownerUid': uid,
          'ownerEmail': email,
          'sharedOwner': false,
          'syncFormat': SyncService.syncFormat,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': DateTime.now().toIso8601String(),
        })
        ..set(unit.collection('members').doc(uid), {
          'uid': uid,
          'email': email,
          'role': 'owner',
          if ((authService.displayName ?? '').isNotEmpty)
            'displayName': authService.displayName,
          'joinedAt': FieldValue.serverTimestamp(),
          // Od razu — inaczej „ostatnio" na liście członków pojawiało się
          // dopiero po [SyncService.memberNoteInterval].
          'lastSyncAt': FieldValue.serverTimestamp(),
          'appVersion': SyncService.appVersion,
        })
        ..set(_fs.collection('inviteCodes').doc(code), {'unitId': unit.id});
      try {
        await batch.commit().timeout(serverTimeout);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' && attempt < 5) continue;
        rethrow;
      }

      _remoteUnitConfig = {
        'unitName': unitName,
        'locality': config.locality,
        'unitStreet': config.unitStreet,
      };
      _updateState(_state.copyWith(
        status: SyncStatus.idle,
        userEmail: authService.userEmail,
        unitFolderId: unit.id,
        unitInviteCode: code,
        founderEmail: email,
        adminEmails: const [],
      ));
      await _saveServerConfig(unit.id, code);
      await _db.saveConfig(_db.getConfig().copyWith(ownerEmail: email));
      await _db.settingsBox.put(SyncService._memberNoteKey, _memberStamp());
      await _pushAllData();
      await _saveServerCache();
      return code;
    }
  }

  @override
  Future<UnitLookup> lookupUnit(String code) async {
    final normalized = code.trim().toUpperCase();
    final found = await _fs
        .collection('inviteCodes')
        .doc(normalized)
        .get()
        .timeout(serverTimeout);
    final unitId = found.data()?['unitId'];
    if (unitId is! String) return const UnitNotFound();
    final unit = _unitRef(unitId);

    // To konto już należy do jednostki (np. nowy telefon) — zaproszenie
    // zużyło się przy pierwszym dołączeniu.
    final member =
        await unit.collection('members').doc(_uid).get().timeout(serverTimeout);
    if (member.exists) {
      final data = (await unit.get().timeout(serverTimeout)).data() ?? {};
      return UnitFound(UnitCandidate(
        folderId: unitId,
        unitName: SyncService._text(data['name']) ?? '',
        ownerEmail: SyncService._text(data['ownerEmail']),
        inviteCode: normalized,
        onServer: true,
      ));
    }

    final invite =
        await unit.collection('invites').doc(_me).get().timeout(serverTimeout);
    final data = invite.data();
    if (data == null) return UnitNotInvited(_me);
    return UnitFound(UnitCandidate(
      folderId: unitId,
      unitName: SyncService._text(data['unitName']) ?? '',
      ownerEmail: SyncService._text(data['invitedBy']),
      inviteCode: normalized,
      onServer: true,
    ));
  }

  @override
  Future<void> joinFoundUnit(UnitCandidate unit, String code) async {
    final normalized = code.trim().toUpperCase();
    await _resetUnitState();
    final ref = _unitRef(unit.folderId);
    final memberRef = ref.collection('members').doc(_uid);

    if (!(await memberRef.get().timeout(serverTimeout)).exists) {
      final inviteRef = ref.collection('invites').doc(_me);
      final invite = await inviteRef.get().timeout(serverTimeout);
      final role = SyncService._text(invite.data()?['role']) ?? 'member';
      final batch = _fs.batch()
        ..set(memberRef, {
          'uid': _uid,
          'email': _me,
          'role': role,
          if ((authService.displayName ?? '').isNotEmpty)
            'displayName': authService.displayName,
          'joinedAt': FieldValue.serverTimestamp(),
          // Od razu — inaczej „ostatnio" na liście członków pojawiało się
          // dopiero po [SyncService.memberNoteInterval].
          'lastSyncAt': FieldValue.serverTimestamp(),
          'appVersion': SyncService.appVersion,
        })
        // Zaproszenie zużyte — na liście członków jest już sam członek.
        ..delete(inviteRef);
      await batch.commit().timeout(serverTimeout);
    }

    _updateState(_state.copyWith(
      status: SyncStatus.idle,
      userEmail: authService.userEmail,
      unitFolderId: unit.folderId,
      unitInviteCode: normalized,
    ));
    await _saveServerConfig(unit.folderId, normalized);
    await _db.settingsBox.put(SyncService._memberNoteKey, _memberStamp());

    await _pullAllData();
    // Jak przy Dysku: listy pochodzą od jednostki, wpisy z telefonu zostają.
    for (final kind in _listKinds) {
      final ids = _remoteListIds[kind];
      if (ids != null) await _db.keepOnlyListEntries(kind, ids);
    }
    await _saveServerCache();
  }

  /// Przed dołączeniem listy jednostki nie da się odczytać — dopiero
  /// członek ją widzi. Ostrzeżenia nie ma; obowiązuje lista jednostki.
  @override
  Future<LocalListEntries> localOnlyListEntries(String unitFolderId) async =>
      const LocalListEntries();

  /// Jednostki, do których należy zalogowane konto.
  @override
  Future<List<UnitCandidate>> ownUnits() async {
    final mine = await _fs
        .collectionGroup('members')
        .where('uid', isEqualTo: _uid)
        .get()
        .timeout(serverTimeout);
    final units = <UnitCandidate>[];
    for (final m in mine.docs) {
      final unit = m.reference.parent.parent;
      if (unit == null) continue;
      final data = (await unit.get().timeout(serverTimeout)).data();
      if (data == null) continue;
      final created = data['createdAt'];
      units.add(UnitCandidate(
        folderId: unit.id,
        unitName: SyncService._text(data['name']) ?? '',
        ownerEmail: SyncService._text(data['ownerEmail']),
        inviteCode: SyncService._text(data['inviteCode']),
        createdAt: created is Timestamp ? created.toDate() : null,
        onServer: true,
      ));
    }
    return units
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
  }

  // ── Członkowie, zaproszenia, role ─────────────────────────────────────

  @override
  Future<String> inviteMember(String email) async {
    final address = email.trim().toLowerCase();
    await _writeInvite(address, 'member');
    return SyncService.inviteMessage(
      unitName: _db.getConfig().fullName,
      code: _state.unitInviteCode ?? '',
      email: address,
    );
  }

  Future<void> _writeInvite(String address, String role) async {
    await _unitRef().collection('invites').doc(address).set({
      'email': address,
      'role': role,
      'unitName': _db.getConfig().fullName,
      'invitedBy': _me,
      'invitedAt': FieldValue.serverTimestamp(),
    }).timeout(serverTimeout);
    _invites[address] = {'email': address, 'role': role};
  }

  /// Członkowie i zaproszeni (tych drugich widzi tylko administrator).
  @override
  Future<List<UnitMemberAccess>> listMembers() async {
    if (_state.unitFolderId == null) return const [];
    await _readMembers();
    return [
      for (final MapEntry(key: email, value: m) in _members.entries)
        UnitMemberAccess(
          permissionId: 'm:${m['uid']}',
          email: email,
          isOwner: m['role'] == 'owner',
        ),
      for (final email in _invites.keys)
        if (!_members.containsKey(email))
          UnitMemberAccess(
            permissionId: 'i:$email',
            email: email,
            isOwner: false,
            invited: true,
          ),
    ];
  }

  /// „Kto dołączył” wprost z rekordów członków.
  @override
  Future<Map<String, MemberNote>> memberNotes() async {
    if (_membersReadAt == null) await _readMembers();
    DateTime? at(Object? v) => v is Timestamp ? v.toDate() : null;
    return {
      for (final MapEntry(key: email, value: m) in _members.entries)
        email: MemberNote(
          email: email,
          joinedAt: at(m['joinedAt']),
          lastSyncAt: at(m['lastSyncAt']),
          appVersion: SyncService._text(m['appVersion']) ?? '',
        ),
    };
  }

  /// Odczyt członków (i zaproszonych, gdy wolno) — role do [SyncState].
  Future<void> _readMembers() async {
    final unit = _unitRef();
    final members =
        await unit.collection('members').get().timeout(serverTimeout);
    _members
      ..clear()
      ..addAll({
        for (final d in members.docs)
          if (SyncService._text(d.data()['email']) case final email?)
            SyncService._normalizeEmail(email): d.data(),
      });
    _invites.clear();
    if (_state.isCurrentUserAdmin || _myRole == 'admin' || _myRole == 'owner') {
      try {
        final invites =
            await unit.collection('invites').get().timeout(serverTimeout);
        for (final d in invites.docs) {
          _invites[d.id] = d.data();
        }
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    _membersReadAt = DateTime.now();
    await _applyRoles();
  }

  String? _myRole;

  /// Administratorzy według serwera: członkowie z rolą `admin` i zaproszeni
  /// jako administratorzy (np. przy przejściu na własne konto).
  Future<void> _applyRoles() async {
    final admins = <String>{
      for (final MapEntry(key: email, value: m) in _members.entries)
        if (m['role'] == 'admin') email,
      for (final MapEntry(key: email, value: i) in _invites.entries)
        if (i['role'] == 'admin' && !_members.containsKey(email)) email,
    }.toList()
      ..sort();
    await _setAdmins(admins);
  }

  Future<void> _setAdmins(List<String> admins) async {
    await _db.cacheAdminEmails(admins);
    await _db.setAdminsTrusted(true);
    _updateState(_state.copyWith(adminEmails: admins));
  }

  @override
  Future<void> revokeMember(UnitMemberAccess member) async {
    _ensureNotLastPersonalAdmin(member.email);
    final email = SyncService._normalizeEmail(member.email);
    final id = member.permissionId;
    if (id.startsWith('i:')) {
      await _unitRef().collection('invites').doc(email).delete()
          .timeout(serverTimeout);
      _invites.remove(email);
    } else {
      await _unitRef()
          .collection('members')
          .doc(id.substring(2))
          .delete()
          .timeout(serverTimeout);
      _members.remove(email);
    }
    await _applyRoles();
  }

  /// Role zmieniają się na serwerze rekord po rekordzie: nowym
  /// administratorom `admin`, odebranym `member`; wspólne konto w danych
  /// jednostki. Sprawdzenia (ostatni administrator przy wspólnym koncie)
  /// robi [SyncService.grantAdmin] i reszta, jak przy Dysku.
  @override
  Future<void> _writeAdmins(List<String> admins, {bool? sharedFounder}) async {
    if (_state.unitFolderId == null) return;
    if (_membersReadAt == null) await _readMembers();
    final shared = sharedFounder ?? _state.sharedFounder;
    final before =
        _state.adminEmails.map(SyncService._normalizeEmail).toSet();
    final after = admins.map(SyncService._normalizeEmail).toSet();
    for (final email in after.difference(before)) {
      await _setRole(email, 'admin');
    }
    for (final email in before.difference(after)) {
      await _setRole(email, 'member');
    }
    if (shared != _state.sharedFounder) {
      await _unitRef()
          .update({'sharedOwner': shared}).timeout(serverTimeout);
    }
    await _db.cacheSharedFounder(shared);
    _updateState(_state.copyWith(sharedFounder: shared));
    await _applyRoles();
  }

  Future<void> _setRole(String email, String role) async {
    final member = _members[email];
    if (member != null) {
      await _unitRef()
          .collection('members')
          .doc(member['uid'] as String)
          .update({'role': role}).timeout(serverTimeout);
      member['role'] = role;
      return;
    }
    // Zaproszony, który jeszcze nie dołączył — dołączy od razu z tą rolą.
    if (_invites.containsKey(email)) {
      await _writeInvite(email, role);
      return;
    }
    throw StateError('$email nie jest członkiem jednostki.');
  }

  /// Przejście na własne konto: zaproszenie z uprawnieniami administratora,
  /// zmiana konta i dołączenie nowym kontem.
  @override
  Future<AccountSwitchResult> switchToPersonalAccount(
    String email, {
    bool sharedAccount = false,
  }) async {
    final code = _state.unitInviteCode;
    if (_state.unitFolderId == null || code == null) {
      throw StateError('Brak połączenia z jednostką.');
    }
    final address = SyncService._normalizeEmail(email);
    if (address == _me) return AccountSwitchResult.sameAccount;
    if (_membersReadAt == null) await _readMembers();
    if (!_members.containsKey(address)) await _writeInvite(address, 'admin');
    await grantAdmin(address);
    if (sharedAccount) await setSharedFounder(true);

    stopAutoSync();
    if (!await authService.switchAccount()) {
      await restoreState();
      return AccountSwitchResult.cancelled;
    }
    if (_me != address) {
      await restoreState();
      return AccountSwitchResult.otherAccount;
    }
    final lookup = await lookupUnit(code);
    if (lookup is! UnitFound) {
      await restoreState();
      return AccountSwitchResult.noAccess;
    }
    await joinFoundUnit(lookup.unit, code);
    return AccountSwitchResult.done;
  }

  @override
  Future<bool> switchAccount() async {
    stopAutoSync();
    final ok = await authService.switchAccount();
    await restoreState();
    if (!ok) return false;
    final unitId = _state.unitFolderId;
    if (unitId != null) {
      final member = await _unitRef(unitId)
          .collection('members')
          .doc(_uid)
          .get()
          .timeout(serverTimeout);
      if (!member.exists) {
        _updateState(_state.copyWith(
          status: SyncStatus.error,
          errorMessage: 'Konto ${authService.userEmail} nie należy do tej '
              'jednostki. Poproś administratora o zaproszenie na ten adres '
              'albo wróć do poprzedniego konta.',
          errorTime: DateTime.now(),
        ));
      }
    }
    return true;
  }

  /// Rekord członka zostaje na serwerze — wylogowanie nie jest odejściem
  /// z jednostki (to robi usunięcie konta).
  @override
  Future<void> removeOwnMemberNote() async =>
      _db.settingsBox.delete(SyncService._memberNoteKey);

  // ── Ślad w aplikacji (kto dołączył, feature/080) ──────────────────────

  Map<String, dynamic> _memberStamp() => {
        'unit': _state.unitFolderId,
        'email': _me,
        'at': DateTime.now().toIso8601String(),
        'version': SyncService.appVersion,
      };

  /// Ostatnia synchronizacja i wersja aplikacji w rekordzie członka —
  /// najwyżej co [SyncService.memberNoteInterval] albo po zmianie wersji.
  @override
  Future<void> _writeMemberNote({bool force = false}) async {
    final unit = _state.unitFolderId;
    if (unit == null || _server.uid == null) return;
    final saved = _db.settingsBox.get(SyncService._memberNoteKey);
    final last = saved is Map ? saved : const {};
    final lastAt = DateTime.tryParse('${last['at']}');
    if (!force &&
        last['unit'] == unit &&
        last['email'] == _me &&
        last['version'] == SyncService.appVersion &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < SyncService.memberNoteInterval) {
      return;
    }
    try {
      await _unitRef().collection('members').doc(_uid).update({
        'lastSyncAt': FieldValue.serverTimestamp(),
        'appVersion': SyncService.appVersion,
      }).timeout(serverTimeout);
      await _db.settingsBox.put(SyncService._memberNoteKey, _memberStamp());
    } catch (e) {
      debugPrint('Ślad członka niezapisany: $e');
    }
  }

  // ── Pobieranie ────────────────────────────────────────────────────────

  /// Dokumenty kolekcji zmienione od ostatniego pobrania (z zapasem
  /// [sinceOverlap]); `null` w [_since] — wszystkie.
  Future<List<Map<String, dynamic>>> _changed(String collection) async {
    final since = _since[collection];
    Query<Map<String, dynamic>> query = _unitRef().collection(collection);
    if (since != null) {
      query = query.where('serverAt',
          isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(
              since - sinceOverlap.inMilliseconds));
    }
    final snap = await query.get().timeout(serverTimeout);
    return [for (final d in snap.docs) d.data()];
  }

  /// Po przetworzeniu kolekcji: od kiedy pytać następnym razem.
  void _advance(String collection, List<Map<String, dynamic>> docs) {
    var max = _since[collection] ?? 0;
    for (final d in docs) {
      final at = d['serverAt'];
      if (at is Timestamp && at.millisecondsSinceEpoch > max) {
        max = at.millisecondsSinceEpoch;
      }
    }
    _since[collection] = max;
  }

  static Map<String, dynamic> _content(Map<String, dynamic> doc) =>
      Map<String, dynamic>.from(doc['data'] as Map);

  void _remember(String kind, String id, String hash, String author) {
    _onServer['$kind:$id'] = (h: hash, a: author);
    _refused.remove('$kind:$id');
  }

  String? _roleFrom(Map<String, dynamic>? member) =>
      SyncService._text(member?['role']);

  @override
  Future<void> _pullConfig() async {
    final unit = _unitRef();
    final me =
        await unit.collection('members').doc(_uid).get().timeout(serverTimeout);
    if (!me.exists) throw UnitAccessRevokedException(_state.userEmail);

    final data = (await unit.get().timeout(serverTimeout)).data() ?? {};
    final format = data['syncFormat'];
    _remoteSyncFormat = format is num ? format.toInt() : SyncService.syncFormat;
    if (_remoteSyncFormat > SyncService.syncFormat) {
      throw SyncFormatTooNewException();
    }

    final founder = SyncService._text(data['ownerEmail']);
    _remoteUnitConfig = {
      'unitName': data['name'],
      'locality': data['locality'],
      'unitStreet': data['unitStreet'],
      'updatedAt': data['updatedAt'],
    };
    await _mergeUnitConfig(_remoteUnitConfig!, founder);
    final shared = data['sharedOwner'] == true;
    await _db.cacheSharedFounder(shared);
    _updateState(_state.copyWith(
      founderEmail: founder,
      sharedFounder: shared,
      unitInviteCode: SyncService._text(data['inviteCode']),
    ));

    // Własna rola przy każdej synchronizacji, cudze co jakiś czas.
    final role = _roleFrom(me.data());
    final roleChanged = role != _myRole;
    _myRole = role;
    final stale = _membersReadAt == null ||
        DateTime.now().difference(_membersReadAt!) > membersInterval;
    if (stale || roleChanged) {
      await _readMembers();
    } else {
      _members[_me] = me.data()!;
      await _applyRoles();
    }

    for (final kind in _listKinds) {
      final collection = _collections[kind]!;
      final full = _since[collection] == null;
      final docs = await _changed(collection);
      final ids = full ? (_remoteListIds[kind] = <String>{}) : null;
      for (final doc in docs) {
        try {
          final entry = _content(doc);
          final id = entry['id'] as String;
          ids?.add(id);
          final canonical = await _mergeListEntry(kind, entry);
          _remember(kind, id, _hash(canonical), '');
        } catch (e) {
          debugPrint('Pominięty wpis z serwera ($kind): $e');
          _skippedFiles++;
        }
      }
      _advance(collection, docs);
    }

    final threats = await _changed(_threatsCollection);
    final entries = <Map<String, dynamic>>[];
    for (final doc in threats) {
      try {
        final entry = _content(doc);
        entries.add(entry);
        _remember(_threatKind, entry['category'] as String, _hash(entry), '');
      } catch (e) {
        _skippedFiles++;
      }
    }
    if (entries.isNotEmpty) await _mergeThreats(entries);
    _advance(_threatsCollection, threats);
    await _saveServerCache();
  }

  @override
  Future<void> _pullDocuments({Set<String>? kinds}) async {
    for (final kind in _docKinds) {
      if (kinds != null && !kinds.contains(kind)) continue;
      final collection = _collections[kind]!;
      final docs = await _changed(collection);
      for (final doc in docs) {
        try {
          final data = _content(doc);
          await _applyRemoteDoc(kind, data);
          _remember(
            kind,
            data['id'] as String,
            _remoteHash(kind, data),
            SyncService._text(doc['author']) ?? '',
          );
        } catch (e) {
          debugPrint('Pominięty dokument z serwera ($kind): $e');
          _skippedFiles++;
        }
      }
      _advance(collection, docs);
    }
    await _saveServerCache();
  }

  /// Skrót wersji z serwera w postaci, jaką zapisałby ten telefon.
  String _remoteHash(String kind, Map<String, dynamic> data) =>
      SyncJson.isTombstone(data) ? _hash(data) : _hash(_canonical(kind, data));

  // ── Wysyłka ───────────────────────────────────────────────────────────

  @override
  Future<void> _pushConfig() async {
    final writes = <_ServerWrite>[];

    // Listy prowadzi administrator — serwer i tak nie przyjąłby ich od
    // innych, a telefon bez uprawnień nie powinien nawet próbować.
    if (_state.isCurrentUserAdmin) {
      void list(String kind, Map<String, dynamic> json) =>
          _consider(writes, kind, json, envelope: (json, deleted, _) => {
                'data': json,
                'deleted': deleted,
                'serverAt': FieldValue.serverTimestamp(),
                'by': _me,
              });
      for (final f in _db.getAllFirefighters()) {
        list(SyncKind.firefighter, SyncJson.firefighterToJson(f));
      }
      for (final v in _db.getAllVehicles()) {
        list(SyncKind.vehicle, SyncJson.vehicleToJson(v));
      }
      for (final e in _db.getAllEquipment()) {
        list(SyncKind.equipment, SyncJson.equipmentToJson(e));
      }
      for (final kind in _listKinds) {
        for (final tomb in _db.tombstonesOf(kind)) {
          list(kind, tomb);
        }
      }
    }

    // Słownik zagrożeń uzupełnia każdy członek.
    for (final t in _db.getAllThreats()) {
      final json = SyncJson.threatToJson(t);
      final hash = _hash(json);
      final key = '$_threatKind:${t.category}';
      if (_onServer[key]?.h == hash || _refused[key] == hash) continue;
      writes.add(_ServerWrite(
        collection: _threatsCollection,
        kind: _threatKind,
        id: t.category,
        hash: hash,
        author: '',
        value: {
          'data': json,
          'serverAt': FieldValue.serverTimestamp(),
          'by': _me,
        },
      ));
    }
    await _commit(writes);

    // Dane jednostki zmienia administrator.
    if (_state.isCurrentUserAdmin) {
      final config = _db.getConfig();
      final remote = _remoteUnitConfig;
      final changed = remote == null ||
          remote['unitName'] != config.fullName ||
          (remote['locality'] ?? '') != config.locality ||
          (remote['unitStreet'] ?? '') != config.unitStreet;
      if (changed && config.fullName.trim().isNotEmpty) {
        final updatedAt =
            (_db.unitConfigEditedAt ?? DateTime.now()).toIso8601String();
        await _unitRef().update({
          'name': config.fullName,
          'locality': config.locality,
          'unitStreet': config.unitStreet,
          'updatedAt': updatedAt,
        }).timeout(serverTimeout);
        _remoteUnitConfig = {
          'unitName': config.fullName,
          'locality': config.locality,
          'unitStreet': config.unitStreet,
          'updatedAt': updatedAt,
        };
      }
    }
  }

  @override
  Future<void> _pushDocuments() async {
    final writes = <_ServerWrite>[];
    void doc(String kind, Map<String, dynamic> json) =>
        _consider(writes, kind, json, envelope: (json, deleted, author) => {
              'data': json,
              'author': author,
              'deleted': deleted,
              'serverAt': FieldValue.serverTimestamp(),
              'by': _me,
            });
    for (final r in _db.getAllReports()) {
      doc(SyncKind.report, SyncJson.reportToJson(r));
    }
    for (final h in _db.getAllHandovers()) {
      doc(SyncKind.handover, SyncJson.handoverToJson(h));
    }
    for (final t in _db.getAllTrips()) {
      doc(SyncKind.trip, SyncJson.tripToJson(t));
    }
    for (final w in _db.getAllEquipmentWork()) {
      doc(SyncKind.equipmentWork, SyncJson.equipmentWorkToJson(w));
    }
    for (final kind in _docKinds) {
      for (final tomb in _db.tombstonesOf(kind)) {
        doc(kind, tomb);
      }
    }
    await _commit(writes);
  }

  /// Dokłada zapis, jeśli wersja z telefonu różni się od serwera.
  /// Znacznik usunięcia tylko dla rekordu, który był na serwerze.
  void _consider(
    List<_ServerWrite> writes,
    String kind,
    Map<String, dynamic> json, {
    required Map<String, dynamic> Function(
            Map<String, dynamic> json, bool deleted, String author)
        envelope,
  }) {
    final id = json['id'];
    if (id is! String) return;
    final key = '$kind:$id';
    final hash = _hash(json);
    final known = _onServer[key];
    if (known?.h == hash || _refused[key] == hash) return;
    final deleted = SyncJson.isTombstone(json);
    if (deleted && known == null) return;
    // Autor wpisu jest na serwerze na zawsze — znacznik usunięcia nie ma
    // już treści, więc bierzemy go z tego, co serwer ma.
    final author = deleted
        ? (known?.a ?? '')
        : (SyncService._text(json['createdBy']) ?? '');
    writes.add(_ServerWrite(
      collection: _collections[kind]!,
      kind: kind,
      id: id,
      hash: hash,
      author: author,
      value: envelope(json, deleted, author),
    ));
  }

  /// Zapis paczkami. Gdy serwer odmówi paczki, zapisujemy po jednym —
  /// jeden wpis bez uprawnień nie może zatrzymać pozostałych.
  Future<void> _commit(List<_ServerWrite> writes) async {
    for (var i = 0; i < writes.length; i += _batchSize) {
      final chunk = writes.sublist(i, min(i + _batchSize, writes.length));
      final batch = _fs.batch();
      for (final w in chunk) {
        batch.set(_unitRef().collection(w.collection).doc(w.id), w.value);
      }
      try {
        await batch.commit().timeout(serverTimeout);
        chunk.forEach(_accepted);
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        for (final w in chunk) {
          try {
            await _unitRef()
                .collection(w.collection)
                .doc(w.id)
                .set(w.value)
                .timeout(serverTimeout);
            _accepted(w);
          } on FirebaseException catch (e) {
            if (e.code != 'permission-denied') rethrow;
            // Np. przejazd kolegi uzupełniony tu o „Skąd” — serwer zostaje
            // przy swojej wersji, a telefon nie ponawia tej samej.
            debugPrint('Serwer nie przyjął ${w.kind}:${w.id}');
            _refused['${w.kind}:${w.id}'] = w.hash;
          }
        }
      }
      await _saveServerCache();
    }
  }

  void _accepted(_ServerWrite w) {
    _remember(w.kind, w.id, w.hash, w.author);
    _sentChanges++;
  }

  /// Wpisy, których obecnej wersji nie ma jeszcze na serwerze.
  @override
  Set<String> _awaitingUpload(
          String kind, Map<String, Map<String, dynamic>> current) =>
      {
        for (final MapEntry(key: id, value: json) in current.entries)
          if (_onServer['$kind:$id']?.h != _hash(json)) id,
      };
}

/// Jeden zapis do bazy z tym, co trzeba zapamiętać po jego przyjęciu.
class _ServerWrite {
  final String collection;
  final String kind;
  final String id;
  final String hash;
  final String author;
  final Map<String, dynamic> value;

  const _ServerWrite({
    required this.collection,
    required this.kind,
    required this.id,
    required this.hash,
    required this.author,
    required this.value,
  });
}

/// Zalogowane konto nie jest już członkiem jednostki — administrator
/// odebrał dostęp albo konto zmieniono na inne.
class UnitAccessRevokedException implements Exception {
  final String? email;
  const UnitAccessRevokedException(this.email);

  @override
  String toString() =>
      'Konto ${email ?? ''} nie ma już dostępu do jednostki — administrator '
      'odebrał dostęp albo zalogowano inne konto. Dane na telefonie zostają.';
}
