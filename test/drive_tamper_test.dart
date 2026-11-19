import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_json.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/fake_drive.dart';
import 'helpers/phone_db.dart';

/// Zmiany na Dysku z pominięciem aplikacji (fix/067).
///
/// Każdy członek jednostki może na drive.google.com zmienić każdy plik
/// w folderze jednostki — ról z aplikacji Dysk nie zna. Telefon sprawdza
/// więc, kto według Google zmienił plik ostatni, i przyjmuje tylko to, na
/// co aplikacja by mu pozwoliła. Pytanie Dawida z 19.11.2026: czy członek
/// jednostki może podmienić dane albo przejąć jednostkę.
///
/// Konta: „a" zakłada jednostkę (właściciel folderu), „b" i „c" to zwykli
/// członkowie, „m" — nieuczciwy członek, który zmienia pliki ręcznie.
void main() {
  late Directory root;
  late FakeDrive drive;
  final db = DatabaseService();
  const m = 'm@gmail.com';

  setUpAll(DatabaseService.registerAdapters);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_tamper');
    drive = FakeDrive();
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Telefon konta [name]; zapisy na Dysku idą od tego konta.
  Future<SyncService> phone(String name) async {
    await openPhoneDb(root, name);
    drive.account = '$name@gmail.com';
    final sync = SyncService(db, FakeAuth('$name@gmail.com'), drive);
    await sync.restoreState();
    return sync;
  }

  Report report(String id, {required String by}) => Report(
        id: id,
        reportNumber: '0001/2026',
        year: 2026,
        date: DateTime(2026, 8, 10),
        departureTime: DateTime(2026, 8, 10, 14, 30),
        addressLocality: 'Kielno',
        addressStreet: '',
        addressDescription: '',
        threatCategory: 'Pożar',
        createdBy: by,
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      );

  /// Ręczna zmiana pliku z nowszym stemplem — tak, żeby telefon uznał ją
  /// za świeższą od swojej wersji.
  void tamper(String fileId, void Function(Map<String, dynamic> j) change,
      {String by = m}) {
    final json = drive.jsonOf(fileId);
    change(json);
    json['updatedAt'] = DateTime(2026, 9, 1).toIso8601String();
    drive.editByHand(fileId, json, by: by);
  }

  /// Jednostka „a" z członkiem „b", który ma już wszystko u siebie.
  Future<String> unitWithMember({List<Report> reports = const []}) async {
    final a = await phone('a');
    for (final r in reports) {
      await db.addReport(r);
    }
    final code = await a.createUnit('OSP Test');
    final b = await phone('b');
    expect(await b.joinUnit(code), isTrue);
    await b.syncAll();
    return code;
  }

  group('założyciel i administratorzy', () {
    test('założyciel to właściciel folderu, a nie „createdBy" z pliku',
        () async {
      await unitWithMember();
      final config = drive.fileIdOf('config', 'unit_config.json');
      tamper(config, (j) => j['createdBy'] = m);

      final b = await phone('b');
      await b.syncAll();
      expect(b.state.founderEmail, 'a@gmail.com');
      expect(b.state.isAdmin(m), isFalse);
      expect(drive.jsonOf(config)['createdBy'], 'a@gmail.com',
          reason: 'telefon wysłał poprawne dane jednostki z powrotem');
    });

    test('członek nie dopisze się do administratorów przez Dysk; telefon '
        'administratora przywraca listę', () async {
      final code = await unitWithMember();
      var a = await phone('a');
      await a.grantAdmin('b@gmail.com');
      final c = await phone('c');
      expect(await c.joinUnit(code), isTrue);
      await c.syncAll();
      expect(c.state.adminEmails, ['b@gmail.com']);

      final admins = drive.fileIdOf('config', 'admins.json');
      tamper(admins, (j) => j['admins'] = ['b@gmail.com', m]);

      var cPhone = await phone('c');
      await cPhone.syncAll();
      expect(cPhone.state.adminEmails, ['b@gmail.com']);
      expect(cPhone.state.isAdmin(m), isFalse);
      expect(cPhone.state.rejectedChanges.single.what, 'Lista administratorów');
      expect(cPhone.state.rejectedChanges.single.by, m);
      expect(cPhone.state.rejectedChanges.single.restored, isFalse);

      a = await phone('a');
      await a.syncAll();
      expect(drive.jsonOf(admins)['admins'], ['b@gmail.com'],
          reason: 'założyciel zapisał listę od nowa');
      expect(drive.files[admins]!.modifiedBy, 'a@gmail.com');
      expect(a.state.rejectedChanges.single.restored, isTrue);

      cPhone = await phone('c');
      expect(cPhone.state.rejectedChanges, hasLength(1),
          reason: 'ostrzeżenie zostaje po ponownym uruchomieniu');
      await cPhone.syncAll();
      expect(cPhone.state.adminEmails, ['b@gmail.com']);
      expect(cPhone.state.rejectedChanges, hasLength(1),
          reason: 'przywrócona lista od założyciela — bez nowego ostrzeżenia');

      await cPhone.clearRejectedChanges();
      expect(cPhone.state.rejectedChanges, isEmpty);
      expect(db.rejectedChanges, isEmpty);
    });

    test('zmianę listy przez administratora przyjmują wszyscy', () async {
      final code = await unitWithMember();
      final a = await phone('a');
      await a.grantAdmin('b@gmail.com');
      final c = await phone('c');
      expect(await c.joinUnit(code), isTrue);

      final b = await phone('b');
      await b.syncAll();
      await b.grantAdmin('c@gmail.com');

      final cAgain = await phone('c');
      await cAgain.syncAll();
      expect(cAgain.state.adminEmails, ['b@gmail.com', 'c@gmail.com']);
      expect(cAgain.state.isCurrentUserAdmin, isTrue);
      expect(cAgain.state.rejectedChanges, isEmpty);
    });

    test('lista ratowników zmieniona przez członka nie trafia na telefony, '
        'a administrator ją przywraca', () async {
      await unitWithMember();
      var a = await phone('a');
      await db.addFirefighter(
          Firefighter(id: 'f1', firstName: 'Jan', lastName: 'Kowalski', rank: ''));
      await a.syncAll();
      var b = await phone('b');
      await b.syncAll();
      expect(db.getAllFirefighters().map((f) => f.id), ['f1']);

      final list = drive.fileIdOf('config', 'firefighters.json');
      final json = drive.jsonOf(list);
      final fake = Map<String, dynamic>.from(
          (json['data'] as List).first as Map<String, dynamic>)
        ..['id'] = 'f2'
        ..['lastName'] = 'Obcy'
        ..['updatedAt'] = DateTime(2026, 9, 1).toIso8601String();
      json['data'] = [...json['data'] as List, fake];
      drive.editByHand(list, json, by: m);

      b = await phone('b');
      await b.syncAll();
      expect(db.getAllFirefighters().map((f) => f.id), ['f1']);
      expect(b.state.rejectedChanges.single.what, 'Lista ratowników');

      a = await phone('a');
      await a.syncAll();
      final ids = [
        for (final e in drive.jsonOf(list)['data'] as List)
          if (!SyncJson.isTombstone(e as Map<String, dynamic>)) e['id'],
      ];
      expect(ids, ['f1'], reason: 'administrator wysłał swoją listę');
      expect(drive.files[list]!.modifiedBy, 'a@gmail.com');
    });
  });

  group('wpisy', () {
    test('cudzy wyjazd zmieniony na Dysku zostaje na telefonie bez zmian; '
        'zwykły członek go nie nadpisuje, administrator przywraca', () async {
      await unitWithMember(reports: [report('r1', by: 'a@gmail.com')]);
      final file = drive.fileOfDoc('r1');
      tamper(file, (j) => j['addressLocality'] = 'Podmienione');

      var b = await phone('b');
      drive.resetCounters();
      await b.syncAll();
      expect(db.getReport('r1')!.addressLocality, 'Kielno');
      expect(b.state.rejectedChanges.single.what, 'Wyjazd 0001/2026');
      expect(b.state.rejectedChanges.single.by, m);
      expect(drive.jsonOf(file)['addressLocality'], 'Podmienione',
          reason: 'zwykły członek nie odsyła swojej wersji');

      // Druga synchronizacja też niczego nie odsyła — bez przepychanek.
      drive.resetCounters();
      b = await phone('b');
      await b.syncAll();
      expect(drive.writes, 0);

      final a = await phone('a');
      await a.syncAll();
      expect(drive.jsonOf(file)['addressLocality'], 'Kielno');
      expect(drive.files[file]!.modifiedBy, 'a@gmail.com');

      b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r1')!.addressLocality, 'Kielno');
      expect(drive.jsonOf(file)['addressLocality'], 'Kielno');
    });

    test('usunięcie cudzego wyjazdu przez Dysk (znacznik) jest pomijane',
        () async {
      await unitWithMember(reports: [report('r1', by: 'a@gmail.com')]);
      final file = drive.fileOfDoc('r1');
      drive.editByHand(
          file,
          {
            'id': 'r1',
            'deleted': true,
            'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
          },
          by: m);
      expect(SyncJson.isTombstone(drive.jsonOf(file)), isTrue,
          reason: 'znacznik usunięcia w formacie synchronizacji');

      final b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r1'), isNotNull);
      expect(b.state.rejectedChanges.single.what, 'Wyjazd 0001/2026');
    });

    test('autor zmienia swój wpis — inni przyjmują', () async {
      await unitWithMember(reports: [report('r1', by: 'a@gmail.com')]);
      final a = await phone('a');
      await db.updateReport(db.getReport('r1')!
        ..addressLocality = 'Szemud'
        ..updatedAt = DateTime(2026, 9, 2));
      await a.syncAll();

      final b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r1')!.addressLocality, 'Szemud');
      expect(b.state.rejectedChanges, isEmpty);
    });

    test('wpis bez autora (tryb offline) może zmienić każdy — jak w aplikacji',
        () async {
      await unitWithMember(reports: [report('r1', by: '')]);
      tamper(drive.fileOfDoc('r1'), (j) => j['addressLocality'] = 'Szemud');
      final b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r1')!.addressLocality, 'Szemud');
    });

    test('przejazd z raportu: godziny i trasę uzgadnia każdy telefon, '
        'licznik zmienia tylko autor', () async {
      await unitWithMember();
      final a = await phone('a');
      await db.addTrip(VehicleTrip(
        id: 't1',
        vehicleId: 'v1',
        date: DateTime(2026, 8, 10),
        departureTime: DateTime(2026, 8, 10, 14, 30),
        odometerStart: 1000,
        odometerEnd: 1020,
        reportId: 'r1',
        createdBy: 'a@gmail.com',
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      ));
      await a.syncAll();
      var b = await phone('b');
      await b.syncAll();
      final file = drive.fileOfDoc('t1');

      tamper(file, (j) => j['returnTime'] =
          DateTime(2026, 8, 10, 16, 0).toIso8601String(), by: 'c@gmail.com');
      b = await phone('b');
      await b.syncAll();
      expect(db.getTrip('t1')!.returnTime, DateTime(2026, 8, 10, 16, 0),
          reason: 'pole z raportu — uzgadnianie na innym telefonie');

      final json = drive.jsonOf(file)
        ..['odometerEnd'] = 1500
        ..['updatedAt'] = DateTime(2026, 9, 5).toIso8601String();
      drive.editByHand(file, json, by: m);
      b = await phone('b');
      await b.syncAll();
      expect(db.getTrip('t1')!.odometerEnd, 1020);
      expect(b.state.rejectedChanges.single.what, 'Przejazd z 10.08.2026');
    });

    test('nowy wpis od członka — przyjmowany (dodawać może każdy)', () async {
      await unitWithMember();
      final year = await drive.findOrCreateYearFolder(
          drive.folderIdByName('reports')!, 2026);
      drive.account = 'c@gmail.com';
      await drive.createJsonFile(year, 'r9.json',
          SyncJson.reportToJson(report('r9', by: 'c@gmail.com')));

      final b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r9'), isNotNull);
      expect(b.state.rejectedChanges, isEmpty);
    });

    test('Dysk bez autora zmiany — zmiana przyjęta jak dawniej', () async {
      await unitWithMember(reports: [report('r1', by: 'a@gmail.com')]);
      final file = drive.fileOfDoc('r1');
      final json = drive.jsonOf(file)
        ..['addressLocality'] = 'Szemud'
        ..['updatedAt'] = DateTime(2026, 9, 1).toIso8601String();
      drive.editByHand(file, json, by: m);
      drive.files[file]!.modifiedBy = null;

      final b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r1')!.addressLocality, 'Szemud');
    });
  });
}
