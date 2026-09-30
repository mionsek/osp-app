import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/trip_from_report.dart';

Report buildReport({
  String id = 'r1',
  List<CrewAssignment> crews = const [],
  String locality = 'Kielno',
  String street = 'Oliwska 12',
}) {
  return Report(
    id: id,
    reportNumber: '0001/2026',
    year: 2026,
    date: DateTime(2026, 8, 10),
    departureTime: DateTime(2026, 8, 10, 14, 30),
    returnTime: DateTime(2026, 8, 10, 16, 0),
    addressLocality: locality,
    addressStreet: street,
    addressDescription: '',
    threatCategory: 'Pożar',
    crewAssignments: crews,
    createdAt: DateTime(2026, 8, 10),
    updatedAt: DateTime(2026, 8, 10),
  );
}

void main() {
  group('TripFromReport.build', () {
    test('tworzy jeden przejazd na kazdy zastep', () {
      final report = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
        CrewAssignment(vehicleId: 'v2', vehicleName: 'GLM', driverId: 'f2'),
      ]);

      final trips = TripFromReport.build(
        report: report,
        stationAddress: 'Kielno',
        resolveDriverName: (id) => id == 'f1' ? 'Jan Kowalski' : 'Adam Nowak',
        existingVehicleIdsForReport: const {},
      );

      expect(trips, hasLength(2));
      expect(trips.map((t) => t.vehicleId), ['v1', 'v2']);
      expect(trips.first.driverName, 'Jan Kowalski');
    });

    test('przepisuje z raportu 7 kolumn karty', () {
      final report = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
      ]);

      final trip = TripFromReport.build(
        report: report,
        stationAddress: 'Kielno',
        resolveDriverName: (_) => 'Jan Kowalski',
        existingVehicleIdsForReport: const {},
      ).single;

      expect(trip.date, DateTime(2026, 8, 10));
      expect(trip.departureTime, DateTime(2026, 8, 10, 14, 30));
      expect(trip.returnTime, DateTime(2026, 8, 10, 16, 0));
      expect(trip.routeFrom, 'Kielno');
      expect(trip.routeTo, 'Kielno, Oliwska 12');
      expect(trip.purpose, TripPurposes.alarm);
      expect(trip.reportId, 'r1');
    });

    test('licznik zostaje pusty - z raportu nie da sie go wyczytac', () {
      final trip = TripFromReport.build(
        report: buildReport(crews: [
          CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA'),
        ]),
        stationAddress: 'Kielno',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: const {},
      ).single;

      expect(trip.odometerStart, isNull);
      expect(trip.odometerEnd, isNull);
      expect(trip.isClosed, isFalse);
    });

    test('ponowny zapis raportu nie dubluje wpisu w karcie', () {
      final report = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA'),
        CrewAssignment(vehicleId: 'v2', vehicleName: 'GLM'),
      ]);

      final trips = TripFromReport.build(
        report: report,
        stationAddress: 'Kielno',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: {'v1'},
      );

      expect(trips, hasLength(1));
      expect(trips.single.vehicleId, 'v2');
    });

    test('id wyprowadzone z raportu i pojazdu jest powtarzalne', () {
      final report = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA'),
      ]);

      final a = TripFromReport.build(
        report: report,
        stationAddress: 'Kielno',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: const {},
      ).single;
      final b = TripFromReport.build(
        report: report,
        stationAddress: 'Kielno',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: const {},
      ).single;

      expect(a.id, b.id);
    });

    test('sam adres bez ulicy daje sama miejscowosc', () {
      final trip = TripFromReport.build(
        report: buildReport(
          crews: [CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA')],
          street: '',
        ),
        stationAddress: 'Kielno',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: const {},
      ).single;

      expect(trip.routeTo, 'Kielno');
    });

    test('mozna podac znacznik czasu zamiast "teraz"', () {
      // Uzupelnianie historii musi dac identyczne rekordy na kazdym telefonie,
      // inaczej kazda synchronizacja nadpisywalaby cudzy wpis jako "nowszy".
      final stamp = DateTime(2026, 7, 1, 12);
      final trip = TripFromReport.build(
        report: buildReport(crews: [
          CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA'),
        ]),
        stationAddress: 'Kielno, Oliwska 12',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: const {},
        timestamp: stamp,
      ).single;

      expect(trip.createdAt, stamp);
      expect(trip.updatedAt, stamp);
    });

    test('zastep bez pojazdu jest pomijany', () {
      final trips = TripFromReport.build(
        report: buildReport(crews: [
          CrewAssignment(vehicleId: '', vehicleName: ''),
        ]),
        stationAddress: 'Kielno',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: const {},
      );

      expect(trips, isEmpty);
    });
  });

  group('TripFromReport.applyReportFields', () {
    VehicleTrip existingTripFor(Report report) => TripFromReport.build(
          report: report,
          stationAddress: 'Kielno, Oliwska 12',
          resolveDriverName: (_) => 'Jan Kowalski',
          existingVehicleIdsForReport: const {},
        ).single;

    test('dopisana godzina powrotu trafia do przejazdu', () {
      final report = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
      ]);
      final trip = existingTripFor(report);
      trip.returnTime = null;

      final changed = TripFromReport.applyReportFields(
        trip,
        report,
        resolveDriverName: (_) => 'Jan Kowalski',
      );

      expect(changed, isTrue);
      expect(trip.returnTime, DateTime(2026, 8, 10, 16, 0));
    });

    test('nie rusza licznika ani danych wpisanych w ewidencji', () {
      final report = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
      ]);
      final trip = existingTripFor(report);
      trip.odometerStart = 1654;
      trip.odometerEnd = 1683;
      trip.dispatcherName = 'SKKM Kartuzy';
      trip.specialEquipmentMinutes = 25;
      trip.notes = 'autopompa';
      trip.routeFrom = 'Kielno, remiza';
      trip.returnTime = null;

      TripFromReport.applyReportFields(trip, report,
          resolveDriverName: (_) => 'Jan Kowalski');

      expect(trip.odometerStart, 1654);
      expect(trip.odometerEnd, 1683);
      expect(trip.dispatcherName, 'SKKM Kartuzy');
      expect(trip.specialEquipmentMinutes, 25);
      expect(trip.notes, 'autopompa');
      expect(trip.routeFrom, 'Kielno, remiza');
    });

    test('bez zmian w raporcie nie zglasza zmiany', () {
      final report = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
      ]);
      final trip = existingTripFor(report);

      final changed = TripFromReport.applyReportFields(
        trip,
        report,
        resolveDriverName: (_) => 'Jan Kowalski',
      );

      expect(changed, isFalse);
    });

    test('godzina powrotu dopisana pozniej trafia do przejazdu przy uzgadnianiu',
        () {
      // Odwzorowanie realnego przypadku: przejazd powstal, gdy raport nie mial
      // jeszcze godziny powrotu; godzine dopisano w wersji bez synchronizacji.
      final reportBez = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
      ]);
      reportBez.returnTime = null;

      final trip = TripFromReport.build(
        report: reportBez,
        stationAddress: 'Kielno, Oliwska 12',
        resolveDriverName: (_) => 'Jan Kowalski',
        existingVehicleIdsForReport: const {},
      ).single;
      expect(trip.returnTime, isNull);

      // Ktos dopisuje godzine powrotu w raporcie.
      reportBez.returnTime = DateTime(2026, 8, 10, 16, 0);

      final changed = TripFromReport.applyReportFields(
        trip,
        reportBez,
        resolveDriverName: (_) => 'Jan Kowalski',
      );

      expect(changed, isTrue);
      expect(trip.returnTime, DateTime(2026, 8, 10, 16, 0));
    });

    test('uzgadnianie nie rusza pola "skad"', () {
      final report = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
      ]);
      final trip = TripFromReport.build(
        report: report,
        stationAddress: 'Kielno, Oliwska 12',
        resolveDriverName: (_) => 'Jan Kowalski',
        existingVehicleIdsForReport: const {},
      ).single;

      trip.routeFrom = 'Kielno, remiza boczna';
      trip.returnTime = null;

      TripFromReport.applyReportFields(trip, report,
          resolveDriverName: (_) => 'Jan Kowalski');

      expect(trip.routeFrom, 'Kielno, remiza boczna');
    });

    test('zmiana kierowcy w raporcie aktualizuje przejazd', () {
      final report = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
      ]);
      final trip = existingTripFor(report);

      report.crewAssignments.first.driverId = 'f2';
      final changed = TripFromReport.applyReportFields(
        trip,
        report,
        resolveDriverName: (id) => id == 'f2' ? 'Adam Nowak' : 'Jan Kowalski',
      );

      expect(changed, isTrue);
      expect(trip.driverId, 'f2');
      expect(trip.driverName, 'Adam Nowak');
    });
  });

  group('UnitConfig.stationAddress', () {
    UnitConfig cfg({String locality = '', String street = ''}) =>
        UnitConfig(locality: locality, unitStreet: street);

    test('miejscowosc i ulica sklejane przecinkiem', () {
      expect(cfg(locality: 'Kielno', street: 'Oliwska 12').stationAddress,
          'Kielno, Oliwska 12');
    });

    test('sama miejscowosc gdy brak ulicy', () {
      expect(cfg(locality: 'Kielno').stationAddress, 'Kielno');
    });

    test('pusty adres gdy nic nie podano - bez zmyslonej podpowiedzi', () {
      expect(cfg().stationAddress, '');
    });
  });

  group('Poprawki reczne w ewidencji (overriddenFields)', () {
    VehicleTrip linkedTrip({List<String> overrides = const []}) => VehicleTrip(
          id: 'trip_r1_v1',
          vehicleId: 'v1',
          date: DateTime(2026, 8, 10),
          departureTime: DateTime(2026, 8, 10, 14, 30),
          returnTime: DateTime(2026, 8, 10, 17, 45),
          routeTo: 'Kielno, Oliwska 12',
          driverId: 'f9',
          driverName: 'Recznie Wpisany',
          reportId: 'r1',
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
          overriddenFields: List.of(overrides),
        );

    final report = buildReport(crews: [
      CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
    ]);
    String names(String id) => 'Kowalski Jan';

    test('bez ochrony raport nadpisuje godzine i kierowce', () {
      final t = linkedTrip();
      expect(TripFromReport.applyReportFields(t, report,
          resolveDriverName: names), isTrue);
      expect(t.returnTime, DateTime(2026, 8, 10, 16, 0));
      expect(t.driverId, 'f1');
    });

    test('chronione pola zostaja - to byl blad cofajacy poprawki po starcie',
        () {
      final t = linkedTrip(overrides: [
        ReportLinkedField.returnTime,
        ReportLinkedField.driver,
      ]);
      TripFromReport.applyReportFields(t, report, resolveDriverName: names);
      expect(t.returnTime, DateTime(2026, 8, 10, 17, 45));
      expect(t.driverId, 'f9');
      expect(t.driverName, 'Recznie Wpisany');
    });

    test('zmiana w raporcie (force) wygrywa i zdejmuje ochrone', () {
      final t = linkedTrip(overrides: [
        ReportLinkedField.returnTime,
        ReportLinkedField.driver,
      ]);
      TripFromReport.applyReportFields(t, report,
          resolveDriverName: names, force: {ReportLinkedField.returnTime});
      expect(t.returnTime, DateTime(2026, 8, 10, 16, 0));
      expect(t.overriddenFields, [ReportLinkedField.driver]);
      expect(t.driverId, 'f9', reason: 'kierowcy raport nie zmienial');
    });

    test('overridesAgainst wskazuje tylko roznice', () {
      final t = linkedTrip();
      expect(
        TripFromReport.overridesAgainst(t, report, resolveDriverName: names),
        [ReportLinkedField.returnTime, ReportLinkedField.driver],
      );
      t.returnTime = report.returnTime;
      t.driverId = 'f1';
      t.driverName = 'Kowalski Jan';
      expect(
        TripFromReport.overridesAgainst(t, report, resolveDriverName: names),
        isEmpty,
        reason: 'cofniecie poprawki zdejmuje ochrone',
      );
    });

    test('changedBetween liczy kierowce osobno dla kazdego wozu', () {
      final before = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
        CrewAssignment(vehicleId: 'v2', vehicleName: 'GLM', driverId: 'f2'),
      ]);
      final after = buildReport(crews: [
        CrewAssignment(vehicleId: 'v1', vehicleName: 'GBA', driverId: 'f1'),
        CrewAssignment(vehicleId: 'v2', vehicleName: 'GLM', driverId: 'f3'),
      ])
        ..returnTime = DateTime(2026, 8, 10, 18, 0);

      expect(TripFromReport.changedBetween(before, after, vehicleId: 'v1'),
          {ReportLinkedField.returnTime});
      expect(TripFromReport.changedBetween(before, after, vehicleId: 'v2'),
          {ReportLinkedField.returnTime, ReportLinkedField.driver});
    });
  });

  group('TripFromReport.reportTimesFromTrips', () {
    VehicleTrip t(String id, DateTime dep, DateTime? ret) => VehicleTrip(
          id: id,
          vehicleId: id,
          date: DateTime(dep.year, dep.month, dep.day),
          departureTime: dep,
          returnTime: ret,
          reportId: 'r1',
          createdAt: dep,
          updatedAt: dep,
        );
    final day = DateTime(2026, 8, 10);

    test('odjazd pierwszego i powrot ostatniego zastepu', () {
      final times = TripFromReport.reportTimesFromTrips([
        t('a', DateTime(2026, 8, 10, 14, 30), DateTime(2026, 8, 10, 16, 0)),
        t('b', DateTime(2026, 8, 10, 14, 35), DateTime(2026, 8, 10, 17, 10)),
      ], reportDate: day)!;
      expect(times.departure, DateTime(2026, 8, 10, 14, 30));
      expect(times.returnTime, DateTime(2026, 8, 10, 17, 10));
    });

    test('powrot po polnocy liczy sie jako najpozniejszy', () {
      final times = TripFromReport.reportTimesFromTrips([
        t('a', DateTime(2026, 8, 10, 23, 10), DateTime(2026, 8, 11, 1, 30)),
      ], reportDate: day)!;
      expect(times.returnTime, DateTime(2026, 8, 11, 1, 30));
    });

    test('brak powrotu wszedzie daje null zamiast zmyslonej godziny', () {
      final times = TripFromReport.reportTimesFromTrips([
        t('a', DateTime(2026, 8, 10, 14, 30), null),
      ], reportDate: day)!;
      expect(times.returnTime, isNull);
    });

    test('przejazd z innego dnia nie wplywa na raport', () {
      expect(
        TripFromReport.reportTimesFromTrips([
          t('a', DateTime(2026, 8, 12, 9, 0), DateTime(2026, 8, 12, 10, 0)),
        ], reportDate: day),
        isNull,
      );
    });
  });
}
