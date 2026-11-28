import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/phone_db.dart';
import 'helpers/server_phones.dart';

/// Synchronizacja z serwerem jednostek (feature/081): zakładanie,
/// zaproszenia, dołączanie, role. Zasady bezpieczeństwa serwera sprawdzają
/// osobne testy na emulatorze (`firebase/test`).
void main() {
  late Directory root;
  late ServerPhones phones;
  final db = DatabaseService();

  setUpAll(DatabaseService.registerAdapters);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_server');
    phones = ServerPhones(root);
    SyncService.appVersion = '2.0.0';
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<SyncService> phone(String name,
          {String? account, String? uid, String? displayName}) =>
      phones.phone(name, account: account, uid: uid, displayName: displayName);

  Report report(String id, {String createdBy = '', DateTime? at}) => Report(
        id: id,
        reportNumber: '0001/2026',
        year: 2026,
        date: DateTime(2026, 11, 10),
        departureTime: DateTime(2026, 11, 10, 14, 30),
        addressLocality: 'Kielno',
        addressStreet: '',
        addressDescription: '',
        threatCategory: 'Pożar',
        createdBy: createdBy,
        createdAt: DateTime(2026, 11, 10),
        updatedAt: at ?? DateTime(2026, 11, 10),
      );

  Firefighter ff(String id, String lastName, {DateTime? at}) => Firefighter(
        id: id,
        firstName: 'Jan',
        lastName: lastName,
        rank: '',
        updatedAt: at ?? DateTime(2026, 11, 1),
      );

  Future<String> create(SyncService sync) => phones.create(sync);

  Future<Map<String, dynamic>?> serverDoc(String path) => phones.doc(path);

  Future<String> unitIdOf(String code) => phones.unitIdOf(code);

  /// a zakłada jednostkę z jednym wyjazdem i ratownikiem, zaprasza b,
  /// b dołącza.
  Future<String> unitWithMember() async {
    final a = await phone('a');
    await db.addReport(report('r1', createdBy: 'a@gmail.com'));
    await db.addFirefighter(ff('f1', 'Kowalski'));
    final code = await create(a);
    await a.inviteMember('b@gmail.com');
    final b = await phone('b');
    expect(await b.joinUnit(code), isTrue);
    return code;
  }

  group('zakładanie jednostki', () {
    test('jednostka, właściciel, kod i dane z telefonu na serwerze', () async {
      final a = await phone('a');
      await db.addReport(report('r1', createdBy: 'a@gmail.com'));
      await db.addFirefighter(ff('f1', 'Kowalski'));
      final code = await create(a);

      expect(code, hasLength(6));
      final unitId = await unitIdOf(code);
      final unit = (await serverDoc('units/$unitId'))!;
      expect(unit['name'], 'OSP Test');
      expect(unit['ownerEmail'], 'a@gmail.com');
      expect(unit['inviteCode'], code);
      final owner = (await serverDoc('units/$unitId/members/a'))!;
      expect(owner['role'], 'owner');
      expect(owner['email'], 'a@gmail.com');
      expect(owner['lastSyncAt'], isA<Timestamp>(),
          reason: '„ostatnio” od razu, nie po 6 godzinach');

      final r1 = (await serverDoc('units/$unitId/reports/r1'))!;
      expect(r1['author'], 'a@gmail.com');
      expect(r1['deleted'], isFalse);
      expect(r1['by'], 'a@gmail.com');
      expect((r1['data'] as Map)['addressLocality'], 'Kielno');
      expect(r1['serverAt'], isA<Timestamp>());
      expect(await serverDoc('units/$unitId/firefighters/f1'), isNotNull);

      expect(a.state.unitId, unitId);
      expect(a.state.isCurrentUserAdmin, isTrue);
    });

    test('po ponownym uruchomieniu telefon pamięta jednostkę', () async {
      final a = await phone('a');
      final code = await create(a);
      final again = await phone('a');
      expect(again.state.unitId, await unitIdOf(code));
      expect(again.state.unitInviteCode, code);
      expect(again.state.status, SyncStatus.idle);
    });
  });

  group('zaproszenie i dołączanie', () {
    test('kod bez zaproszenia: jednostka jest, ale adresu nie ma na liście',
        () async {
      final a = await phone('a');
      final code = await create(a);
      final c = await phone('c');
      final lookup = await c.lookupUnit(code);
      expect(lookup, isA<UnitNotInvited>());
      expect((lookup as UnitNotInvited).email, 'c@gmail.com');
      expect(await c.lookupUnit('ZZZZZZ'), isA<UnitNotFound>());
    });

    test('zaproszony widzi nazwę jednostki i zapraszającego', () async {
      final a = await phone('a');
      final code = await create(a);
      await a.inviteMember(' B@Gmail.com ');
      final b = await phone('b');
      final lookup = await b.lookupUnit(code.toLowerCase());
      expect(lookup, isA<UnitFound>());
      final unit = (lookup as UnitFound).unit;
      expect(unit.unitName, 'OSP Test');
      expect(unit.ownerEmail, 'a@gmail.com');
    });

    test('dołączenie: rekord członka, zaproszenie zużyte, dane jednostki '
        'na telefonie', () async {
      final code = await unitWithMember();
      final unitId = await unitIdOf(code);
      expect((await serverDoc('units/$unitId/members/b'))!['role'], 'member');
      expect((await serverDoc('units/$unitId/members/b'))!['lastSyncAt'],
          isA<Timestamp>());
      expect(await serverDoc('units/$unitId/invites/b@gmail.com'), isNull);

      final b = await phone('b');
      expect(db.getReport('r1'), isNotNull);
      expect(db.getFirefighter('f1')?.lastName, 'Kowalski');
      expect(b.state.founderEmail, 'a@gmail.com');
      expect(b.state.isCurrentUserAdmin, isFalse);
    });

    test('nowy telefon tego samego konta dołącza bez nowego zaproszenia',
        () async {
      final code = await unitWithMember();
      final again = await phone('b-nowy', account: 'b@gmail.com', uid: 'b');
      expect(await again.lookupUnit(code), isA<UnitFound>());
      expect(await again.joinUnit(code), isTrue);
      expect(db.getReport('r1'), isNotNull);
    });

    test('lista ratowników z telefonu zastąpiona listą jednostki', () async {
      final a = await phone('a');
      await db.addFirefighter(ff('f1', 'Kowalski'));
      final code = await create(a);
      await a.inviteMember('b@gmail.com');

      await phone('b');
      await db.addFirefighter(ff('f9', 'Obcy'));
      final b = await phone('b');
      expect(await b.joinUnit(code), isTrue);
      expect(db.getAllFirefighters().map((f) => f.lastName), ['Kowalski']);
    });
  });

  group('synchronizacja dwóch telefonów', () {
    test('wpis z jednego telefonu trafia na drugi, zmiana i usunięcie też',
        () async {
      await unitWithMember();
      var b = await phone('b');
      await db.addReport(report('r2', createdBy: 'b@gmail.com'));
      await b.syncAll();

      var a = await phone('a');
      await a.syncAll();
      expect(db.getReport('r2'), isNotNull);

      final edited = db.getReport('r2')!
        ..addressLocality = 'Gdynia'
        ..updatedAt = DateTime(2026, 11, 11);
      await db.updateReport(edited);
      await a.syncAll();

      b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r2')!.addressLocality, 'Gdynia');

      await db.deleteReport('r2');
      await b.syncAll();
      a = await phone('a');
      await a.syncAll();
      expect(db.getReport('r2'), isNull);
    });

    test('bez zmian: nic nie wysyła i nic nie pobiera', () async {
      await unitWithMember();
      final a = await phone('a');
      await a.syncAll();
      await a.syncAll();
      expect(a.state.lastSyncSent, 0);
      expect(a.state.lastSyncReceived, 0);
      expect(a.state.status, SyncStatus.idle);
    });

    test('usunięty wpis na serwerze: sam znacznik, bez treści', () async {
      final code = await unitWithMember();
      final a = await phone('a');
      await db.deleteReport('r1');
      await a.syncAll();
      final r1 = (await serverDoc('units/${await unitIdOf(code)}/reports/r1'))!;
      expect(r1['deleted'], isTrue);
      expect(r1['author'], 'a@gmail.com',
          reason: 'autor zostaje — serwer nie pozwoli „wskrzesić” cudzego');
      expect((r1['data'] as Map).keys.toSet(),
          {'id', 'updatedAt', 'deleted', 'deletedAt'});
    });

    test('członek nie wysyła list ratowników — prowadzi je administrator',
        () async {
      final code = await unitWithMember();
      final b = await phone('b');
      await db.addFirefighter(ff('f2', 'Nowak'));
      await b.syncAll();
      expect(
          await serverDoc('units/${await unitIdOf(code)}/firefighters/f2'),
          isNull);
    });

    test('dane jednostki od administratora trafiają do członka', () async {
      await unitWithMember();
      final a = await phone('a');
      await db.saveConfig(db.getConfig().copyWith(
        unitFullName: 'OSP Kielno',
        locality: 'Kielno',
        unitStreet: 'Oliwska 12',
      ));
      await db.markUnitConfigEdited();
      await a.syncAll();

      final b = await phone('b');
      await b.syncAll();
      expect(db.getConfig().fullName, 'OSP Kielno');
      expect(db.getConfig().unitStreet, 'Oliwska 12');
    });

    test('„czeka na wysłanie” do pierwszej udanej synchronizacji', () async {
      await unitWithMember();
      final b = await phone('b');
      await db.addReport(report('r3', createdBy: 'b@gmail.com'));
      expect(b.reportsAwaitingUpload(db.getAllReports()), {'r3'});
      await b.syncAll();
      expect(b.reportsAwaitingUpload(db.getAllReports()), isEmpty);
    });
  });

  group('członkowie i role', () {
    test('lista: członkowie z „kto dołączył” i zaproszeni, którzy jeszcze '
        'nie dołączyli', () async {
      await unitWithMember();
      final a = await phone('a');
      await a.inviteMember('c@gmail.com');
      final members = await a.listMembers();
      expect(members.map((m) => m.email),
          unorderedEquals(['a@gmail.com', 'b@gmail.com', 'c@gmail.com']));
      expect(members.firstWhere((m) => m.email == 'c@gmail.com').invited,
          isTrue);
      expect(members.firstWhere((m) => m.email == 'a@gmail.com').isOwner,
          isTrue);

      // „Kto dołączył" wprost z rekordu członka.
      final b = members.firstWhere((m) => m.email == 'b@gmail.com');
      expect(b.appVersion, '2.0.0');
      expect(b.joinedAt, isNotNull);
      expect(b.uid, 'b');
    });

    test('nadanie administratora: rola na serwerze i uprawnienia u członka',
        () async {
      final code = await unitWithMember();
      final a = await phone('a');
      await a.listMembers();
      await a.grantAdmin('b@gmail.com');
      expect(
          (await serverDoc('units/${await unitIdOf(code)}/members/b'))!['role'],
          'admin');

      final b = await phone('b');
      await b.syncAll();
      expect(b.state.isCurrentUserAdmin, isTrue);

      final a2 = await phone('a');
      await a2.listMembers();
      await a2.revokeAdmin('b@gmail.com');
      final b2 = await phone('b');
      await b2.syncAll();
      expect(b2.state.isCurrentUserAdmin, isFalse);
    });

    test('zaproszony od razu jako administrator dołącza z tą rolą', () async {
      final a = await phone('a');
      final code = await create(a);
      await a.inviteMember('c@gmail.com');
      await a.listMembers();
      await a.grantAdmin('c@gmail.com');
      final c = await phone('c');
      expect(await c.joinUnit(code), isTrue);
      expect(c.state.isCurrentUserAdmin, isTrue);
    });

    test('odebrany dostęp: synchronizacja mówi o tym wprost, dane zostają',
        () async {
      await unitWithMember();
      final a = await phone('a');
      final members = await a.listMembers();
      await a.revokeMember(members.firstWhere((m) => m.email == 'b@gmail.com'));

      final b = await phone('b');
      await b.syncAll();
      expect(b.state.status, SyncStatus.error);
      expect(b.state.errorMessage, contains('nie ma już dostępu'));
      expect(db.getReport('r1'), isNotNull);
    });

    test('cofnięcie zaproszenia, zanim ktoś dołączył', () async {
      final a = await phone('a');
      final code = await create(a);
      await a.inviteMember('c@gmail.com');
      final members = await a.listMembers();
      await a.revokeMember(members.firstWhere((m) => m.email == 'c@gmail.com'));
      final c = await phone('c');
      expect(await c.lookupUnit(code), isA<UnitNotInvited>());
    });

    // Dawid, 27.11.2026: „skoro i tak jest logowanie Google, to można by
    // dodać imię i nazwisko, kto dołączył".
    test('imię z konta Google: u zaproszonego przy dołączaniu i na liście '
        'członków', () async {
      final a = await phone('a', displayName: 'Anna Nowak');
      final code = await create(a);
      await a.inviteMember('b@gmail.com');

      final b = await phone('b', displayName: 'Bartek Kowalski');
      final lookup = await b.lookupUnit(code) as UnitFound;
      expect(lookup.unit.ownerName, 'Anna Nowak');
      expect(lookup.unit.ownerEmail, 'a@gmail.com');
      await b.joinFoundUnit(lookup.unit, code);

      final a2 = await phone('a', displayName: 'Anna Nowak');
      final members = await a2.listMembers();
      String nameOf(String email) =>
          members.firstWhere((m) => m.email == email).name;
      expect(nameOf('a@gmail.com'), 'Anna Nowak');
      expect(nameOf('b@gmail.com'), 'Bartek Kowalski');
    });

    // Dawid, 27.11.2026: tablet w wozie loguje się kontem jednostki,
    // telefon swoim — niezależnie od tego, kto założył jednostkę.
    test('wspólne urządzenie, które nie zakładało jednostki: pyta, kto '
        'wpisuje, i nie zarządza jednostką — także po restarcie', () async {
      final code = await unitWithMember();
      final unitId = await unitIdOf(code);
      final a = await phone('a');
      await a.listMembers();
      await a.setSharedDevice('b@gmail.com', true);
      expect((await serverDoc('units/$unitId/members/b'))!['role'], 'shared');
      expect(a.state.sharedEmails, ['b@gmail.com']);
      expect(a.state.isSharedDevice('b@gmail.com'), isTrue);

      final b = await phone('b');
      await b.syncAll();
      expect(b.state.isSharedAccount, isTrue);
      expect(b.state.isCurrentUserAdmin, isFalse);
      // Restart bez zasięgu — z pamięci telefonu.
      final bAgain = await phone('b');
      expect(bAgain.state.isSharedAccount, isTrue);

      final a2 = await phone('a');
      await a2.listMembers();
      await a2.setSharedDevice('b@gmail.com', false);
      expect((await serverDoc('units/$unitId/members/b'))!['role'], 'member');
      final b2 = await phone('b');
      await b2.syncAll();
      expect(b2.state.isSharedAccount, isFalse);
    });

    test('zaproszony od razu jako wspólne urządzenie dołącza z tą rolą',
        () async {
      final a = await phone('a');
      final code = await create(a);
      await a.inviteMember('t@gmail.com', sharedDevice: true);
      expect(a.state.sharedEmails, ['t@gmail.com']);

      final t = await phone('t');
      expect(await t.joinUnit(code), isTrue);
      expect(t.state.isSharedAccount, isTrue);
      expect(t.state.isCurrentUserAdmin, isFalse);
    });

    test('konto założyciela jako wspólne urządzenie; ostatni administrator '
        'na własnym koncie nim nie zostanie', () async {
      final code = await unitWithMember();
      final unitId = await unitIdOf(code);
      final a = await phone('a');
      await a.listMembers();
      await expectLater(a.setSharedDevice('a@gmail.com', true),
          throwsA(isA<LastPersonalAdminException>()));

      await a.grantAdmin('b@gmail.com');
      await a.setSharedDevice('a@gmail.com', true);
      expect((await serverDoc('units/$unitId'))!['sharedOwner'], isTrue);
      expect(a.state.isSharedAccount, isTrue);
      await expectLater(a.setSharedDevice('b@gmail.com', true),
          throwsA(isA<LastPersonalAdminException>()));
      expect((await serverDoc('units/$unitId/members/b'))!['role'], 'admin');
    });

    test('ślad w aplikacji: ostatnia synchronizacja i wersja', () async {
      final code = await unitWithMember();
      final unitId = await unitIdOf(code);
      SyncService.appVersion = '2.0.1';
      final b = await phone('b');
      await b.syncAll();
      final me = (await serverDoc('units/$unitId/members/b'))!;
      expect(me['appVersion'], '2.0.1');
      expect(me['lastSyncAt'], isA<Timestamp>());
    });
  });

  test('telefon z jednostką na Dysku: po aktualizacji bez folderu, dane '
      'zostają i idą do nowej jednostki na serwerze (Dawid, 27.11.2026)',
      () async {
    await openPhoneDb(root, 'stary');
    await db.configBox.put('driveSync', UnitConfig(namePrefix: 'folder-na-dysku'));
    await db.cacheAdminEmails(const ['kolega@gmail.com']);
    await db.addReport(report('r-stary', createdBy: 'kolega@gmail.com'));

    final a = await phone('stary', account: 'a@gmail.com', uid: 'a');
    expect(a.state.status, SyncStatus.disconnected);
    expect(a.state.unitId, isNull);
    expect(db.configBox.get('driveSync'), isNull);
    expect(db.cachedAdminEmails, isEmpty);
    expect(db.getReport('r-stary'), isNotNull);

    final code = await create(a);
    final r = (await serverDoc(
        'units/${await unitIdOf(code)}/reports/r-stary'))!;
    expect(r['author'], 'kolega@gmail.com',
        reason: 'administrator przenosi cudze wpisy z autorem');
  });

  test('jednostka zapisana przez wersję testową 2.0.0 (w polach '
      'konfiguracji) wraca po aktualizacji', () async {
    final a = await phone('a');
    final code = await create(a);
    final unitId = await unitIdOf(code);
    await db.settingsBox.delete('serverUnit');
    await db.configBox.put(
        'serverSync', UnitConfig(namePrefix: unitId, locality: code));

    final again = await phone('a');
    expect(again.state.unitId, unitId);
    expect(again.state.unitInviteCode, code);
    expect(db.configBox.get('serverSync'), isNull);
    await again.syncAll();
    expect(again.state.status, SyncStatus.idle);
  });

  test('jednostki konta — do propozycji „dołącz zamiast zakładać”', () async {
    final a = await phone('a');
    final code = await create(a);
    final again = await phone('a-nowy', account: 'a@gmail.com', uid: 'a');
    final units = await again.ownUnits();
    expect(units, hasLength(1));
    expect(units.single.inviteCode, code);
    expect(units.single.unitName, 'OSP Test');
    expect(await (await phone('nowy')).ownUnits(), isEmpty,
        reason: 'nowe konto nie ma jednostek');
  });

  test('kolekcje, których dotyka aplikacja, zgadzają się z zasadami serwera',
      () {
    final rules = File('firebase/firestore.rules').readAsStringSync();
    for (final c in [
      'reports', 'handovers', 'trips', 'equipmentWork', 'firefighters',
      'vehicles', 'equipment', 'threatTypes', 'members', 'invites',
      'inviteCodes', 'consents',
    ]) {
      expect(rules, contains(c), reason: c);
    }
  });
}
