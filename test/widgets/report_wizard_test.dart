import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
