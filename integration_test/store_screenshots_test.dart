import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:osp_app/main.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/database_service.dart';

/// Zrzuty ekranu do sklepu Play (chore/064).
///
/// Jednostka, ratownicy i zdarzenia są **zmyślone** — w sklepie nie może być
/// prawdziwych nazwisk ani adresów. Dane trafiają prosto do bazy, a zrzuty
/// robi sterownik `test_driver/store_screenshots.dart` i zapisuje je
/// w `build/store_screenshots/`.
///
/// Uruchamianie (emulator, czyste dane, ekran 9:16 — Play przyjmuje
/// proporcje najwyżej 2:1, a emulator ma 20:9):
///
/// ```
/// adb shell pm clear pl.osp.osp_app
/// adb shell wm size 1080x1920
/// flutter drive --driver=test_driver/store_screenshots.dart \
///   --target=integration_test/store_screenshots_test.dart -d emulator-5554
/// adb shell wm size reset
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('zrzuty ekranu do sklepu', (tester) async {
    await DatabaseService.initialize();
    final db = DatabaseService();
    expect(db.getConfig().onboardingCompleted, isFalse,
        reason: 'Zrzuty wymagają czystych danych: '
            'adb shell pm clear pl.osp.osp_app');
    await _seed(db);

    runApp(const ProviderScope(child: OspApp()));
    await _settle(tester, seconds: 5);
    await binding.convertFlutterSurfaceToImage();
    await _settle(tester);

    Future<void> shot(String name, [String? location]) async {
      if (location != null) {
        GoRouter.of(tester.element(find.byType(Scaffold).first))
            .go(location);
        await _settle(tester, seconds: 3);
      }
      await binding.takeScreenshot(name);
    }

    await shot('01-ekran-glowny');
    await shot('02-wyjazdy', '/reports');
    await shot('03-szczegoly-wyjazdu', '/reports/view/r18');
    await shot('04-przekazanie-mienia', '/handovers/view/h1');
    await shot('05-ewidencja-przejazdow', '/trips');
    await shot('06-karta-pracy-sprzetu', '/equipment/card/e1');
    await shot('07-statystyki', '/statistics');
  });
}

