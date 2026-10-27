import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_json.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/fake_drive.dart';
import 'helpers/phone_db.dart';

/// Listy ratowników i pojazdów, jednostki na koncie i to, co synchronizacja
/// mówi po skończeniu.
///
/// Pytanie z testów 1.7.3: „kolega po dołączeniu powinien widzieć te same
/// wozy i ratowników co ja, a bez uprawnień administratora nie powinien móc
/// ich zmieniać". Z ekranu nie mógł — ale jego telefon wysyłał na Dysk
/// własną kopię list, razem z wpisami sprzed dołączenia.
void main() {
  late Directory root;
  late FakeDrive drive;
  final db = DatabaseService();

  setUpAll(() {
    DatabaseService.registerAdapters();
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_unit_lists');
    drive = FakeDrive();
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Przełącza „telefon" (własna baza, wspólny Dysk) zalogowany kontem
  /// `<name>@gmail.com`.
  Future<SyncService> phone(String name) async {
    await openPhoneDb(root, name);
    drive.account = '$name@gmail.com';
    final sync = SyncService(db, FakeAuth('$name@gmail.com'), drive);
    await sync.restoreState();
    return sync;
  }

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

  /// Nazwiska i nazwy na listach jednostki — tak, jak leżą na Dysku.
  List<String> onDrive(String fileName) {
    final file = drive.files.values.firstWhere((f) => f.name == fileName);
    final data =
        (jsonDecode(file.content!) as Map<String, dynamic>)['data'] as List;
    return [
      for (final e in data.cast<Map<String, dynamic>>())
        if (!SyncJson.isTombstone(e)) (e['lastName'] ?? e['name']) as String,
    ]..sort();
  }

  /// A (ospkielno) zakłada jednostkę z jednym ratownikiem i jednym wozem.
  Future<String> unitWithLists() async {
    final a = await phone('ospkielno');
    await db.addFirefighter(ff('f1', 'Kowalski'));
    await db.addVehicle(vehicle('v1', 'GBA 2,5/16'));
    return a.createUnit('OSP Kielno');
  }

  group('dołączenie do jednostki', () {
    test('kolega widzi listy jednostki, a jego wpisy sprzed dołączenia '
        'znikają z telefonu i nie trafiają na Dysk', () async {
      final code = await unitWithLists();

      final b = await phone('wojtek');
      // Testy w trybie offline, zanim dostał zaproszenie.
      await db.addFirefighter(ff('x1', 'Testowy'));
      await db.addVehicle(vehicle('x2', 'Ffgt'));
      await db.addReport(report('r-b'));

      final unit = (await b.lookupUnit(code) as UnitFound).unit;
      final localOnly = await b.localOnlyListEntries(unit.folderId);
      expect(localOnly.firefighters, ['Testowy Jan']);
      expect(localOnly.vehicles, ['Ffgt']);

      await b.joinFoundUnit(unit, code);
      expect(db.getAllFirefighters().map((f) => f.id), ['f1']);
      expect(db.getAllVehicles().map((v) => v.id), ['v1']);
      expect(db.tombstonesOf(SyncKind.firefighter), isEmpty,
          reason: 'jednostka tych wpisów nie miała — nie ma czego usuwać');

      await b.syncAll();
      expect(b.state.status, SyncStatus.idle);
      expect(onDrive('firefighters.json'), ['Kowalski']);
      expect(onDrive('vehicles.json'), ['GBA 2,5/16']);
      expect(drive.jsonIn('2026').any((j) => j['id'] == 'r-b'), isTrue,
          reason: 'wyjazdy z telefonu nadal trafiają do jednostki');
    });

    test('uszkodzona lista na Dysku nie czyści listy z telefonu', () async {
      final code = await unitWithLists();
      drive.files.values
          .firstWhere((f) => f.name == 'firefighters.json')
          .content = '{to nie jest json';

      final b = await phone('wojtek');
      await db.addFirefighter(ff('x1', 'Testowy'));
      final unit = (await b.lookupUnit(code) as UnitFound).unit;
      expect((await b.localOnlyListEntries(unit.folderId)).firefighters,
          isEmpty, reason: 'nie ostrzegamy o czymś, czego nie zrobimy');

      await b.joinFoundUnit(unit, code);
      expect(db.getFirefighter('x1'), isNotNull);
      expect(db.getAllVehicles().map((v) => v.id), ['v1'],
          reason: 'czytelna lista pojazdów zastępuje lokalną jak zwykle');
    });

    test('ponowne dołączenie do tej samej jednostki niczego nie usuwa',
        () async {
      final code = await unitWithLists();
      final a = await phone('ospkielno');
      await a.syncAll();

      final unit = (await a.lookupUnit(code) as UnitFound).unit;
      expect((await a.localOnlyListEntries(unit.folderId)).isEmpty, isTrue);
      await a.joinFoundUnit(unit, code);
      expect(db.getAllFirefighters().map((f) => f.id), ['f1']);
    });
  });

  group('listy prowadzi administrator', () {
    test('telefon bez uprawnień nie wysyła swojej kopii list', () async {
      final code = await unitWithLists();
      final b = await phone('wojtek');
      expect(await b.joinUnit(code), isTrue);
      expect(b.state.isCurrentUserAdmin, isFalse);

      // Z ekranu się nie da — ale gdyby wpis jakoś powstał (np. stara
      // wersja aplikacji), nie może trafić do całej jednostki.
      await db.addFirefighter(ff('x1', 'Nowak'));
      await b.syncAll();

      expect(b.state.status, SyncStatus.idle);
      expect(onDrive('firefighters.json'), ['Kowalski']);
    });

    test('administrator nadany przez założyciela wysyła zmiany list',
        () async {
      final code = await unitWithLists();
      var a = await phone('ospkielno');
      await a.grantAdmin('wojtek@gmail.com');

      final b = await phone('wojtek');
      expect(await b.joinUnit(code), isTrue);
      expect(b.state.isCurrentUserAdmin, isTrue);
      await db.addFirefighter(ff('f2', 'Nowak'));
      await b.syncAll();

      expect(onDrive('firefighters.json'), ['Kowalski', 'Nowak']);
      a = await phone('ospkielno');
      await a.syncAll();
      expect(db.getFirefighter('f2'), isNotNull, reason: 'dotarło do A');
    });
  });

  group('jednostki na koncie', () {
    test('widać jednostki założone na tym koncie, z kodem, najnowsze '
        'pierwsze — a nie cudze', () async {
      // Jak w aplikacji: nazwa jednostki jest zapisana, zanim powstanie
      // folder — synchronizacja bierze ją z ustawień telefonu.
      Future<String> create(SyncService sync, String name) async {
        await db.saveConfig(db.getConfig().copyWith(unitFullName: name));
        return sync.createUnit(name);
      }

      var a = await phone('ospkielno');
      final first = await create(a, 'OSP Kielno');
      a = await phone('ospkielno');
      final second = await create(a, 'OSP Kielno');
      await create(await phone('obcy'), 'OSP Gdzieś');

      a = await phone('ospkielno');
      final units = await a.ownUnits();

      expect(units.map((u) => u.inviteCode), unorderedEquals([first, second]));
      expect(units.every((u) => u.unitName == 'OSP Kielno'), isTrue);
      expect(
        units.first.createdAt!.isAfter(units.last.createdAt!) ||
            units.first.createdAt == units.last.createdAt,
        isTrue,
      );
    });

    test('nowe konto nie ma jednostek', () async {
      final a = await phone('nowy');
      expect(await a.ownUnits(), isEmpty);
    });
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
      drive.failWrites = http.ClientException(
        'Software caused connection abort',
        Uri.parse('https://www.googleapis.com/upload/drive/v3/files'),
      );

      final before = DateTime.now();
      await a.syncAll();

      expect(a.state.status, SyncStatus.error);
      expect(a.state.errorMessage,
          contains('Połączenie z internetem zostało przerwane'));
      expect(a.state.errorTime, isNotNull);
      expect(a.state.errorTime!.isBefore(before), isFalse);
      expect(db.getReport('r1'), isNotNull);

      drive.failWrites = null;
      await a.syncAll();
      expect(a.state.status, SyncStatus.idle);
      expect(a.state.errorMessage, isNull);
      expect(a.state.errorTime, isNull, reason: 'stary błąd znika');
    });
  });
}
