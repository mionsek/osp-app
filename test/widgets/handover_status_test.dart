import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/handovers/handover_detail_screen.dart';
import 'package:osp_app/screens/handovers/handovers_list_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Ekran i lista przekazań mienia: czy przekazanie jest na Dysku jednostki.
///
/// Zgłoszenie z testu 1.7.6: przekazanie kolegi nie dotarło do Dawida, a ekran
/// przekazania nie mówił, czy w ogóle wyszło z telefonu — inaczej niż ekran
/// wyjazdu od 1.7.5.
void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUp(() async {
    tempDir = await setUpTestHive();
    db = DatabaseService();
  });

  tearDown(() => disposeTestHive(tempDir));

  const inUnit = SyncState(
    status: SyncStatus.idle,
    userEmail: 'wojtek@gmail.com',
    unitFolderId: 'folder',
    unitInviteCode: 'URZEAZ',
    founderEmail: 'ospkielno@gmail.com',
  );

  final at = DateTime(2026, 10, 27, 17, 30);
  PropertyHandover handover(String id) => PropertyHandover(
        id: id,
        eventLocation: 'Kielno',
        eventDate: DateTime(2026, 10, 27),
        eventTime: at,
        recipientName: 'Jan Właściciel',
        signDate: DateTime(2026, 10, 27),
        createdAt: at,
        updatedAt: at,
        createdBy: 'wojtek@gmail.com',
      );

  late FakeSyncService sync;

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    SyncState state = inUnit,
    Set<String> awaiting = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Zapis pliku Hive to prawdziwe operacje na dysku — na prawdziwym czasie.
    await tester.runAsync(() => db.addHandover(handover('h1')));
    sync = fakeSync();
    when(() => sync.handoversAwaitingUpload(any())).thenReturn(awaiting);
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

  testWidgets('przekazanie, które nie wyszło z telefonu — „Czeka na '
      'wysłanie" i „Wyślij teraz"', (tester) async {
    await pump(tester, const HandoverDetailScreen(handoverId: 'h1'),
        awaiting: {'h1'});

    expect(find.text('Czeka na wysłanie na Dysk jednostki'), findsOneWidget);
    expect(find.text('Wyślij teraz'), findsOneWidget);
  });

  testWidgets('wysłane — „Zapisano na Dysku jednostki"', (tester) async {
    await pump(tester, const HandoverDetailScreen(handoverId: 'h1'));

    expect(find.text('Zapisano na Dysku jednostki'), findsOneWidget);
  });

  testWidgets('po błędzie — że przekazanie jest tylko na telefonie',
      (tester) async {
    await pump(
      tester,
      const HandoverDetailScreen(handoverId: 'h1'),
      state: inUnit.copyWith(
        status: SyncStatus.error,
        errorMessage: 'Połączenie z internetem zostało przerwane.',
        errorTime: DateTime.now(),
      ),
      awaiting: {'h1'},
    );

    expect(
      find.textContaining(
          'Przekazanie jest na telefonie, ale jeszcze nie na Dysku'),
      findsOneWidget,
    );
  });

  testWidgets('bez jednostki — bez paska o Dysku', (tester) async {
    await pump(tester, const HandoverDetailScreen(handoverId: 'h1'),
        state: const SyncState());

    expect(find.textContaining('Dysku jednostki'), findsNothing);
  });

  testWidgets('lista oznacza przekazanie czekające na wysłanie i przy '
      'otwarciu pobiera zmiany kolegów', (tester) async {
    await pump(tester, const HandoversListScreen(), awaiting: {'h1'});

    expect(find.text('Kielno'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    verify(() => sync.syncIfStale()).called(1);
  });
}
