import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/handovers/handover_detail_screen.dart';
import 'package:osp_app/screens/reports/report_detail_screen.dart';
import 'package:osp_app/screens/statistics/statistics_screen.dart';
import 'package:osp_app/screens/trips/trip_form_screen.dart';
import 'package:osp_app/screens/trips/trips_list_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Jeden układ pasków na każdym ekranie z dokumentem.
///
/// Uwaga Dawida z 6.11.2026 (zrzuty „Ewidencja przejazdów" i „Przekazanie
/// mienia"): ikony obok tytułu ucinały go do „Ewidencj…" i „Przekazanie …",
/// a druk był raz w ikonach na górze, raz w przyciskach na dole przewijanej
/// treści. Wybrany wariant A: na czerwonym pasku tylko tytuł i domek, pod
/// nim pasek z podpisanymi przyciskami — wszędzie w tej samej kolejności.
void main() {
  late Directory tempDir;
  late DatabaseService db;
  final year = DateTime.now().year;

  setUp(() async {
    tempDir = await setUpTestHive();
    db = DatabaseService();
  });

  tearDown(() => disposeTestHive(tempDir));

  const author = SyncState(
    status: SyncStatus.idle,
    userEmail: 'wojtek@gmail.com',
    unitFolderId: 'folder',
    unitInviteCode: 'URZEAZ',
    founderEmail: 'ospkielno@gmail.com',
  );
  const colleague = SyncState(
    status: SyncStatus.idle,
    userEmail: 'ania@gmail.com',
    unitFolderId: 'folder',
    unitInviteCode: 'URZEAZ',
    founderEmail: 'ospkielno@gmail.com',
  );

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    SyncState state = author,
    Future<void> Function()? seed,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Zapis pliku Hive to prawdziwe operacje na dysku — na prawdziwym czasie.
    if (seed != null) await tester.runAsync(seed);
    final sync = fakeSync();
    when(() => sync.reportsAwaitingUpload(any())).thenReturn(const {});
    when(() => sync.handoversAwaitingUpload(any())).thenReturn(const {});
    await tester.pumpWidget(testApp(
      screen,
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith(
            (ref) => FixedSyncState(ref.watch(syncServiceProvider), state)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  Finder inBar(String text) => find.descendant(
      of: find.byType(AppBar), matching: find.text(text));

  /// Przyciski z ikoną na czerwonym pasku — poza paskiem akcji pod nim.
  int barIconButtons(WidgetTester tester) => tester
      .widgetList(find.descendant(
          of: find.byType(AppBar), matching: find.byType(IconButton)))
      .length;

  bool enabled(WidgetTester tester, String label) => tester
      .widget<InkWell>(find.ancestor(
          of: inBar(label), matching: find.byType(InkWell)))
      .onTap != null;

  Report report() => Report(
        id: 'r1',
        reportNumber: '0002/$year',
        year: year,
        date: DateTime(year, 10, 27),
        departureTime: DateTime(year, 10, 27, 16, 35),
        addressLocality: 'Kielno',
        addressStreet: '',
        addressDescription: '',
        threatCategory: 'Miejscowe Zagrożenie',
        createdAt: DateTime(year, 10, 27),
        updatedAt: DateTime(year, 10, 27),
        createdBy: 'wojtek@gmail.com',
      );

  PropertyHandover handover() => PropertyHandover(
        id: 'h1',
        eventLocation: 'Kielno',
        eventDate: DateTime(2026, 10, 27),
        eventTime: DateTime(2026, 10, 27, 17, 30),
        recipientName: 'Jan Właściciel',
        signDate: DateTime(2026, 10, 27),
        createdAt: DateTime(2026, 10, 27),
        updatedAt: DateTime(2026, 10, 27),
        createdBy: 'wojtek@gmail.com',
      );

  group('wyjazd', () {
    testWidgets('autor: Drukuj, Bluetooth, Wyślij, Edytuj, Usuń — pod '
        'tytułem, z podpisami', (tester) async {
      await pump(tester, const ReportDetailScreen(reportId: 'r1'),
          seed: () => db.reportsBox.put('r1', report()));

      for (final label in ['Drukuj', 'Bluetooth', 'Wyślij', 'Edytuj', 'Usuń']) {
        expect(inBar(label), findsOneWidget, reason: label);
      }
      expect(barIconButtons(tester), 1, reason: 'na czerwonym pasku sam domek');
      expect(find.text('Drukuj (2 egzemplarze)'), findsNothing,
          reason: 'druk nie dubluje się na dole treści');
      expect(find.byTooltip('Drukuj (2 egzemplarze)'), findsOneWidget);
    });

    testWidgets('kolega: drukuje i wysyła, ale bez Edytuj i Usuń',
        (tester) async {
      await pump(tester, const ReportDetailScreen(reportId: 'r1'),
          state: colleague, seed: () => db.reportsBox.put('r1', report()));

      expect(inBar('Drukuj'), findsOneWidget);
      expect(inBar('Wyślij'), findsOneWidget);
      expect(inBar('Edytuj'), findsNothing);
      expect(inBar('Usuń'), findsNothing);
    });
  });

  testWidgets('przekazanie mienia: ten sam pasek co wyjazd', (tester) async {
    await pump(tester, const HandoverDetailScreen(handoverId: 'h1'),
        seed: () => db.addHandover(handover()));

    expect(inBar('Przekazanie mienia'), findsOneWidget);
    for (final label in ['Drukuj', 'Bluetooth', 'Wyślij', 'Edytuj', 'Usuń']) {
      expect(inBar(label), findsOneWidget, reason: label);
    }
    expect(barIconButtons(tester), 1);
    expect(find.text('Udostępnij / Wyślij'), findsNothing);
  });

  testWidgets('statystyki pustego roku: przyciski na miejscu, wyszarzone — '
      'i jest Bluetooth', (tester) async {
    await pump(tester, const StatisticsScreen());

    for (final label in ['Drukuj', 'Bluetooth', 'Wyślij']) {
      expect(inBar(label), findsOneWidget, reason: label);
      expect(enabled(tester, label), isFalse, reason: label);
    }
    expect(find.text('Drukuj statystyki'), findsNothing);
  });

  testWidgets('statystyki z wyjazdem — przyciski działają', (tester) async {
    await pump(tester, const StatisticsScreen(),
        seed: () => db.reportsBox.put('r1', report()));

    expect(enabled(tester, 'Drukuj'), isTrue);
    expect(enabled(tester, 'Bluetooth'), isTrue);
  });

  group('ewidencja przejazdów', () {
    setUp(() {
      seededDb(vehicles: [Vehicle(id: 'v1', name: 'GBA 2,5/16', seats: 6)]);
    });

    testWidgets('pełny tytuł i cztery drogi wyjścia, w tym Excel',
        (tester) async {
      await pump(tester, const TripsListScreen());

      expect(inBar('Ewidencja przejazdów'), findsOneWidget);
      for (final label in ['Drukuj', 'Bluetooth', 'Wyślij', 'Excel']) {
        expect(inBar(label), findsOneWidget, reason: label);
      }
      expect(barIconButtons(tester), 1);
      expect(find.byTooltip('Wyślij karty w Excelu — do poprawienia '
          'na komputerze'), findsOneWidget);
    });

    testWidgets('druk pyta: wszystkie karty miesiąca (domyślnie) czy jedna',
        (tester) async {
      // Dawid, 9.11.2026: Dering rozlicza wszystkie karty — każdy wóz
      // i każde urządzenie, także nieużywane.
      await tester.runAsync(() async {
        await db.addEquipment(Equipment(id: 'e1', name: 'Pilarka'));
        await db.addEquipment(Equipment(id: 'e2', name: 'Agregat'));
        await db.addEquipment(Equipment(
            id: 'e3', name: 'Autopompa', vehicleId: 'v1', poweredByVehicle: true));
      });
      await pump(tester, const TripsListScreen());

      await tester.tap(inBar('Drukuj'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wszystkie karty'), findsOneWidget);
      expect(find.text('Karty drogowe: 1, karty pracy sprzętu: 2'),
          findsOneWidget,
          reason: 'autopompa liczy się na karcie drogowej, nie ma swojej');
      expect(find.text('Tylko karta drogowa GBA 2,5/16'), findsOneWidget);
      final all = tester.getTopLeft(find.textContaining('Wszystkie karty'));
      final one = tester.getTopLeft(find.textContaining('Tylko karta'));
      expect(all.dy, lessThan(one.dy), reason: 'wszystkie — pierwsze');
    });

    testWidgets('Excel z pustego miesiąca pyta o „Wyślij pustą kartę", '
        'a nie o druk', (tester) async {
      await pump(tester, const TripsListScreen());

      await tester.tap(inBar('Excel'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Tylko karta drogowa'));
      await tester.pumpAndSettle();
      expect(find.text('Miesiąc bez przejazdów'), findsOneWidget);
      expect(find.text('Wyślij pustą kartę'), findsOneWidget);
      expect(find.text('Drukuj pustą kartę'), findsNothing);

      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(find.text('Miesiąc bez przejazdów'), findsNothing);
    });

    testWidgets('przejazd: „Usuń" pod zapisem, a nie obok tytułu',
        (tester) async {
      await pump(tester, const TripFormScreen(tripId: 't1'),
          seed: () => db.addTrip(VehicleTrip(
                id: 't1',
                vehicleId: 'v1',
                date: DateTime(2026, 11, 3),
                departureTime: DateTime(2026, 11, 3, 10),
                odometerStart: 1000,
                odometerStartManual: true,
                createdAt: DateTime(2026, 11, 3),
                updatedAt: DateTime(2026, 11, 3),
                createdBy: 'wojtek@gmail.com',
              )));

      expect(barIconButtons(tester), 1, reason: 'sam domek');
      final delete = find.text('Usuń przejazd');
      await tester.ensureVisible(delete);
      expect(delete, findsOneWidget);
      expect(
        tester.getTopLeft(delete).dy,
        greaterThan(tester.getTopLeft(find.text('Zapisz zmiany')).dy),
      );
    });
  });
}
