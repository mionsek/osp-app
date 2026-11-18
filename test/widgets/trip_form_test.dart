import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/screens/trips/trip_form_screen.dart';
import 'package:osp_app/screens/trips/trips_list_screen.dart';
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

  /// [routed] — formularz pod trasą, z której wraca po zapisie
  /// (`context.pop`); potrzebne w testach, które zapisują.
  Future<void> pumpForm(WidgetTester tester,
      {String vehicleId = withHistory, bool routed = false}) async {
    // Domyślne okno testowe to 800×600 — formularz przejazdu jest znacznie
    // dłuższy, więc `ensureVisible` przewijało cel pod pasek tytułu i kliknięcia
    // trafiały w `AppBar` zamiast w przycisk. Wymiary telefonu, na którym
    // aplikacja realnie chodzi, mieszczą całość i usuwają problem u źródła.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final form = TripFormScreen(initialVehicleId: vehicleId);
    await tester.pumpWidget(routed
        ? testRouterApp(GoRouter(
            initialLocation: '/new',
            routes: [
              GoRoute(
                path: '/',
                builder: (c, s) => const Text('LISTA'),
                routes: [GoRoute(path: 'new', builder: (c, s) => form)],
              ),
            ],
          ))
        : testApp(form));
    await tester.pumpAndSettle();
  }

  /// „Dodaj przejazd" i nowy przejazd z bazy. Zapis Hive to prawdziwe
  /// operacje na dysku — na prawdziwym czasie.
  Future<VehicleTrip> saveNewTrip(WidgetTester tester) async {
    final before = {for (final t in db.getAllTrips()) t.id};
    await tester.ensureVisible(find.text('Dodaj przejazd'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Dodaj przejazd'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    return db.getAllTrips().firstWhere((t) => !before.contains(t.id));
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
            'Co pracowało na tym wyjeździe i ile minut — sprzęt tego '
            'wozu albo bez przypisanego wozu.'),
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

  group('lista sprzętu jednostki', () {
    // Dane w setUp — patrz komentarz na górze pliku.
    setUp(() async {
      await db.addEquipment(Equipment(
          id: 'e-pump',
          name: 'Autopompa A16/8',
          vehicleId: withHistory,
          poweredByVehicle: true));
      await db.addEquipment(
          Equipment(id: 'e-gen', name: 'Agregat Honda', vehicleId: brandNew));
      await db.addEquipment(Equipment(id: 'e-saw', name: 'Pilarka'));
    });

    Future<void> addDevice(WidgetTester tester) async {
      final addButton = find.text('Dodaj urządzenie');
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
    }

    testWidgets('na liście sprzęt tego wozu i bez przypisanego wozu — sprzętu '
        'innych wozów nie ma', (tester) async {
      // Dawid, 9.11.2026: „te, które są przypisane do tego samochodu, który
      // był na akcji, oraz te, które nie są przypisane do żadnego wozu".
      await pumpForm(tester);
      await addDevice(tester);
      expect(find.text('Autopompa A16/8'), findsOneWidget);

      await tester.tap(find.text('Autopompa A16/8'));
      await tester.pumpAndSettle();
      expect(find.text('Bez przypisanego wozu'), findsOneWidget);
      expect(find.text('Pilarka'), findsOneWidget);
      expect(find.textContaining('Agregat Honda'), findsNothing,
          reason: 'agregat jest na GLM 8');
      expect(find.text('Spoza listy — wpisz nazwę'), findsOneWidget);
      expect(find.text(SpecialEquipment.pump), findsNothing,
          reason: 'stała lista tylko bez listy sprzętu');

      await tester.tap(find.text('Pilarka').last);
      await tester.pumpAndSettle();
      expect(find.text('Pilarka'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nazwa urządzenia'),
          findsNothing);
    });

    testWidgets('sekcja sprzętu stoi zaraz pod licznikiem pojazdu',
        (tester) async {
      await pumpForm(tester);
      final odometer = tester.getTopLeft(find.text('Stan licznika pojazdu'));
      final equipment = tester.getTopLeft(find.text('Praca sprzętu'));
      final purpose = tester.getTopLeft(find.text('Cel jazdy').first);
      expect(equipment.dy, greaterThan(odometer.dy));
      expect(equipment.dy, lessThan(purpose.dy));
    });

    testWidgets('„Spoza listy" — pole na własną nazwę', (tester) async {
      await pumpForm(tester);
      await addDevice(tester);
      await tester.tap(find.text('Autopompa A16/8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spoza listy — wpisz nazwę').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Nazwa urządzenia'),
          findsOneWidget);
    });

    testWidgets('sprzęt z własnym silnikiem pyta o obsługującego (karta '
        'pracy) i zapisuje go w przejeździe', (tester) async {
      await pumpForm(tester, routed: true);
      await addDevice(tester);

      final operator = find.widgetWithText(TextFormField, 'Obsługujący');
      expect(operator, findsNothing, reason: 'autopompa — z silnika wozu');

      await tester.tap(find.text('Autopompa A16/8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilarka').last);
      await tester.pumpAndSettle();
      expect(operator, findsOneWidget);

      await tester.enterText(operator, 'Kowalski Jan');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Minuty'), '25');
      await tester.pumpAndSettle();

      final use = (await saveNewTrip(tester)).equipmentUse.single;
      expect(use.equipmentId, 'e-saw');
      expect(use.minutes, 25);
      expect(use.operatorName, 'Kowalski Jan');
      expect(use.operatorId, 'ff1', reason: 'nazwisko z kartoteki');
    });
  });

  group('pobyt na miejscu (dwa wiersze karty)', () {
    testWidgets('godziny ułożone jak wiersze karty: odjazd, na miejscu, '
        'z miejsca, przyjazd — na miejscu opcjonalne', (tester) async {
      await pumpForm(tester);
      for (final label in ['Odjazd', 'Na miejscu', 'Z miejsca', 'Przyjazd']) {
        expect(find.widgetWithText(InputDecorator, label), findsOneWidget,
            reason: label);
      }
      expect(find.textContaining('wiersz wyjazdu (OSP → miejsce)'),
          findsOneWidget);
    });

    testWidgets('licznik na miejscu ostrzega poza zakresem i zapisuje się',
        (tester) async {
      await pumpForm(tester, routed: true);
      const warning =
          'Licznik na miejscu jest poza zakresem przed wyjazdem – po powrocie';

      await enterInto(tester, 'Na miejscu (km, opcjonalnie)', '1030');
      expect(find.text(warning), findsOneWidget,
          reason: 'mniej niż 1042 przed wyjazdem');

      await enterInto(tester, 'Na miejscu (km, opcjonalnie)', '1050');

      // Cyfra po cyfrze, jak na telefonie: ostrzeżenie pojawia się
      // i znika, a pole „Po powrocie" nie może przy tym tracić kursora —
      // na emulatorze dalsze cyfry trafiały do innego pola.
      final end = find.widgetWithText(TextFormField, 'Po powrocie (km)');
      await tester.ensureVisible(end);
      await tester.tap(end);
      await tester.pump();
      bool endFocused() => tester
          .widget<EditableText>(
              find.descendant(of: end, matching: find.byType(EditableText)))
          .focusNode
          .hasFocus;
      for (final typed in ['1', '10', '106', '1060']) {
        await tester.enterText(end, typed);
        await tester.pump();
        expect(endFocused(), isTrue, reason: 'po wpisaniu „$typed"');
      }
      await tester.pumpAndSettle();
      expect(find.text(warning), findsNothing);

      final trip = await saveNewTrip(tester);
      expect(trip.sceneOdometer, 1050);
      expect(trip.odometerStart, 1042);
      expect(trip.odometerEnd, 1060);
      expect(trip.sceneArrivalTime, isNull, reason: 'nikt nie wpisał');
    });
  });

  group('licznik na miejscu — połowa drogi (Dawid, 18.11.2026)', () {
    const scene = 'Na miejscu (km, opcjonalnie)';

    /// Wyjazd z połową drogi wpisaną sama: 1100 → 1120, na miejscu 1110.
    setUp(() async {
      await db.addTrip(VehicleTrip(
        id: 'trip_mid',
        vehicleId: brandNew,
        date: DateTime(2026, 8, 10),
        departureTime: DateTime(2026, 8, 10, 10, 0),
        returnTime: DateTime(2026, 8, 10, 11, 0),
        odometerStart: 1100,
        odometerEnd: 1120,
        odometerStartManual: true,
        sceneOdometer: 1110,
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      ));
    });

    Future<void> pumpEdit(WidgetTester tester, String tripId) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testRouterApp(GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(
            path: '/',
            builder: (c, s) => const Text('LISTA'),
            routes: [
              GoRoute(
                  path: 'edit',
                  builder: (c, s) => TripFormScreen(tripId: tripId)),
            ],
          ),
        ],
      )));
      await tester.pumpAndSettle();
    }

    Future<void> saveChanges(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Zapisz zmiany'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Zapisz zmiany'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
    }

    test('połowa drogi, przy nieparzystej liczbie km w dół', () {
      expect(VehicleTrip.halfwayOdometer(1200, 1220), 1210);
      expect(VehicleTrip.halfwayOdometer(1200, 1221), 1210,
          reason: '10,5 km — wpisujemy mniejszą');
      expect(VehicleTrip.halfwayOdometer(1200, 1201), 1200);
      expect(VehicleTrip.halfwayOdometer(1200, 1200), 1200);
      expect(VehicleTrip.halfwayOdometer(null, 1220), isNull);
      expect(VehicleTrip.halfwayOdometer(1200, null), isNull);
      expect(VehicleTrip.halfwayOdometer(1220, 1200), isNull,
          reason: 'sprzeczny licznik — nie zgadujemy');
    });

    testWidgets('puste pole pokazuje połowę drogi i ją zapisuje',
        (tester) async {
      await pumpForm(tester, routed: true);
      expect(find.textContaining('zapisze się połowa drogi'), findsNothing,
          reason: 'bez stanu po powrocie nie ma czego liczyć');

      // Cyfra po cyfrze: podpowiedź w polu wyżej nie zabiera kursora.
      final end = find.widgetWithText(TextFormField, 'Po powrocie (km)');
      await tester.ensureVisible(end);
      await tester.tap(end);
      await tester.pump();
      for (final typed in ['1', '10', '106', '1063']) {
        await tester.enterText(end, typed);
        await tester.pump();
        expect(
            tester
                .widget<EditableText>(find.descendant(
                    of: end, matching: find.byType(EditableText)))
                .focusNode
                .hasFocus,
            isTrue,
            reason: 'po wpisaniu „$typed"');
      }
      await tester.pumpAndSettle();

      // 1042 → 1063 to 21 km: połowa 10,5 — w dół, czyli 1052.
      expect(
          find.text('Puste — zapisze się połowa drogi: 1052. '
              'Wpisz, jeśli było inaczej'),
          findsOneWidget);
      final field = tester.widget<TextField>(find.descendant(
          of: find.widgetWithText(TextFormField, scene),
          matching: find.byType(TextField)));
      expect(field.decoration?.hintText, '1052');
      expect(field.controller?.text, '', reason: 'do poprawienia — pole puste');

      final trip = await saveNewTrip(tester);
      expect(trip.sceneOdometer, 1052);
    });

    testWidgets('wpisany stan na miejscu wygrywa z połową drogi',
        (tester) async {
      await pumpForm(tester, routed: true);
      await enterInto(tester, scene, '1045');
      await enterInto(tester, 'Po powrocie (km)', '1063');
      expect(find.textContaining('zapisze się połowa drogi'), findsNothing);

      final trip = await saveNewTrip(tester);
      expect(trip.sceneOdometer, 1045);
    });

    testWidgets('po poprawce licznika połowa drogi liczy się od nowa',
        (tester) async {
      await pumpEdit(tester, 'trip_mid');
      expect(find.textContaining('zapisze się połowa drogi: 1110'),
          findsOneWidget,
          reason: '1110 to połowa drogi — w polu podpowiedź, a nie liczba');

      await enterInto(tester, 'Po powrocie (km)', '1130');
      expect(find.textContaining('zapisze się połowa drogi: 1115'),
          findsOneWidget);
      await saveChanges(tester);
      expect(db.getTrip('trip_mid')!.sceneOdometer, 1115);
    });
  });

  group('dysponent z listy (Dawid, 18.11.2026)', () {
    setUp(() async {
      await db.addFirefighter(firefighter('ff2', 'Mateusz', 'Dering'));
    });

    testWidgets('przejazd bez zastępu podpowiada wszystkich ratowników, '
        'także bez uprawnień kierowcy', (tester) async {
      await pumpForm(tester, routed: true);
      final dispatcher = find.widgetWithText(TextFormField, 'Dysponent');
      expect(find.text('Kto zadysponował pojazd — z listy ratowników albo '
          'wpisz nazwisko'), findsOneWidget);

      await tester.ensureVisible(dispatcher);
      await tester.tap(dispatcher);
      await tester.pumpAndSettle();
      expect(find.text('Dering Mateusz'), findsOneWidget);
      expect(find.text('Kowalski Jan'), findsWidgets);

      await tester.tap(find.text('Dering Mateusz'));
      await tester.pumpAndSettle();
      final trip = await saveNewTrip(tester);
      expect(trip.dispatcherName, 'Dering Mateusz');
    });

    testWidgets('nazwisko spoza kartoteki da się wpisać z ręki',
        (tester) async {
      await pumpForm(tester, routed: true);
      await enterInto(tester, 'Dysponent', 'SK KM PSP');
      final trip = await saveNewTrip(tester);
      expect(trip.dispatcherName, 'SK KM PSP');
    });
  });

  group('cel jazdy pełną nazwą (Dawid, 18.11.2026)', () {
    setUp(() async {
      await db.addReport(Report(
        id: 'r1',
        reportNumber: '0007/2026',
        year: 2026,
        date: DateTime(2026, 8, 11),
        departureTime: DateTime(2026, 8, 11, 19, 40),
        addressLocality: 'Kielno',
        addressStreet: 'Oliwska 85',
        threatCategory: 'Pożar',
        createdAt: DateTime(2026, 8, 11),
        updatedAt: DateTime(2026, 8, 11),
      ));
      await db.addTrip(VehicleTrip(
        id: 'trip_r1_v2',
        vehicleId: brandNew,
        date: DateTime(2026, 8, 11),
        departureTime: DateTime(2026, 8, 11, 19, 40),
        purpose: TripPurposes.alarm,
        reportId: 'r1',
        createdAt: DateTime(2026, 8, 11),
        updatedAt: DateTime(2026, 8, 11),
      ));
      // Ten sam wyjazd w bieżącym miesiącu — do listy przejazdów.
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, 1);
      await db.addTrip(VehicleTrip(
        id: 'trip_r1_now',
        vehicleId: withHistory,
        date: day,
        departureTime: day.add(const Duration(hours: 10)),
        odometerStart: 1042,
        odometerEnd: 1050,
        odometerStartManual: true,
        purpose: TripPurposes.alarm,
        reportId: 'r1',
        createdAt: day,
        updatedAt: day,
      ));
    });

    testWidgets('do wyboru Pożar, Miejscowe Zagrożenie i Fałszywy Alarm — '
        'bez „Wyjazd alarmowy"', (tester) async {
      await pumpForm(tester, routed: true);
      final purpose = find.widgetWithText(
          DropdownButtonFormField<String>, 'Wyjazd gospodarczy');
      await tester.ensureVisible(purpose);
      await tester.tap(purpose);
      await tester.pumpAndSettle();
      for (final p in ['Miejscowe Zagrożenie', 'Pożar', 'Fałszywy Alarm',
          'Tankowanie', 'Ćwiczenia']) {
        expect(find.text(p), findsWidgets, reason: p);
      }
      expect(find.text('Wyjazd alarmowy'), findsNothing);

      await tester.tap(find.text('Miejscowe Zagrożenie').last);
      await tester.pumpAndSettle();
      final trip = await saveNewTrip(tester);
      expect(trip.purpose, TripPurposes.localThreat);
    });

    testWidgets('wyjazd z raportu pokazuje rodzaj zdarzenia z raportu',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
          testApp(const TripFormScreen(tripId: 'trip_r1_v2')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputDecorator, 'Pożar'), findsOneWidget);
      expect(find.text('Z wyjazdu alarmowego — rodzaj zdarzenia zmienisz '
          'w raporcie'), findsOneWidget);
      expect(find.text('Wyjazd alarmowy'), findsNothing);
    });

    testWidgets('lista przejazdów: „Pożar" zamiast „Wyjazd alarmowy"',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp(const TripsListScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('· Pożar'), findsOneWidget);
      expect(find.textContaining('Wyjazd alarmowy'), findsNothing);
      expect(
          find.descendant(
              of: find.byType(CircleAvatar),
              matching: find.byIcon(Icons.local_fire_department)),
          findsOneWidget);
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
