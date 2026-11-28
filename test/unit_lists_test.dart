import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_json.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/server_phones.dart';

/// Listy ratowników, pojazdów i sprzętu jednostki i to, co synchronizacja
/// mówi po skończeniu.
///
/// Pytanie z testów 1.7.3: „kolega po dołączeniu powinien widzieć te same
/// wozy i ratowników co ja, a bez uprawnień administratora nie powinien móc
/// ich zmieniać".
void main() {
  late Directory root;
  late ServerPhones phones;
  final db = DatabaseService();

  setUpAll(DatabaseService.registerAdapters);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_unit_lists');
    phones = ServerPhones(root);
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<SyncService> phone(String name) => phones.phone(name);

  Firefighter ff(String id, String lastName) => Firefighter(
        id: id,
        firstName: 'Jan',
        lastName: lastName,
        rank: '',
        updatedAt: DateTime(2026, 8, 1),
      );

  Vehicle vehicle(String id, String name) =>
      Vehicle(id: id, name: name, seats: 6, updatedAt: DateTime(2026, 8, 1));

  Report report(String id) => Report(
        id: id,
        reportNumber: '0001/2026',
        year: 2026,
        date: DateTime(2026, 8, 10),
        departureTime: DateTime(2026, 8, 10, 14, 30),
        addressLocality: 'Kielno',
        addressStreet: '',
        addressDescription: '',
        threatCategory: 'Pożar',
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      );

  /// Nazwiska i nazwy na liście jednostki — tak, jak są na serwerze.
  Future<List<String>> onServer(String code, String collection) async => [
        for (final e in await phones.live(code, collection))
          (e['lastName'] ?? e['name']) as String,
      ]..sort();

  /// A (ospkielno) zakłada jednostkę z jednym ratownikiem i jednym wozem
  /// i zaprasza Wojtka.
  Future<String> unitWithLists() async {
    final a = await phone('ospkielno');
    await db.addFirefighter(ff('f1', 'Kowalski'));
    await db.addVehicle(vehicle('v1', 'GBA 2,5/16'));
    final code = await phones.create(a, 'OSP Kielno');
    await a.inviteMember('wojtek@gmail.com');
    return code;
  }

  group('dołączenie do jednostki', () {
    test('kolega widzi listy jednostki, a jego wpisy sprzed dołączenia '
        'znikają z telefonu i nie trafiają na serwer', () async {
      final code = await unitWithLists();

      final b = await phone('wojtek');
      // Testy w trybie offline, zanim dostał zaproszenie.
      await db.addFirefighter(ff('x1', 'Testowy'));
      await db.addVehicle(vehicle('x2', 'Ffgt'));
      await db.addReport(report('r-b'));

      expect(await b.joinUnit(code), isTrue);
      expect(db.getAllFirefighters().map((f) => f.id), ['f1']);
      expect(db.getAllVehicles().map((v) => v.id), ['v1']);
      expect(db.tombstonesOf(SyncKind.firefighter), isEmpty,
          reason: 'jednostka tych wpisów nie miała — nie ma czego usuwać');

      await b.syncAll();
      expect(b.state.status, SyncStatus.idle);
      expect(await onServer(code, 'firefighters'), ['Kowalski']);
      expect(await onServer(code, 'vehicles'), ['GBA 2,5/16']);
      expect((await phones.live(code, 'reports')).map((r) => r['id']),
          contains('r-b'),
          reason: 'wyjazdy z telefonu nadal trafiają do jednostki');
    });

    test('uszkodzony wpis listy na serwerze jest pomijany, reszta listy '
        'dociera', () async {
      final code = await unitWithLists();
      await phones.fs
          .doc('units/${await phones.unitIdOf(code)}/firefighters/zepsuty')
          .set({
        'data': {'id': 'zepsuty', 'lastName': 42},
        'deleted': false,
        'serverAt': FieldValue.serverTimestamp(),
        'by': 'ospkielno@gmail.com',
      });

      final b = await phone('wojtek');
      expect(await b.joinUnit(code), isTrue);
      expect(db.getAllFirefighters().map((f) => f.id), ['f1']);
      await b.syncAll();
      expect(b.state.status, SyncStatus.idle);
      expect(b.state.skippedFiles, 1,
          reason: 'pominięty i policzony, ale nie zatrzymuje synchronizacji');
    });

    test('ponowne dołączenie do tej samej jednostki niczego nie usuwa',
        () async {
      final code = await unitWithLists();
      final a = await phone('ospkielno');
      await a.syncAll();

      expect(await a.joinUnit(code), isTrue);
      expect(db.getAllFirefighters().map((f) => f.id), ['f1']);
    });
  });

  test('administrator nadany przez założyciela wysyła zmiany list',
      () async {
    final code = await unitWithLists();
    var a = await phone('ospkielno');
    await a.listMembers();
    await a.grantAdmin('wojtek@gmail.com');

    final b = await phone('wojtek');
    expect(await b.joinUnit(code), isTrue);
    expect(b.state.isCurrentUserAdmin, isTrue);
    await db.addFirefighter(ff('f2', 'Nowak'));
    await b.syncAll();

    expect(await onServer(code, 'firefighters'), ['Kowalski', 'Nowak']);
    a = await phone('ospkielno');
    await a.syncAll();
    expect(db.getFirefighter('f2'), isNotNull, reason: 'dotarło do A');
  });

  group('wynik synchronizacji', () {
    test('liczy wysłane i pobrane zmiany, a bez zmian zero', () async {
      final code = await unitWithLists();
      var a = await phone('ospkielno');
      await a.syncAll();
      await db.addReport(report('r1'));
      await a.syncAll();
      expect(a.state.lastSyncSent, 1);
      expect(a.state.lastSyncReceived, 0);

      final b = await phone('wojtek');
      expect(await b.joinUnit(code), isTrue);
      await db.addReport(report('r2')..reportNumber = '0002/2026');
      await b.syncAll();
      expect(b.state.lastSyncSent, 1);

      a = await phone('ospkielno');
      await a.syncAll();
      expect(a.state.lastSyncReceived, 1, reason: 'raport od kolegi');
      await a.syncAll();
      expect(a.state.lastSyncSent, 0);
      expect(a.state.lastSyncReceived, 0);
    });

    test('zerwane połączenie: komunikat po polsku i godzina błędu, a dane '
        'zostają na telefonie', () async {
      await unitWithLists();
      final a = await phone('ospkielno');
      await db.addReport(report('r1'));
      phones.auth.failRefresh =
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

      final before = DateTime.now();
      await a.syncAll();

      expect(a.state.status, SyncStatus.error);
      expect(a.state.errorMessage,
          contains('Serwer jednostki chwilowo nie odpowiada'));
      expect(a.state.errorTime, isNotNull);
      expect(a.state.errorTime!.isBefore(before), isFalse);
      expect(db.getReport('r1'), isNotNull);

      phones.auth.failRefresh = null;
      await a.syncAll();
      expect(a.state.status, SyncStatus.idle);
      expect(a.state.errorMessage, isNull);
      expect(a.state.errorTime, isNull, reason: 'stary błąd znika');
    });
  });
}
