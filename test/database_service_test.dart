import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/core/constants/threat_types.dart';
import 'package:osp_app/services/database_service.dart';

/// Testy warstwy bazy — dotąd nietestowanej.
///
/// Czysta logika łańcucha licznika i generowania przejazdów z raportu miała
/// testy od początku, ale **spięcie ich z Hive nie miało żadnych**: to, czy
/// `addTrip` faktycznie przelicza łańcuch, czy uzupełnianie historii nie
/// dubluje wpisów i czy migracje nie kasują danych, sprawdzało się dotąd
/// wyłącznie ręcznie na emulatorze.
///
/// Hive działa tu na katalogu tymczasowym, więc testy nie dotykają
/// prawdziwych danych i są niezależne od siebie.
void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('osp_db_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(VehicleAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FirefighterAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CrewAssignmentAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ThreatEntryAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ReportAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(UnitConfigAdapter());
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(PropertyHandoverAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(VehicleTripAdapter());
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(TripEquipmentUseAdapter());
    }

    await Future.wait([
      Hive.openBox<Vehicle>('vehicles'),
      Hive.openBox<Firefighter>('firefighters'),
      Hive.openBox<Report>('reports'),
      Hive.openBox<UnitConfig>('config'),
      Hive.openBox<ThreatEntry>('threats'),
      Hive.openBox<dynamic>('settings'),
      Hive.openBox<PropertyHandover>('property_handovers'),
      Hive.openBox<VehicleTrip>('vehicle_trips'),
    ]);

    db = DatabaseService();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  VehicleTrip trip({
    required String id,
    String vehicleId = 'v1',
    required DateTime departure,
    int? start,
    int? end,
    String? reportId,
    String routeFrom = '',
  }) =>
      VehicleTrip(
        id: id,
        vehicleId: vehicleId,
        date: DateTime(departure.year, departure.month, departure.day),
        departureTime: departure,
        returnTime: end == null ? null : departure.add(const Duration(hours: 2)),
        odometerStart: start,
        odometerEnd: end,
        odometerStartManual: start != null,
        routeFrom: routeFrom,
        reportId: reportId,
        createdAt: departure,
        updatedAt: departure,
      );

  Report report({
    String id = 'r1',
    String vehicleId = 'v1',
    DateTime? date,
    DateTime? returnTime,
  }) {
    final d = date ?? DateTime(2026, 8, 10);
    return Report(
      id: id,
      reportNumber: '0001/2026',
      year: d.year,
      date: d,
      departureTime: DateTime(d.year, d.month, d.day, 8, 0),
      returnTime: returnTime,
      addressLocality: 'Kielno',
      addressStreet: 'Oliwska 12',
      addressDescription: '',
      threatCategory: 'Pożar',
      crewAssignments: [
        CrewAssignment(vehicleId: vehicleId, vehicleName: 'GBA'),
      ],
      createdAt: d,
      updatedAt: d,
    );
  }

  group('addTrip przelicza lancuch licznika', () {
    test('drugi przejazd dostaje stan po pierwszym', () async {
      await db.addTrip(trip(
          id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050));
      await db.addTrip(trip(id: 'b', departure: DateTime(2026, 8, 5, 8)));

      expect(db.getTrip('b')!.odometerStart, 1050);
    });

    test('wpis dodany wstecz przesuwa pozniejsze', () async {
      await db.addTrip(trip(
          id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050));
      await db.addTrip(trip(id: 'c', departure: DateTime(2026, 8, 9, 8)));
      expect(db.getTrip('c')!.odometerStart, 1050);

      // Ktos uzupelnia zaleglosci z 5 sierpnia.
      await db.addTrip(
          trip(id: 'b', departure: DateTime(2026, 8, 5, 8), end: 1120));

      expect(db.getTrip('b')!.odometerStart, 1050);
      expect(db.getTrip('c')!.odometerStart, 1120,
          reason: 'wpis wstecz musi przesunac pozniejszy');
    });

    test('usuniecie przejazdu przelicza lancuch', () async {
      await db.addTrip(trip(
          id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050));
      await db.addTrip(
          trip(id: 'b', departure: DateTime(2026, 8, 5, 8), end: 1120));
      await db.addTrip(trip(id: 'c', departure: DateTime(2026, 8, 9, 8)));
      expect(db.getTrip('c')!.odometerStart, 1120);

      await db.deleteTrip('b');

      expect(db.getTrip('c')!.odometerStart, 1050,
          reason: 'po usunieciu srodkowego liczy sie od poprzedniego');
    });

    test('lancuch nie miesza pojazdow', () async {
      await db.addTrip(trip(
          id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050));
      await db.addTrip(trip(
          id: 'x',
          vehicleId: 'v2',
          departure: DateTime(2026, 8, 2, 8),
          start: 9000,
          end: 9500));
      await db.addTrip(trip(id: 'b', departure: DateTime(2026, 8, 5, 8)));

      expect(db.getTrip('b')!.odometerStart, 1050);
    });
  });

  group('getTripsForCard', () {
    test('zwraca tylko dany pojazd i miesiac, chronologicznie', () async {
      await db.addTrip(trip(id: 'sier2', departure: DateTime(2026, 8, 9, 8)));
      await db.addTrip(trip(id: 'sier1', departure: DateTime(2026, 8, 2, 8)));
      await db.addTrip(trip(id: 'lip', departure: DateTime(2026, 7, 9, 8)));
      await db.addTrip(trip(
          id: 'inny', vehicleId: 'v2', departure: DateTime(2026, 8, 5, 8)));

      final card = db.getTripsForCard(vehicleId: 'v1', year: 2026, month: 8);

      expect(card.map((t) => t.id), ['sier1', 'sier2']);
    });
  });

  group('backfillTripsFromReports', () {
    test('dopisuje przejazd z istniejacego raportu', () async {
      await db.addReport(report());

      final added =
          await db.backfillTripsFromReports(stationAddress: 'Kielno');

      expect(added, 1);
      expect(db.getAllTrips().single.reportId, 'r1');
    });

    test('powtorne uruchomienie nie dubluje', () async {
      await db.addReport(report());
      await db.backfillTripsFromReports(stationAddress: 'Kielno');

      final second =
          await db.backfillTripsFromReports(stationAddress: 'Kielno');

      expect(second, 0);
      expect(db.getAllTrips(), hasLength(1));
    });

    test('nie wskrzesza przejazdu skasowanego recznie', () async {
      await db.addReport(report());
      await db.backfillTripsFromReports(stationAddress: 'Kielno');
      final id = db.getAllTrips().single.id;

      await db.deleteTrip(id);
      await db.backfillTripsFromReports(stationAddress: 'Kielno');

      expect(db.getAllTrips(), isEmpty,
          reason: 'raport jest juz odnotowany jako przerobiony');
    });

    test('raport sciagniety pozniej tez zostaje dopisany', () async {
      await db.backfillTripsFromReports(stationAddress: 'Kielno');
      await db.addReport(report(id: 'r2'));

      final added =
          await db.backfillTripsFromReports(stationAddress: 'Kielno');

      expect(added, 1);
    });
  });

  group('reconcileTripsWithReports', () {
    test('dopisana godzina powrotu trafia do przejazdu', () async {
      final r = report();
      await db.addReport(r);
      await db.backfillTripsFromReports(stationAddress: 'Kielno');
      expect(db.getAllTrips().single.returnTime, isNull);

      r.returnTime = DateTime(2026, 8, 10, 16, 0);
      await db.updateReport(r);

      final changed = await db.reconcileTripsWithReports();

      expect(changed, 1);
      expect(db.getAllTrips().single.returnTime, DateTime(2026, 8, 10, 16, 0));
    });

    test('nie rusza licznika wpisanego w ewidencji', () async {
      final r = report();
      await db.addReport(r);
      await db.backfillTripsFromReports(stationAddress: 'Kielno');

      final t = db.getAllTrips().single;
      t.odometerStart = 1000;
      t.odometerEnd = 1042;
      await db.updateTrip(t);

      r.returnTime = DateTime(2026, 8, 10, 16, 0);
      await db.updateReport(r);
      await db.reconcileTripsWithReports();

      final after = db.getAllTrips().single;
      expect(after.odometerStart, 1000);
      expect(after.odometerEnd, 1042);
    });

    test('bez zmian w raporcie nic nie zapisuje', () async {
      await db.addReport(report());
      await db.backfillTripsFromReports(stationAddress: 'Kielno');

      expect(await db.reconcileTripsWithReports(), 0);
    });
  });

  group('fillMissingRouteFrom', () {
    test('uzupelnia tylko puste pola', () async {
      await db.addTrip(trip(id: 'a', departure: DateTime(2026, 8, 1, 8)));
      await db.addTrip(trip(
          id: 'b',
          departure: DateTime(2026, 8, 2, 8),
          routeFrom: 'Kielno, remiza boczna'));

      final filled = await db.fillMissingRouteFrom('Kielno, Oliwska 12');

      expect(filled, 1);
      expect(db.getTrip('a')!.routeFrom, 'Kielno, Oliwska 12');
      expect(db.getTrip('b')!.routeFrom, 'Kielno, remiza boczna');
    });

    test('pusty adres nic nie zmienia', () async {
      await db.addTrip(trip(id: 'a', departure: DateTime(2026, 8, 1, 8)));

      expect(await db.fillMissingRouteFrom('   '), 0);
      expect(db.getTrip('a')!.routeFrom, '');
    });
  });

  group('ensureDefaultThreats — migracja słownika zagrożeń', () {
    test('zaklada domyslne kategorie i nic wiecej', () async {
      await db.ensureDefaultThreats();

      final categories = db.threatsBox.keys.map((k) => k.toString()).toSet();
      expect(categories, ThreatTypes.defaults.keys.toSet());
    });

    test('zachowuje wlasne podtypy uzytkownika', () async {
      await db.ensureDefaultThreats();
      final pozar = db.threatsBox.get('Pożar')!;
      await db.threatsBox.put(
        'Pożar',
        ThreatEntry(
          category: 'Pożar',
          subtypes: [...pozar.subtypes, 'Pożar stodoły'],
        ),
      );

      await db.ensureDefaultThreats();

      expect(db.threatsBox.get('Pożar')!.subtypes, contains('Pożar stodoły'));
      // Domyślne zostają i idą pierwsze.
      expect(db.threatsBox.get('Pożar')!.subtypes.first,
          ThreatTypes.defaults['Pożar']!.first);
    });

    test('usuwa kategorie spoza zamknietej listy', () async {
      await db.threatsBox.put(
        'Wyjazd gospodarczy',
        ThreatEntry(category: 'Wyjazd gospodarczy', subtypes: const []),
      );

      await db.ensureDefaultThreats();

      expect(db.threatsBox.get('Wyjazd gospodarczy'), isNull);
    });

    test('powtorny przebieg nie zapisuje niczego ponownie', () async {
      // Migracja idzie przy **każdym** starcie aplikacji i po **każdym**
      // pobraniu z Dysku. Wcześniej przepisywała trzy rekordy za każdym razem,
      // mimo że wynik był identyczny. Sprawdzamy po tożsamości obiektów:
      // brak zapisu znaczy, że w pudełku leżą te same instancje.
      await db.ensureDefaultThreats();
      final before = {
        for (final k in db.threatsBox.keys) k: db.threatsBox.get(k)
      };

      await db.ensureDefaultThreats();

      for (final k in db.threatsBox.keys) {
        expect(identical(db.threatsBox.get(k), before[k]), isTrue,
            reason: 'kategoria $k została przepisana bez potrzeby');
      }
    });

    test('wynik jest ten sam niezaleznie od liczby przebiegow', () async {
      await db.ensureDefaultThreats();
      final once = {
        for (final k in db.threatsBox.keys)
          k.toString(): [...db.threatsBox.get(k)!.subtypes]
      };

      await db.ensureDefaultThreats();
      await db.ensureDefaultThreats();

      final thrice = {
        for (final k in db.threatsBox.keys)
          k.toString(): [...db.threatsBox.get(k)!.subtypes]
      };
      expect(thrice, once);
    });
  });

  group('saveTripEditedByUser — poprawki z ewidencji', () {
    const ret = ReportLinkedField.returnTime;

    Future<void> seed(Report r) async {
      await db.addReport(r);
      await db.backfillTripsFromReports(stationAddress: 'Kielno');
    }

    VehicleTrip of(String vehicleId) =>
        db.getAllTrips().firstWhere((t) => t.vehicleId == vehicleId);

    Report twoVehicles() => report()
      ..crewAssignments = [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA'),
        CrewAssignment(vehicleId: 'v2', vehicleName: 'GLM'),
      ];

    test('zgloszenie testera: godzina z ewidencji trafia do raportu', () async {
      await seed(report());
      final t = of('v1')..returnTime = DateTime(2026, 8, 10, 16, 0);

      final updated =
          await db.saveTripEditedByUser(t, touched: {ret}, canEditReport: true);

      expect(updated, isNotNull);
      expect(db.getReport('r1')!.returnTime, DateTime(2026, 8, 10, 16, 0));
      expect(db.getTrip(t.id)!.overriddenFields, isEmpty,
          reason: 'jeden woz: zgodny z raportem, idzie za jego zmianami');
    });

    test('poprawka przezywa uzgadnianie przy starcie (dawniej ginela)',
        () async {
      await seed(report());
      final t = of('v1')..returnTime = DateTime(2026, 8, 10, 16, 0);
      await db.saveTripEditedByUser(t, touched: {ret}, canEditReport: false);

      expect(db.getReport('r1')!.returnTime, isNull,
          reason: 'bez uprawnien raport zostaje nietkniety');

      await db.reconcileTripsWithReports();

      expect(db.getTrip(t.id)!.returnTime, DateTime(2026, 8, 10, 16, 0));
    });

    test('recznie wpisany kierowca przezywa uzgadnianie', () async {
      await seed(report());
      final t = of('v1')..driverName = 'Nowak Adam';
      await db.saveTripEditedByUser(t,
          touched: {ReportLinkedField.driver}, canEditReport: true);

      await db.reconcileTripsWithReports();

      expect(db.getTrip(t.id)!.driverName, 'Nowak Adam');
    });

    test('dwa wozy: powrot jednego nie jest zmyslonym powrotem drugiego',
        () async {
      await seed(twoVehicles());

      final a = of('v1')..returnTime = DateTime(2026, 8, 10, 10, 0);
      await db.saveTripEditedByUser(a, touched: {ret}, canEditReport: true);

      expect(db.getReport('r1')!.returnTime, DateTime(2026, 8, 10, 10, 0));
      await db.reconcileTripsWithReports();
      expect(of('v2').returnTime, isNull,
          reason: 'GLM mogl byc jeszcze na akcji');
    });

    test('dwa wozy: kolejne poprawki nie skacza miedzy przejazdami', () async {
      await seed(twoVehicles());

      final a = of('v1')..returnTime = DateTime(2026, 8, 10, 10, 0);
      await db.saveTripEditedByUser(a, touched: {ret}, canEditReport: true);
      final b = of('v2')..returnTime = DateTime(2026, 8, 10, 11, 0);
      await db.saveTripEditedByUser(b, touched: {ret}, canEditReport: true);

      expect(db.getReport('r1')!.returnTime, DateTime(2026, 8, 10, 11, 0),
          reason: 'raport: powrot ostatniego zastepu');

      await db.reconcileTripsWithReports();
      await db.reconcileTripsWithReports();
      expect(of('v1').returnTime, DateTime(2026, 8, 10, 10, 0));
      expect(of('v2').returnTime, DateTime(2026, 8, 10, 11, 0));
    });

    test('godzina w raporcie nigdy nie zmienia sie na pusta', () async {
      await seed(report(returnTime: DateTime(2026, 8, 10, 11, 0)));
      final t = of('v1')..returnTime = null;

      await db.saveTripEditedByUser(t, touched: {ret}, canEditReport: true);

      expect(db.getReport('r1')!.returnTime, DateTime(2026, 8, 10, 11, 0));
      expect(db.getTrip(t.id)!.returnTime, isNull,
          reason: 'wyczyszczona godzina w ewidencji zostaje wyczyszczona');
      await db.reconcileTripsWithReports();
      expect(db.getTrip(t.id)!.returnTime, isNull);
    });

    test('zapis samego licznika nie rusza raportu ani ochrony', () async {
      await seed(report(returnTime: DateTime(2026, 8, 10, 11, 0)));
      final t = of('v1')
        ..returnTime = DateTime(2026, 8, 10, 12, 0)
        ..overriddenFields = [ret];
      await db.updateTrip(t);
      final reportStamp = db.getReport('r1')!.updatedAt;

      final edited = db.getTrip(t.id)!..odometerEnd = 1042;
      expect(
        await db.saveTripEditedByUser(edited,
            touched: const {}, canEditReport: true),
        isNull,
      );
      expect(db.getReport('r1')!.updatedAt, reportStamp);
      expect(db.getTrip(t.id)!.overriddenFields, [ret]);
      expect(db.getTrip(t.id)!.returnTime, DateTime(2026, 8, 10, 12, 0));
    });

    test('raport chwilowo nieobecny: poprawka dostaje ochrone na jego powrot',
        () async {
      await seed(report());
      final t = of('v1')..returnTime = DateTime(2026, 8, 10, 16, 0);
      final r = db.getReport('r1')!;
      await db.deleteReport('r1');

      await db.saveTripEditedByUser(t, touched: {ret}, canEditReport: true);
      expect(db.getTrip(t.id)!.overriddenFields, [ret]);

      await db.addReport(r);
      await db.reconcileTripsWithReports();
      expect(db.getTrip(t.id)!.returnTime, DateTime(2026, 8, 10, 16, 0));
    });

    test('zamrozenie drugiego wozu jest scisle nowsze od raportu', () async {
      await seed(twoVehicles());
      final a = of('v1')..returnTime = DateTime(2026, 8, 10, 10, 0);
      await db.saveTripEditedByUser(a, touched: {ret}, canEditReport: true);

      expect(of('v2').updatedAt.isAfter(db.getReport('r1')!.updatedAt), isTrue,
          reason: 'przy remisie inny telefon nie przyjalby zamrozenia');
    });

    test('przejazd przeniesiony na inny dzien nie zmienia godzin raportu',
        () async {
      await seed(report());
      final t = of('v1')
        ..date = DateTime(2026, 8, 11)
        ..departureTime = DateTime(2026, 8, 11, 9, 0)
        ..returnTime = DateTime(2026, 8, 11, 10, 0);

      expect(
        await db.saveTripEditedByUser(t,
            touched: {ReportLinkedField.departure, ret}, canEditReport: true),
        isNull,
      );
      expect(db.getReport('r1')!.departureTime, DateTime(2026, 8, 10, 8, 0));
      await db.reconcileTripsWithReports();
      expect(db.getTrip(t.id)!.date, DateTime(2026, 8, 11));
    });
  });

  group('uzgadnianie w tle', () {
    test('przejazd dostaje stempel raportu, nie biezacy czas', () async {
      final r = report();
      await db.addReport(r);
      await db.backfillTripsFromReports(stationAddress: 'Kielno');

      r
        ..returnTime = DateTime(2026, 8, 10, 16, 0)
        ..updatedAt = DateTime(2026, 8, 10, 17, 0);
      await db.updateReport(r);
      await db.reconcileTripsWithReports();

      expect(db.getAllTrips().single.updatedAt, DateTime(2026, 8, 10, 17, 0),
          reason: 'stempel teraz przebijal prawdziwe edycje z innych telefonow');
    });

    test('usuniety z kartoteki kierowca zostaje w dawnych przejazdach',
        () async {
      final r = report()
        ..crewAssignments = [
          CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
        ];
      await db.addFirefighter(
          Firefighter(id: 'f1', firstName: 'Jan', lastName: 'Kowalski', rank: ''));
      await db.addReport(r);
      await db.backfillTripsFromReports(stationAddress: 'Kielno');
      expect(db.getAllTrips().single.driverName, 'Kowalski Jan');

      await db.deleteFirefighter('f1');
      await db.reconcileTripsWithReports();

      expect(db.getAllTrips().single.driverName, 'Kowalski Jan');
    });
  });

  group('fixOvernightReturnTimes', () {
    test('powrot po polnocy przechodzi na nastepny dzien', () async {
      final r = report()
        ..departureTime = DateTime(2026, 8, 10, 23, 10)
        ..returnTime = DateTime(2026, 8, 10, 1, 30);
      await db.addReport(r);

      expect(await db.fixOvernightReturnTimes(), 1);
      final after = db.getReport('r1')!;
      expect(after.returnTime, DateTime(2026, 8, 11, 1, 30));
      expect(after.updatedAt, DateTime(2026, 8, 10),
          reason: 'bez stempla - inaczej lawina zapisow na Dysk');
      expect(await db.fixOvernightReturnTimes(), 0, reason: 'idempotentne');
    });

    test('literowki w godzinie nie zamienia w akcje na dobe', () async {
      final r = report()
        ..departureTime = DateTime(2026, 8, 10, 14, 50)
        ..returnTime = DateTime(2026, 8, 10, 14, 5);
      await db.addReport(r);

      expect(await db.fixOvernightReturnTimes(), 0);
      expect(db.getReport('r1')!.returnTime, DateTime(2026, 8, 10, 14, 5));
    });
  });
}
