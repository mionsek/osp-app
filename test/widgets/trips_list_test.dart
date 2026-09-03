import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/screens/trips/trips_list_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Testy ekranu ewidencji przejazdów — tego, co widać **przed** wydrukiem.
///
/// Karta drogowa idzie do gminy, więc najgorszy możliwy moment na odkrycie,
/// że pojazd nie ma wpisanych norm albo że minuty urządzeń nie doszły, to
/// spojrzenie na wydrukowaną kartkę. Te testy pilnują, żeby ekran mówił o tym
/// wcześniej.
///
/// **Dane przygotowujemy wyłącznie w `setUp`** — zapis do Hive w ciele
/// `testWidgets` kolejkuje timery w sztucznej pętli zdarzeń i test wisi bez
/// żadnego komunikatu. Dlatego wszystkie cztery pojazdy istnieją od początku,
/// a testy różnią się tym, **który wybierają** z listy na ekranie.
void main() {
  late Directory tempDir;

  /// Komplet norm — rozliczenie na karcie wyjdzie policzone.
  const withNorms = 'GBA 2.5/16';

  /// Pojazd prosto z formularza. Sekcja „Dane do karty drogowej" jest zwijana
  /// i domyślnie zamknięta, więc tak wygląda większość świeżo dodanych wozów.
  const noNorms = 'GLM 8';

  /// Brakuje dokładnie jednej normy — pracy na postoju.
  const oneNormMissing = 'SLRt 1';

  /// Pojazd bez ani jednego przejazdu w tym miesiącu.
  const noTrips = 'Quad';

  VehicleTrip trip(
    String vehicleId, {
    int equipmentMinutes = 0,
    int? idleMinutes,
  }) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, 5);
    return VehicleTrip(
      id: 'trip_$vehicleId',
      vehicleId: vehicleId,
      date: day,
      departureTime: DateTime(day.year, day.month, day.day, 10),
      returnTime: DateTime(day.year, day.month, day.day, 12),
      odometerStart: 1000,
      odometerEnd: 1042,
      odometerStartManual: true,
      idleMinutes: idleMinutes,
      equipmentUse: equipmentMinutes == 0
          ? []
          : [
              TripEquipmentUse(
                  name: SpecialEquipment.pump, minutes: equipmentMinutes)
            ],
      createdAt: day,
      updatedAt: day,
    );
  }

  setUp(() async {
    tempDir = await setUpTestHive();
    final DatabaseService db = seededDb(
      vehicles: [
        Vehicle(
          id: 'v1',
          name: withNorms,
          seats: 6,
          fuelPer100Km: 9.5,
          pumpFuelPerHour: 12,
          idleFuelPerMinute: 0.05,
          startupFuelPerMonth: 1,
        ),
        Vehicle(id: 'v2', name: noNorms, seats: 4),
        Vehicle(
          id: 'v3',
          name: oneNormMissing,
          seats: 6,
          fuelPer100Km: 9.5,
          pumpFuelPerHour: 12,
          startupFuelPerMonth: 1,
        ),
        Vehicle(
          id: 'v4',
          name: noTrips,
          seats: 2,
          fuelPer100Km: 6,
          pumpFuelPerHour: 4,
          idleFuelPerMinute: 0.02,
          startupFuelPerMonth: 1,
        ),
      ],
      config: UnitConfig(unitFullName: 'OSP Testowa', locality: 'Kielno'),
    );

    await db.addTrip(trip('v1', equipmentMinutes: 45, idleMinutes: 12));
    await db.addTrip(trip('v2'));
    await db.addTrip(trip('v3'));
    // v4 celowo bez przejazdów.
  });

  tearDown(() async => disposeTestHive(tempDir));

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(testApp(const TripsListScreen()));
    await tester.pumpAndSettle();
  }

  /// Przełącza listę rozwijaną pojazdu — jedyna interakcja różnicująca testy.
  Future<void> selectVehicle(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  group('ostrzeżenie o brakujących normach', () {
    testWidgets('pojazd bez zadnej normy ostrzega przed pustym rozliczeniem',
        (tester) async {
      await pumpScreen(tester);
      await selectVehicle(tester, noNorms);

      expect(find.textContaining('nie ma wpisanych norm zużycia paliwa'),
          findsOneWidget);
    });

    testWidgets('pojazd z kompletem norm nie ostrzega o niczym',
        (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining('norm zużycia'), findsNothing);
    });

    testWidgets('brak pojedynczej normy wymienia dokladnie ta brakujaca',
        (tester) async {
      // Wymienienie z nazwy ma znaczenie: samo „uzupełnij normy" kazałoby
      // szukać po omacku w formularzu, w którym pól jest cztery.
      await pumpScreen(tester);
      await selectVehicle(tester, oneNormMissing);

      expect(find.textContaining('Brakuje norm zużycia: pracy na postoju'),
          findsOneWidget);
    });
  });

  group('podsumowanie miesiąca', () {
    testWidgets('pokazuje minuty urzadzen i postoju', (tester) async {
      // To one wchodzą do pozycji 5 i 7 rozliczenia materiałów pędnych,
      // a dotąd widać je było dopiero na wydrukowanej karcie.
      await pumpScreen(tester);

      expect(find.text('urządzenia 45 min'), findsOneWidget);
      expect(find.text('postój 12 min'), findsOneWidget);
    });

    testWidgets('bez minut nie zasmieca podsumowania zerami', (tester) async {
      await pumpScreen(tester);
      await selectVehicle(tester, noNorms);

      expect(find.textContaining('urządzenia'), findsNothing);
      expect(find.textContaining('postój'), findsNothing);
    });
  });

  group('druk karty', () {
    testWidgets('sa trzy drogi wyjscia: system, Bluetooth i udostepnianie',
        (tester) async {
      await pumpScreen(tester);

      expect(find.byIcon(Icons.print), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('miesiac bez przejazdow pyta, zamiast blokowac druk',
        (tester) async {
      // Papierową kartę zakłada się na początku miesiąca i wypełnia długopisem,
      // więc pusty formularz jest osobną, sensowną potrzebą — ale nie chcemy
      // go wydrukować przez pomyłkę.
      await pumpScreen(tester);
      await selectVehicle(tester, noTrips);

      await tester.tap(find.byIcon(Icons.print));
      await tester.pumpAndSettle();

      expect(find.text('Miesiąc bez przejazdów'), findsOneWidget);
      expect(find.text('Drukuj pustą kartę'), findsOneWidget);

      // Nazwa miesiąca w nawiasie, nie po przyimku. `monthLabel` zwraca
      // mianownik, więc pierwsza wersja komunikatu brzmiała „W wrzesień 2026"
      // — wyszło dopiero na emulatorze.
      expect(find.textContaining('W tym miesiącu ('), findsOneWidget);

      // „Anuluj" ma naprawdę przerwać — okno znika i nic nie idzie na drukarkę.
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(find.text('Miesiąc bez przejazdów'), findsNothing);
    });
  });
}
