import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/settings/unit_members_section.dart';
import 'package:osp_app/models/unit_member.dart';
import 'package:osp_app/widgets/upload_status.dart';

import '../helpers/test_app.dart';

/// Napisy przy jednostce na serwerze (feature/081): bez „Dysku” i bez
/// zgadywania o starszej wersji przy kimś, kto jeszcze nie dołączył.
void main() {
  late Directory tempDir;

  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() => disposeTestHive(tempDir));

  const connected = SyncState(
    status: SyncStatus.idle,
    userEmail: 'dawid@gmail.com',
    unitId: 'unit1',
    founderEmail: 'dawid@gmail.com',
  );

  FakeSyncService serverSync() => fakeSync();

  testWidgets('pasek wysyłki mówi o serwerze jednostki', (tester) async {
    final sync = serverSync();
    await tester.pumpWidget(testApp(
      const Scaffold(
        body: Column(children: [
          UploadStatusBanner(subject: 'Wyjazd', pending: false),
          UploadStatusBanner(subject: 'Wyjazd', pending: true),
          AwaitingUploadIcon(),
        ]),
      ),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith((ref) =>
            FixedSyncState(ref.watch(syncServiceProvider), connected)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Zapisano na serwerze jednostki'), findsOneWidget);
    expect(find.text('Czeka na wysłanie na serwer jednostki'), findsOneWidget);
    expect(find.textContaining('Dysk'), findsNothing);
  });

  testWidgets('członkowie: kto dołączył i kto jest tylko zaproszony',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sync = serverSync();
    when(() => sync.listMembers()).thenAnswer((_) async => [
          UnitMember(
            email: 'dawid@gmail.com',
            uid: 'u1',
            isOwner: true,
            joinedAt: DateTime(2026, 11, 27, 9),
            lastSyncAt: DateTime(2026, 11, 20, 8),
            appVersion: '2.0.0',
          ),
          const UnitMember(email: 'jan@gmail.com'),
        ]);

    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: UnitMembersSection())),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith((ref) =>
            FixedSyncState(ref.watch(syncServiceProvider), connected)),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('musi być na liście zaproszonych'),
        findsOneWidget);
    await tester.tap(find.text('Pokaż członków'));
    await tester.pumpAndSettle();

    expect(find.text('Zaproszony — jeszcze nie dołączył'), findsOneWidget);
    expect(find.textContaining('W aplikacji od 27.11.2026'), findsOneWidget);
    expect(find.textContaining('starsza wersja'), findsNothing);
    expect(find.textContaining('Dysk'), findsNothing);
  });
}
