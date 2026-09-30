import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/providers/statistics_provider.dart';
import 'package:osp_app/services/handover_pdf.dart';
import 'package:osp_app/services/report_pdf.dart';
import 'package:osp_app/services/stats_pdf.dart';
import 'package:osp_app/services/trip_card_pdf.dart';

/// Generowanie wszystkich czterech dokumentów — dotąd żaden nie miał testu.
///
/// Test przechodzi bez sieci, więc przy okazji pilnuje, że czcionki są
/// w paczce aplikacji: wcześniej pobierały się z internetu i bez zasięgu nie
/// drukowało się nic. W testach asercje biblioteki `pdf` są włączone, więc
/// łapią też układ, który nie mieści się na stronie.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Liczba stron — po znacznikach `/Type /Page` (bez `/Pages`).
  int pageCount(List<int> bytes) => RegExp(r'/Type\s*/Page(?!s)')
      .allMatches(latin1.decode(bytes, allowInvalid: true))
      .length;

  final config = UnitConfig(
    unitFullName: 'Ochotnicza Straż Pożarna w Kielnie',
    locality: 'Kielno',
    unitStreet: 'Oliwska 12',
  );
  final ff = Firefighter(
      id: 'f1', firstName: 'Łukasz', lastName: 'Żółkiewski', rank: 'dh');
  final vehicle = Vehicle(
    id: 'v1',
    name: 'GBA 2.5/16',
    seats: 6,
    make: 'MAN',
    plate: 'GWE 12345',
    fuelPer100Km: 30,
    pumpFuelPerHour: 12,
    idleFuelPerMinute: 0.05,
    startupFuelPerMonth: 1,
  );
  final report = Report(
    id: 'r1',
    reportNumber: '0001/2026',
    year: 2026,
    date: DateTime(2026, 8, 10),
    departureTime: DateTime(2026, 8, 10, 14, 30),
    returnTime: DateTime(2026, 8, 10, 16, 0),
    addressLocality: 'Żukowo',
    addressStreet: 'Gdańska 1',
    addressDescription: '',
    threatCategory: 'Pożar',
    crewAssignments: [
      CrewAssignment(
          vehicleId: 'v1', vehicleName: 'GBA 2.5/16', driverId: 'f1'),
    ],
    createdAt: DateTime(2026, 8, 10),
    updatedAt: DateTime(2026, 8, 10),
  );

  VehicleTrip trip(int day) => VehicleTrip(
        id: 'trip_$day',
        vehicleId: 'v1',
        date: DateTime(2026, 8, day),
        departureTime: DateTime(2026, 8, day, 8, 0),
        returnTime: DateTime(2026, 8, day, 10, 0),
        routeFrom: 'Kielno, Oliwska 12',
        routeTo: 'Szemud',
        driverName: 'Żółkiewski Łukasz',
        dispatcherName: 'Nowak Adam',
        odometerStart: 1000 + day * 10,
        odometerEnd: 1010 + day * 10,
        equipmentUse: [TripEquipmentUse(name: 'Autopompa', minutes: 30)],
        idleMinutes: 5,
        createdAt: DateTime(2026, 8, day),
        updatedAt: DateTime(2026, 8, day),
      );

  test('potwierdzenie udzialu', () async {
    final bytes = await ReportPdf.bytes(report, config, [ff]);
    expect(pageCount(bytes), 1);
  });

  test('przekazanie mienia', () async {
    final handover = PropertyHandover(
      id: 'h1',
      eventLocation: 'Żukowo, Gdańska 1',
      eventDate: DateTime(2026, 8, 10),
      eventTime: DateTime(2026, 8, 10, 16, 30),
      recipientName: 'Jan Kowalski',
      propertyDescription: 'Budynek mieszkalny',
      signLocality: 'Żukowo',
      signDate: DateTime(2026, 8, 10),
      createdAt: DateTime(2026, 8, 10),
      updatedAt: DateTime(2026, 8, 10),
    );
    final bytes = await HandoverPdf.bytes(handover, config, ff);
    expect(pageCount(bytes), 1);
  });

  test('statystyki roczne', () async {
    final stats = computeYearStats([report], [ff], 2026);
    final bytes = await StatsPdf.bytes(stats, config);
    expect(pageCount(bytes), greaterThanOrEqualTo(1));
  });

  group('karta drogowa', () {
    test('pusta karta — dwie strony: przejazdy i rozliczenie', () async {
      final bytes = await TripCardPdf.bytes(
          trips: const [], vehicle: vehicle, config: config, year: 2026, month: 8);
      expect(pageCount(bytes), 2);
    });

    test('pojazd bez norm', () async {
      final bytes = await TripCardPdf.bytes(
          trips: [trip(3)],
          vehicle: Vehicle(id: 'v1', name: 'GLM', seats: 3),
          config: config,
          year: 2026,
          month: 8);
      expect(pageCount(bytes), 2);
    });

    test('pelny miesiac przejazdow przechodzi na kolejne strony', () async {
      final bytes = await TripCardPdf.bytes(
          trips: [for (var d = 1; d <= 28; d++) trip(d)],
          vehicle: vehicle,
          config: config,
          year: 2026,
          month: 8);
      expect(pageCount(bytes), greaterThanOrEqualTo(3));
    });
  });
}
