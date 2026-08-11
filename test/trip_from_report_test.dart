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
}
