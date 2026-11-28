import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/server_phones.dart';

/// Wysyłka zaraz po zapisie, stan wysłania wyjazdu i numer przy dwóch
/// telefonach.
///
/// Test 1.7.4 na dwóch telefonach: wyjazd kolegi czekał na jego telefonie —
/// zapis niczego nie wysyłał, a synchronizacja co 5 minut idzie tylko przy
/// aplikacji otwartej na ekranie. W tych samych minutach drugi telefon nadał
/// ten sam numer 0002/2026, bo wyjazdu kolegi nie było jeszcze w jednostce.
void main() {
  late Directory root;
  late ServerPhones phones;
  final db = DatabaseService();
  final year = DateTime.now().year;

  setUpAll(DatabaseService.registerAdapters);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_sync_after_save');
    phones = ServerPhones(root);
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<SyncService> phone(String name, {Duration delay = Duration.zero}) =>
      phones.phone(name, localChangeDelay: delay);

  Report report(String id, String number) => Report(
        id: id,
        reportNumber: number,
        year: year,
        date: DateTime(year, 8, 10),
        departureTime: DateTime(year, 8, 10, 14, 30),
        addressLocality: 'Kielno',
        addressStreet: '',
        addressDescription: '',
        threatCategory: 'Pożar',
        createdAt: DateTime(year, 8, 10),
        updatedAt: DateTime(year, 8, 10),
      );

  /// Wyjazd [id] w obecnej wersji jest na serwerze.
  bool sent(SyncService sync, String id) =>
      db.getReport(id) != null &&
      !sync.reportsAwaitingUpload(db.getAllReports()).contains(id);

  /// Czeka, aż wysyłka w tle dojdzie do skutku.
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue, reason: 'wysyłka w tle nie doszła do skutku');
  }

  /// A (ospkielno) zakłada jednostkę, B (wojtek) do niej dołącza i zostaje
  /// na ekranie.
  Future<SyncService> colleagueInUnit({Duration delay = Duration.zero}) async {
    await phones.unitWith('ospkielno', 'wojtek', unitName: 'OSP Kielno');
    return phone('wojtek', delay: delay);
  }

  /// Liczba przebiegów synchronizacji, które ruszyły na danym telefonie.
  int Function() countPasses(SyncService sync) {
    var passes = 0;
    var syncing = sync.state.isSyncing;
    // Stan zmienia się też w trakcie przebiegu (np. role), więc liczymy tylko
    // przejścia do „synchronizuję".
    sync.onStateChanged = (s) {
      if (s.isSyncing && !syncing) passes++;
      syncing = s.isSyncing;
    };
    return () => passes;
  }

  group('wysyłka zaraz po zapisie', () {
    test('wyjazd kolegi trafia na serwer bez „Synchronizuj teraz"', () async {
      final b = await colleagueInUnit();
      final reports = ReportsNotifier(db, onChanged: b.notifyLocalChange);

      await reports.add(report('r-b', '0002/$year'));

      await until(() => sent(b, 'r-b') && b.state.status == SyncStatus.idle);
    });

    test('wyjazd i jego przejazdy w ewidencji idą jednym przebiegiem',
        () async {
      final b = await colleagueInUnit(delay: const Duration(milliseconds: 50));
      final passes = countPasses(b);

      await db.addReport(report('r-b', '0002/$year'));
      b.notifyLocalChange();
      b.notifyLocalChange();
      b.notifyLocalChange();

      await until(() => sent(b, 'r-b') && b.state.status == SyncStatus.idle);
      expect(passes(), 1);
    });

    test('zapis w trakcie synchronizacji wychodzi kolejnym przebiegiem',
        () async {
      final b = await colleagueInUnit();
      final passes = countPasses(b);

      final first = b.syncAll();
      // Ta synchronizacja mogła już minąć etap wysyłki.
      await db.addReport(report('r-b', '0002/$year'));
      b.notifyLocalChange();
      await first;

      await until(() => passes() == 2 && b.state.status == SyncStatus.idle);
      expect(sent(b, 'r-b'), isTrue);
    });

    test('bez jednostki zapis niczego nie uruchamia', () async {
      final solo = await phone('samotny');
      final passes = countPasses(solo);

      await db.addReport(report('r1', '0001/$year'));
      solo.notifyLocalChange();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(passes(), 0);
    });
  });

  group('stan wysłania wyjazdu', () {
    test('czeka, aż wyjdzie; po edycji czeka znowu; pobrany od kolegi '
        'jest na serwerze', () async {
      final a = await phone('ospkielno');
      final code = await phones.create(a, 'OSP Kielno');
      await db.addReport(report('r1', '0001/$year'));
      expect(a.reportsAwaitingUpload(db.getAllReports()), {'r1'});

      await a.syncAll();
      expect(a.reportsAwaitingUpload(db.getAllReports()), isEmpty);

      final edited = db.getReport('r1')!
        ..notes = 'Dopisane po powrocie'
        ..updatedAt = DateTime.now();
      await db.updateReport(edited);
      expect(a.reportsAwaitingUpload(db.getAllReports()), {'r1'},
          reason: 'na serwerze jest wersja sprzed edycji');
      await a.syncAll();
      await a.inviteMember('wojtek@gmail.com');

      final b = await phone('wojtek');
      expect(await b.joinUnit(code), isTrue);
      expect(db.getReport('r1')?.notes, 'Dopisane po powrocie');
      expect(b.reportsAwaitingUpload(db.getAllReports()), isEmpty);
    });
  });

  group('numer wyjazdu przy dwóch telefonach', () {
    test('sprawdzenie przed zapisem widzi numer nadany w międzyczasie '
        'na innym telefonie', () async {
      var b = await colleagueInUnit();
      // Kolega otwiera „Nowy wyjazd" — dostaje 0001.
      final proposed = db.getNextReportNumber();
      expect(proposed, '0001/$year');

      // W tym czasie A zapisuje swój wyjazd i od razu go wysyła.
      final a = await phone('ospkielno');
      await db.addReport(report('r-a', '0001/$year'));
      await a.syncAll();

      // Kolega naciska „Zapisz": kreator pobiera wyjazdy jeszcze raz.
      b = await phone('wojtek');
      expect(await b.pullReportsOnly(), isTrue);
      expect(db.reportsWithNumber(proposed), hasLength(1));
      expect(db.getNextReportNumber(), '0002/$year');
    });

    test('pobranie przed zapisem czeka na trwającą synchronizację',
        () async {
      final b = await colleagueInUnit();

      final full = b.syncAll();
      expect(b.state.status, SyncStatus.syncing);
      expect(await b.pullReportsOnly(), isTrue);
      // Wcześniej wracało od razu, a numer liczył się z danych sprzed
      // tej synchronizacji.
      expect(b.state.status, SyncStatus.idle);
      await full;
    });
  });

  group('powtórzony numer rozstrzyga się sam', () {
    /// Wyjazd dnia 27.10 o [h]:[m], dodany z konta `<by>@gmail.com`.
    Report trip(
      String id,
      String number,
      int h,
      int m, {
      required String by,
      String locality = 'Kielno',
      String threat = 'Miejscowe Zagrożenie',
    }) {
      final departure = DateTime(year, 10, 27, h, m);
      return Report(
        id: id,
        reportNumber: '$number/$year',
        year: year,
        date: DateTime(year, 10, 27),
        departureTime: departure,
        addressLocality: locality,
        addressStreet: '',
        addressDescription: '',
        threatCategory: threat,
        createdAt: departure,
        updatedAt: departure,
        createdBy: by.isEmpty ? '' : '$by@gmail.com',
      );
    }

    String numberOf(String id) => db.getReport(id)!.reportNumber;

    /// A (ospkielno) zakłada jednostkę, B (wojtek) dołącza.
    Future<void> unit() =>
        phones.unitWith('ospkielno', 'wojtek', unitName: 'OSP Kielno');

    test('test 1.7.4: wcześniejszy alarm zatrzymuje 0002, późniejszy '
        'wypadek dostaje 0003 — na obu telefonach', () async {
      await unit();
      // Bez zasięgu każdy zapisał swój wyjazd z tym samym numerem.
      await db.addReport(trip('r-w', '0002', 17, 10, by: 'wojtek'));
      var a = await phone('ospkielno');
      await db.addReport(trip('r-a', '0002', 16, 35,
          by: 'ospkielno', locality: 'Gdynia', threat: 'Fałszywy Alarm'));
      await a.syncAll();

      final b = await phone('wojtek');
      await b.syncAll();
      expect(numberOf('r-w'), '0003/$year');
      expect(numberOf('r-a'), '0002/$year');
      expect(b.state.duplicateReportNumbers, isEmpty);
      expect(b.state.renumberNotes.single,
          allOf(contains('17:10'), contains('0003/$year'), contains('0002')));

      a = await phone('ospkielno');
      await a.syncAll();
      expect(numberOf('r-w'), '0003/$year', reason: 'nowy numer dotarł do A');
      expect(db.findDuplicateReportNumbers(), isEmpty);
      expect(a.state.renumberNotes, isEmpty, reason: 'A niczego nie zmieniał');
    });

    test('cudzego wyjazdu telefon nie przenumerowuje — robi to telefon '
        'autora późniejszego', () async {
      await unit();
      await db.addReport(trip('r-w', '0002', 16, 0, by: 'wojtek'));
      var a = await phone('ospkielno');
      await db.addReport(trip('r-a', '0002', 17, 0,
          by: 'ospkielno', locality: 'Gdynia', threat: 'Pożar'));
      await a.syncAll();

      var b = await phone('wojtek');
      await b.syncAll();
      expect(numberOf('r-a'), '0002/$year',
          reason: 'późniejszy jest wyjazdem A — B go nie rusza');
      expect(b.state.duplicateReportNumbers, ['0002/$year']);

      a = await phone('ospkielno');
      await a.syncAll();
      expect(numberOf('r-a'), '0003/$year');
      expect(numberOf('r-w'), '0002/$year');

      b = await phone('wojtek');
      await b.syncAll();
      expect(numberOf('r-a'), '0003/$year');
      expect(b.state.duplicateReportNumbers, isEmpty);
    });

    test('następny numer zajęty — późniejszy dostaje pierwszy wolny, '
        'a wyjazdy bez konfliktu zostają', () async {
      await unit();
      await db.addReport(trip('r-w', '0002', 17, 0, by: 'wojtek'));
      final a = await phone('ospkielno');
      await db.addReport(trip('r-a2', '0002', 16, 0,
          by: 'ospkielno', locality: 'Gdynia', threat: 'Pożar'));
      await db.addReport(trip('r-a3', '0003', 18, 0,
          by: 'ospkielno', locality: 'Szemud', threat: 'Inne'));
      await a.syncAll();

      final b = await phone('wojtek');
      await b.syncAll();
      expect(numberOf('r-w'), '0004/$year');
      expect(numberOf('r-a2'), '0002/$year');
      expect(numberOf('r-a3'), '0003/$year');
    });

    test('ta sama akcja zapisana dwa razy — numery zostają, duplikat '
        'czeka na decyzję', () async {
      await unit();
      await db.addReport(trip('r-w', '0002', 16, 50, by: 'wojtek'));
      final a = await phone('ospkielno');
      await db.addReport(trip('r-a', '0002', 16, 35, by: 'ospkielno'));
      await a.syncAll();

      final b = await phone('wojtek');
      await b.syncAll();
      expect(numberOf('r-w'), '0002/$year');
      expect(numberOf('r-a'), '0002/$year');
      expect(b.state.duplicateReportNumbers, ['0002/$year']);
      expect(b.state.renumberNotes, isEmpty);
    });

    test('wyjazd bez autora przenumerowuje administrator, nie kolega',
        () async {
      await unit();
      var a = await phone('ospkielno');
      await db.addReport(trip('r-a', '0002', 16, 0,
          by: 'ospkielno', locality: 'Gdynia', threat: 'Pożar'));
      await a.syncAll();

      final b = await phone('wojtek');
      await db.addReport(trip('r-x', '0002', 18, 0, by: ''));
      await b.syncAll();
      expect(numberOf('r-x'), '0002/$year', reason: 'kolega nie jest adminem');

      a = await phone('ospkielno');
      await a.syncAll();
      expect(numberOf('r-x'), '0003/$year');
    });
  });

  group('nowy numer dla powtórzonego', () {
    test('dostaje pierwszy wolny numer w swoim roku i idzie na serwer',
        () async {
      await phone('ospkielno');
      await db.addReport(report('r-a', '0002/$year'));
      await db.addReport(report('r-b', '0002/$year'));
      await db.addReport(
          report('r-old', '0007/${year - 1}')..year = year - 1);
      var changes = 0;
      final reports = ReportsNotifier(db, onChanged: () => changes++);

      final number = await reports.assignNextNumber(db.getReport('r-b')!);

      expect(number, '0003/$year');
      expect(db.getReport('r-b')!.reportNumber, '0003/$year');
      expect(db.reportsWithNumber('0002/$year', exceptId: 'r-a'), isEmpty);
      expect(db.findDuplicateReportNumbers(), isEmpty);
      expect(changes, 1, reason: 'zmiana numeru idzie na serwer');
    });

    test('numer z poprzedniego roku liczy się w tamtym roku', () async {
      await phone('ospkielno');
      await db.addReport(report('r1', '0009/$year'));
      await db.addReport(report('r2', '0004/${year - 1}')..year = year - 1);

      expect(db.getNextReportNumber(year: year - 1), '0005/${year - 1}');
      expect(db.getNextReportNumber(), '0010/$year');
      expect(DatabaseService.yearOfReportNumber('0004/${year - 1}'),
          year - 1);
    });
  });
}
