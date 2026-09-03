import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/screens/trips/trip_form_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Testy formularza przejazdu — łańcuch licznika **w interfejsie**.
///
/// `TripOdometer` ma 15 testów jednostkowych, a `DatabaseService` kolejne 14,
/// więc sam łańcuch jest policzony i sprawdzony. Nie było natomiast żadnego
/// testu na to, czy formularz **pokazuje** podstawiony stan, czy kłódka
/// faktycznie odblokowuje pole i czy podgląd przejechanych kilometrów zgadza
/// się z tym, co pójdzie do zapisu. Dwa błędy z feature/026 dotyczyły dokładnie
/// tej warstwy i wyszły dopiero na emulatorze.
///
/// **Dane przygotowujemy wyłącznie w `setUp`.** Ciało `testWidgets` biegnie
/// w sztucznej pętli zdarzeń, a zapis do Hive kolejkuje tam timery, których
/// `pumpAndSettle` nigdy nie wyczerpie — test wisi bez żadnego komunikatu.
/// Stąd dwa pojazdy: `v1` ma historię przejazdów, `v2` jest fabrycznie nowy.
void main() {
  late Directory tempDir;
  late DatabaseService db;

  /// Pojazd z historią — stan po ostatnim przejeździe to 1042 km.
  const withHistory = 'v1';

  /// Pojazd bez ani jednego przejazdu — łańcuch nie ma się o co zaczepić.
  const brandNew = 'v2';

  setUp(() async {
    tempDir = await setUpTestHive();
    db = seededDb(
      vehicles: [
        Vehicle(id: withHistory, name: 'GBA 2.5/16', seats: 6),
        Vehicle(id: brandNew, name: 'GLM 8', seats: 4),
      ],
      firefighters: [firefighter('ff1', 'Jan', 'Kowalski', isDriver: true)],
      config: UnitConfig(
        unitFullName: 'OSP Testowa',
        locality: 'Kielno',
        unitStreet: 'Oliwska 12',
        onboardingCompleted: true,
      ),
    );

    await db.addTrip(VehicleTrip(
      id: 'trip_0',
      vehicleId: withHistory,
      date: DateTime(2026, 8, 9),
      departureTime: DateTime(2026, 8, 9, 10, 0),
      returnTime: DateTime(2026, 8, 9, 11, 0),
      odometerStart: 1000,
      odometerEnd: 1042,
      odometerStartManual: true,
      createdAt: DateTime(2026, 8, 9),
      updatedAt: DateTime(2026, 8, 9),
    ));
  });

  tearDown(() async => disposeTestHive(tempDir));

  Future<void> pumpForm(WidgetTester tester,
      {String vehicleId = withHistory}) async {
    // Domyślne okno testowe to 800×600 — formularz przejazdu jest znacznie
    // dłuższy, więc `ensureVisible` przewijało cel pod pasek tytułu i kliknięcia
    // trafiały w `AppBar` zamiast w przycisk. Wymiary telefonu, na którym
    // aplikacja realnie chodzi, mieszczą całość i usuwają problem u źródła.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
        testApp(TripFormScreen(initialVehicleId: vehicleId)));
    await tester.pumpAndSettle();
  }

  Future<void> enterInto(
      WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field.first);
    await tester.enterText(field.first, value);
    await tester.pumpAndSettle();
  }

  group('łańcuch licznika', () {
    testWidgets('pierwszy przejazd pojazdu pyta o obie liczby', (tester) async {
      await pumpForm(tester, vehicleId: brandNew);

      // Brak poprzednika, więc „przed wyjazdem" jest zwykłym polem
      // do wpisania, a nie zablokowaną wartością z łańcucha.
      expect(
        find.text(
            'Pierwszy przejazd tego pojazdu — przy kolejnych podstawi się sam'),
        findsOneWidget,
      );
      expect(find.text('Stan po poprzednim przejeździe tego pojazdu'),
          findsNothing);
    });

    testWidgets('kolejny przejazd podstawia stan z poprzedniego',
        (tester) async {
      await pumpForm(tester);

      expect(find.text('1042'), findsOneWidget);
      expect(find.text('Stan po poprzednim przejeździe tego pojazdu'),
          findsOneWidget);
      // Kłódka — pole jest zablokowane do czasu świadomej poprawki.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('kłódka odblokowuje pole i wstawia wartosc z lancucha',
        (tester) async {
      // Pominięty przejazd rozjeżdża licznik do końca miesiąca, więc musi
      // istnieć droga do ręcznej korekty — ale świadoma, nie przypadkiem.
      await pumpForm(tester);

      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();

      expect(find.text('Stan po poprzednim przejeździe tego pojazdu'),
          findsNothing);
      expect(
        find.text('Wpisany ręcznie — zamiast stanu z poprzedniego przejazdu'),
        findsOneWidget,
      );
      // Wartość z łańcucha zostaje jako punkt wyjścia do poprawki.
      expect(find.widgetWithText(TextFormField, '1042'), findsOneWidget);
    });

    testWidgets('powrot do wartosci z lancucha cofa reczna korekte',
        (tester) async {
      await pumpForm(tester);
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      expect(find.text('Stan po poprzednim przejeździe tego pojazdu'),
          findsOneWidget);
      expect(find.text('1042'), findsOneWidget);
    });
  });

  group('podgląd przejechanych kilometrów', () {
    testWidgets('liczy od stanu podstawionego z lancucha', (tester) async {
      await pumpForm(tester);

      await enterInto(tester, 'Po powrocie (km)', '1100');

      expect(find.text('Przejechano 58 km'), findsOneWidget);
    });

    testWidgets('liczy takze przy pierwszym przejezdzie pojazdu',
        (tester) async {
      // Błąd z feature/026: przy pierwszym przejeździe podgląd nie działał,
      // bo liczył stan początkowy z łańcucha (`null`) zamiast z liczby
      // wpisanej ręcznie — flaga „ręcznie" jest wtedy jeszcze `false`.
      await pumpForm(tester, vehicleId: brandNew);

      await enterInto(tester, 'Przed wyjazdem (km)', '2000');
      await enterInto(tester, 'Po powrocie (km)', '2042');

      expect(find.text('Przejechano 42 km'), findsOneWidget);
    });

    testWidgets('ostrzega, gdy licznik po powrocie jest mniejszy',
        (tester) async {
      // Ostrzeżenie, nie blokada: papierowa karta jest dokumentem źródłowym
      // i czasem trzeba odwzorować to, co ktoś już wpisał długopisem.
      await pumpForm(tester);

      await enterInto(tester, 'Po powrocie (km)', '900');

      expect(find.text('Licznik po powrocie jest mniejszy niż przed wyjazdem'),
          findsOneWidget);
    });
  });

  group('praca urządzeń specjalnych', () {
    testWidgets('pusta lista tlumaczy, do czego sluzy rubryka',
        (tester) async {
      await pumpForm(tester);

      expect(
        find.text(
            'Kolumna 10 karty drogowej. Dodaj urządzenie i czas jego pracy.'),
        findsOneWidget,
      );
    });

    testWidgets('dodane urzadzenie pokazuje sume minut', (tester) async {
      // Zgłoszenie z fix/035: bez wyboru urządzenia rubryka była w praktyce
      // nie do użycia i ludzie wpisywali „autopompa 2h" w uwagach.
      await pumpForm(tester);

      final addButton = find.text('Dodaj urządzenie');
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      await enterInto(tester, 'Minuty', '45');

      expect(find.text(SpecialEquipment.pump), findsOneWidget);
      expect(find.text('45 min'), findsOneWidget);
    });

    testWidgets('dwa urzadzenia sumuja sie razem', (tester) async {
      await pumpForm(tester);

      for (var i = 0; i < 2; i++) {
        final addButton = find.text('Dodaj urządzenie');
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pumpAndSettle();
      }

      final minutes = find.widgetWithText(TextFormField, 'Minuty');
      await tester.ensureVisible(minutes.first);
      await tester.enterText(minutes.first, '30');
      await tester.pumpAndSettle();
      await tester.ensureVisible(minutes.last);
      await tester.enterText(minutes.last, '15');
      await tester.pumpAndSettle();

      expect(find.text('45 min'), findsOneWidget);
    });
  });

  group('trasa', () {
    testWidgets('„Skąd" podpowiada adres remizy', (tester) async {
      // Z fix/029: pusty adres jednostki nie podpowiada nic zamiast zmyślać,
      // ale wpisany ma trafiać do przejazdu bez przepisywania.
      await pumpForm(tester);

      expect(find.widgetWithText(TextFormField, 'Kielno, Oliwska 12'),
          findsOneWidget);
    });
  });
}
