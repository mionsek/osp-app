import 'dart:convert';
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

/// Scalanie „dwa telefony, jeden serwer": usunięcia, stemple, starsze kopie.
///
/// Każdy telefon ma własną bazę Hive, serwer jest wspólny, w pamięci. Właśnie
/// w tych scenariuszach siedziały dawniej błędy: usunięte wpisy wracały,
/// a starsza kopia listy nadpisywała nowszą. Przeniesione z testów na Dysku
/// (chore/082) — scalanie zostało, zmienił się tylko transport.
void main() {
  late Directory root;
  late ServerPhones phones;
  final db = DatabaseService();
  late String code;

  setUpAll(DatabaseService.registerAdapters);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_two_phones');
    phones = ServerPhones(root);
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<SyncService> phone(String name) => phones.phone(name);

  /// Telefon A zakłada jednostkę, telefon B do niej dołącza.
  Future<void> twoPhones() async => code = await phones.unitWith('a', 'b');

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

  Future<String> unitPath() async => 'units/${await phones.unitIdOf(code)}';

  /// Zmiana zrobiona na serwerze z pominięciem telefonów — z czasem serwera,
  /// żeby telefony ją pobrały.
  Future<void> putOnServer(String path, Map<String, dynamic> value) =>
      phones.fs.doc(path).set({...value, 'serverAt': FieldValue.serverTimestamp()});

  group('usunięcie bez danych osobowych (fix/062)', () {
    const slimKeys = {'id', 'updatedAt', 'deleted', 'deletedAt'};

    Future<Set<String>> keysOnServer(String id) async =>
        ((await phones.doc('${await unitPath()}/reports/$id'))!['data'] as Map)
            .keys
            .cast<String>()
            .toSet();

    test('usunięty raport i ratownik: na serwerze zostaje sam znacznik, bez '
        'nazwiska i adresu', () async {
      await twoPhones();
      final a = await phone('a');
      await db.addReport(report('r1'));
      await db.addFirefighter(ff('f1', 'Kowalski', at: DateTime(2026, 8, 1)));
      await a.syncAll();
      expect(phones.mentions('Kowalski'), isTrue);
      expect(phones.mentions('Kielno'), isTrue);

      await db.deleteReport('r1');
      await db.deleteFirefighter('f1');
      await a.syncAll();

      expect(await keysOnServer('r1'), slimKeys);
      expect(phones.mentions('Kowalski'), isFalse,
          reason: 'nazwisko zniknęło z listy ratowników na serwerze');
      expect(phones.mentions('Kielno'), isFalse,
          reason: 'adres zniknął z wyjazdu');

      final b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r1'), isNull, reason: 'usunięcie dalej dociera');
      expect(db.getFirefighter('f1'), isNull);
    });

    test('stary pełny znacznik w telefonie: po aktualizacji odchudzony '
        'i wysłany na serwer', () async {
      await twoPhones();
      var a = await phone('a');
      await db.addReport(report('r1'));
      await a.syncAll();

      // Tak usuwała wersja sprzed fix/062: pełna treść z dopiskiem `deleted`.
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

      a = await phone('a'); // start nowej wersji
      expect(db.tombstoneOf(SyncKind.report, 'r1')!.keys.toSet(), slimKeys);
      await a.syncAll();

      expect(await keysOnServer('r1'), slimKeys);
      expect(phones.mentions('Kielno'), isFalse);
      expect(db.getReport('r1'), isNull);
    });

    test('pełny znacznik z serwera (ze starszej wersji): w telefonie bez '
        'treści, a na serwerze zastąpiony odchudzonym', () async {
      await twoPhones();
      final a = await phone('a');
      await db.addReport(report('r1'));
      await a.syncAll();
      final b = await phone('b');
      await b.syncAll();
      expect(db.getReport('r1'), isNotNull);

      final path = '${await unitPath()}/reports/r1';
      final stored = (await phones.doc(path))!;
      final deletedAt = DateTime(2026, 9, 1).toIso8601String();
      await putOnServer(path, {
        ...stored,
        'deleted': true,
        'data': {
          ...(stored['data'] as Map).cast<String, dynamic>(),
          'updatedAt': deletedAt,
          'deleted': true,
          'deletedAt': deletedAt,
        },
      });

      await b.syncAll();

      expect(db.getReport('r1'), isNull);
      expect(db.tombstoneOf(SyncKind.report, 'r1')!.keys.toSet(), slimKeys);
      expect(await keysOnServer('r1'), slimKeys);
      expect(phones.mentions('Kielno'), isFalse);
    });
  });

  test('usunięty raport nie wraca z serwera', () async {
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

  test('edycja po usunięciu na innym telefonie przywraca rekord', () async {
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

  test('usunięty ratownik nie wraca z listy kolegi', () async {
    await twoPhones();
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
        reason: 'B nie nadpisał serwera starszą kopią');
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

  test('zmiana jednego raportu wysyła tylko ten raport', () async {
    await twoPhones();
    final a = await phone('a');
    await db.addReport(report('r1'));
    await db.addReport(report('r2')..reportNumber = '0002/2026');
    await a.syncAll();

    await db.updateReport(
        report('r2', updatedAt: DateTime(2026, 8, 11))..reportNumber = '0002/2026');
    await a.syncAll();
    expect(a.state.lastSyncSent, 1);
  });

  test('uszkodzony dokument na serwerze nie zatrzymuje synchronizacji',
      () async {
    await twoPhones();
    final a = await phone('a');
    await db.addReport(report('r1'));
    await a.syncAll();
    await putOnServer(
        '${await unitPath()}/handovers/zepsuty', {'data': 'to nie mapa'});

    final b = await phone('b');
    await b.syncAll();
    expect(b.state.status, SyncStatus.idle);
    expect(b.state.skippedFiles, 1);
    expect(db.getReport('r1'), isNotNull, reason: 'reszta dotarła');
  });

  test('złe typy w danych jednostki nie zatrzymują synchronizacji', () async {
    await twoPhones();
    await phones.fs.doc(await unitPath()).update({
      'name': 42,
      'locality': ['Kielno'],
      'ownerEmail': 7,
    });

    final b = await phone('b');
    await b.syncAll();
    expect(b.state.status, SyncStatus.idle);
    expect(db.getConfig().fullName, 'OSP Test', reason: 'zła nazwa pominięta');
    expect(b.state.founderEmail, 'a@gmail.com',
        reason: 'założyciel znany telefonowi zostaje');
  });

  test('zmiana danych jednostki nie jest nadpisana przed wysłaniem', () async {
    await twoPhones();
    final a = await phone('a');
    await db.saveConfig(db.getConfig().copyWith(unitStreet: 'Oliwska 12'));
    await db.markUnitConfigEdited();
    await a.syncAll();
    expect(db.getConfig().unitStreet, 'Oliwska 12');

    final b = await phone('b');
    await b.syncAll();
    expect(db.getConfig().unitStreet, 'Oliwska 12', reason: 'dotarło do B');
  });

  test('nowszy format danych blokuje synchronizację starej wersji', () async {
    await twoPhones();
    await phones.fs.doc(await unitPath()).update({'syncFormat': 99});

    final a = await phone('a');
    await db.addReport(report('r1'));
    await a.syncAll();

    expect(a.state.status, SyncStatus.error);
    expect(a.state.errorMessage, contains('Zaktualizuj'));
    expect(await phones.docs(code, 'reports'), isEmpty,
        reason: 'stara wersja niczego nie nadpisuje');
  });

  test('przejazd usunięty ręcznie nie wraca z uzupełniania ewidencji',
      () async {
    await twoPhones();
    var a = await phone('a');
    await db.addReport(report('r1')
      ..crewAssignments = [CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA')]);
    await db.backfillTripsFromReports(stationAddress: 'Kielno');
    await a.syncAll();

    final b = await phone('b');
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
}
