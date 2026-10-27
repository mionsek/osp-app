import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/reports/report_detail_screen.dart';
import 'package:osp_app/screens/reports/reports_list_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Ekran wyjazdu i lista wyjazdów: czy wyjazd jest na Dysku jednostki i czy
/// jego numer się nie powtarza.
///
/// Test 1.7.4 na dwóch telefonach: wyjazd kolegi czekał na telefonie, a jego
/// ekran pisał „Zapisano na Google Drive". Oba telefony nadały w tych samych
/// minutach numer 0002/2026, a o duplikacie mówił tylko 6-sekundowy pasek.
void main() {
  late Directory tempDir;
  late DatabaseService db;
  final year = DateTime.now().year;

  setUp(() async {
    tempDir = await setUpTestHive();
    db = DatabaseService();
  });

  tearDown(() => disposeTestHive(tempDir));

  const wojtekInUnit = SyncState(
    status: SyncStatus.idle,
    userEmail: 'wojtek@gmail.com',
    unitFolderId: 'folder',
    unitInviteCode: 'URZEAZ',
    founderEmail: 'ospkielno@gmail.com',
  );

  Report report(
    String id,
    String number, {
    String createdBy = 'wojtek@gmail.com',
    String locality = 'Kielno',
    String threat = 'Miejscowe Zagrożenie',
    int minute = 35,
  }) =>
      Report(
        id: id,
        reportNumber: number,
        year: year,
        date: DateTime(year, 10, 27),
        departureTime: DateTime(year, 10, 27, 16, minute),
        addressLocality: locality,
        addressStreet: '',
        addressDescription: '',
        threatCategory: threat,
        createdAt: DateTime(year, 10, 27),
        updatedAt: DateTime(year, 10, 27),
        createdBy: createdBy,
      );

  /// Wyjazdy do zapisania przed uruchomieniem ekranu. Zapis pliku Hive to
  /// prawdziwe operacje na dysku — w teście widoku (udawany czas) `await`
  /// na nim nie wraca, więc [pump] zapisuje je w `runAsync`.
  final pending = <Report>[];
  void seed(Report r) => pending.add(r);

  Future<FakeSyncService> pump(
    WidgetTester tester,
    Widget screen,
    SyncState state, {
    Set<String> awaiting = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      for (final r in pending) {
        await db.reportsBox.put(r.id, r);
      }
    });
    pending.clear();

    final sync = fakeSync();
    when(() => sync.reportsAwaitingUpload(any())).thenReturn(awaiting);
    await tester.pumpWidget(testApp(
      screen,
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith(
            (ref) => FixedSyncState(ref.watch(syncServiceProvider), state)),
      ],
    ));
    await tester.pumpAndSettle();
    return sync;
  }

  group('ekran wyjazdu — czy jest na Dysku', () {
    testWidgets('wyjazd, który nie wyszedł z telefonu, nie udaje, że jest '
        'na Dysku', (tester) async {
      seed(report('r-w', '0002/$year'));
      await pump(
        tester,
        const ReportDetailScreen(reportId: 'r-w'),
        wojtekInUnit.copyWith(lastSyncTime: DateTime.now()),
        awaiting: {'r-w'},
      );

      expect(find.text('Czeka na wysłanie na Dysk jednostki'), findsOneWidget);
      expect(find.text('Wyślij teraz'), findsOneWidget);
      expect(find.text('Zapisano na Dysku jednostki'), findsNothing);
      expect(find.text('Zapisano na Google Drive'), findsNothing);
    });

    testWidgets('wysłany wyjazd — „Zapisano na Dysku jednostki"',
        (tester) async {
      seed(report('r-w', '0002/$year'));
      await pump(tester, const ReportDetailScreen(reportId: 'r-w'),
          wojtekInUnit);

      expect(find.text('Zapisano na Dysku jednostki'), findsOneWidget);
      expect(find.text('Wyślij teraz'), findsNothing);
    });

    testWidgets('po błędzie — że wyjazd jest tylko na telefonie, z powodem '
        'i godziną', (tester) async {
      seed(report('r-w', '0002/$year'));
      final now = DateTime.now();
      await pump(
        tester,
        const ReportDetailScreen(reportId: 'r-w'),
        wojtekInUnit.copyWith(
          status: SyncStatus.error,
          errorMessage: 'Połączenie z internetem zostało przerwane.',
          errorTime: DateTime(now.year, now.month, now.day, 17, 41),
        ),
        awaiting: {'r-w'},
      );

      expect(
        find.textContaining('jest na telefonie, ale jeszcze nie na Dysku'),
        findsOneWidget,
      );
      expect(find.textContaining('o 17:41'), findsOneWidget);
    });

    testWidgets('bez jednostki — bez paska o Dysku', (tester) async {
      seed(report('r-w', '0002/$year'));
      await pump(tester, const ReportDetailScreen(reportId: 'r-w'),
          const SyncState());

      expect(find.textContaining('Dysku jednostki'), findsNothing);
      expect(find.text('Wyślij teraz'), findsNothing);
    });
  });

  group('powtórzony numer', () {
    Future<void> twoPhonesSameNumber() async {
      seed(report('r-a', '0002/$year',
          createdBy: 'ospkielno@gmail.com',
          locality: 'Gdynia',
          threat: 'Fałszywy Alarm'));
      seed(report('r-w', '0002/$year'));
    }

    testWidgets('autor widzi drugi wyjazd i nadaje swojemu nowy numer',
        (tester) async {
      await twoPhonesSameNumber();
      final sync = await pump(
          tester, const ReportDetailScreen(reportId: 'r-w'), wojtekInUnit);

      expect(find.text('Numer 0002/$year ma też inny wyjazd'), findsOneWidget);
      expect(
        find.textContaining('Gdynia — Fałszywy Alarm, z konta '
            'ospkielno@gmail.com'),
        findsOneWidget,
      );

      // Zmiana numeru zapisuje wyjazd w Hive — cały przebieg (okno i zapis)
      // na prawdziwym czasie.
      Future<void> tapReal(String label) async {
        await tester.runAsync(() async {
          await tester.tap(find.text(label));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
      }

      await tapReal('Nadaj temu wyjazdowi numer 0003/$year');
      expect(find.text('Zmienić numer na 0003/$year?'), findsOneWidget);
      await tapReal('Zmień numer');

      expect(db.getReport('r-w')!.reportNumber, '0003/$year');
      expect(db.getReport('r-a')!.reportNumber, '0002/$year');
      expect(find.text('Wyjazd 0003/$year'), findsOneWidget);
      expect(find.textContaining('ma też inny wyjazd'), findsNothing);
      verify(() => sync.notifyLocalChange()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('cudzy wyjazd — bez przycisku, z informacją, kto może '
        'zmienić numer', (tester) async {
      await twoPhonesSameNumber();
      await pump(
          tester, const ReportDetailScreen(reportId: 'r-a'), wojtekInUnit);

      expect(find.text('Numer 0002/$year ma też inny wyjazd'), findsOneWidget);
      expect(find.textContaining('może zmienić jego autor albo administrator'),
          findsOneWidget);
      expect(find.textContaining('Nadaj temu wyjazdowi'), findsNothing);
    });

    testWidgets('różne wyjazdy — że późniejszy poprawi się sam', (tester) async {
      await twoPhonesSameNumber();
      await pump(
          tester, const ReportDetailScreen(reportId: 'r-w'), wojtekInUnit);

      expect(find.textContaining('dostanie nowy numer sam'), findsOneWidget);
      expect(find.text('Ten sam wyjazd zapisany dwa razy?'), findsNothing);
    });

    testWidgets('ta sama akcja zapisana dwa razy — pytanie zamiast '
        'automatu', (tester) async {
      // Dwóch strażaków z tej samej akcji: kwadrans różnicy, ta sama
      // miejscowość i zagrożenie.
      seed(report('r-a', '0002/$year', createdBy: 'ospkielno@gmail.com'));
      seed(report('r-w', '0002/$year', minute: 50));
      await pump(
          tester, const ReportDetailScreen(reportId: 'r-w'), wojtekInUnit);

      expect(find.text('Ten sam wyjazd zapisany dwa razy?'), findsOneWidget);
      expect(find.textContaining('usuń jeden z wyjazdów'), findsOneWidget);
      expect(find.textContaining('16:35, Kielno — Miejscowe Zagrożenie'),
          findsOneWidget);
      expect(find.textContaining('dostanie nowy numer sam'), findsNothing);
    });

    testWidgets('lista oznacza oba wyjazdy z tym samym numerem i ten, który '
        'czeka na wysłanie', (tester) async {
      await twoPhonesSameNumber();
      seed(report('r-1', '0001/$year'));
      await pump(tester, const ReportsListScreen(), wojtekInUnit,
          awaiting: {'r-w'});

      expect(find.text('Ten sam numer ma inny wyjazd'), findsNWidgets(2));
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });
  });
}
