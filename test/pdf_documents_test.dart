import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/providers/statistics_provider.dart';
import 'package:osp_app/services/equipment_card.dart';
import 'package:osp_app/services/card_sheet.dart';
import 'package:osp_app/services/equipment_card_sheet.dart';
import 'package:osp_app/services/handover_pdf.dart';
import 'package:osp_app/services/report_pdf.dart';
import 'package:osp_app/services/stats_pdf.dart';
import 'package:osp_app/services/trip_card.dart';

/// Generowanie wszystkich dokumentów — dotąd żaden nie miał testu.
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

  Future<List<int>> cardPdf(List<CardPage> pages) =>
      CardSheet.pdf(pages, title: 'Karty', author: 'OSP');

  group('karta drogowa — kartka składana na pół', () {
    test('pusta karta — strona zewnętrzna i wewnętrzna', () async {
      final bytes = await cardPdf(TripCard.pages(
          trips: const [], vehicle: vehicle, config: config, year: 2026, month: 8));
      expect(pageCount(bytes), 2);
    });

    test('pojazd bez norm', () async {
      final bytes = await cardPdf(TripCard.pages(
          trips: [trip(3)],
          vehicle: Vehicle(id: 'v1', name: 'GLM', seats: 3),
          config: config,
          year: 2026,
          month: 8));
      expect(pageCount(bytes), 2);
    });

    test('więcej niż 12 przejazdów — kolejne strony wewnętrzne', () async {
      final bytes = await cardPdf(TripCard.pages(
          trips: [for (var d = 1; d <= 28; d++) trip(d)],
          vehicle: vehicle,
          config: config,
          year: 2026,
          month: 8));
      // 56 wierszy po 24 na stronę: okładka + 3 strony przejazdów.
      expect(pageCount(bytes), 4);
    });
  });

  group('karta pracy sprzętu — dwie A5 na kartce', () {
    final niagara = Equipment(
      id: 'e1',
      name: 'Motopompa pływająca',
      brand: 'Niagara',
      model: 'GXV160KN/5',
      fuelType: EquipmentFuel.petrol,
      fuelPerHour: 2,
    );
    EquipmentCardRow row(int day, {bool startup = false}) => EquipmentCardRow(
          date: DateTime(2026, 11, day, 14),
          operatorName: 'Żółkiewski Łukasz',
          minutes: startup ? 15 : 45,
          purpose: startup
              ? EquipmentWork.startupPurpose
              : 'Miejscowe zagrożenie, Żukowo — wypompowanie wody z piwnicy',
          isStartup: startup,
        );
    Future<List<int>> cards(List<(Equipment, List<EquipmentCardRow>)> c) =>
        cardPdf(EquipmentCardSheet.pages(
            cards: c, config: config, year: 2026, month: 11));

    test('jedno urządzenie — przód i tył kartki', () async {
      expect(pageCount(await cards([(niagara, const [])])), 2);
    });

    test('dwa urządzenia na jednej kartce, trzecie na następnej', () async {
      final pila = Equipment(id: 'e2', name: 'Pilarka');
      expect(pageCount(await cards([(niagara, const []), (pila, const [])])), 2);
      expect(
          pageCount(await cards(
              [(niagara, const []), (pila, const []), (niagara, const [])])),
          4);
    });

    test('sprzęt bez normy, rodzaju paliwa i marki; dużo wpisów', () async {
      final bytes = await cards([
        (Equipment(id: 'e2', name: 'Pilarka'), [row(1, startup: true), row(3)]),
        (niagara, [for (var i = 0; i < 45; i++) row(1 + i % 28, startup: i.isOdd)]),
      ]);
      expect(pageCount(bytes), 2, reason: 'wpisy gęściej, bez nowej kartki');
    });
  });
}
