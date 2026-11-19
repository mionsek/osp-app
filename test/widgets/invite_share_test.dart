import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/settings/unit_members_section.dart';

import '../helpers/test_app.dart';

/// Zaproszenie także SMS-em albo komunikatorem (Dawid, 19.11.2026):
/// powiadomienie Google o udostępnieniu folderu wygląda jak każde inne
/// z Dysku, więc zaproszony go nie rozpoznał.
void main() {
  late Directory tempDir;
  final original = UnitMembersSection.shareText;

  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() async {
    UnitMembersSection.shareText = original;
    await disposeTestHive(tempDir);
  });

  /// Napisy bez „kolegi" i „strażaka" — nie każdy zaproszony to kolega,
  /// a zaproszenie jest już wysłane (Dawid, 19.11.2026: „Udostępnij kod").
  Finder neutral() =>
      find.textContaining(RegExp('koleg|strażak', caseSensitive: false));

  const admin = SyncState(
    status: SyncStatus.idle,
    userEmail: 'dawid@gmail.com',
    unitFolderId: 'folder',
    unitInviteCode: 'ABC234',
    founderEmail: 'dawid@gmail.com',
  );

  Future<FakeSyncService> pumpSection(WidgetTester tester,
      {required List<String> shared}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sync = fakeSync();
    when(() => sync.inviteMember('jan@gmail.com'))
        .thenAnswer((_) async => 'TREŚĆ ZAPROSZENIA Z KODEM ABC234');
    when(() => sync.listMembers()).thenAnswer((_) async => const []);
    UnitMembersSection.shareText = (text) async => shared.add(text);

    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: UnitMembersSection())),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith(
            (ref) => FixedSyncState(ref.watch(syncServiceProvider), admin)),
      ],
    ));
    await tester.pumpAndSettle();
    expect(neutral(), findsNothing, reason: 'sekcja „Członkowie jednostki"');

    await tester.tap(find.text('Zaproś do jednostki'));
    await tester.pumpAndSettle();
    expect(neutral(), findsNothing, reason: 'okno „Zaproś do jednostki"');
    await tester.enterText(find.byType(TextField), 'jan@gmail.com');
    await tester.tap(find.text('Zaproś'));
    await tester.pumpAndSettle();
    return sync;
  }

  testWidgets('po zaproszeniu okno z „Udostępnij kod" — wysyła tę samą treść '
      'co powiadomienie Google', (tester) async {
    final shared = <String>[];
    final sync = await pumpSection(tester, shared: shared);

    verify(() => sync.inviteMember('jan@gmail.com')).called(1);
    expect(find.text('Zaproszenie wysłane'), findsOneWidget);
    expect(
        find.textContaining('Google wyśle na jan@gmail.com powiadomienie'),
        findsOneWidget);
    expect(find.textContaining('z kodem ABC234'), findsOneWidget);
    expect(neutral(), findsNothing, reason: 'okno „Zaproszenie wysłane"');

    await tester.tap(find.text('Udostępnij kod'));
    await tester.pumpAndSettle();
    expect(shared, ['TREŚĆ ZAPROSZENIA Z KODEM ABC234']);
    expect(find.text('Zaproszenie wysłane'), findsNothing);
  });

  testWidgets('„Gotowe" zamyka okno bez wysyłania', (tester) async {
    final shared = <String>[];
    await pumpSection(tester, shared: shared);

    await tester.tap(find.text('Gotowe'));
    await tester.pumpAndSettle();
    expect(shared, isEmpty);
    expect(find.text('Zaproszenie wysłane'), findsNothing);
  });
}
