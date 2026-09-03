import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/core/constants/handover_recipient_types.dart';
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
          'equipmentUse',
        },
      );
    });
  });

  group('Report', () {
    Report sample() => Report(
          id: 'r1',
          reportNumber: '12/2026',
          year: 2026,
          date: DateTime(2026, 8, 10),
          departureTime: DateTime(2026, 8, 10, 14, 30),
          returnTime: DateTime(2026, 8, 10, 16, 5),
          addressLocality: 'Kielno',
          addressStreet: 'Oliwska 12',
          addressDescription: 'Budynek gospodarczy za posesją',
          threatCategory: 'Pożar',
          threatSubtype: 'Pożar budynku',
          crewAssignments: [
            CrewAssignment(
              vehicleId: 'v1',
              vehicleName: 'GBA 2.5/16',
              driverId: 'ff1',
              commanderId: 'ff2',
              crewMemberIds: ['ff3', 'ff4'],
            ),
            CrewAssignment(vehicleId: 'v2', vehicleName: 'GLM 8'),
          ],
          operationCommanderId: 'ff2',
          notes: 'Podano jeden prąd wody',
          createdAt: DateTime(2026, 8, 10, 17),
          updatedAt: DateTime(2026, 8, 11, 9),
          createdBy: 'ospkielno@gmail.com',
        );

    test('komplet danych przezywa zapis i odczyt', () {
      final r = sample();
      final back =
          SyncService.reportFromJson(roundTrip(SyncService.reportToJson(r)));

      expect(back.id, r.id);
      expect(back.reportNumber, r.reportNumber);
      expect(back.year, r.year);
      expect(back.date, r.date);
      expect(back.departureTime, r.departureTime);
      expect(back.returnTime, r.returnTime);
      expect(back.addressLocality, r.addressLocality);
      expect(back.addressStreet, r.addressStreet);
      expect(back.addressDescription, r.addressDescription);
      expect(back.threatCategory, r.threatCategory);
      expect(back.threatSubtype, r.threatSubtype);
      expect(back.operationCommanderId, r.operationCommanderId);
      expect(back.notes, r.notes);
      expect(back.createdAt, r.createdAt);
      expect(back.updatedAt, r.updatedAt);
      expect(back.createdBy, r.createdBy);
    });

    test('sklad zastepow przezywa razem z raportem', () {
      // Zastępy to zagnieżdżona lista z własnym mapowaniem, więc mają własny
      // sposób na ciche zgubienie danych — np. przy dopisaniu miejsca w wozie.
      final back = SyncService.reportFromJson(
          roundTrip(SyncService.reportToJson(sample())));

      expect(back.crewAssignments, hasLength(2));
      expect(back.crewAssignments[0].vehicleName, 'GBA 2.5/16');
      expect(back.crewAssignments[0].driverId, 'ff1');
      expect(back.crewAssignments[0].commanderId, 'ff2');
      expect(back.crewAssignments[0].crewMemberIds, ['ff3', 'ff4']);
      // Drugi wóz wyjechał bez obsady — puste pola mają zostać puste,
      // a nie przejąć wartości pierwszego zastępu.
      expect(back.crewAssignments[1].driverId, isNull);
      expect(back.crewAssignments[1].commanderId, isNull);
      expect(back.crewAssignments[1].crewMemberIds, isEmpty);
      expect(back.totalFirefighters, 4);
    });

    test('wyjazd bez zakonczenia: puste pola zostaja puste', () {
      final r = sample()
        ..returnTime = null
        ..threatSubtype = null
        ..operationCommanderId = null
        ..notes = null;

      final back =
          SyncService.reportFromJson(roundTrip(SyncService.reportToJson(r)));

      expect(back.returnTime, isNull);
      expect(back.threatSubtype, isNull);
      expect(back.operationCommanderId, isNull);
      expect(back.notes, isNull);
    });

    test('raport ze starszej wersji (bez adresu opisowego i autora)', () {
      // Na Dysku jednostki leżą pliki zapisane każdą wcześniejszą wersją
      // aplikacji. Odczyt ma się udać, a brakujące pola przyjąć wartości
      // domyślne — nie wysypać synchronizacji u kolegi.
      final old = {
        'id': 'r_old',
        'reportNumber': '3/2025',
        'year': 2025,
        'date': DateTime(2025, 3, 4).toIso8601String(),
        'departureTime': DateTime(2025, 3, 4, 11).toIso8601String(),
        'addressLocality': 'Kielno',
        'threatCategory': 'Miejscowe zagrożenie',
        'createdAt': DateTime(2025, 3, 4).toIso8601String(),
        'updatedAt': DateTime(2025, 3, 4).toIso8601String(),
      };

      final back = SyncService.reportFromJson(old);

      expect(back.id, 'r_old');
      expect(back.addressStreet, '');
      expect(back.addressDescription, '');
      expect(back.createdBy, '');
      expect(back.crewAssignments, isEmpty);
      expect(back.returnTime, isNull);
    });

    test('zapisany JSON zawiera wszystkie pola modelu', () {
      final json = SyncService.reportToJson(sample());

      expect(
        json.keys.toSet(),
        {
          'id', 'reportNumber', 'year', 'date', 'departureTime', 'returnTime',
          'addressLocality', 'addressStreet', 'addressDescription',
          'threatCategory', 'threatSubtype', 'crewAssignments',
          'operationCommanderId', 'notes', 'createdAt', 'updatedAt',
          'createdBy', 'syncStatus',
        },
      );
    });

    test('zapis na Dysk oznacza raport jako zsynchronizowany', () {
      // Plik leżący na Dysku jest z definicji zsynchronizowany, niezależnie
      // od tego, w jakim stanie był lokalnie w chwili wysyłki.
      final r = sample()..syncStatus = 'local';
      expect(SyncService.reportToJson(r)['syncStatus'], 'synced');
    });
  });

  group('PropertyHandover', () {
    PropertyHandover sample() => PropertyHandover(
          id: 'h1',
          reportId: 'r1',
          eventLocation: 'Kielno, Oliwska 12',
          eventDate: DateTime(2026, 8, 10),
          eventTime: DateTime(2026, 8, 10, 16, 30),
          recipientType: HandoverRecipientTypes.owner,
          recipientName: 'Kowalski Jan',
          recipientAddress: 'Oliwska 12, Kielno',
          recipientPhone: '600100200',
          propertyDescription: 'Budynek gospodarczy, dach częściowo spalony',
          propertyKind: 'obiekt',
          notes: 'Zabezpieczono instalację elektryczną',
          handoverFirefighterId: 'ff2',
          signLocality: 'Kielno',
          signDate: DateTime(2026, 8, 10),
          createdAt: DateTime(2026, 8, 10, 17),
          updatedAt: DateTime(2026, 8, 11, 9),
          createdBy: 'ospkielno@gmail.com',
        );

    test('komplet danych przezywa zapis i odczyt', () {
      final h = sample();
      final back = SyncService.handoverFromJson(
          roundTrip(SyncService.handoverToJson(h)));

      expect(back.id, h.id);
      expect(back.reportId, h.reportId);
      expect(back.eventLocation, h.eventLocation);
      expect(back.eventDate, h.eventDate);
      expect(back.eventTime, h.eventTime);
      expect(back.recipientType, h.recipientType);
      expect(back.recipientName, h.recipientName);
      expect(back.recipientAddress, h.recipientAddress);
      expect(back.recipientPhone, h.recipientPhone);
      expect(back.propertyDescription, h.propertyDescription);
      expect(back.propertyKind, h.propertyKind);
      expect(back.notes, h.notes);
      expect(back.handoverFirefighterId, h.handoverFirefighterId);
      expect(back.signLocality, h.signLocality);
      expect(back.signDate, h.signDate);
      expect(back.createdAt, h.createdAt);
      expect(back.updatedAt, h.updatedAt);
      expect(back.createdBy, h.createdBy);
    });

    test('podmiot spoza listy zamknietej: wlasny opis przezywa', () {
      // Pozycja „Inne" z dodatkowym polem — gdyby zginęła, druk pokazałby
      // przekazanie komuś bez nazwy rodzaju podmiotu.
      final h = sample()
        ..recipientType = HandoverRecipientTypes.other
        ..recipientTypeOther = 'zarządca drogi powiatowej';

      final back = SyncService.handoverFromJson(
          roundTrip(SyncService.handoverToJson(h)));

      expect(back.recipientType, HandoverRecipientTypes.other);
      expect(back.recipientTypeOther, 'zarządca drogi powiatowej');
    });

    test('przekazanie bez wyjazdu i uwag: puste pola zostaja puste', () {
      final h = sample()
        ..reportId = null
        ..notes = null
        ..propertyKind = null
        ..handoverFirefighterId = null;

      final back = SyncService.handoverFromJson(
          roundTrip(SyncService.handoverToJson(h)));

      expect(back.reportId, isNull);
      expect(back.notes, isNull);
      expect(back.propertyKind, isNull);
      expect(back.handoverFirefighterId, isNull);
    });

    test('przekazanie ze starszej wersji (bez rodzaju mienia i miejscowosci)',
        () {
      final old = {
        'id': 'h_old',
        'eventDate': DateTime(2025, 5, 1).toIso8601String(),
        'eventTime': DateTime(2025, 5, 1, 12).toIso8601String(),
        'signDate': DateTime(2025, 5, 1).toIso8601String(),
        'createdAt': DateTime(2025, 5, 1).toIso8601String(),
        'updatedAt': DateTime(2025, 5, 1).toIso8601String(),
      };

      final back = SyncService.handoverFromJson(old);

      expect(back.id, 'h_old');
      expect(back.eventLocation, '');
      expect(back.recipientName, '');
      expect(back.propertyDescription, '');
      expect(back.signLocality, '');
      expect(back.createdBy, '');
      expect(back.propertyKind, isNull);
    });

    test('zapisany JSON zawiera wszystkie pola modelu', () {
      final json = SyncService.handoverToJson(sample());

      expect(
        json.keys.toSet(),
        {
          'id', 'reportId', 'eventLocation', 'eventDate', 'eventTime',
          'recipientType', 'recipientTypeOther', 'recipientName',
          'recipientAddress', 'recipientPhone', 'propertyDescription',
          'propertyKind', 'notes', 'handoverFirefighterId', 'signLocality',
          'signDate', 'createdAt', 'updatedAt', 'createdBy', 'syncStatus',
        },
      );
    });
  });

  group('CrewAssignment', () {
    test('zapisany JSON zawiera wszystkie pola modelu', () {
      final json = SyncService.crewToJson(CrewAssignment(
        vehicleId: 'v1',
        vehicleName: 'GBA 2.5/16',
        driverId: 'ff1',
        commanderId: 'ff2',
        crewMemberIds: ['ff3'],
      ));

      expect(
        json.keys.toSet(),
        {
          'vehicleId', 'vehicleName', 'driverId', 'commanderId',
          'crewMemberIds',
        },
      );
    });

    test('zastep ze starszej wersji bez listy zalogi', () {
      final back = SyncService.crewFromJson({
        'vehicleId': 'v1',
        'vehicleName': 'GLM 8',
      });

      expect(back.driverId, isNull);
      expect(back.commanderId, isNull);
      expect(back.crewMemberIds, isEmpty);
    });
  });
}
