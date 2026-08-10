import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/vehicle_trip.dart';
import 'package:osp_app/services/trip_odometer.dart';

VehicleTrip trip({
  required String id,
  String vehicleId = 'v1',
  required DateTime departure,
  int? start,
  int? end,
  bool manual = false,
}) {
  return VehicleTrip(
    id: id,
    vehicleId: vehicleId,
    date: DateTime(departure.year, departure.month, departure.day),
    departureTime: departure,
    // Licznik po powrocie notuje sie razem z godzina powrotu - jedno bez
    // drugiego nie wystepuje w realnym wpisie.
    returnTime: end == null ? null : departure.add(const Duration(hours: 2)),
    odometerStart: start,
    odometerEnd: end,
    odometerStartManual: manual,
    createdAt: departure,
    updatedAt: departure,
  );
}

void main() {
  group('TripOdometer.previousReading', () {
    test('pierwszy przejazd pojazdu nie ma z czego wziac stanu', () {
      final result = TripOdometer.previousReading(
        const <VehicleTrip>[],
        vehicleId: 'v1',
        before: DateTime(2026, 8, 10, 8),
      );
      expect(result, isNull);
    });

    test('bierze stan po ostatnim wczesniejszym przejezdzie', () {
      final trips = [
        trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050),
        trip(id: 'b', departure: DateTime(2026, 8, 5, 8), start: 1050, end: 1120),
      ];
      final result = TripOdometer.previousReading(
        trips,
        vehicleId: 'v1',
        before: DateTime(2026, 8, 10, 8),
      );
      expect(result, 1120);
    });

    test('nie miesza licznikow roznych pojazdow', () {
      final trips = [
        trip(id: 'a', vehicleId: 'v1', departure: DateTime(2026, 8, 1, 8), end: 1050),
        trip(id: 'b', vehicleId: 'v2', departure: DateTime(2026, 8, 5, 8), end: 9999),
      ];
      final result = TripOdometer.previousReading(
        trips,
        vehicleId: 'v1',
        before: DateTime(2026, 8, 10, 8),
      );
      expect(result, 1050);
    });

    test('pomija przejazd bez zapisanego stanu po powrocie', () {
      final trips = [
        trip(id: 'a', departure: DateTime(2026, 8, 1, 8), end: 1050),
        trip(id: 'b', departure: DateTime(2026, 8, 5, 8), end: null),
      ];
      final result = TripOdometer.previousReading(
        trips,
        vehicleId: 'v1',
        before: DateTime(2026, 8, 10, 8),
      );
      expect(result, 1050);
    });

    test('edytowany przejazd nie wyznacza sam sobie stanu poczatkowego', () {
      final trips = [
        trip(id: 'a', departure: DateTime(2026, 8, 1, 8), end: 1050),
        trip(id: 'b', departure: DateTime(2026, 8, 5, 8), end: 1200),
      ];
      final result = TripOdometer.previousReading(
        trips,
        vehicleId: 'v1',
        before: DateTime(2026, 8, 5, 8).add(const Duration(minutes: 1)),
        excludeTripId: 'b',
      );
      expect(result, 1050);
    });
  });

  group('TripOdometer.rechain', () {
    test('podstawia stany poczatkowe wzdluz lancucha', () {
      final trips = [
        trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050),
        trip(id: 'b', departure: DateTime(2026, 8, 5, 8), end: 1120),
        trip(id: 'c', departure: DateTime(2026, 8, 9, 8), end: 1200),
      ];

      TripOdometer.rechain(trips, vehicleId: 'v1');

      expect(trips[1].odometerStart, 1050);
      expect(trips[2].odometerStart, 1120);
    });

    test('liczy po godzinie odjazdu, nie po kolejnosci wpisywania', () {
      // Ktos uzupelnia zaleglosci: najpierw wpisuje 9 sierpnia, potem 5.
      final trips = [
        trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050),
        trip(id: 'c', departure: DateTime(2026, 8, 9, 8), end: 1200),
        trip(id: 'b', departure: DateTime(2026, 8, 5, 8), end: 1120),
      ];

      TripOdometer.rechain(trips, vehicleId: 'v1');

      final byId = {for (final t in trips) t.id: t};
      expect(byId['b']!.odometerStart, 1050);
      expect(byId['c']!.odometerStart, 1120);
    });

    test('reczna korekta nie jest nadpisywana i wyznacza dalszy lancuch', () {
      // Ktos pojechal i nie wpisal - licznik faktyczny to 1500, nie 1050.
      final trips = [
        trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050),
        trip(id: 'b', departure: DateTime(2026, 8, 5, 8), start: 1500, end: 1560, manual: true),
        trip(id: 'c', departure: DateTime(2026, 8, 9, 8), end: 1600),
      ];

      TripOdometer.rechain(trips, vehicleId: 'v1');

      expect(trips[1].odometerStart, 1500, reason: 'reczna wartosc zostaje');
      expect(trips[2].odometerStart, 1560, reason: 'dalszy lancuch idzie od korekty');
    });

    test('zwraca tylko przejazdy, ktore faktycznie sie zmienily', () {
      final trips = [
        trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050),
        trip(id: 'b', departure: DateTime(2026, 8, 5, 8), start: 1050, end: 1120),
      ];

      final changed = TripOdometer.rechain(trips, vehicleId: 'v1');

      expect(changed, isEmpty);
    });

    test('przejazd bez stanu po powrocie nie przerywa lancucha', () {
      final trips = [
        trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050),
        trip(id: 'b', departure: DateTime(2026, 8, 5, 8), end: null),
        trip(id: 'c', departure: DateTime(2026, 8, 9, 8), end: 1200),
      ];

      TripOdometer.rechain(trips, vehicleId: 'v1');

      expect(trips[1].odometerStart, 1050);
      expect(trips[2].odometerStart, 1050,
          reason: 'nieznany powrot nie przesuwa licznika');
    });
  });

  group('VehicleTrip', () {
    test('dystans nieznany dopoki brak stanu po powrocie', () {
      final t = trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000);
      expect(t.distance, isNull);
      expect(t.isClosed, isFalse);
    });

    test('dystans z obu stanow licznika', () {
      final t = trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1042);
      expect(t.distance, 42);
      expect(t.isClosed, isTrue);
      expect(t.hasOdometerConflict, isFalse);
    });

    test('stan po mniejszy niz przed to konflikt, ale nie blokada', () {
      final t = trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 900);
      expect(t.hasOdometerConflict, isTrue);
    });

    test('trasa sklejana tylko z wypelnionych czesci', () {
      final t = VehicleTrip(
        id: 'a',
        vehicleId: 'v1',
        date: DateTime(2026, 8, 1),
        departureTime: DateTime(2026, 8, 1, 8),
        routeFrom: 'Kielno',
        routeTo: '',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
      expect(t.routeLabel, 'Kielno');
      t.routeTo = 'Gdynia';
      expect(t.routeLabel, 'Kielno – Gdynia');
    });
  });

  group('TripOdometer.distanceInMonth', () {
    test('sumuje tylko domkniete przejazdy danego pojazdu i miesiaca', () {
      final trips = [
        trip(id: 'a', departure: DateTime(2026, 8, 1, 8), start: 1000, end: 1050),
        trip(id: 'b', departure: DateTime(2026, 8, 5, 8), start: 1050, end: 1120),
        trip(id: 'c', departure: DateTime(2026, 8, 9, 8), start: 1120),
        trip(id: 'd', departure: DateTime(2026, 7, 9, 8), start: 900, end: 1000),
        trip(id: 'e', vehicleId: 'v2', departure: DateTime(2026, 8, 9, 8), start: 0, end: 500),
      ];

      final km = TripOdometer.distanceInMonth(
        trips,
        vehicleId: 'v1',
        year: 2026,
        month: 8,
      );

      expect(km, 120);
    });
  });
}
