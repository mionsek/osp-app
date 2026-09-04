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
}
