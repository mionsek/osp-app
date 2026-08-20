import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/sync_service.dart';

/// Testy serializacji na Dysk Google.
///
/// Dotąd nietestowane, a to najbardziej krucha część synchronizacji: przy
/// każdym dodaniu pola do modelu trzeba pamiętać o dopisaniu go **i** do
/// zapisu, **i** do odczytu. Nic tego nie wymusza, a pominięcie objawia się
/// dopiero u kolegi, któremu dane wrócą niekompletne — najgorszy możliwy
/// moment na wykrycie błędu.
///
/// Testy przechodzą przez prawdziwy `jsonEncode`/`jsonDecode`, bo zapis na
/// Dysk też przez nie przechodzi: dzięki temu wyjdą typy, których JSON nie
/// przenosi (np. `DateTime` bez konwersji na tekst).
void main() {
  Map<String, dynamic> roundTrip(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  group('Vehicle', () {
    test('komplet danych przezywa zapis i odczyt', () {
      final v = Vehicle(
        id: 'v1',
        name: 'GBA 2.5/16',
        seats: 6,
        make: 'MITSUBISHI',
        model: 'L200',
        kind: 'SLRr',
        plate: 'GWE 2998X',
        operationalNumber: '341[G]24',
        fuelType: 'ON',
        fuelPer100Km: 9.5,
        pumpFuelPerHour: 12,
        idleFuelPerMinute: 0.05,
        startupFuelPerMonth: 1,
      );

      final back = SyncService.vehicleFromJson(
          roundTrip(SyncService.vehicleToJson(v)));

      expect(back.id, v.id);
      expect(back.name, v.name);
      expect(back.seats, v.seats);
      expect(back.make, v.make);
      expect(back.model, v.model);
      expect(back.kind, v.kind);
      expect(back.plate, v.plate);
      expect(back.operationalNumber, v.operationalNumber);
      expect(back.fuelType, v.fuelType);
      expect(back.fuelPer100Km, v.fuelPer100Km);
      expect(back.pumpFuelPerHour, v.pumpFuelPerHour);
      expect(back.idleFuelPerMinute, v.idleFuelPerMinute);
      expect(back.startupFuelPerMonth, v.startupFuelPerMonth);
    });

    test('pojazd ze starszej wersji (bez danych karty) wczytuje sie', () {
      // Tak wygląda plik zapisany przed feature/033 — brakuje wszystkich
      // nowych pól. Odczyt nie może się na tym wywrócić.
      final old = {'id': 'v1', 'name': 'GBA', 'seats': 6};

      final back = SyncService.vehicleFromJson(old);

      expect(back.name, 'GBA');
      expect(back.make, '');
      expect(back.fuelPer100Km, isNull);
    });
  });

  group('VehicleTrip', () {
    VehicleTrip sample() => VehicleTrip(
          id: 'trip_1',
          vehicleId: 'v1',
          date: DateTime(2026, 8, 10),
          dispatcherName: 'Nowak Adam',
          routeFrom: 'Kielno, Oliwska 12',
          routeTo: 'Gdynia',
          purpose: TripPurposes.alarm,
          driverName: 'Kowalski Jan',
          driverId: 'f1',
          departureTime: DateTime(2026, 8, 10, 14, 30),
          returnTime: DateTime(2026, 8, 10, 16, 0),
          odometerStart: 1000,
          odometerEnd: 1042,
          odometerStartManual: true,
          specialEquipmentMinutes: 25,
          idleMinutes: 12,
          extras: 'dodatek zimowy',
          notes: 'autopompa',
          reportId: 'r1',
          createdAt: DateTime(2026, 8, 10, 9),
          updatedAt: DateTime(2026, 8, 10, 18),
          createdBy: 'a@b.pl',
        );

    test('komplet danych przezywa zapis i odczyt', () {
      final t = sample();

      final back =
          SyncService.tripFromJson(roundTrip(SyncService.tripToJson(t)));

      expect(back.id, t.id);
      expect(back.vehicleId, t.vehicleId);
      expect(back.date, t.date);
      expect(back.dispatcherName, t.dispatcherName);
      expect(back.routeFrom, t.routeFrom);
      expect(back.routeTo, t.routeTo);
      expect(back.purpose, t.purpose);
      expect(back.driverName, t.driverName);
      expect(back.driverId, t.driverId);
      expect(back.departureTime, t.departureTime);
      expect(back.returnTime, t.returnTime);
      expect(back.odometerStart, t.odometerStart);
      expect(back.odometerEnd, t.odometerEnd);
      expect(back.odometerStartManual, t.odometerStartManual);
      expect(back.specialEquipmentMinutes, t.specialEquipmentMinutes);
      expect(back.idleMinutes, t.idleMinutes);
      expect(back.extras, t.extras);
      expect(back.notes, t.notes);
      expect(back.reportId, t.reportId);
      expect(back.createdAt, t.createdAt);
      expect(back.updatedAt, t.updatedAt);
      expect(back.createdBy, t.createdBy);
    });

    test('przejazd niedokonczony: puste pola zostaja puste', () {
      final t = sample()
        ..returnTime = null
        ..odometerEnd = null
        ..specialEquipmentMinutes = null
        ..idleMinutes = null
        ..notes = null
        ..reportId = null;

      final back =
          SyncService.tripFromJson(roundTrip(SyncService.tripToJson(t)));

      expect(back.returnTime, isNull);
      expect(back.odometerEnd, isNull);
      expect(back.specialEquipmentMinutes, isNull);
      expect(back.idleMinutes, isNull);
      expect(back.notes, isNull);
      expect(back.reportId, isNull);
    });

    test('przejazd ze starszej wersji (bez dodatkow i postoju)', () {
      final old = {
        'id': 'trip_1',
        'vehicleId': 'v1',
        'date': DateTime(2026, 8, 10).toIso8601String(),
        'departureTime': DateTime(2026, 8, 10, 14, 30).toIso8601String(),
        'createdAt': DateTime(2026, 8, 10).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 10).toIso8601String(),
      };

      final back = SyncService.tripFromJson(old);

      expect(back.id, 'trip_1');
      expect(back.extras, '');
      expect(back.idleMinutes, isNull);
      expect(back.purpose, TripPurposes.economic);
    });

    test('zapisany JSON zawiera wszystkie pola modelu', () {
      // Strażnik przed najczęstszym błędem: dodaniem pola do modelu
      // i zapomnieniem o mapowaniu. Lista jest ręczna, ale zmiana modelu
      // bez zmiany tej listy oznacza świadomą decyzję, a nie przeoczenie.
      final json = SyncService.tripToJson(sample());

      expect(
        json.keys.toSet(),
        {
          'id', 'vehicleId', 'date', 'dispatcherName', 'routeFrom', 'routeTo',
          'purpose', 'driverName', 'driverId', 'departureTime', 'returnTime',
          'odometerStart', 'odometerEnd', 'odometerStartManual',
          'specialEquipmentMinutes', 'idleMinutes', 'extras', 'notes',
          'reportId', 'createdAt', 'updatedAt', 'createdBy', 'syncStatus',
        },
      );
    });
  });
}