/// `pumpAndSettle` bez wywracania testu, gdy coś kręci się w nieskończoność
/// (np. wskaźnik synchronizacji).
Future<void> _settle(WidgetTester tester, {int seconds = 2}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

DateTime _at(int month, int day, int hour, int minute) =>
    DateTime(2026, month, day, hour, minute);

Future<void> _seed(DatabaseService db) async {
  await db.saveConfig(UnitConfig(
    locality: 'Leśna Wola',
    unitStreet: 'Strażacka 3',
    onboardingCompleted: true,
  ));
  await db.dismissGettingStarted();
  await db.ensureDefaultThreats();

  final now = _at(11, 18, 8, 0);

  // --- Pojazdy i sprzęt ---
  await db.addVehicle(Vehicle(
    id: 'v1',
    name: 'GBA 2,5/16',
    seats: 6,
    make: 'Jelcz',
    kind: 'Samochód ratowniczo-gaśniczy',
    fuelType: 'ON',
    fuelPer100Km: 32,
    pumpFuelPerHour: 18,
    idleFuelPerMinute: 0.05,
    startupFuelPerMonth: 2,
    updatedAt: now,
  ));
  await db.addVehicle(Vehicle(
    id: 'v2',
    name: 'GLBA 1/8',
    seats: 6,
    make: 'Ford Transit',
    kind: 'Samochód ratowniczo-gaśniczy',
    fuelType: 'ON',
    fuelPer100Km: 14,
    pumpFuelPerHour: 6,
    idleFuelPerMinute: 0.03,
    startupFuelPerMonth: 1,
    updatedAt: now,
  ));
  await db.addEquipment(Equipment(
    id: 'e1',
    name: 'Pilarka spalinowa',
    brand: 'Stihl',
    model: 'MS 362',
    vehicleId: 'v2',
    fuelType: 'Mieszanka',
    fuelPerHour: 1.2,
    updatedAt: now,
  ));
  await db.addEquipment(Equipment(
    id: 'e2',
    name: 'Agregat prądotwórczy',
    brand: 'Honda',
    model: 'EU 22i',
    vehicleId: 'v1',
    fuelType: 'Pb95',
    fuelPerHour: 1.1,
    updatedAt: now,
  ));
  await db.addEquipment(Equipment(
    id: 'e3',
    name: 'Motopompa pływająca',
    brand: 'Niagara',
    vehicleId: 'v1',
    fuelType: 'Pb95',
    fuelPerHour: 1.5,
    updatedAt: now,
  ));

  // --- Ratownicy (zmyśleni) ---
  const people = [
    ('f1', 'Jan', 'Kowalski', true, true, false, 2027, 5),
    ('f2', 'Adam', 'Nowak', true, false, false, 2027, 2),
    ('f3', 'Piotr', 'Wiśniewski', false, false, true, 2027, 9),
    ('f4', 'Tomasz', 'Wójcik', false, false, false, 2026, 12),
    ('f5', 'Anna', 'Kamińska', false, true, true, 2027, 3),
    ('f6', 'Marek', 'Lewandowski', true, false, false, 2027, 6),
    ('f7', 'Paweł', 'Zieliński', false, false, true, 2027, 1),
    ('f8', 'Katarzyna', 'Szymańska', false, false, false, 2027, 8),
  ];
  for (final p in people) {
    await db.addFirefighter(Firefighter(
      id: p.$1,
      firstName: p.$2,
      lastName: p.$3,
      rank: '',
      isDriver: p.$4,
      isCommander: p.$5,
      isKPP: p.$6,
      medicalExamExpiry: DateTime(p.$7, p.$8, 15),
      updatedAt: now,
    ));
  }

  CrewAssignment gba() => CrewAssignment(
        vehicleId: 'v1',
        vehicleName: 'GBA 2,5/16',
        driverId: 'f2',
        commanderId: 'f1',
        crewMemberIds: ['f3', 'f4'],
      );
  CrewAssignment glba() => CrewAssignment(
        vehicleId: 'v2',
        vehicleName: 'GLBA 1/8',
        driverId: 'f6',
        commanderId: 'f5',
        crewMemberIds: ['f7', 'f8'],
      );

  // --- Wyjazdy: najnowsze opisane dokładnie, starsze tylko do statystyk ---
  final detailed = [
    ('r18', 18, 11, 17, 6, 40, 8, 5, 'Polna 7', '', 'Pożar', 'Pożar sadzy w kominie', [gba()]),
    ('r17', 17, 11, 14, 19, 12, 21, 30, '', 'Droga gminna Leśna Wola – Brzozowo', 'Miejscowe Zagrożenie', 'Powalone drzewo', [glba()]),
    ('r16', 16, 11, 9, 15, 3, 16, 20, '', 'DW 224, km 12', 'Miejscowe Zagrożenie', 'Kolizja', [gba(), glba()]),
    ('r15', 15, 11, 2, 22, 47, 23, 25, 'Leśna 14', '', 'Fałszywy Alarm', null, [gba()]),
    ('r14', 14, 10, 27, 13, 55, 18, 10, 'Ogrodowa 2', '', 'Pożar', 'Pożar budynku', [gba(), glba()]),
    ('r13', 13, 10, 19, 7, 20, 8, 15, '', 'Skrzyżowanie Polnej i Szkolnej', 'Miejscowe Zagrożenie', 'Plama ropopochodna', [glba()]),
    ('r12', 12, 10, 11, 10, 5, 13, 40, 'Łąkowa 9', '', 'Miejscowe Zagrożenie', 'Zalana posesja', [gba()]),
  ];
  for (final r in detailed) {
    final dep = _at(r.$3, r.$4, r.$5, r.$6);
    final ret = _at(r.$3, r.$4, r.$7, r.$8);
    await db.addReport(Report(
      id: r.$1,
      reportNumber: '${r.$2.toString().padLeft(4, '0')}/2026',
      year: 2026,
      date: dep,
      departureTime: dep,
      returnTime: ret,
      addressLocality: 'Leśna Wola',
      addressStreet: r.$9,
      addressDescription: r.$10,
      threatCategory: r.$11,
      threatSubtype: r.$12,
      crewAssignments: r.$13,
      operationCommanderId: r.$13.first.commanderId,
      createdAt: ret,
      updatedAt: ret,
    ));
  }
  const older = [
    (1, 1, 'Pożar', 'Pożar samochodu'),
    (2, 2, 'Miejscowe Zagrożenie', 'Powalone drzewo'),
    (3, 3, 'Pożar', 'Pożar sadzy w kominie'),
    (4, 4, 'Pożar', 'Pożar lasu'),
    (5, 4, 'Miejscowe Zagrożenie', 'Wypadek'),
    (6, 5, 'Pożar', 'Pożar lasu'),
    (7, 6, 'Miejscowe Zagrożenie', 'Zalana posesja'),
    (8, 7, 'Fałszywy Alarm', null),
    (9, 7, 'Miejscowe Zagrożenie', 'Kolizja'),
    (10, 8, 'Pożar', 'Pożar budynku'),
    (11, 9, 'Miejscowe Zagrożenie', 'Powalone drzewo'),
  ];
  for (final r in older) {
    final dep = _at(r.$2, 10 + r.$1, 14, 0);
    await db.addReport(Report(
      id: 'r${r.$1.toString().padLeft(2, '0')}',
      reportNumber: '${r.$1.toString().padLeft(4, '0')}/2026',
      year: 2026,
      date: dep,
      departureTime: dep,
      returnTime: dep.add(const Duration(hours: 1, minutes: 35)),
      addressLocality: 'Leśna Wola',
      threatCategory: r.$3,
      threatSubtype: r.$4,
      crewAssignments: [r.$1.isEven ? glba() : gba()],
      operationCommanderId: r.$1.isEven ? 'f5' : 'f1',
      createdAt: dep,
      updatedAt: dep,
    ));
  }

  // --- Przekazanie mienia po pożarze budynku ---
  await db.addHandover(PropertyHandover(
    id: 'h1',
    reportId: 'r14',
    eventLocation: 'Leśna Wola, ul. Ogrodowa 2',
    eventDate: _at(10, 27, 13, 55),
    eventTime: _at(10, 27, 13, 55),
    recipientType: 'Właściciel',
    recipientName: 'Stefan Malinowski',
    recipientAddress: 'Leśna Wola, ul. Ogrodowa 2',
    recipientPhone: '500 100 200',
    propertyKind: 'Obiekt',
    propertyDescription:
        'Budynek gospodarczy po pożarze, dach częściowo spalony, '
        'pogorzelisko przelane wodą i sprawdzone kamerą termowizyjną.',
    handoverFirefighterId: 'f1',
    signLocality: 'Leśna Wola',
    signDate: _at(10, 27, 18, 0),
    createdAt: _at(10, 27, 18, 5),
    updatedAt: _at(10, 27, 18, 5),
  ));

  // --- Ewidencja: przejazdy z wyjazdów i dwa gospodarcze ---
  await db.addTrip(VehicleTrip(
    id: 't-cw',
    vehicleId: 'v1',
    date: _at(11, 7, 9, 0),
    departureTime: _at(11, 7, 9, 0),
    returnTime: _at(11, 7, 12, 30),
    routeFrom: 'Leśna Wola, Strażacka 3',
    routeTo: 'Brzozowo, zbiornik p.poż.',
    purpose: 'Ćwiczenia',
    driverName: 'Nowak Adam',
    driverId: 'f2',
    dispatcherName: 'Kowalski Jan',
    specialEquipmentMinutes: 45,
    createdAt: _at(11, 7, 12, 40),
    updatedAt: _at(11, 7, 12, 40),
  ));
  await db.addTrip(VehicleTrip(
    id: 't-tank',
    vehicleId: 'v1',
    date: _at(11, 12, 17, 0),
    departureTime: _at(11, 12, 17, 0),
    returnTime: _at(11, 12, 17, 45),
    routeFrom: 'Leśna Wola, Strażacka 3',
    routeTo: 'Stacja paliw, Brzozowo',
    purpose: 'Tankowanie',
    driverName: 'Lewandowski Marek',
    driverId: 'f6',
    dispatcherName: 'Kowalski Jan',
    createdAt: _at(11, 12, 17, 50),
    updatedAt: _at(11, 12, 17, 50),
  ));
  await db.backfillTripsFromReports(
    stationAddress: db.getConfig().stationAddress,
  );
  final odometer = {'v1': 48210, 'v2': 112730};
  final trips = db.getAllTrips()
    ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
  for (final trip in trips) {
    final start = odometer[trip.vehicleId]!;
    final end = start + 6 + (trip.id.hashCode % 19).abs();
    trip.odometerStart = start;
    trip.odometerEnd = end;
    odometer[trip.vehicleId] = end;
    await db.updateTrip(trip);
  }

  // --- Karta pracy pilarki ---
  for (final w in [
    ('w1', 11, 14, 85, 'Powalone drzewo, droga gminna', 'Zieliński Paweł', 'f7'),
    ('w2', 11, 3, 10, '', 'Zieliński Paweł', 'f7'),
    ('w3', 10, 8, 40, 'Ćwiczenia', 'Szymańska Katarzyna', 'f8'),
  ]) {
    await db.addEquipmentWork(EquipmentWork(
      id: w.$1,
      equipmentId: 'e1',
      equipmentName: 'Pilarka spalinowa',
      date: _at(w.$2, w.$3, 12, 0),
      minutes: w.$4,
      isStartup: w.$5.isEmpty,
      purpose: w.$5,
      operatorName: w.$6,
      operatorId: w.$7,
      createdAt: _at(w.$2, w.$3, 12, 0),
      updatedAt: _at(w.$2, w.$3, 12, 0),
    ));
  }
}
