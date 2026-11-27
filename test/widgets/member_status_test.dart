import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/settings/unit_members_section.dart';
import 'package:osp_app/services/google_drive_service.dart';

import '../helpers/test_app.dart';

/// „Członkowie jednostki": przy każdej osobie z dostępem — czy naprawdę
/// dołączyła (feature/080).
void main() {
  late Directory tempDir;

  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() => disposeTestHive(tempDir));

  testWidgets('osoba z notatką: od kiedy, ostatnio, wersja; bez notatki — '
      'brak śladu', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sync = fakeSync();
    when(() => sync.listMembers()).thenAnswer((_) async => const [
          UnitMemberAccess(
              permissionId: 'p0', email: 'dawid@gmail.com', isOwner: true),
          UnitMemberAccess(
              permissionId: 'p1', email: 'Anna@gmail.com', isOwner: false),
          UnitMemberAccess(
              permissionId: 'p2', email: 'jan@gmail.com', isOwner: false),
        ]);
    when(() => sync.memberNotes()).thenAnswer((_) async => {
          'anna@gmail.com': MemberNote(
            email: 'anna@gmail.com',
            joinedAt: DateTime(2026, 11, 25, 9),
            lastSyncAt: DateTime(2026, 11, 20, 8),
            appVersion: '1.9.20',
          ),
        });

    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: UnitMembersSection())),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith((ref) => FixedSyncState(
            ref.watch(syncServiceProvider),
            const SyncState(
              status: SyncStatus.idle,
              userEmail: 'dawid@gmail.com',
              unitFolderId: 'folder',
              founderEmail: 'dawid@gmail.com',
            ))),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pokaż, kto ma dostęp'));
    await tester.pumpAndSettle();

    expect(
        find.text('W aplikacji od 25.11.2026 · ostatnio 20.11.2026 · '
            'wersja 1.9.20'),
        findsOneWidget,
        reason: 'adres z uprawnień wielkimi literami pasuje do notatki');
    expect(
        find.text('Brak śladu w aplikacji — zaproszenie nieprzyjęte albo '
            'starsza wersja aplikacji'),
        findsNWidgets(2),
        reason: 'założyciel na starej wersji i Jan bez notatek');
  });

  testWidgets('błąd odczytu notatek nie blokuje listy uprawnień',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sync = fakeSync();
    when(() => sync.listMembers()).thenAnswer((_) async => const [
          UnitMemberAccess(
              permissionId: 'p1', email: 'jan@gmail.com', isOwner: false),
        ]);
    when(() => sync.memberNotes()).thenThrow(Exception('brak sieci'));

    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: UnitMembersSection())),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith((ref) => FixedSyncState(
            ref.watch(syncServiceProvider),
            const SyncState(
              status: SyncStatus.idle,
              userEmail: 'dawid@gmail.com',
              unitFolderId: 'folder',
              founderEmail: 'dawid@gmail.com',
            ))),
      ],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokaż, kto ma dostęp'));
    await tester.pumpAndSettle();

    expect(find.text('jan@gmail.com'), findsOneWidget);
    expect(find.textContaining('Nie udało się pobrać listy'), findsNothing);
  });
}
