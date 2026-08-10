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
        unitLocality: 'Kielno',
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
        unitLocality: 'Kielno',
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
        unitLocality: 'Kielno',
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
        unitLocality: 'Kielno',
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
        unitLocality: 'Kielno',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: const {},
      ).single;
      final b = TripFromReport.build(
        report: report,
        unitLocality: 'Kielno',
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
        unitLocality: 'Kielno',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: const {},
      ).single;

      expect(trip.routeTo, 'Kielno');
    });

    test('zastep bez pojazdu jest pomijany', () {
      final trips = TripFromReport.build(
        report: buildReport(crews: [
          CrewAssignment(vehicleId: '', vehicleName: ''),
        ]),
        unitLocality: 'Kielno',
        resolveDriverName: (_) => '',
        existingVehicleIdsForReport: const {},
      );

      expect(trips, isEmpty);
    });
  });
}
