import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/support_links.dart';
import '../core/utils/time_format.dart';
import '../models/models.dart';
import '../models/sync_state.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'report_numbers.dart';
import 'sync_json.dart';

/// Komunikat dla użytkownika zamiast surowego tekstu wyjątku.
String describeSyncError(Object e) {
  // Brak sieci albo chwilowa awaria serwera.
  if (e is TimeoutException ||
      (e is FirebaseException &&
          const {'unavailable', 'deadline-exceeded', 'aborted'}
              .contains(e.code))) {
    return 'Serwer jednostki chwilowo nie odpowiada. Dane są zapisane na '
        'telefonie, synchronizacja ponowi się sama.';
  }
  if (e is FirebaseException && e.code == 'permission-denied') {
    return 'Serwer odmówił dostępu — to konto może nie należeć już do '
        'jednostki. Dane są zapisane na telefonie.';
  }
  return '$e';
}

/// Synchronizacja bazy na telefonie (Hive) z serwerem jednostek — Firestore
/// (feature/081, PLAN_BAZA_DANYCH.md).
///
/// ```
/// units/{u}                    dane jednostki, właściciel, kod
/// units/{u}/members/{uid}      członek: adres, rola, imię, ostatnio, wersja
/// units/{u}/invites/{adres}    lista zaproszonych
/// units/{u}/reports/{id}       { data: treść (SyncJson), author, deleted,
///                                serverAt, by } — tak samo przekazania,
///                                przejazdy i praca sprzętu
/// units/{u}/firefighters/{id}  listy administratora (bez `author`)
/// units/{u}/threatTypes/{kat.} słownik zagrożeń
/// ```
///
/// Scalanie rozstrzyga stempel `updatedAt` każdego rekordu, usunięcia jeżdżą
/// jako znaczniki bez treści. Uprawnień pilnuje serwer
/// ([firebase/firestore.rules]) — zapisu, którego aplikacja by nie zrobiła,
/// baza po prostu nie przyjmie.
class SyncService {
  final DatabaseService _db;
  final AuthService authService;

  /// Baza w testach; w aplikacji [FirebaseFirestore.instance], pobierana
  /// dopiero przy pierwszym użyciu — bez uruchomionego Firebase (testy
  /// ekranów) sama usługa da się utworzyć.
  FirebaseFirestore? _firestore;
  FirebaseFirestore get _fs => _firestore ??= FirebaseFirestore.instance;

  Timer? _autoSyncTimer;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  /// Callback to notify listeners about sync state changes.
  void Function(SyncState)? onStateChanged;

  /// Wołane po zapisaniu danych pobranych z serwera.
  ///
  /// Listy na ekranach trzymają migawkę z chwili utworzenia, więc bez
  /// odświeżenia raport dodany przez kolegę pojawiał się dopiero po
  /// ponownym uruchomieniu aplikacji.
  void Function()? onDataPulled;

  SyncState _state = const SyncState();
  SyncState get state => _state;

  /// Zwłoka między zapisem na telefonie a wysyłką — zbiera w jeden przebieg
  /// zapisy idące razem (wyjazd i jego wiersze w ewidencji przejazdów).
  final Duration localChangeDelay;

  Timer? _localChangeTimer;

  /// Zapis w trakcie synchronizacji — ta mogła już minąć etap wysyłki.
  bool _changedWhileSyncing = false;

  SyncService(
    this._db,
    this.authService, {
    FirebaseFirestore? firestore,
    this.localChangeDelay = const Duration(seconds: 2),
  }) : _firestore = firestore;

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

  // ── Synchronizacja w tle ───────────────────────────────────────────

