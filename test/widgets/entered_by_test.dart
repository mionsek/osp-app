import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/core/constants/handover_property_kinds.dart';
import 'package:osp_app/core/constants/handover_recipient_types.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/handovers/handover_detail_screen.dart';
import 'package:osp_app/screens/handovers/handover_form_screen.dart';
import 'package:osp_app/screens/reports/report_detail_screen.dart';
import 'package:osp_app/screens/reports/report_wizard_screen.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/widgets/entered_by_field.dart';

import '../helpers/test_app.dart';

/// „Kto wpisuje?" na wspólnym koncie jednostki, np. tablecie w samochodzie.
///
/// Prośba Dawida z 12.11.2026: na wspólnym koncie „Dodał" pokazywał tylko
/// adres jednostki. Formularz pyta więc, kto wpisuje — z podpowiedzią
/// z samego wpisu — a szczegóły pokazują „Wpisał" i konto.
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

  tearDown(() => disposeTestHive(tempDir));

  /// Tablet zalogowany kontem jednostki z włączonym wspólnym kontem.
  const tablet = SyncState(
    status: SyncStatus.idle,
    userEmail: 'ospkielno@gmail.com',
    unitFolderId: 'folder',
    founderEmail: 'ospkielno@gmail.com',
    adminEmails: ['dawid@gmail.com'],
    sharedFounder: true,
  );

  /// Ten sam stan oglądany z prywatnego telefonu Dawida.
  const dawid = SyncState(
    status: SyncStatus.idle,
    userEmail: 'dawid@gmail.com',
    unitFolderId: 'folder',
    founderEmail: 'ospkielno@gmail.com',
    adminEmails: ['dawid@gmail.com'],
    sharedFounder: true,
  );

  List<Override> on(SyncState state) => [
        syncStateProvider.overrideWith(
            (ref) => FixedSyncState(ref.watch(syncServiceProvider), state)),
      ];

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Report report({String? enteredById, List<CrewAssignment>? crew}) => Report(
        id: 'r1',
        reportNumber: '0017/2026',
        year: 2026,
        date: DateTime(2026, 11, 12),
        departureTime: DateTime(2026, 11, 12, 11, 20),
        addressLocality: 'Tuchom',
        threatCategory: 'Fałszywy Alarm',
        crewAssignments: crew,
        createdAt: DateTime(2026, 11, 12),
        updatedAt: DateTime(2026, 11, 12),
        createdBy: 'ospkielno@gmail.com',
        enteredById: enteredById,
      );

  PropertyHandover handover({String? enteredById}) => PropertyHandover(
        id: 'h1',
        eventLocation: 'Tuchom',
        eventDate: DateTime(2026, 11, 12),
        eventTime: DateTime(2026, 11, 12, 12, 30),
        recipientType: HandoverRecipientTypes.owner,
        recipientName: 'Jan Właściciel',
        propertyDescription: 'Działka przy ul. Tęczowej 44',
        propertyKind: HandoverPropertyKinds.teren,
        handoverFirefighterId: 'ff2',
        signLocality: 'Tuchom',
        signDate: DateTime(2026, 11, 12),
        createdAt: DateTime(2026, 11, 12),
        updatedAt: DateTime(2026, 11, 12),
        createdBy: 'ospkielno@gmail.com',
        enteredById: enteredById,
      );

  /// Wiersz szczegółów: etykieta i wartość w jednym rzędzie.
  Finder row(String label, String value) => find.ancestor(
        of: find.text(value),
        matching:
            find.ancestor(of: find.text(label), matching: find.byType(Row)),
      );

  /// Wartość pokazana w polu „Kto wpisuje?".
  Finder enteredBy(String name) => find.descendant(
      of: find.byType(EnteredByField), matching: find.text(name));

  /// Stuknięcie, po którym ekran zapisuje do Hive — na prawdziwym czasie.
  Future<void> tapAndWrite(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.runAsync(() async {
      await tester.tap(find.text(label));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('szczegóły', () {
    Future<void> pump(WidgetTester tester, Widget screen) async {
      bigScreen(tester);
      final sync = fakeSync();
      when(() => sync.reportsAwaitingUpload(any())).thenReturn(const {});
      when(() => sync.handoversAwaitingUpload(any())).thenReturn(const {});
      await tester
          .pumpWidget(testApp(screen, sync: sync, overrides: on(dawid)));
      await tester.pumpAndSettle();
    }

    testWidgets('wyjazd z tabletu: „Wpisał" ratownik i „Konto" jednostki '
        'zamiast „Dodał"', (tester) async {
      await tester.runAsync(
          () => db.reportsBox.put('r1', report(enteredById: 'ff2')));
      await pump(tester, const ReportDetailScreen(reportId: 'r1'));

      expect(row('Wpisał', 'Nowak Adam'), findsOneWidget);
      expect(row('Konto', 'ospkielno@gmail.com'), findsOneWidget);
      expect(find.text('Dodał'), findsNothing);
    });

    testWidgets('przekazanie z tabletu: „Wpisał" i „Konto"', (tester) async {
      await tester.runAsync(() => db.addHandover(handover(enteredById: 'ff1')));
      await pump(tester, const HandoverDetailScreen(handoverId: 'h1'));

      expect(row('Wpisał', 'Kowalski Jan'), findsOneWidget);
      expect(row('Konto', 'ospkielno@gmail.com'), findsOneWidget);
      expect(find.text('Dodał'), findsNothing);
    });

    testWidgets('ratownik usunięty z listy — kreska, a konto zostaje',
        (tester) async {
      await tester.runAsync(
          () => db.reportsBox.put('r1', report(enteredById: 'usuniety')));
      await pump(tester, const ReportDetailScreen(reportId: 'r1'));

      expect(row('Wpisał', '—'), findsOneWidget);
      expect(row('Konto', 'ospkielno@gmail.com'), findsOneWidget);
    });
  });

  group('kreator wyjazdu', () {
    Widget wizardApp(SyncState state, {String? reportId}) => testRouterApp(
          GoRouter(
            initialLocation: '/reports/edit',
            routes: [
              GoRoute(
                path: '/reports/edit',
                builder: (context, state) =>
                    ReportWizardScreen(reportId: reportId),
              ),
              GoRoute(
                path: '/reports/view/:id',
                builder: (context, state) => Scaffold(
                  body: Text('Zapisano ${state.pathParameters['id']}'),
                ),
              ),
            ],
          ),
          overrides: on(state),
        );

    /// Krok 1 z pojazdem i zagrożeniem, potem przez oba ostrzeżenia
    /// o obsadzie aż do podsumowania.
    Future<void> newReportToSummary(WidgetTester tester) async {
      await tester.ensureVisible(find.text('GBA 2.5/16'));
      await tester.tap(find.text('GBA 2.5/16'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fałszywy Alarm').last);
      await tester.pumpAndSettle();
      await tapNext(tester, 'Dalej — Zastępy');
      await tapNext(tester, 'Podsumowanie');
      await tester.tap(find.text('Kontynuuj mimo to'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kontynuuj mimo to'));
      await tester.pumpAndSettle();
    }

    testWidgets('na tablecie bez wyboru nie zapisuje, po wyborze zapisuje '
        'ratownika', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(wizardApp(tablet));
      await tester.pumpAndSettle();
      await newReportToSummary(tester);

      expect(find.text('Kto wpisuje?'), findsOneWidget);
      await tapAndWrite(tester, 'Zapisz raport');
      expect(find.text('Wybierz, kto wpisuje'), findsOneWidget);
      expect(db.getAllReports(), isEmpty);

      await tester.tap(find.byType(EnteredByField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nowak Adam'));
      await tester.pumpAndSettle();
      expect(enteredBy('Nowak Adam'), findsOneWidget);

      await tapAndWrite(tester, 'Zapisz raport');
      final saved = db.getAllReports().single;
      expect(saved.enteredById, 'ff2');
      expect(saved.createdBy, 'ospkielno@gmail.com');
    });

    testWidgets('podpowiedź to dowódca zastępu', (tester) async {
      bigScreen(tester);
      await tester.runAsync(() => db.reportsBox.put(
          'r1',
          report(crew: [
            CrewAssignment(
                vehicleId: 'v1', vehicleName: 'GBA 2.5/16', commanderId: 'ff2'),
          ])));
      await tester.pumpWidget(wizardApp(tablet, reportId: 'r1'));
      await tester.pumpAndSettle();
      await tapNext(tester, 'Dalej — Zastępy');
      await tapNext(tester, 'Podsumowanie');
      while (find.text('Kontynuuj mimo to').evaluate().isNotEmpty) {
        await tester.tap(find.text('Kontynuuj mimo to'));
        await tester.pumpAndSettle();
      }

      expect(enteredBy('Nowak Adam'), findsOneWidget);
      await tapAndWrite(tester, 'Zapisz raport');
      expect(db.getReport('r1')!.enteredById, 'ff2');
    });

    testWidgets('na prywatnym koncie bez pytania, a poprawka nie kasuje '
        'tego, kto wpisał na tablecie', (tester) async {
      bigScreen(tester);
      await tester.runAsync(() => db.reportsBox.put(
          'r1',
          report(enteredById: 'ff1', crew: [
            CrewAssignment(
                vehicleId: 'v1', vehicleName: 'GBA 2.5/16', commanderId: 'ff2'),
          ])));
      await tester.pumpWidget(wizardApp(dawid, reportId: 'r1'));
      await tester.pumpAndSettle();
      await tapNext(tester, 'Dalej — Zastępy');
      await tapNext(tester, 'Podsumowanie');
      while (find.text('Kontynuuj mimo to').evaluate().isNotEmpty) {
        await tester.tap(find.text('Kontynuuj mimo to'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Kto wpisuje?'), findsNothing);
      await tapAndWrite(tester, 'Zapisz raport');
      expect(find.text('Zapisano r1'), findsOneWidget);
      expect(db.getReport('r1')!.enteredById, 'ff1');
    });
  });

  group('przekazanie mienia', () {
    Widget formApp(SyncState state) => testRouterApp(
          GoRouter(
            initialLocation: '/handovers/edit/h1',
            routes: [
              GoRoute(
                path: '/handovers/edit/:id',
                builder: (context, s) =>
                    HandoverFormScreen(handoverId: s.pathParameters['id']),
              ),
              GoRoute(
                path: '/handovers/view/:id',
                builder: (context, s) => Scaffold(
                  body: Text('Zapisano ${s.pathParameters['id']}'),
                ),
              ),
            ],
          ),
          overrides: on(state),
        );

    testWidgets('na tablecie podpowiedź to przekazujący i trafia do zapisu',
        (tester) async {
      bigScreen(tester);
      await tester.runAsync(() => db.addHandover(handover()));
      await tester.pumpWidget(formApp(tablet));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(EnteredByField));
      expect(enteredBy('Nowak Adam'), findsOneWidget);

      await tapAndWrite(tester, 'Zapisz zmiany');
      expect(find.text('Zapisano h1'), findsOneWidget);
      expect(db.getHandover('h1')!.enteredById, 'ff2');
    });

    testWidgets('na prywatnym koncie pola nie ma', (tester) async {
      bigScreen(tester);
      await tester.runAsync(() => db.addHandover(handover()));
      await tester.pumpWidget(formApp(dawid));
      await tester.pumpAndSettle();

      expect(find.byType(EnteredByField), findsNothing);
      await tapAndWrite(tester, 'Zapisz zmiany');
      expect(find.text('Zapisano h1'), findsOneWidget);
      expect(db.getHandover('h1')!.enteredById, isNull);
    });
  });
}
