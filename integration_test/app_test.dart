import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:osp_app/main.dart' as app;

/// Przejście przez realną aplikację na urządzeniu — od pustej instalacji
/// do wpisu w ewidencji przejazdów.
///
/// To jest dokładnie ta ścieżka, którą po każdej zmianie przechodziłem ręcznie
/// na emulatorze: onboarding w trybie offline → dane jednostki → pojazd →
/// ratownicy → wyjazd → sprawdzenie, że przejazd dopisał się sam. Opisana raz
/// jako test, przestaje zależeć od tego, czy pamiętam ją przejść i czy
/// przeklikam wszystkie kroki tak samo jak poprzednio.
///
/// **Wymaga czystych danych aplikacji.** Uruchamiać po
/// `adb shell pm clear pl.osp.osp_app`, inaczej aplikacja wystartuje od razu
/// na ekranie głównym istniejącej jednostki i test nie miałby czego zakładać.
/// Test sprawdza to na wstępie i mówi wprost, zamiast wywalić się później
/// na niezrozumiałym „nie znaleziono przycisku".
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field.first);
    await tester.pumpAndSettle();
    await tester.enterText(field.first, value);
    await tester.pumpAndSettle();
  }

  /// Powrót strzałką w pasku tytułu.
  ///
  /// Świadomie zamiast `tester.pageBack()`, które szuka przycisku po typie
  /// wewnętrznym (`BackButtonIcon` / `CupertinoNavigationBarBackButton`)
  /// i na tych ekranach go nie znajduje. `BackButton` to ten sam widżet,
  /// który wstawia `AppBar`, więc szukanie po nim jest i prostsze, i pewniejsze.
  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
  }

  testWidgets('od onboardingu do wpisu w ewidencji przejazdów',
      (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(
      find.text('Witaj w aplikacji OSP'),
      findsOneWidget,
      reason: 'Aplikacja ma wystartować na onboardingu. Jeśli widzisz ekran '
          'główny, wyczyść dane: adb shell pm clear pl.osp.osp_app',
    );

    // --- Jednostka, bez logowania do Google ---
    await tapText(tester, 'Utwórz nową jednostkę');
    await tapText(tester, 'Kontynuuj bez logowania (tryb offline)');

    await fill(tester, 'Pełna nazwa jednostki', 'OSP Testowa');
    await fill(tester, 'Miejscowość', 'Kielno');
    await fill(tester, 'Ulica i numer (opcjonalnie)', 'Oliwska 12');
    await tapText(tester, 'Utwórz jednostkę');

    expect(find.text('Dodaj wyjazd'), findsOneWidget);

    // --- Pojazd ---
    await tapText(tester, 'Pojazdy (0)');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await fill(tester, 'Nazwa pojazdu', 'GBA 2.5/16');
    await tapText(tester, 'Dodaj pojazd');
    expect(find.text('GBA 2.5/16'), findsWidgets);
    await goBack(tester);

    // --- Ratownicy: trzy osoby, bo zastęp poniżej trzech wywoła ostrzeżenie ---
    await tapText(tester, 'Ratownicy (0)');
    for (final person in const [
      ('Jan', 'Kowalski'),
      ('Adam', 'Nowak'),
      ('Piotr', 'Wiśniewski'),
    ]) {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await fill(tester, 'Imię', person.$1);
      await fill(tester, 'Nazwisko', person.$2);
      await tapText(tester, 'Dodaj ratownika');
      await tester.pumpAndSettle();
    }
    // Nazwisko przed imieniem — obowiązująca kolejność od fix/035.
    expect(find.text('Kowalski Jan'), findsOneWidget);
    await goBack(tester);

    // --- Wyjazd ---
    await tapText(tester, 'Dodaj wyjazd');

    await tapText(tester, 'GBA 2.5/16');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tapText(tester, 'Fałszywy Alarm');
    await tapText(tester, 'Dalej — Zastępy');

    // Zastęp zostaje pusty — przechodzimy przez oba ostrzeżenia, bo sprawdzamy
    // dopisanie przejazdu, a nie kompletowanie obsady.
    await tapText(tester, 'Podsumowanie');
    await tapText(tester, 'Kontynuuj mimo to');
    await tapText(tester, 'Kontynuuj mimo to');
    await tapText(tester, 'Zapisz raport');
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Kreator prowadzi wprost do szczegółów zapisanego wyjazdu, nie na ekran
    // główny — zapisany raport zwykle chce się od razu obejrzeć albo wydrukować.
    expect(find.textContaining('Wyjazd '), findsWidgets,
        reason: 'Po zapisaniu otwierają się szczegóły raportu');

    // Powrót ikoną domku — dodana w feature/002 właśnie dlatego, że
    // ze szczegółów raportu nie było jak wrócić do menu.
    await tester.tap(find.byIcon(Icons.home).first);
    await tester.pumpAndSettle();

    expect(find.text('Lista wyjazdów (1)'), findsOneWidget);

    // --- Sedno testu: wyjazd alarmowy dopisał się do ewidencji sam ---
    await tapText(tester, 'Ewidencja przejazdów');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Ewidencja przejazdów'), findsWidgets);
    expect(
      find.textContaining('Wyjazd alarmowy'),
      findsWidgets,
      reason: 'Zapisany wyjazd ma dopisać wiersz karty drogowej bez '
          'przepisywania go ręcznie',
    );
  });
}
