import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/screens/reports/report_wizard_screen.dart';
import 'package:osp_app/screens/reports/steps/step_summary.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Testy kreatora wyjazdu — trzy kroki, walidacje i ostrzeżenia.
///
/// Logika składu zastępu ma testy jednostkowe od feature/003, ale to, czy
/// ostrzeżenie **faktycznie pojawia się na ekranie** i czy „Dalej" faktycznie
/// zatrzymuje przy pustych polach, sprawdzało się dotąd wyłącznie ręcznie
/// na emulatorze. Kreator to najczęściej używany ekran aplikacji i jedyny,
/// przez który przechodzi każdy raport.
void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUp(() async {
    tempDir = await setUpTestHive();
    db = seededDb(
      vehicles: [Vehicle(id: 'v1', name: 'GBA 2.5/16', seats: 6)],
      firefighters: [
        firefighter('ff1', 'Jan', 'Kowalski', isDriver: true),
        firefighter('ff2', 'Adam', 'Nowak', isCommander: true),
      ],
      config: UnitConfig(
        unitFullName: 'OSP Testowa',
        locality: 'Kielno',
        onboardingCompleted: true,
      ),
    );
    await db.ensureDefaultThreats();
  });

  tearDown(() async => disposeTestHive(tempDir));

  /// Wypełnia krok 1 na tyle, żeby dało się z niego wyjść: pojazd + zagrożenie.
  /// „Fałszywy Alarm" celowo — jako jedyna kategoria nie ma podtypów, więc
  /// nie odsłania drugiej listy i nie zaciemnia testu.
  Future<void> fillStepOne(WidgetTester tester) async {
    await tester.ensureVisible(find.text('GBA 2.5/16'));
    await tester.tap(find.text('GBA 2.5/16'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fałszywy Alarm').last);
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('krok 1 — dane podstawowe', () {
    testWidgets('bez wybranego pojazdu nie przepuszcza dalej', (tester) async {
      await tester.pumpWidget(testApp(const ReportWizardScreen()));
      await tester.pumpAndSettle();

      await tapNext(tester, 'Dalej — Zastępy');

      expect(find.text('Wybierz przynajmniej jeden pojazd'), findsOneWidget);
      // Nadal krok 1 — lista pojazdów wciąż na ekranie.
      expect(find.text('GBA 2.5/16'), findsWidgets);
    });

    testWidgets('bez zagrozenia nie przepuszcza dalej', (tester) async {
      await tester.pumpWidget(testApp(const ReportWizardScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('GBA 2.5/16'));
      await tester.tap(find.text('GBA 2.5/16'));
      await tester.pumpAndSettle();

      await tapNext(tester, 'Dalej — Zastępy');

      expect(find.text('Wybierz rodzaj zagrożenia'), findsOneWidget);
    });

    testWidgets('komplet danych przenosi do zastepow', (tester) async {
      await tester.pumpWidget(testApp(const ReportWizardScreen()));
      await tester.pumpAndSettle();

      await fillStepOne(tester);
      await tapNext(tester, 'Dalej — Zastępy');

      expect(find.text('Wróć do danych podstawowych'), findsOneWidget);
    });

    testWidgets('miejscowosc podpowiada sie z danych jednostki',
        (tester) async {
      await tester.pumpWidget(testApp(const ReportWizardScreen()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Kielno'), findsOneWidget);
    });
  });

  group('krok 2 — zastępy', () {
    testWidgets('pusty zastep ostrzega o braku kierowcy, dowodcy i obsady',
        (tester) async {
      await tester.pumpWidget(testApp(const ReportWizardScreen()));
      await tester.pumpAndSettle();
      await fillStepOne(tester);
      await tapNext(tester, 'Dalej — Zastępy');

      await tapNext(tester, 'Podsumowanie');

      expect(find.text('Uwaga — niepełny skład'), findsOneWidget);
      expect(find.text('Brak kierowcy'), findsOneWidget);
      expect(find.text('Brak dowódcy'), findsOneWidget);
      expect(find.text('Minimalna obsada to 3 osoby (jest 0)'), findsOneWidget);
    });

    testWidgets('„Popraw" zatrzymuje w zastepach', (tester) async {
      await tester.pumpWidget(testApp(const ReportWizardScreen()));
      await tester.pumpAndSettle();
      await fillStepOne(tester);
      await tapNext(tester, 'Dalej — Zastępy');
      await tapNext(tester, 'Podsumowanie');

      await tester.tap(find.text('Popraw'));
      await tester.pumpAndSettle();

      expect(find.text('Uwaga — niepełny skład'), findsNothing);
      expect(find.text('Wróć do danych podstawowych'), findsOneWidget);
      // Podsumowanie ma się **nie** pokazać — to jest sedno ostrzeżenia.
      expect(find.text('Zapisz raport'), findsNothing);
    });

    testWidgets('„Kontynuuj mimo to" przepuszcza przez oba ostrzezenia',
        (tester) async {
      // Kreator pokazuje drugie okno („Mała obsada zastępu") już po tym,
      // które wystawia sam krok zastępów — obydwa trzeba przeklikać, żeby
      // dojść do podsumowania.
      await tester.pumpWidget(testApp(const ReportWizardScreen()));
      await tester.pumpAndSettle();
      await fillStepOne(tester);
      await tapNext(tester, 'Dalej — Zastępy');
      await tapNext(tester, 'Podsumowanie');

      await tester.tap(find.text('Kontynuuj mimo to'));
      await tester.pumpAndSettle();

      expect(find.text('Mała obsada zastępu'), findsOneWidget);

      await tester.tap(find.text('Kontynuuj mimo to'));
      await tester.pumpAndSettle();

      expect(find.text('Zapisz raport'), findsOneWidget);
    });
  });

  group('numer wyjazdu przy dwóch telefonach', () {
    final year = DateTime.now().year;

    Report fromOtherPhone(String id, String number) => Report(
          id: id,
          reportNumber: number,
          year: year,
          date: DateTime(year, 8, 10),
          departureTime: DateTime(year, 8, 10, 14, 30),
          addressLocality: 'Gdynia',
          addressStreet: '',
          addressDescription: '',
          threatCategory: 'Miejscowe Zagrożenie',
          createdAt: DateTime(year, 8, 10),
          updatedAt: DateTime(year, 8, 10),
          createdBy: 'wojtek@gmail.com',
        );

    /// Kreator z routerem — po zapisie przechodzi do ekranu wyjazdu.
    Widget wizardApp(FakeSyncService sync) => testRouterApp(
          GoRouter(
            initialLocation: '/reports/new',
            routes: [
              GoRoute(
                path: '/reports/new',
                builder: (context, state) => const ReportWizardScreen(),
              ),
              GoRoute(
                path: '/reports/view/:id',
                builder: (context, state) => Scaffold(
                  body: Text('Zapisano ${state.pathParameters['id']}'),
                ),
              ),
            ],
          ),
          sync: sync,
        );

    /// Od kroku 1 do „Zapisz raport" — przez oba ostrzeżenia o obsadzie.
    Future<void> goToSummary(WidgetTester tester) async {
      await fillStepOne(tester);
      await tapNext(tester, 'Dalej — Zastępy');
      await tapNext(tester, 'Podsumowanie');
      await tester.tap(find.text('Kontynuuj mimo to'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kontynuuj mimo to'));
      await tester.pumpAndSettle();
    }

    /// Wyjazd z innego telefonu, od razu w pamięci bazy. Zapis pliku Hive to
    /// prawdziwe operacje na dysku — na udawanym czasie `await` nie wraca.
    void seed(Report r) => db.reportsBox.put(r.id, r);

    /// To samo przed uruchomieniem ekranu — do końca, żeby późniejszy zapis
    /// z kreatora nie czekał w kolejce Hive za niedokończonym.
    Future<void> seedBefore(WidgetTester tester, Report r) =>
        tester.runAsync(() => db.reportsBox.put(r.id, r));

    /// Stuknięcie, po którym kreator zapisuje do Hive — na prawdziwym czasie.
    Future<void> tapAndWrite(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.runAsync(() async {
        await tester.tap(find.text(label));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) =>
        tapAndWrite(tester, 'Zapisz raport');

    /// Treść pola numeru. Podpowiedź pola to też „0001/2026", więc szukanie
    /// po tekście trafia w dwa miejsca.
    String numberField(WidgetTester tester) => tester
        .widget<EditableText>(find.descendant(
          of: find.widgetWithText(TextFormField, 'Numer ewidencyjny'),
          matching: find.byType(EditableText),
        ))
        .controller
        .text;

    testWidgets('pole pokazuje numer policzony po pobraniu wyjazdów z Dysku',
        (tester) async {
      // Pole trzymało numer z chwili otwarcia kreatora, a zapisywał się
      // inny — ten po pobraniu.
      final sync = fakeSync();
      final pulled = Completer<bool>();
      when(() => sync.pullReportsOnly()).thenAnswer((_) => pulled.future);

      await tester.pumpWidget(testApp(const ReportWizardScreen(), sync: sync));
      await tester.pumpAndSettle();
      expect(numberField(tester), '0001/$year');

      // Pobranie z Dysku przyniosło wyjazd kolegi.
      await seedBefore(tester, fromOtherPhone('r-w', '0001/$year'));
      pulled.complete(true);
      await tester.pumpAndSettle();

      expect(numberField(tester), '0002/$year');
    });

    testWidgets('numer zajęty w międzyczasie na innym telefonie — wyjazd '
        'dostaje następny i mówi o tym', (tester) async {
      final sync = fakeSync();
      var pulls = 0;
      when(() => sync.pullReportsOnly()).thenAnswer((_) async {
        // Przy otwarciu kreatora Dysk jest pusty; przy zapisie jest już
        // wyjazd kolegi z tym samym numerem.
        if (++pulls == 2) seed(fromOtherPhone('r-w', '0001/$year'));
        return true;
      });

      await tester.pumpWidget(wizardApp(sync));
      await tester.pumpAndSettle();
      expect(numberField(tester), '0001/$year');
      await goToSummary(tester);
      await save(tester);

      final mine = db.getAllReports().where((r) => r.id != 'r-w').single;
      expect(mine.reportNumber, '0002/$year');
      expect(db.findDuplicateReportNumbers(), isEmpty);
      expect(
        find.textContaining('Numer 0001/$year ma już wyjazd dodany '
            'w międzyczasie na innym telefonie'),
        findsOneWidget,
      );
    });

    testWidgets('ręcznie wpisany zajęty numer — pytanie przed zapisem',
        (tester) async {
      await seedBefore(tester, fromOtherPhone('r-w', '0001/$year'));

      await tester.pumpWidget(wizardApp(fakeSync()));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, '0002/$year'), '0001/$year');
      await tester.pumpAndSettle();
      await goToSummary(tester);
      await save(tester);

      expect(find.text('Numer 0001/$year jest zajęty'), findsOneWidget);
      expect(find.textContaining('Gdynia — Miejscowe Zagrożenie'),
          findsOneWidget);
      await tapAndWrite(tester, 'Zapisz jako 0002/$year');

      final mine = db.getAllReports().where((r) => r.id != 'r-w').single;
      expect(mine.reportNumber, '0002/$year');
    });

    testWidgets('„Wróć" przy zajętym numerze niczego nie zapisuje',
        (tester) async {
      await seedBefore(tester, fromOtherPhone('r-w', '0001/$year'));

      await tester.pumpWidget(wizardApp(fakeSync()));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, '0002/$year'), '0001/$year');
      await tester.pumpAndSettle();
      await goToSummary(tester);
      await save(tester);
      await tester.tap(find.text('Wróć'));
      await tester.pumpAndSettle();

      expect(db.getAllReports(), hasLength(1));
      expect(find.text('Zapisz raport'), findsOneWidget);
    });
  });

  group('krok 3 — podsumowanie', () {
    testWidgets('ratownicy wypisani jako „Nazwisko Imię"', (tester) async {
      // Regresja wprost z fix/035: podsumowanie używało `fullName`, czyli
      // „Imię Nazwisko", mimo że cała reszta aplikacji i wszystkie wydruki
      // pokazują nazwisko pierwsze. Zgłoszenie brzmiało, że na telefonie
      // przez radio czyta się nazwiska, nie imiona.
      await tester.pumpWidget(testApp(
        StepSummary(
          reportNumber: '1/2026',
          date: DateTime(2026, 8, 10),
          departureTime: const TimeOfDay(hour: 14, minute: 30),
          returnTime: const TimeOfDay(hour: 16, minute: 0),
          addressLocality: 'Kielno',
          addressStreet: 'Oliwska 12',
          addressDescription: '',
          threatCategory: 'Pożar',
          threatSubtype: 'Pożar budynku',
          crewAssignments: {
            'v1': CrewAssignment(
              vehicleId: 'v1',
              vehicleName: 'GBA 2.5/16',
              driverId: 'ff1',
              commanderId: 'ff2',
            ),
          },
          notes: '',
          onSave: () {},
          onBack: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kowalski Jan'), findsOneWidget);
      expect(find.text('Nowak Adam'), findsOneWidget);
      expect(find.text('Jan Kowalski'), findsNothing);
      expect(find.text('Adam Nowak'), findsNothing);
    });
  });
}
