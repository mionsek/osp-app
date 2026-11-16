import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_json.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/fake_drive.dart';
import 'helpers/phone_db.dart';

/// Synchronizacja „dwa telefony, jeden Dysk".
///
/// Każdy telefon ma własny katalog bazy Hive, a Dysk jest wspólny, w pamięci.
/// Przełączenie telefonu zamyka bazę jednego i otwiera bazę drugiego — tak,
/// jakby kolega uruchomił aplikację u siebie. Tego scenariusza nie dało się
/// dotąd sprawdzić bez dwóch telefonów z różnymi kontami Google, a właśnie
/// w nim siedziały błędy: usunięte wpisy wracały, a starsza kopia listy
/// nadpisywała nowszą.
void main() {
  late Directory root;
  late FakeDrive drive;
  final db = DatabaseService();

  setUpAll(() {
    DatabaseService.registerAdapters();
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_two_phones');
    drive = FakeDrive();
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Przełącza „telefon" i zwraca jego usługę synchronizacji.
  Future<SyncService> phone(String name) async {
    await openPhoneDb(root, name);
    final sync = SyncService(db, FakeAuth('$name@osp.pl'), drive);
    await sync.restoreState();
    return sync;
  }

  Report report(String id, {DateTime? updatedAt}) => Report(
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
        updatedAt: updatedAt ?? DateTime(2026, 8, 10),
      );

  Firefighter ff(String id, String lastName, {DateTime? at, DateTime? exam}) =>
      Firefighter(
        id: id,
        firstName: 'Jan',
        lastName: lastName,
        rank: '',
        medicalExamExpiry: exam,
        updatedAt: at,
      );

  /// Telefon A zakłada jednostkę, telefon B do niej dołącza.
  Future<void> twoPhones({void Function()? seedA}) async {
    final a = await phone('a');
    seedA?.call();
    final code = await a.createUnit('OSP Test');
    final b = await phone('b');
    expect(await b.joinUnit(code), isTrue);
  }

  group('usunięcie bez danych osobowych (fix/062)', () {
    const slimKeys = {'id', 'updatedAt', 'deleted', 'deletedAt'};

    FakeFile fileOf(String id) => drive.files.values.firstWhere((f) {
          if (f.isFolder || f.content == null) return false;
          final json = jsonDecode(f.content!);
          return json is Map && json['id'] == id;
        });

    Set<String> keysOnDrive(String id) =>
        (jsonDecode(fileOf(id).content!) as Map<String, dynamic>).keys.toSet();

    bool driveMentions(String text) =>
        drive.files.values.any((f) => f.content?.contains(text) ?? false);

    test('usunięty raport i ratownik: na Dysku zostaje sam znacznik, bez '
        'nazwiska i adresu', () async {
      await twoPhones();
      final a = await phone('a');
      await db.addReport(report('r1'));
      await db.addFirefighter(ff('f1', 'Kowalski', at: DateTime(2026, 8, 1)));
      await a.syncAll();
      expect(driveMentions('Kowalski'), isTrue);
      expect(driveMentions('Kielno'), isTrue);

      await db.deleteReport('r1');
      await db.deleteFirefighter('f1');
      await a.syncAll();

      expect(keysOnDrive('r1'), slimKeys);
      expect(driveMentions('Kowalski'), isFalse,
          reason: 'nazwisko zniknęło z listy ratowników na Dysku');
      expect(driveMentions('Kielno'), isFalse,
          reason: 'adres zniknął z pliku wyjazdu');

      final b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r1'), isNull, reason: 'usunięcie dalej dociera');
      expect(db.getFirefighter('f1'), isNull);
    });

    test('stary pełny znacznik w telefonie: po aktualizacji odchudzony '
        'i wysłany na Dysk w miejsce pełnego', () async {
      await twoPhones();
      var a = await phone('a');
      await db.addReport(report('r1'));
      await a.syncAll();

      // Tak usuwała wersja sprzed fix/062: pełna treść z dopiskiem `deleted`,
      // w telefonie i na Dysku.
      final deletedAt = DateTime(2026, 9, 1).toIso8601String();
      final full = {
        ...SyncJson.reportToJson(db.getReport('r1')!),
        'updatedAt': deletedAt,
        'deleted': true,
        'deletedAt': deletedAt,
      };
      await db.reportsBox.delete('r1');
      await db.settingsBox.put(
          'syncTombstones', {'${SyncKind.report}:r1': jsonEncode(full)});
      fileOf('r1')
        ..content = jsonEncode(full)
        ..modified = DateTime.utc(2030);

      a = await phone('a'); // start nowej wersji
      expect(db.tombstoneOf(SyncKind.report, 'r1')!.keys.toSet(), slimKeys);
      await a.syncAll();

      expect(keysOnDrive('r1'), slimKeys);
      expect(driveMentions('Kielno'), isFalse);
      expect(db.getReport('r1'), isNull);
    });

    test('pełny znacznik z Dysku (ze starszej wersji): w telefonie bez '
        'treści, a na Dysku zastąpiony odchudzonym', () async {
      await twoPhones();
      final a = await phone('a');
      await db.addReport(report('r1'));
      await a.syncAll();
      final b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r1'), isNotNull);

      final file = fileOf('r1');
      final deletedAt = DateTime(2026, 9, 1).toIso8601String();
      file
        ..content = jsonEncode({
          ...jsonDecode(file.content!) as Map<String, dynamic>,
          'updatedAt': deletedAt,
          'deleted': true,
          'deletedAt': deletedAt,
        })
        ..modified = DateTime.utc(2030);

      await b.syncAll();

      expect(db.getReport('r1'), isNull);
      expect(db.tombstoneOf(SyncKind.report, 'r1')!.keys.toSet(), slimKeys);
      expect(keysOnDrive('r1'), slimKeys);
      expect(driveMentions('Kielno'), isFalse);
    });
  });

  test('usuniety raport nie wraca z Dysku', () async {
    await twoPhones();
    var a = await phone('a');
    await db.addReport(report('r1'));
    await a.syncAll();

    var b = await phone('b');
    await b.syncAll();
    expect(db.getReport('r1'), isNotNull, reason: 'B dostaje raport');
    await db.deleteReport('r1');
    await b.syncAll();

    a = await phone('a');
    await a.syncAll();
    expect(db.getReport('r1'), isNull, reason: 'usunięcie dotarło do A');
    await a.syncAll();
    expect(db.getReport('r1'), isNull, reason: 'i nie wraca przy kolejnej');

    b = await phone('b');
    await b.syncAll();
    expect(db.getReport('r1'), isNull, reason: 'A nie odesłało go do B');
  });

  test('edycja po usunieciu na innym telefonie przywraca rekord', () async {
    await twoPhones();
    var a = await phone('a');
    await db.addReport(report('r1'));
    await a.syncAll();

    var b = await phone('b');
    await b.syncAll();
    await db.deleteReport('r1');
    await b.syncAll();

    // A poprawia raport PO usunięciu na B — nowsza zmiana wygrywa.
    a = await phone('a');
    await db.updateReport(report('r1', updatedAt: DateTime.now()));
    await a.syncAll();
    expect(db.getReport('r1'), isNotNull);

    b = await phone('b');
    await b.syncAll();
    expect(db.getReport('r1'), isNotNull);
  });

  test('usuniety ratownik nie wraca z listy kolegi', () async {
    await twoPhones(seedA: () {});
    var a = await phone('a');
    await db.addFirefighter(ff('f1', 'Kowalski', at: DateTime(2026, 8, 1)));
    await a.syncAll();

    var b = await phone('b');
    await b.syncAll();
    expect(db.getFirefighter('f1'), isNotNull);

    a = await phone('a');
    await db.deleteFirefighter('f1');
    await a.syncAll();

    b = await phone('b');
    await b.syncAll();
    expect(db.getFirefighter('f1'), isNull);
    await b.syncAll();

    a = await phone('a');
    await a.syncAll();
    expect(db.getFirefighter('f1'), isNull, reason: 'B nie odesłał starej kopii');
  });

  test('starsza kopia ratownika nie nadpisuje nowszej', () async {
    await twoPhones();
    var a = await phone('a');
    await db.addFirefighter(ff('f1', 'Kowalski', at: DateTime(2026, 8, 1)));
    await a.syncAll();
    var b = await phone('b');
    await b.syncAll();

    // A wpisuje datę badań później niż B zmienia coś u siebie, ale B
    // synchronizuje dopiero po A.
    a = await phone('a');
    await db.updateFirefighter(ff('f1', 'Kowalski',
        at: DateTime(2026, 8, 20), exam: DateTime(2027, 3, 31)));
    await a.syncAll();

    b = await phone('b');
    await db.updateFirefighter(ff('f1', 'Kowalsky', at: DateTime(2026, 8, 5)));
    await b.syncAll();
    expect(db.getFirefighter('f1')!.medicalExamExpiry, DateTime(2027, 3, 31),
        reason: 'nowsza wersja z A wygrywa ze starszą z B');

    a = await phone('a');
    await a.syncAll();
    expect(db.getFirefighter('f1')!.lastName, 'Kowalski',
        reason: 'B nie nadpisał Dysku starszą kopią');
  });

  test('stempel ratownika i pojazdu przetrwa ponowne uruchomienie', () async {
    // Hive trzyma obiekty w pamięci, więc bez pola w adapterze stempel
    // „działał" aż do zamknięcia bazy — i znikał po restarcie aplikacji.
    await phone('a');
    await db.addFirefighter(ff('f1', 'Kowalski', at: DateTime(2026, 8, 20)));
    await db.addVehicle(Vehicle(
        id: 'v1', name: 'GBA', seats: 6, updatedAt: DateTime(2026, 8, 21)));

    await phone('a'); // zamknięcie i ponowne otwarcie bazy
    expect(db.getFirefighter('f1')!.updatedAt, DateTime(2026, 8, 20));
    expect(db.getVehicle('v1')!.updatedAt, DateTime(2026, 8, 21));
  });

  test('synchronizacja bez zmian niczego nie wysyla ani nie czyta', () async {
    await twoPhones();
    final a = await phone('a');
    await db.addReport(report('r1'));
    await db.addFirefighter(ff('f1', 'Kowalski', at: DateTime(2026, 8, 1)));
    await a.syncAll();
    await a.syncAll();

    drive.resetCounters();
    await a.syncAll();
    expect(drive.writes, 0, reason: 'nic się nie zmieniło');

    // Czytane są tylko małe pliki konfiguracji (dane jednostki, ratownicy,
    // pojazdy, sprzęt, słownik) — dokumenty, których nikt nie zmienił, już
    // nie.
    await db.addReport(report('r2')..reportNumber = '0002/2026');
    await db.addReport(report('r3')..reportNumber = '0003/2026');
    await a.syncAll();
    drive.resetCounters();
    await a.syncAll();
    expect(drive.reads, 5);
  });

  test('zmiana jednego raportu wysyla tylko ten raport', () async {
    await twoPhones();
    final a = await phone('a');
    await db.addReport(report('r1'));
    await db.addReport(report('r2')..reportNumber = '0002/2026');
    await a.syncAll();

    drive.resetCounters();
    await db.updateReport(
        (report('r2', updatedAt: DateTime(2026, 8, 11)))..reportNumber = '0002/2026');
    await a.syncAll();
    expect(drive.writes, 1);
  });

  test('uszkodzony plik nie zatrzymuje synchronizacji', () async {
    await twoPhones();
    var a = await phone('a');
    await db.addReport(report('r1'));
    await a.syncAll();
    drive.putRaw(drive.folderIdByName('handovers')!, 'zepsuty.json', '{nie json');

    final b = await phone('b');
    await b.syncAll();
    expect(b.state.status, SyncStatus.idle);
    expect(b.state.skippedFiles, 1);
    expect(db.getReport('r1'), isNotNull, reason: 'reszta dotarła');
  });

  test('zmiana danych jednostki nie jest nadpisana przed wysłaniem', () async {
    await twoPhones();
    final b = await phone('b');
    await db.saveConfig(db.getConfig().copyWith(unitStreet: 'Oliwska 12'));
    await db.markUnitConfigEdited();
    await b.syncAll();
    expect(db.getConfig().unitStreet, 'Oliwska 12');

    await phone('a').then((a) => a.syncAll());
    expect(db.getConfig().unitStreet, 'Oliwska 12', reason: 'dotarło do A');
  });

  test('nowszy format danych blokuje synchronizacje starej wersji', () async {
    await twoPhones();
    final config = drive.files.values
        .firstWhere((f) => f.name == 'unit_config.json');
    config.content = config.content!.replaceFirst(
        '"syncFormat":${SyncService.syncFormat}', '"syncFormat":99');
    expect(config.content, contains('"syncFormat":99'));

    final a = await phone('a');
    await db.addReport(report('r1'));
    drive.resetCounters();
    await a.syncAll();

    expect(a.state.status, SyncStatus.error);
    expect(a.state.errorMessage, contains('Zaktualizuj'));
    expect(drive.writes, 0, reason: 'stara wersja niczego nie nadpisuje');
  });

  test('przejazd usuniety recznie nie wraca z uzupelniania ewidencji',
      () async {
    await twoPhones();
    var a = await phone('a');
    await db.addReport(report('r1')
      ..crewAssignments = [CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA')]);
    await db.backfillTripsFromReports(stationAddress: 'Kielno');
    await a.syncAll();

    var b = await phone('b');
    await b.syncAll();
    final tripId = db.getAllTrips().single.id;
    await db.deleteTrip(tripId);
    await b.syncAll();

    a = await phone('a');
    await a.syncAll();
    expect(db.getTrip(tripId), isNull);
    await db.backfillTripsFromReports(stationAddress: 'Kielno');
    expect(db.getTrip(tripId), isNull, reason: 'znacznik blokuje odtworzenie');
  });

  test('ten sam rekord w dwoch plikach: bierzemy nowszy', () async {
    await twoPhones();
    final a = await phone('a');
    await db.addReport(report('r1', updatedAt: DateTime(2026, 8, 10)));
    await a.syncAll();

    // Stara wersja aplikacji zostawiła obok drugi plik z nowszą treścią.
    final newer = SyncJson.reportToJson(
        report('r1', updatedAt: DateTime(2026, 8, 15))..addressStreet = 'Nowa 1');
    final yearFolder = drive.folderIdByName('2026')!;
    drive.putRaw(yearFolder, 'duplikat.json', jsonEncode(newer));

    final b = await phone('b');
    await b.syncAll();
    expect(db.getReport('r1')!.addressStreet, 'Nowa 1');
  });
}

