import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/handovers/handover_detail_screen.dart';
import 'package:osp_app/screens/reports/report_detail_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// „Dodał: e-mail" na wyjeździe i przekazaniu mienia.
///
/// Prośba Dawida z 11.11.2026: przy wpisie kolegi widać, kto go dodał —
/// mała informacja tylko na ekranie, bez zmiany wydruku. Adres to konto,
/// z którego wpis zapisano (`createdBy`, jedzie przez Dysk od dawna).
void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUp(() async {
    tempDir = await setUpTestHive();
    db = DatabaseService();
  });

  tearDown(() => disposeTestHive(tempDir));

  /// Telefon Dawida w jednostce — oglądane wpisy dodał kolega.
  const viewer = SyncState(
    status: SyncStatus.idle,
    userEmail: 'mionskowski.dawid@gmail.com',
    unitFolderId: 'folder',
    founderEmail: 'ospkielno@gmail.com',
  );

  Future<void> pump(WidgetTester tester, Widget screen,
      Future<void> Function() seed) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(seed);
    final sync = fakeSync();
    when(() => sync.reportsAwaitingUpload(any())).thenReturn(const {});
    when(() => sync.handoversAwaitingUpload(any())).thenReturn(const {});
    await tester.pumpWidget(testApp(
      screen,
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith(
            (ref) => FixedSyncState(ref.watch(syncServiceProvider), viewer)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  Report report(String createdBy) => Report(
        id: 'r1',
        reportNumber: '0017/2026',
        year: 2026,
        date: DateTime(2026, 11, 11),
        departureTime: DateTime(2026, 11, 11, 11, 20),
        addressLocality: 'Tuchom',
        addressStreet: 'Tęczowa 44',
        addressDescription: '',
        threatCategory: 'Fałszywy Alarm',
        createdAt: DateTime(2026, 11, 11),
        updatedAt: DateTime(2026, 11, 11),
        createdBy: createdBy,
      );

  PropertyHandover handover(String createdBy) => PropertyHandover(
        id: 'h1',
        eventLocation: 'Tuchom',
        eventDate: DateTime(2026, 11, 11),
        eventTime: DateTime(2026, 11, 11, 12, 30),
        recipientName: 'Jan Właściciel',
        signDate: DateTime(2026, 11, 11),
        createdAt: DateTime(2026, 11, 11),
        updatedAt: DateTime(2026, 11, 11),
        createdBy: createdBy,
      );

  /// Wiersz „Dodał" z adresem — etykieta i wartość w jednym rzędzie.
  Finder authorRow(String email) => find.ancestor(
        of: find.text(email),
        matching: find.ancestor(
            of: find.text('Dodał'), matching: find.byType(Row)),
      );

  testWidgets('wyjazd kolegi: „Dodał" i jego e-mail', (tester) async {
    await pump(tester, const ReportDetailScreen(reportId: 'r1'),
        () => db.reportsBox.put('r1', report('wojtek@gmail.com')));

    expect(authorRow('wojtek@gmail.com'), findsOneWidget);
  });

  testWidgets('przekazanie mienia kolegi: „Dodał" i jego e-mail',
      (tester) async {
    await pump(tester, const HandoverDetailScreen(handoverId: 'h1'),
        () => db.addHandover(handover('wojtek@gmail.com')));

    expect(authorRow('wojtek@gmail.com'), findsOneWidget);
  });

  testWidgets('wpis bez zalogowania nie ma autora — bez pustego wiersza',
      (tester) async {
    await pump(tester, const ReportDetailScreen(reportId: 'r1'),
        () => db.reportsBox.put('r1', report('')));
    expect(find.text('Dodał'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await pump(tester, const HandoverDetailScreen(handoverId: 'h1'),
        () => db.addHandover(handover('')));
    expect(find.text('Dodał'), findsNothing);
  });
}
