import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/core/router/app_router.dart';
import 'package:osp_app/core/theme/osp_theme.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/google_auth_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_app.dart';

class _MockAuth extends Mock implements GoogleAuthService {}

/// Nawigacja na prawdziwym drzewie tras aplikacji.
///
/// Zgłoszenie z testu 1.7.6: po dodaniu przekazania lista nie miała żadnej
/// nawigacji, a systemowe „wstecz" zamykało aplikację. Zasada Dawida:
/// z każdego miejsca wstecz albo do menu głównego, a w operacji z kilku
/// kroków — przechodzenie między krokami.
void main() {
  late Directory tempDir;
  late GoRouter router;
  final db = DatabaseService();
  final at = DateTime(2026, 10, 27, 17, 30);

  setUp(() async {
    tempDir = await setUpTestHive();
    PackageInfo.setMockInitialValues(
      appName: 'Raporty OSP',
      packageName: 'pl.osp.osp_app',
      version: '1.7.7',
      buildNumber: '20',
      buildSignature: '',
    );
    seededDb(
      vehicles: [Vehicle(id: 'v1', name: 'GBA 2.5/16', seats: 6)],
      firefighters: [firefighter('f1', 'Jan', 'Kowalski', isDriver: true)],
      config: UnitConfig(
        unitFullName: 'OSP Testowa',
        locality: 'Kielno',
        onboardingCompleted: true,
      ),
    );
    db.reportsBox.put(
      'r1',
      Report(
        id: 'r1',
        reportNumber: '0001/2026',
        year: 2026,
        date: DateTime(2026, 10, 27),
        departureTime: at,
        addressLocality: 'Kielno',
        addressStreet: '',
        addressDescription: '',
        threatCategory: 'Pożar',
        createdAt: at,
        updatedAt: at,
      ),
    );
    db.handoversBox.put(
      'h1',
      PropertyHandover(
        id: 'h1',
        eventLocation: 'Kielno, Szkolna 1',
        eventDate: DateTime(2026, 10, 27),
        eventTime: at,
        signDate: DateTime(2026, 10, 27),
        createdAt: at,
        updatedAt: at,
      ),
    );
    await db.ensureDefaultThreats();
  });

  tearDown(() => disposeTestHive(tempDir));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _MockAuth();
    when(() => auth.displayName).thenReturn(null);
    when(() => auth.userEmail).thenReturn(null);
    final sync = fakeSync();
    when(() => sync.authService).thenReturn(auth);

    router = GoRouter(initialLocation: '/', routes: appRoutes);
    await tester.pumpWidget(ProviderScope(
      overrides: [syncServiceProvider.overrideWithValue(sync)],
      child: MaterialApp.router(
        theme: OspTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pl')],
        locale: const Locale('pl'),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Ekran główny — po kafelku, którego nie ma nigdzie indziej.
  Finder home() => find.text('Dodaj przekazanie mienia');

  /// Systemowe „wstecz" Androida.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('po zapisie przekazania: wstecz do listy przekazań, potem do '
      'menu — aplikacja się nie zamyka', (tester) async {
    await pumpApp(tester);
    // Tak kończy się zapis w formularzu przekazania.
    router.go('/handovers/view/h1');
    await tester.pumpAndSettle();
    expect(find.text('Przekazanie mienia'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Przekazania mienia'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget,
        reason: 'lista po zapisie nie była bez nawigacji');

    await systemBack(tester);
    expect(home(), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('po zapisie wyjazdu i „Lista wyjazdów": wstecz do menu',
      (tester) async {
    await pumpApp(tester);
    router.go('/reports/view/r1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lista wyjazdów'));
    await tester.tap(find.text('Lista wyjazdów'));
    await tester.pumpAndSettle();

    await systemBack(tester);
    expect(home(), findsOneWidget);
  });

  testWidgets('każdy ekran ma strzałkę wstecz i „Menu główne"',
      (tester) async {
    await pumpApp(tester);
    const locations = [
      '/reports',
      '/reports/new',
      '/reports/view/r1',
      '/reports/edit/r1',
      '/handovers',
      '/handovers/new',
      '/handovers/view/h1',
      '/handovers/edit/h1',
      '/trips',
      '/trips/new?vehicleId=v1',
      '/vehicles',
      '/vehicles/add',
      '/vehicles/edit/v1',
      '/firefighters',
      '/firefighters/add',
      '/firefighters/edit/f1',
      '/statistics',
      '/settings',
      '/info',
    ];
    for (final location in locations) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget, reason: location);
      expect(find.byTooltip('Menu główne'), findsOneWidget, reason: location);

      await tester.tap(find.byTooltip('Menu główne'));
      await tester.pumpAndSettle();
      expect(home(), findsOneWidget, reason: '$location → menu');
    }
  });

  group('kreator wyjazdu', () {
    Future<void> fillStepOne(WidgetTester tester) async {
      await tester.tap(find.text('GBA 2.5/16'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fałszywy Alarm').last);
      await tester.pumpAndSettle();
    }

    testWidgets('wstecz cofa o krok, a na pierwszym — pytanie i wyjście',
        (tester) async {
      await pumpApp(tester);
      router.push('/reports/new');
      await tester.pumpAndSettle();
      await fillStepOne(tester);
      await tester.ensureVisible(find.text('Dalej — Zastępy'));
      await tester.tap(find.text('Dalej — Zastępy'));
      await tester.pumpAndSettle();
      expect(find.text('Wróć do danych podstawowych'), findsOneWidget);

      await systemBack(tester);
      expect(find.text('Krok 1 z 3 — Dane podstawowe'), findsOneWidget,
          reason: 'cofnięcie o krok, nie wyjście z kreatora');

      await systemBack(tester);
      expect(find.text('Wyjść bez zapisywania?'), findsOneWidget);
      await tester.tap(find.text('Wyjdź'));
      await tester.pumpAndSettle();
      expect(home(), findsOneWidget);
    });

    testWidgets('nic nie wpisano — wyjście bez pytania', (tester) async {
      await pumpApp(tester);
      router.push('/reports/new');
      await tester.pumpAndSettle();

      await systemBack(tester);
      expect(find.text('Wyjść bez zapisywania?'), findsNothing);
      expect(home(), findsOneWidget);
    });

    testWidgets('„Menu główne" z wpisanymi danymi pyta, „Zostań" zostawia',
        (tester) async {
      await pumpApp(tester);
      router.push('/reports/new');
      await tester.pumpAndSettle();
      await fillStepOne(tester);

      await tester.tap(find.byTooltip('Menu główne'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zostań'));
      await tester.pumpAndSettle();
      expect(find.text('Krok 1 z 3 — Dane podstawowe'), findsOneWidget);
    });
  });

  testWidgets('formularz z wpisanymi danymi pyta przed wyjściem — domkiem '
      'i wstecz', (tester) async {
    await pumpApp(tester);
    router.push('/vehicles/add');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'GLM 8');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu główne'));
    await tester.pumpAndSettle();
    expect(find.text('Wyjść bez zapisywania?'), findsOneWidget);
    await tester.tap(find.text('Zostań'));
    await tester.pumpAndSettle();
    expect(find.text('Nowy pojazd'), findsOneWidget);

    await systemBack(tester);
    expect(find.text('Wyjść bez zapisywania?'), findsOneWidget);
    await tester.tap(find.text('Wyjdź'));
    await tester.pumpAndSettle();
    expect(home(), findsOneWidget);
  });

  testWidgets('po zapisie formularz zamyka się sam, bez pytania',
      (tester) async {
    await pumpApp(tester);
    router.push('/vehicles/add');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'GLM 8');
    await tester.pumpAndSettle();

    // Zapis do Hive to prawdziwe operacje na dysku — na prawdziwym czasie.
    await tester.ensureVisible(find.text('Dodaj pojazd'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Dodaj pojazd'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('Wyjść bez zapisywania?'), findsNothing);
    expect(home(), findsOneWidget);
    expect(db.getAllVehicles().map((v) => v.name), contains('GLM 8'));
  });

  testWidgets('ustawienia: zmienione dane jednostki pytają, po zapisie już '
      'nie', (tester) async {
    await pumpApp(tester);
    router.push('/settings');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'OSP Testowa'), 'OSP Kielno');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu główne'));
    await tester.pumpAndSettle();
    expect(find.text('Wyjść bez zapisywania?'), findsOneWidget);
    await tester.tap(find.text('Zostań'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Zapisz ustawienia'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Zapisz ustawienia'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu główne'));
    await tester.pumpAndSettle();
    expect(find.text('Wyjść bez zapisywania?'), findsNothing);
    expect(home(), findsOneWidget);
  });

  testWidgets('pusty formularz zamyka się bez pytania', (tester) async {
    await pumpApp(tester);
    router.push('/vehicles/add');
    await tester.pumpAndSettle();

    await systemBack(tester);
    expect(find.text('Wyjść bez zapisywania?'), findsNothing);
    expect(home(), findsOneWidget);
  });
}
