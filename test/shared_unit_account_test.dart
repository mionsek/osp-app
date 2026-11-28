import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_json.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/server_phones.dart';

/// Wspólne konto jednostki — np. tablet w samochodzie zalogowany kontem,
/// na którym założono jednostkę.
///
/// Prośba Dawida z 12.11.2026: zostać przy jednym koncie jednostki zamiast
/// zakładać drugie dla tabletu. Bez zmian każdy, kto weźmie tablet, byłby
/// administratorem (założyciel jest nim zawsze), a „Dodał" pokazywałby
/// przy każdym wpisie adres jednostki.
void main() {
  group('SyncState — uprawnienia wspólnego konta', () {
    SyncState state({
      required String me,
      bool shared = true,
      List<String> admins = const ['dawid@gmail.com'],
    }) =>
        SyncState(
          status: SyncStatus.idle,
          userEmail: me,
          unitId: 'folder',
          founderEmail: 'ospkielno@gmail.com',
          adminEmails: admins,
          sharedFounder: shared,
        );

    test('wspólne konto jednostki nie jest administratorem, gdy jest '
        'administrator na własnym koncie', () {
      final tablet = state(me: 'ospkielno@gmail.com');
      expect(tablet.isCurrentUserAdmin, isFalse);
      expect(tablet.isSharedAccount, isTrue);
      expect(tablet.isAdmin('dawid@gmail.com'), isTrue);
    });

    test('bez administratora na własnym koncie wspólne konto zachowuje '
        'uprawnienia — jednostka nie zostaje bez nikogo', () {
      final tablet = state(me: 'OSPKielno@gmail.com ', admins: const []);
      expect(tablet.isCurrentUserAdmin, isTrue);
      expect(tablet.isSharedAccount, isTrue, reason: 'nadal pyta, kto wpisuje');
    });

    test('założyciel na liście administratorów nie liczy się jako '
        'administrator na własnym koncie', () {
      final tablet =
          state(me: 'ospkielno@gmail.com', admins: const ['ospkielno@gmail.com']);
      expect(tablet.hasPersonalAdmin, isFalse);
      expect(tablet.isCurrentUserAdmin, isTrue);
    });

    test('bez włączonego wspólnego konta założyciel jest administratorem '
        'i nikt nie pyta, kto wpisuje', () {
      final founder = state(me: 'ospkielno@gmail.com', shared: false);
      expect(founder.isCurrentUserAdmin, isTrue);
      expect(founder.isSharedAccount, isFalse);
    });

    test('na telefonie kolegi nic się nie zmienia', () {
      final colleague = state(me: 'wojtek@gmail.com');
      expect(colleague.isCurrentUserAdmin, isFalse);
      expect(colleague.isSharedAccount, isFalse);
    });

    test('tablet poprawia wpisy z konta jednostki, ale nie wpisy kolegów', () {
      final tablet = state(me: 'ospkielno@gmail.com');
      expect(tablet.canEditDocument('ospkielno@gmail.com'), isTrue);
      expect(tablet.canEditDocument('wojtek@gmail.com'), isFalse);
    });
  });

  group('SyncService — wspólne konto założyciela na serwerze', () {
    late Directory root;
    late ServerPhones phones;

    setUpAll(DatabaseService.registerAdapters);

    setUp(() async {
      root = await Directory.systemTemp.createTemp('osp_shared_account');
      phones = ServerPhones(root);
    });

    tearDown(() async {
      await Hive.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    Future<SyncService> phone(String name) => phones.phone(name);

    late String code;

    Future<Map<String, dynamic>> unitDoc() async =>
        (await phones.doc('units/${await phones.unitIdOf(code)}'))!;

    /// Jednostka na koncie ospkielno, Dawid administratorem na swoim koncie.
    Future<void> unitWithAdmin() async {
      final a = await phone('ospkielno');
      code = await phones.create(a, 'OSP Kielno');
      await a.inviteMember('dawid@gmail.com');
      await a.grantAdmin('dawid@gmail.com');
      final d = await phone('dawid');
      expect(await d.joinUnit(code), isTrue);
    }

    test('bez administratora na własnym koncie nie da się włączyć', () async {
      final a = await phone('ospkielno');
      await phones.create(a, 'OSP Kielno');

      await expectLater(
          a.setSharedFounder(true), throwsA(isA<LastPersonalAdminException>()));
      expect(a.state.sharedFounder, isFalse);
      expect(a.state.isCurrentUserAdmin, isTrue);
    });

    test('włączone z tabletu — od razu traci uprawnienia, także po '
        'restarcie bez zasięgu; kolega widzi to po synchronizacji', () async {
      await unitWithAdmin();
      var tablet = await phone('ospkielno');
      await tablet.syncAll();
      await tablet.setSharedFounder(true);

      expect((await unitDoc())['sharedOwner'], isTrue);
      expect(tablet.state.isCurrentUserAdmin, isFalse);
      expect(tablet.state.isSharedAccount, isTrue);

      // Restart aplikacji bez synchronizacji — kopia lokalna.
      tablet = await phone('ospkielno');
      expect(tablet.state.isCurrentUserAdmin, isFalse);
      expect(tablet.state.isSharedAccount, isTrue);

      final d = await phone('dawid');
      await d.syncAll();
      expect(d.state.sharedFounder, isTrue);
      expect(d.state.isCurrentUserAdmin, isTrue);
      expect(d.state.isSharedAccount, isFalse);
    });

    test('wyłączyć może administrator na własnym koncie — tablet wraca do '
        'uprawnień po synchronizacji', () async {
      await unitWithAdmin();
      final t = await phone('ospkielno');
      await t.syncAll();
      await t.setSharedFounder(true);

      final d = await phone('dawid');
      await d.syncAll();
      await d.setSharedFounder(false);
      expect((await unitDoc())['sharedOwner'], isFalse);

      final tablet = await phone('ospkielno');
      await tablet.syncAll();
      expect(tablet.state.isCurrentUserAdmin, isTrue);
      expect(tablet.state.isSharedAccount, isFalse);
    });

    test('ostatniemu administratorowi na własnym koncie nie da się odebrać '
        'uprawnień ani dostępu', () async {
      await unitWithAdmin();
      final d = await phone('dawid');
      await d.syncAll();
      await d.setSharedFounder(true);

      await expectLater(d.revokeAdmin('dawid@gmail.com'),
          throwsA(isA<LastPersonalAdminException>()));
      await expectLater(
        d.revokeMember(
            const UnitMember(email: 'dawid@gmail.com', uid: 'dawid')),
        throwsA(isA<LastPersonalAdminException>()),
      );
      expect(d.state.adminEmails, ['dawid@gmail.com']);

      // Z drugim administratorem pierwszy może oddać uprawnienia.
      await d.inviteMember('prezes@gmail.com');
      await d.grantAdmin('prezes@gmail.com');
      await d.revokeAdmin('dawid@gmail.com');
      expect(d.state.adminEmails, ['prezes@gmail.com']);
    });

    test('nieznana wartość na serwerze to zwykły założyciel z uprawnieniami',
        () async {
      await unitWithAdmin();
      await phones.fs
          .doc('units/${await phones.unitIdOf(code)}')
          .update({'sharedOwner': 'tak'});

      final tablet = await phone('ospkielno');
      await tablet.syncAll();
      expect(tablet.state.sharedFounder, isFalse);
      expect(tablet.state.isCurrentUserAdmin, isTrue);
    });
  });

  group('„Kto wpisuje?" w zapisie wpisu', () {
    Report report({String? enteredById}) => Report(
          id: 'r1',
          reportNumber: '0017/2026',
          year: 2026,
          date: DateTime(2026, 11, 12),
          departureTime: DateTime(2026, 11, 12, 11, 20),
          addressLocality: 'Tuchom',
          threatCategory: 'Fałszywy Alarm',
          createdAt: DateTime(2026, 11, 12),
          updatedAt: DateTime(2026, 11, 12),
          createdBy: 'ospkielno@gmail.com',
          enteredById: enteredById,
        );

    PropertyHandover handover({String? enteredById}) => PropertyHandover(
          id: 'h1',
          eventDate: DateTime(2026, 11, 12),
          eventTime: DateTime(2026, 11, 12, 12, 30),
          signDate: DateTime(2026, 11, 12),
          createdAt: DateTime(2026, 11, 12),
          updatedAt: DateTime(2026, 11, 12),
          createdBy: 'ospkielno@gmail.com',
          enteredById: enteredById,
        );

    test('wyjazd i przekazanie z tabletu niosą ratownika na serwer', () {
      final r = SyncJson.reportFromJson(
          SyncJson.reportToJson(report(enteredById: 'ff2')));
      final h = SyncJson.handoverFromJson(
          SyncJson.handoverToJson(handover(enteredById: 'ff2')));
      expect(r.enteredById, 'ff2');
      expect(h.enteredById, 'ff2');
    });

    test('wpisy z prywatnych kont — plik bez nowego pola, jak dotąd', () {
      // Inaczej każdy stary wpis wyglądałby na zmieniony i jechał na serwer.
      expect(SyncJson.reportToJson(report()).containsKey('enteredById'),
          isFalse);
      expect(SyncJson.handoverToJson(handover()).containsKey('enteredById'),
          isFalse);
    });

    test('pusta albo zła wartość w pliku to brak ratownika', () {
      final json = SyncJson.reportToJson(report())..['enteredById'] = 7;
      expect(SyncJson.reportFromJson(json).enteredById, isNull);
      json['enteredById'] = '';
      expect(SyncJson.reportFromJson(json).enteredById, isNull);
    });
  });
}