  /// Co 5 minut, gdy aplikacja jest otwarta, i po powrocie zasięgu.
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

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _localChangeTimer?.cancel();
    _localChangeTimer = null;
  }

  /// Coś zapisano na telefonie — wysyłka zaraz, a nie przy najbliższej
  /// synchronizacji co 5 minut.
  ///
  /// Zgłoszenie z testu 1.7.4 na dwóch telefonach: zapis wyjazdu niczego
  /// nie wysyłał, a co 5 minut synchronizacja idzie tylko przy aplikacji
  /// otwartej na ekranie. Wyjazd kolegi czekał więc na telefonie, a drugi
  /// telefon nadał w tym czasie ten sam numer 0002/2026.
  ///
  /// Bez sieci przebieg kończy się błędem, a zmiana czeka na powrót
  /// połączenia albo na następną synchronizację.
  void notifyLocalChange() {
    if (!_state.isConnected || _state.unitId == null) return;
    if (_isSyncing) {
      _changedWhileSyncing = true;
      return;
    }
    _localChangeTimer?.cancel();
    _localChangeTimer = Timer(localChangeDelay, () async {
      _localChangeTimer = null;
      // Bez sieci każdy zapis kończyłby się czerwonym błędem — wyśle go
      // powrót zasięgu (nasłuch zmian sieci w [startAutoSync]).
      if (await _hasNetwork()) syncAll();
    });
  }

  /// Czy telefon ma jakąkolwiek sieć. Gdy nie da się tego sprawdzić,
  /// próbujemy — najwyżej skończy się zwykłym błędem połączenia.
  Future<bool> _hasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Po synchronizacji: zapis z jej trwania wysyłamy osobnym przebiegiem.
  void _afterSyncPass() {
    if (!_changedWhileSyncing) return;
    _changedWhileSyncing = false;
    notifyLocalChange();
  }

  /// Uruchomienie aplikacji i powrót do niej z tła. Android usypia aplikację
  /// po chwili, więc synchronizacja co 5 minut stoi, dopóki ktoś jej znów
  /// nie otworzy — a wtedy powinien od razu zobaczyć wyjazdy z innych
  /// telefonów. Bez sieci nie próbujemy: zrobi to powrót zasięgu.
  Future<void> syncIfOnline() async {
    if (_isSyncing || !await _hasNetwork()) return;
    await syncAll();
  }

  /// Najkrótszy odstęp między synchronizacjami przy otwieraniu list.
  static const staleAfter = Duration(seconds: 30);

  /// Otwarcie listy wyjazdów, przekazań albo ewidencji. Kolega mógł właśnie
  /// coś dodać, a w tle telefon pobiera co 5 minut — zgłoszenie z testu
  /// 1.7.6: „raz nie pokazało, dopiero po naciśnięciu chmurki". Najwyżej
  /// raz na [staleAfter], także po nieudanej próbie, żeby przechodzenie
  /// między ekranami nie pytało serwera za każdym razem.
  Future<void> syncIfStale() async {
    final last = [_state.lastSyncTime, _state.errorTime]
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    if (last != null && DateTime.now().difference(last) < staleAfter) return;
    await syncIfOnline();
  }

  void dispose() {
    stopAutoSync();
  }

  // ── Zakładanie jednostki i dołączanie ──────────────────────────────

  /// Zakłada jednostkę z danymi z telefonu. Zwraca kod zaproszenia.
  Future<String> createUnit(String unitName) async {
    await _resetUnitState();
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
          'ownerUid': _uid,
          'ownerEmail': email,
          'sharedOwner': false,
          'syncFormat': syncFormat,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': DateTime.now().toIso8601String(),
        })
        ..set(unit.collection('members').doc(_uid), _memberRecord('owner'))
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
        unitId: unit.id,
        unitInviteCode: code,
        founderEmail: email,
        adminEmails: const [],
      ));
      await _saveUnit(unit.id, code);
      await _db.saveConfig(_db.getConfig().copyWith(ownerEmail: email));
      await _db.settingsBox.put(_memberNoteKey, _memberStamp());
      await _pushAllData();
      await _saveServerCache();
      return code;
    }
  }

  /// Rekord członka — przy założeniu jednostki i przy dołączeniu.
  Map<String, dynamic> _memberRecord(String role) => {
        'uid': _uid,
        'email': _me,
        'role': role,
        if ((authService.displayName ?? '').isNotEmpty)
          'displayName': authService.displayName,
        'joinedAt': FieldValue.serverTimestamp(),
        // Od razu — inaczej „ostatnio" na liście członków pojawiało się
        // dopiero po [memberNoteInterval].
        'lastSyncAt': FieldValue.serverTimestamp(),
        'appVersion': appVersion,
      };

  /// Szuka jednostki po kodzie zaproszenia, niczego jeszcze nie zmieniając.
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
        unitId: unitId,
        unitName: _text(data['name']) ?? '',
        ownerEmail: _text(data['ownerEmail']),
        inviteCode: normalized,
      ));
    }

    final invite =
        await unit.collection('invites').doc(_me).get().timeout(serverTimeout);
    final data = invite.data();
    if (data == null) return UnitNotInvited(_me);
    return UnitFound(UnitCandidate(
      unitId: unitId,
      unitName: _text(data['unitName']) ?? '',
      ownerEmail: _text(data['invitedBy']),
      ownerName: _text(data['invitedByName']),
      inviteCode: normalized,
    ));
  }

  /// Dołącza do jednostki znalezionej przez [lookupUnit].
  Future<void> joinFoundUnit(UnitCandidate unit, String code) async {
    final normalized = code.trim().toUpperCase();
    await _resetUnitState();
    final ref = _unitRef(unit.unitId);
    final memberRef = ref.collection('members').doc(_uid);

    if (!(await memberRef.get().timeout(serverTimeout)).exists) {
      final inviteRef = ref.collection('invites').doc(_me);
      final invite = await inviteRef.get().timeout(serverTimeout);
      final role = _text(invite.data()?['role']) ?? 'member';
      final batch = _fs.batch()
        ..set(memberRef, _memberRecord(role))
        // Zaproszenie zużyte — na liście członków jest już sam członek.
        ..delete(inviteRef);
      await batch.commit().timeout(serverTimeout);
    }

    _updateState(_state.copyWith(
      status: SyncStatus.idle,
      userEmail: authService.userEmail,
      unitId: unit.unitId,
      unitInviteCode: normalized,
    ));
    await _saveUnit(unit.unitId, normalized);
    await _db.settingsBox.put(_memberNoteKey, _memberStamp());

    await _pullAllData();
    // Ratownicy, pojazdy i sprzęt pochodzą od jednostki. Wyjazdy,
    // przekazania i przejazdy z tego telefonu zostają i pojadą na serwer —
    // to praca tej osoby, a nie lista, którą prowadzi administrator.
    for (final kind in _listKinds) {
      final ids = _remoteListIds[kind];
      if (ids != null) await _db.keepOnlyListEntries(kind, ids);
    }
    await _saveServerCache();
  }

  /// Wyszukanie i dołączenie bez pytania. Ekrany przed dołączeniem
  /// pokazują zapraszającego i proszą o potwierdzenie ([lookupUnit]
  /// i [joinFoundUnit]).
  Future<bool> joinUnit(String code) async {
    final lookup = await lookupUnit(code);
    if (lookup is! UnitFound) return false;
    await joinFoundUnit(lookup.unit, code);
    return true;
  }

  /// Jednostki, do których należy zalogowane konto, najnowsze pierwsze —
  /// do propozycji „dołącz zamiast zakładać kolejną”.
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
        unitId: unit.id,
        unitName: _text(data['name']) ?? '',
        ownerEmail: _text(data['ownerEmail']),
        inviteCode: _text(data['inviteCode']),
        createdAt: created is Timestamp ? created.toDate() : null,
      ));
    }
    return units
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
  }

  // ── Zaproszenia ────────────────────────────────────────────────────

  /// Dopisuje adres do listy zaproszonych — dopiero z nim można dołączyć
  /// kodem. Zwraca treść zaproszenia; kod wysyła zapraszający (SMS,
  /// komunikator, e-mail).
  ///
  /// Z [sharedDevice] zaproszony od razu jest wspólnym urządzeniem
  /// jednostki (rola `shared`).
  Future<String> inviteMember(String email, {bool sharedDevice = false}) async {
    final address = _normalizeEmail(email);
    await _writeInvite(address, sharedDevice ? 'shared' : 'member');
    if (sharedDevice) await _applyRoles();
    return inviteMessage(
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
      // Imię zapraszającego w oknie dołączania — zaproszony nie odczyta
      // jeszcze listy członków.
      if ((authService.displayName ?? '').isNotEmpty)
        'invitedByName': authService.displayName,
      'invitedAt': FieldValue.serverTimestamp(),
    }).timeout(serverTimeout);
    _invites[address] = {'email': address, 'role': role};
  }

  /// Strona aplikacji — skąd ją pobrać; po publikacji prowadzi do Sklepu Play.
  static const String appPage = kWebsiteUrl;

  /// Treść zaproszenia, którą zapraszający wysyła sam.
  @visibleForTesting
  static String inviteMessage({
    required String unitName,
    required String code,
    required String email,
  }) =>
      'Zaproszenie do jednostki „$unitName" w aplikacji Raporty OSP.\n\n'
      'Kod zaproszenia: $code\n\n'
      'Jak dołączyć: zainstaluj aplikację Raporty OSP, wybierz „Dołącz do '
      'jednostki", zaloguj się kontem $email i wpisz kod. Jeśli aplikację '
      'już masz: Ustawienia → Dołącz do jednostki kodem.\n\n'
      'O aplikacji: $appPage';

  // ── Ślad w aplikacji (kto dołączył, feature/080) ───────────────────

  /// Wersja aplikacji do rekordu członka — ustawiana w `main()`, w testach
  /// wpisywana wprost.
  static String appVersion = '';

  /// Jak często telefon odświeża „ostatnio” w swoim rekordzie. Przy każdej
  /// synchronizacji (co 5 minut) byłby to zapis co chwilę, a dokładność do
  /// kilku godzin wystarczy.
  static const Duration memberNoteInterval = Duration(hours: 6);

  static const String _memberNoteKey = 'memberNote';

  Map<String, dynamic> _memberStamp() => {
        'unit': _state.unitId,
        'email': _me,
        'at': DateTime.now().toIso8601String(),
        'version': appVersion,
      };

  /// Ostatnia synchronizacja i wersja aplikacji w rekordzie członka —
  /// najwyżej co [memberNoteInterval] albo po zmianie wersji. Błąd nie
  /// zatrzymuje synchronizacji.
  Future<void> _writeMemberNote() async {
    final unit = _state.unitId;
    if (unit == null || authService.uid == null) return;
    final saved = _db.settingsBox.get(_memberNoteKey);
    final last = saved is Map ? saved : const {};
    final lastAt = DateTime.tryParse('${last['at']}');
    if (last['unit'] == unit &&
        last['email'] == _me &&
        last['version'] == appVersion &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < memberNoteInterval) {
      return;
    }
    try {
      await _unitRef().collection('members').doc(_uid).update({
        'lastSyncAt': FieldValue.serverTimestamp(),
        'appVersion': appVersion,
      }).timeout(serverTimeout);
      await _db.settingsBox.put(_memberNoteKey, _memberStamp());
    } catch (e) {
      debugPrint('Ślad członka niezapisany: $e');
    }
  }

  /// „Wyloguj i usuń dane". Rekord członka zostaje na serwerze —
  /// wylogowanie nie jest odejściem z jednostki (to robi usunięcie konta).
  Future<void> removeOwnMemberNote() =>
      _db.settingsBox.delete(_memberNoteKey);

  // ── Konto ──────────────────────────────────────────────────────────

  /// Logowanie z ekranu aplikacji.
  ///
  /// Jednostka zapisana na telefonie wraca od razu. Automatyczną
  /// synchronizację uruchamia potem [SyncStateNotifier], tak jak po
  /// założeniu jednostki i dołączeniu do niej.
  Future<bool> signIn() async {
    final ok = await authService.signIn();
    if (!ok) return false;
    await restoreState();
    return true;
  }

  /// Zmienia konto, zostając w tej samej jednostce.
  ///
  /// Zwraca `false`, gdy nie wybrano żadnego konta — aplikacja zostaje wtedy
  /// wylogowana. Gdy nowe konto nie należy do jednostki, połączenie zostaje
  /// zapisane, a stan pokazuje, kogo trzeba zaprosić; po powrocie na
  /// poprzednie konto wszystko działa jak wcześniej.
  Future<bool> switchAccount() async {
    stopAutoSync();
    final ok = await authService.switchAccount();
    await restoreState();
    if (!ok) return false;
    final unitId = _state.unitId;
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

  // ── Członkowie i role ──────────────────────────────────────────────

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Członkowie z ostatniego odczytu: adres (małymi literami) → rekord.
  final Map<String, Map<String, dynamic>> _members = {};

  /// Zaproszeni z ostatniego odczytu (tylko administrator): adres → rekord.
  final Map<String, Map<String, dynamic>> _invites = {};

  DateTime? _membersReadAt;
  String? _myRole;

  /// Członkowie i zaproszeni (tych drugich widzi tylko administrator).
  Future<List<UnitMember>> listMembers() async {
    if (_state.unitId == null) return const [];
    await _readMembers();
    DateTime? at(Object? v) => v is Timestamp ? v.toDate() : null;
    return [
      for (final MapEntry(key: email, value: m) in _members.entries)
        UnitMember(
          email: email,
          uid: _text(m['uid']),
          isOwner: m['role'] == 'owner',
          name: _text(m['displayName']) ?? '',
          joinedAt: at(m['joinedAt']),
          lastSyncAt: at(m['lastSyncAt']),
          appVersion: _text(m['appVersion']) ?? '',
        ),
      for (final email in _invites.keys)
        if (!_members.containsKey(email)) UnitMember(email: email),
    ];
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
          if (_text(d.data()['email']) case final email?)
            _normalizeEmail(email): d.data(),
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

  /// Administratorzy i wspólne urządzenia według serwera: członkowie
  /// z rolą `admin` albo `shared` i tak samo zaproszeni.
  Future<void> _applyRoles() async {
    List<String> withRole(String role) => <String>{
          for (final MapEntry(key: email, value: m) in _members.entries)
            if (m['role'] == role) email,
          for (final MapEntry(key: email, value: i) in _invites.entries)
            if (i['role'] == role && !_members.containsKey(email)) email,
        }.toList()
          ..sort();
    final shared = withRole('shared');
    final admins = withRole('admin');
    await _db.cacheSharedEmails(shared);
    await _db.cacheAdminEmails(admins);
    _updateState(_state.copyWith(sharedEmails: shared, adminEmails: admins));
  }

  /// Odbiera dostęp członkowi albo cofa zaproszenie.
  Future<void> revokeMember(UnitMember member) async {
    _ensureNotLastPersonalAdmin(member.email);
    final email = _normalizeEmail(member.email);
    final uid = member.uid;
    if (uid == null) {
      await _unitRef()
          .collection('invites')
          .doc(email)
          .delete()
          .timeout(serverTimeout);
      _invites.remove(email);
    } else {
      await _unitRef()
          .collection('members')
          .doc(uid)
          .delete()
          .timeout(serverTimeout);
      _members.remove(email);
    }
    await _applyRoles();
  }

  bool _isAdminEmail(String email) {
    final normalized = _normalizeEmail(email);
    return _state.adminEmails.any((e) => _normalizeEmail(e) == normalized);
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
    _ensureNotLastPersonalAdmin(email);
    final normalized = _normalizeEmail(email);
    await _writeAdmins(_state.adminEmails
        .where((e) => _normalizeEmail(e) != normalized)
        .toList());
  }

  /// Przy wspólnym koncie założyciela ostatni administrator na własnym
  /// koncie zostaje — bez niego uprawnienia wróciłyby po cichu na tablet.
  void _ensureNotLastPersonalAdmin(String email) {
    if (!_state.sharedFounder || _state.isFounder(email)) return;
    final normalized = _normalizeEmail(email);
    final others = _state.personalAdminEmails
        .where((e) => _normalizeEmail(e) != normalized);
    if (_isAdminEmail(email) && others.isEmpty) {
      throw const LastPersonalAdminException();
    }
  }

  /// Włącza albo wyłącza wspólne konto założyciela
  /// ([SyncState.sharedFounder]).
  ///
  /// Włączyć można tylko przy co najmniej jednym administratorze na własnym
  /// koncie — to on potem zarządza jednostką i tylko on może to cofnąć,
  /// bo wspólne konto przestaje być administratorem.
  Future<void> setSharedFounder(bool shared) async {
    if (shared && !_state.hasPersonalAdmin) {
      throw const LastPersonalAdminException();
    }
    await _writeAdmins(_state.adminEmails, sharedFounder: shared);
  }

  /// Wspólne urządzenie jednostki, np. tablet w wozie
  /// ([SyncState.isSharedDevice]): rola `shared` zamiast `member`/`admin`,
  /// a u założyciela [setSharedFounder]. Ostatni administrator na własnym
  /// koncie przy wspólnym koncie założyciela zostaje — jak przy odbieraniu
  /// uprawnień.
  Future<void> setSharedDevice(String email, bool shared) async {
    if (_state.isFounder(email)) return setSharedFounder(shared);
    if (_membersReadAt == null) await _readMembers();
    final address = _normalizeEmail(email);
    if (shared) _ensureNotLastPersonalAdmin(address);
    await _setRole(address, shared ? 'shared' : 'member');
    await _applyRoles();
  }

  /// Role zmieniają się na serwerze rekord po rekordzie: nowym
  /// administratorom `admin`, odebranym `member`; wspólne konto założyciela
  /// w danych jednostki.
  Future<void> _writeAdmins(List<String> admins, {bool? sharedFounder}) async {
    if (_state.unitId == null) return;
    if (_membersReadAt == null) await _readMembers();
    final shared = sharedFounder ?? _state.sharedFounder;
    final before = _state.adminEmails.map(_normalizeEmail).toSet();
    final after = admins.map(_normalizeEmail).toSet();
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

  // ── Odłączenie i usunięcie danych ──────────────────────────────────

  /// Odłącza telefon od jednostki; dane na telefonie zostają.
  Future<void> disconnectUnit() async {
    stopAutoSync();
    // copyWith, nie nowy obiekt: budowanie od zera gubiło pełną nazwę
    // jednostki, ulicę remizy i sparowaną drukarkę.
    await _db.saveConfig(_db.getConfig().copyWith(ownerEmail: ''));
    // Bez tego po restarcie aplikacja sama łączyła się z powrotem ze starą
    // jednostką — także po zalogowaniu innym kontem.
    await _db.settingsBox.delete(_unitKey);
    await _db.cacheSharedFounder(false);
    await _resetUnitState();
    _updateState(const SyncState());
  }

  /// Usuwa z telefonu dane jednostki — po wylogowaniu, na życzenie osoby,
  /// która odchodzi z jednostki albo oddaje telefon.
  ///
  /// Dane zostają na serwerze jednostki; telefon traci tylko swoją kopię.
  Future<void> wipeLocalUnitData() async {
    stopAutoSync();
    await _resetUnitState();
    await _db.wipeUnitData();
    _updateState(SyncState(userEmail: authService.userEmail));
  }

  /// Zapomina wszystko, co dotyczyło poprzedniej jednostki — inaczej zapis
  /// w nowej szedłby z wiedzą o starej.
  Future<void> _resetUnitState() async {
    await _db.cacheAdminEmails(const []);
    await _db.cacheSharedEmails(const []);
    _remoteListIds.clear();
    _remoteUnitConfig = null;
    _onServer.clear();
    _refused.clear();
    _since.clear();
    _members.clear();
    _invites.clear();
    _membersReadAt = null;
    _myRole = null;
    await _db.settingsBox.delete(_cacheKey);
    _updateState(_state.copyWith(sharedEmails: const []));
  }

  // ── Pełna synchronizacja ───────────────────────────────────────────

  /// Pełna synchronizacja w obie strony. Zwraca liczbę powtórzonych
  /// numerów wyjazdów po pobraniu.
  ///
  /// Kolejność: najpierw pobieramy, potem wysyłamy — i wysyłamy tylko to,
  /// co różni się od serwera.
  Future<int> syncAll() async {
    if (_isSyncing || !_state.isConnected || _state.unitId == null) {
      return 0;
    }

    _isSyncing = true;
    final pass = Completer<void>();
    _currentPass = pass.future;
    _skippedFiles = 0;
    _sentChanges = 0;
    _receivedChanges = 0;
    _renumberNotes.clear();
    _updateState(_state.copyWith(status: SyncStatus.syncing));

    try {
      await _withAuthRetry(() async {
        await _pullConfig();
        await _pullDocuments();
        await _afterPull();
        // Po pobraniu, przed wysyłką — nowy numer wychodzi tym samym
        // przebiegiem.
        await _resolveNumberConflicts();
        await _pushConfig();
        await _pushDocuments();
        await _writeMemberNote();
      });

      final duplicates = _db.findDuplicateReportNumbers();

      _updateState(
        _state.copyWith(
          status: SyncStatus.idle,
          lastSyncTime: DateTime.now(),
          clearError: true,
          duplicateReportNumbers: duplicates,
          skippedFiles: _skippedFiles,
          lastSyncSent: _sentChanges,
          lastSyncReceived: _receivedChanges,
          // Bez nowych zmian numerów — poprzednie zostają do przeczytania.
          renumberNotes: _renumberNotes.isEmpty
              ? null
              : [..._state.renumberNotes, ..._renumberNotes],
        ),
      );
      return duplicates.length;
    } on SyncFormatTooNewException {
      _updateState(_state.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Jednostka używa nowszej wersji aplikacji. '
            'Zaktualizuj aplikację, żeby synchronizować dane.',
        errorTime: DateTime.now(),
      ));
      return 0;
    } catch (e) {
      debugPrint('Sync error: $e');
      _updateState(_state.copyWith(
        status: SyncStatus.error,
        errorMessage: describeSyncError(e),
        errorTime: DateTime.now(),
      ));
      return 0;
    } finally {
      _isSyncing = false;
      pass.complete();
      // Także po błędzie w połowie — część danych mogła już się zapisać.
      onDataPulled?.call();
      _afterSyncPass();
    }
  }

  /// Trwająca synchronizacja albo pobranie raportów.
  Future<void>? _currentPass;

  /// Nowe numery nadane w bieżącym przebiegu — komunikaty dla autora.
  final List<String> _renumberNotes = [];

  /// Powtórzony numer z dwóch telefonów rozstrzygamy sami: wcześniejszy
  /// wyjazd zatrzymuje numer, późniejszy dostaje pierwszy wolny w swoim roku
  /// ([ReportNumbers.laterDuplicates]).
  ///
  /// Numer zmienia tylko telefon autora późniejszego wyjazdu, a przy
  /// wyjazdach bez autora — telefon administratora. Gdyby poprawiał każdy,
  /// dwa telefony mogłyby nadać temu samemu wyjazdowi różne numery.
  Future<void> _resolveNumberConflicts() async {
    for (final r in ReportNumbers.laterDuplicates(_db.getAllReports())) {
      final mine = r.createdBy.trim().isEmpty
          ? _state.isCurrentUserAdmin
          : _state.isAuthor(r.createdBy);
      if (!mine) continue;

      final old = r.reportNumber;
      r
        ..reportNumber = _db.nextReportNumberFor(old, fallbackYear: r.year)
        // Nowszy stempel — inaczej telefony z numerem sprzed zmiany
        // uznałyby swoją wersję za aktualną.
        ..updatedAt = DateTime.now();
      await _db.updateReport(r);
      _renumberNotes.add(
        'Wyjazd z ${TimeFormat.date(r.date)}, '
        '${TimeFormat.hhmm(r.departureTime)}'
        '${r.addressLocality.isEmpty ? '' : ' (${r.addressLocality})'} '
        'ma teraz numer ${r.reportNumber} — numer $old ma wcześniejszy '
        'wyjazd. Jeśli był już wydrukowany, popraw numer na wydruku.',
      );
    }
  }

  /// Komunikaty o nowych numerach zostały pokazane.
  void clearRenumberNotes() {
    if (_state.renumberNotes.isEmpty) return;
    _updateState(_state.copyWith(renumberNotes: const []));
  }

  /// Samo pobranie wyjazdów — przed nadaniem numeru w kreatorze. `true`,
  /// gdy się udało.
  Future<bool> pullReportsOnly() async {
    if (!_state.isConnected || _state.unitId == null) return false;
    // Bez zasięgu kreator nie może czekać na ponowienia przy zapisie
    // wyjazdu — numer liczy się wtedy z tego, co jest na telefonie.
    if (!_isSyncing && !await _hasNetwork()) return false;
    // Pełna synchronizacja i tak pobiera raporty, a dwa przebiegi naraz
    // zapisywałyby te same rekordy z dwóch miejsc. Czekamy na jej koniec —
    // kreator liczy po tym numer wyjazdu.
    if (_isSyncing) {
      await _currentPass;
      return true;
    }
    _isSyncing = true;
    final pass = Completer<void>();
    _currentPass = pass.future;
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
      pass.complete();
      onDataPulled?.call();
      _afterSyncPass();
    }
  }

  /// Wyjazdy z telefonu, których obecnej wersji nie ma jeszcze na serwerze
  /// — nie wyszły albo zmieniono je po wysłaniu.
  Set<String> reportsAwaitingUpload(Iterable<Report> reports) =>
      _awaitingUpload(SyncKind.report, {
        for (final r in reports) r.id: SyncJson.reportToJson(r),
      });

  /// To samo dla przekazań mienia — zgłoszenie z testu 1.7.6: przekazanie
  /// kolegi nie dotarło, a jego ekran nie mówił, czy w ogóle wyszło.
  Set<String> handoversAwaitingUpload(Iterable<PropertyHandover> handovers) =>
      _awaitingUpload(SyncKind.handover, {
        for (final h in handovers) h.id: SyncJson.handoverToJson(h),
      });

  Set<String> _awaitingUpload(
          String kind, Map<String, Map<String, dynamic>> current) =>
      {
        for (final MapEntry(key: id, value: json) in current.entries)
          if (_onServer['$kind:$id']?.h != _hash(json)) id,
      };

  /// Świeży token przed pracą z serwerem, a przy odmowie jeszcze jedna
  /// próba z tokenem wymuszonym na nowo.
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

  // ── Stan jednego przebiegu ─────────────────────────────────────────

  /// Dane jednostki z serwera z ostatniego pobrania.
  Map<String, dynamic>? _remoteUnitConfig;

  int _skippedFiles = 0;

  /// Zmiany wysłane i pobrane w bieżącym przebiegu.
  int _sentChanges = 0;
  int _receivedChanges = 0;

  /// Identyfikatory wpisów (także usuniętych) na listach ratowników,
  /// pojazdów i sprzętu jednostki — z pełnego pobrania.
  final Map<String, Set<String>> _remoteListIds = {};

  /// Wersja formatu danych jednostki (`syncFormat` w jednostce), którą ta
  /// aplikacja rozumie. Jednostka z wyższą wersją (nowsza aplikacja
  /// u kolegi) blokuje synchronizację z komunikatem „zaktualizuj”, zamiast
  /// pozwolić staremu telefonowi nadpisać dane w formacie, którego nie
  /// rozumie.
  ///
  /// 3 — znaczniki usunięcia bez treści rekordu (fix/062), wspólne konto
  /// jednostki i „Wpisał" (feature/058).
  static const int syncFormat = 3;

  // ── Pamięć tego, co jest na serwerze ───────────────────────────────

  static const String _cacheKey = 'serverCache';

  /// „rodzaj:id” → skrót treści na serwerze i autor wpisu.
  final Map<String, ({String h, String a})> _onServer = {};

  /// „rodzaj:id” → skrót wersji z telefonu, której serwer nie przyjął —
  /// nie ponawiamy jej, dopóki ktoś jej tu nie zmieni.
  final Map<String, String> _refused = {};

  /// Kolekcja → najpóźniejszy `serverAt` (ms) z ostatniego pobrania.
  final Map<String, int> _since = {};

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
        'unit': _state.unitId,
        'docs': {
          for (final e in _onServer.entries) e.key: {'h': e.value.h, 'a': e.value.a},
        },
        'refused': _refused,
        'since': _since,
      }));

  /// Skrót niezależny od kolejności kluczy — serwer nie musi oddać pól
  /// w tej kolejności, w jakiej je zapisaliśmy.
  static String _hash(Object? json) =>
      SyncJson.contentHash(_sorted(json) ?? const {});

  static Object? _sorted(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return {for (final k in keys) k: _sorted(v[k])};
    }
    if (v is List) return [for (final e in v) _sorted(e)];
    return v;
  }

  String get _me => _normalizeEmail(authService.userEmail ?? '');

  String get _uid {
    final uid = authService.uid;
    if (uid == null) throw StateError('Nie zalogowano na serwer.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _unitRef([String? id]) =>
      _fs.collection('units').doc(id ?? _state.unitId);

  // ── Stan zapisany na telefonie ─────────────────────────────────────

  /// Jednostka, do której należy telefon: `{unit, code}` w `settings`.
  static const String _unitKey = 'serverUnit';

  Future<void> _saveUnit(String unitId, String code) =>
      _db.settingsBox.put(_unitKey, {'unit': unitId, 'code': code});

  ({String unitId, String code})? _savedUnit() {
    final saved = _db.settingsBox.get(_unitKey);
    if (saved is! Map || saved['unit'] is! String) return null;
    return (unitId: saved['unit'] as String, code: '${saved['code'] ?? ''}');
  }

  /// Wersja testowa 2.0.0 trzymała jednostkę w polach konfiguracji
  /// (identyfikator jako „prefiks nazwy”, kod jako „miejscowość”).
  Future<void> _moveOldUnitKey() async {
    final old = _db.configBox.get('serverSync');
    if (old == null) return;
    if (_savedUnit() == null) await _saveUnit(old.namePrefix, old.locality);
    await _db.configBox.delete('serverSync');
  }

  /// Przywraca stan po uruchomieniu aplikacji.
  Future<void> restoreState() async {
    // Znaczniki usunięcia sprzed fix/062 — bez treści rekordów, zanim
    // cokolwiek pójdzie na serwer. Za drugim razem nic nie zmienia.
    await _db.slimStoredTombstones();
    await _forgetDriveUnit();
    await _moveOldUnitKey();
    if (!authService.isSignedIn) {
      _updateState(const SyncState());
      return;
    }
    final saved = _savedUnit();
    if (saved == null) {
      _updateState(SyncState(
        status: SyncStatus.disconnected,
        userEmail: authService.userEmail,
      ));
      return;
    }
    _loadServerCache(saved.unitId);
    final owner = _db.getConfig().ownerEmail;
    _updateState(SyncState(
      status: SyncStatus.idle,
      userEmail: authService.userEmail,
      unitId: saved.unitId,
      unitInviteCode: saved.code,
      // Uprawnienia z ostatniej synchronizacji — inaczej po restarcie
      // aplikacji (albo bez zasięgu) nikt nie byłby administratorem.
      founderEmail: owner.isEmpty ? null : owner,
      adminEmails: _db.cachedAdminEmails,
      sharedFounder: _db.cachedSharedFounder,
      sharedEmails: _db.cachedSharedEmails,
    ));
  }

  /// Telefon z wersji na Dysku (1.x): połączenie z folderem jednostki nie ma
  /// już znaczenia. Dane na telefonie zostają — pójdą na serwer, gdy telefon
  /// założy jednostkę albo do niej dołączy (Dawid, 27.11.2026: „najwyżej
  /// przerzucę wszystko ręcznie").
  Future<void> _forgetDriveUnit() async {
    if (_db.configBox.get('driveSync') == null) return;
    await _db.configBox.delete('driveSync');
    await _db.settingsBox
        .deleteAll(const ['driveFileCache', 'rejectedChanges', 'adminsTrusted']);
    await _db.cacheAdminEmails(const []);
    await _db.cacheSharedFounder(false);
  }

  // ── Pobieranie ─────────────────────────────────────────────────────

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

  /// Dane jednostki, własna rola, listy i słownik.
  Future<void> _pullConfig() async {
    final unit = _unitRef();
    final me =
        await unit.collection('members').doc(_uid).get().timeout(serverTimeout);
    if (!me.exists) throw UnitAccessRevokedException(_state.userEmail);

    final data = (await unit.get().timeout(serverTimeout)).data() ?? {};
    final format = data['syncFormat'];
    if (format is num && format.toInt() > syncFormat) {
      throw SyncFormatTooNewException();
    }

    final founder = _text(data['ownerEmail']);
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
      unitInviteCode: _text(data['inviteCode']),
    ));

    // Własna rola przy każdej synchronizacji, cudze co jakiś czas.
    final role = _text(me.data()?['role']);
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
    final entries = <ThreatEntry>[];
    for (final doc in threats) {
      try {
        final entry = _content(doc);
        entries.add(SyncJson.threatFromJson(entry));
        _remember(_threatKind, entry['category'] as String, _hash(entry), '');
      } catch (e) {
        debugPrint('Pominięty wpis słownika: $e');
        _skippedFiles++;
      }
    }
    if (entries.isNotEmpty) await _mergeThreats(entries);
    _advance(_threatsCollection, threats);
    await _saveServerCache();
  }

  /// Wyjazdy, przekazania, przejazdy i praca sprzętu zmienione od ostatniego
  /// pobrania. [kinds] zawęża do wybranych rodzajów (szybkie pobranie
  /// wyjazdów przed kreatorem).
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
            _text(doc['author']) ?? '',
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

  // ── Scalanie ───────────────────────────────────────────────────────

  /// Tekst z serwera albo `null`, gdy jest tam coś innego.
  static String? _text(Object? value) => value is String ? value : null;

  /// Dane jednostki z serwera — chyba że na tym telefonie zmieniono je
  /// później.
  Future<void> _mergeUnitConfig(
      Map<String, dynamic> configData, String? founderEmail) async {
    final config = _db.getConfig();
    final editedHere = _db.unitConfigEditedAt;
    final remoteAt = SyncJson.stampOf(configData);
    final localIsNewer = editedHere != null &&
        (remoteAt == null || editedHere.isAfter(remoteAt));

    // Wartości złego typu traktujemy jak brak.
    final unitName = (_text(configData['unitName']) ?? '').trim();
    // Adresu nie wymuszamy na pustkę — nadpisanie skasowałoby to, co ktoś
    // wpisał lokalnie.
    final remoteLocality = (_text(configData['locality']) ?? '').trim();
    final remoteStreet = (_text(configData['unitStreet']) ?? '').trim();
    // Bez założyciela z serwera zostaje lokalny.
    final founder = founderEmail ?? config.ownerEmail;

    await _db.saveConfig(localIsNewer
        ? config.copyWith(ownerEmail: founder)
        : config.copyWith(
            // Nazwę bierzemy w całości. Wcześniej była rozbijana po spacjach
            // („ostatni wyraz to miejscowość"), co przy nazwach w rodzaju
            // „Ochotnicza Straż Pożarna w Kielnie" dawało bezsens.
            unitFullName: unitName.isEmpty ? null : unitName,
            locality: remoteLocality.isEmpty ? null : remoteLocality,
            unitStreet: remoteStreet.isEmpty ? null : remoteStreet,
            ownerEmail: founder,
          ));
  }

  /// Wpis listy ratowników, pojazdów albo sprzętu z serwera — według
  /// stempli. Zwraca wpis w postaci, jaką zapisałby ten telefon.
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
        if (exists) _receivedChanges++;
      }
      return entry;
    }

    final canonical = switch (kind) {
      SyncKind.firefighter =>
        SyncJson.firefighterToJson(SyncJson.firefighterFromJson(entry)),
      SyncKind.vehicle => SyncJson.vehicleToJson(SyncJson.vehicleFromJson(entry)),
      _ => SyncJson.equipmentToJson(SyncJson.equipmentFromJson(entry)),
    };

    final tomb = _db.tombstoneOf(kind, id);
    final tombAt = tomb == null ? null : SyncJson.stampOf(tomb);
    if (tombAt != null && (remoteAt == null || !remoteAt.isAfter(tombAt))) {
      return canonical; // usunięcie tutaj jest nowsze
    }

    // Wpis bez stempla po obu stronach: bierzemy serwer. Ze stemplem
    // wygrywa nowszy.
    final takeRemote = !exists ||
        (remoteAt == null && localAt == null) ||
        (remoteAt != null && (localAt == null || remoteAt.isAfter(localAt)));
    if (takeRemote) {
      final before = switch (kind) {
        SyncKind.firefighter => switch (_db.getFirefighter(id)) {
            final f? => SyncJson.firefighterToJson(f),
            null => null,
          },
        SyncKind.vehicle => switch (_db.getVehicle(id)) {
            final v? => SyncJson.vehicleToJson(v),
            null => null,
          },
        _ => switch (_db.getEquipment(id)) {
            final e? => SyncJson.equipmentToJson(e),
            null => null,
          },
      };
      if (before == null ||
          SyncJson.contentHash(before) != SyncJson.contentHash(canonical)) {
        _receivedChanges++;
      }
      switch (kind) {
        case SyncKind.firefighter:
          await _db.addFirefighter(SyncJson.firefighterFromJson(
            entry,
            local: _db.getFirefighter(id),
          ));
        case SyncKind.vehicle:
          await _db.addVehicle(SyncJson.vehicleFromJson(entry));
        default:
          await _db.addEquipment(SyncJson.equipmentFromJson(entry));
      }
      if (tomb != null) await _db.removeTombstone(kind, id);
    }
    return canonical;
  }

  /// Słownik zagrożeń: suma zbiorów. Własnych podtypów nie da się usuwać,
  /// więc łączenie nie wskrzesza niczego, co ktoś skasował.
  Future<void> _mergeThreats(List<ThreatEntry> remote) async {
    for (final t in remote) {
      final local =
          _db.getAllThreats().where((l) => l.category == t.category).firstOrNull;
      if (local == null) {
        await _db.addThreat(t);
        _receivedChanges++;
        continue;
      }
      final missing = t.subtypes.where((s) => !local.subtypes.contains(s));
      if (missing.isEmpty) continue;
      _receivedChanges++;
      await _db.addThreat(ThreatEntry(
        category: local.category,
        subtypes: [...local.subtypes, ...missing],
        isCustom: local.isCustom,
      ));
    }
    // Uzgodnij słownik ze stałymi listami kategorii.
    await _db.ensureDefaultThreats();
  }

  /// Nakłada dokument z serwera na bazę, jeśli jest nowszy.
  Future<void> _applyRemoteDoc(String kind, Map<String, dynamic> data) async {
    final id = data['id'] as String;
    final remoteAt = SyncJson.stampOf(data) ?? DateTime(2000);

    if (SyncJson.isTombstone(data)) {
      final localAt = _localStamp(kind, id);
      final tombAt = _tombstoneStamp(kind, id);
      final newerHere = localAt != null && localAt.isAfter(remoteAt);
      if (!newerHere &&
          (localAt != null || tombAt == null || tombAt.isBefore(remoteAt))) {
        await _db.applyRemoteDeletion(kind, id, data);
        if (localAt != null) _receivedChanges++;
      }
      return;
    }

    final tombAt = _tombstoneStamp(kind, id);
    if (tombAt != null && !remoteAt.isAfter(tombAt)) {
      return; // usunięcie tutaj jest nowsze
    }

    final localAt = _localStamp(kind, id);
    if (localAt == null || remoteAt.isAfter(localAt)) {
      _receivedChanges++;
      switch (kind) {
        case SyncKind.report:
          await _db.addReport(SyncJson.reportFromJson(data));
        case SyncKind.handover:
          await _db.addHandover(SyncJson.handoverFromJson(data));
        case SyncKind.trip:
          await _db.addTrip(SyncJson.tripFromJson(data));
        case SyncKind.equipmentWork:
          await _db.addEquipmentWork(SyncJson.equipmentWorkFromJson(data));
      }
      if (tombAt != null) await _db.removeTombstone(kind, id);
    }
  }

  Map<String, dynamic> _canonical(String kind, Map<String, dynamic> data) =>
      switch (kind) {
        SyncKind.report =>
          SyncJson.reportToJson(SyncJson.reportFromJson(data)),
        SyncKind.handover =>
          SyncJson.handoverToJson(SyncJson.handoverFromJson(data)),
        SyncKind.trip => SyncJson.tripToJson(SyncJson.tripFromJson(data)),
        SyncKind.equipmentWork => SyncJson.equipmentWorkToJson(
            SyncJson.equipmentWorkFromJson(data)),
        _ => data,
      };

  bool _existsLocally(String kind, String id) => switch (kind) {
        SyncKind.firefighter => _db.getFirefighter(id) != null,
        SyncKind.vehicle => _db.getVehicle(id) != null,
        SyncKind.equipment => _db.getEquipment(id) != null,
        _ => false,
      };

  /// Stempel rekordu w telefonie; `null`, gdy go tu nie ma albo (ratownik,
  /// pojazd) pochodzi sprzed stempli.
  DateTime? _localStamp(String kind, String id) => switch (kind) {
        SyncKind.report => _db.getReport(id)?.updatedAt,
        SyncKind.handover => _db.getHandover(id)?.updatedAt,
        SyncKind.trip => _db.getTrip(id)?.updatedAt,
        SyncKind.equipmentWork => _db.getEquipmentWork(id)?.updatedAt,
        SyncKind.firefighter => _db.getFirefighter(id)?.updatedAt,
        SyncKind.vehicle => _db.getVehicle(id)?.updatedAt,
        SyncKind.equipment => _db.getEquipment(id)?.updatedAt,
        _ => null,
      };

  DateTime? _tombstoneStamp(String kind, String id) {
    final tomb = _db.tombstoneOf(kind, id);
    return tomb == null ? null : SyncJson.stampOf(tomb);
  }

  // ── Wysyłka ────────────────────────────────────────────────────────

  /// Listy (administrator), słownik zagrożeń i dane jednostki.
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

  /// Wyjazdy, przekazania, przejazdy i praca sprzętu — tylko te, które
  /// różnią się od serwera, oraz znaczniki usunięcia.
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
    final author =
        deleted ? (known?.a ?? '') : (_text(json['createdBy']) ?? '');
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

  // ── Pobranie i wysłanie całości ────────────────────────────────────

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
    // Raport mógł przyjechać nowszy niż powiązany z nim przejazd — np.
    // kolega dopisał godzinę powrotu u siebie.
    await _db.reconcileTripsWithReports();
    await _db.fillMissingRouteFrom(_db.getConfig().stationAddress);
  }

  // ── Pomocnicze ─────────────────────────────────────────────────────

  void _updateState(SyncState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
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

/// Jednostka zapisała dane w formacie nowszym, niż ta wersja aplikacji
/// rozumie.
class SyncFormatTooNewException implements Exception {}

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

/// Zmiana zostawiłaby jednostkę ze wspólnym kontem założyciela bez żadnego
/// administratora na własnym koncie ([SyncService.setSharedFounder],
/// [SyncService.revokeAdmin], [SyncService.revokeMember]).
class LastPersonalAdminException implements Exception {
  const LastPersonalAdminException();

  @override
  String toString() =>
      'Przy wspólnym koncie jednostki musi zostać co najmniej jeden '
      'administrator na własnym koncie. Najpierw nadaj uprawnienia '
      'komuś innemu albo wyłącz wspólne konto.';
}

/// Wynik [SyncService.lookupUnit].
sealed class UnitLookup {
  const UnitLookup();
}

/// Żadna jednostka nie ma tego kodu.
class UnitNotFound extends UnitLookup {
  const UnitNotFound();
}

/// Kod pasuje do jednostki, ale tego adresu nie ma na liście zaproszonych.
class UnitNotInvited extends UnitLookup {
  final String email;
  const UnitNotInvited(this.email);
}

class UnitFound extends UnitLookup {
  final UnitCandidate unit;
  const UnitFound(this.unit);
}
