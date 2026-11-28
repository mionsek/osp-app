import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/settings/unit_members_section.dart';

import '../helpers/test_app.dart';

/// „Członkowie jednostki": przy każdej osobie — czy i kiedy dołączyła
/// (feature/080), z rekordu członka na serwerze.
void main() {
  late Directory tempDir;

  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() => disposeTestHive(tempDir));

  group('napis przy osobie', () {
    final now = DateTime(2026, 11, 27, 15, 30);

    UnitMember member(DateTime last) => UnitMember(
          email: 'b@gmail.com',
          uid: 'b',
          joinedAt: DateTime(2026, 11, 25, 9),
          lastSyncAt: last,
          appVersion: '1.9.20',
        );

    test('dziś, wczoraj, wcześniej', () {
      expect(memberStatus(member(DateTime(2026, 11, 27, 14, 5)), now),
          'W aplikacji od 25.11.2026 · ostatnio dziś 14:05 · wersja 1.9.20');
      expect(memberStatus(member(DateTime(2026, 11, 26, 20, 0)), now),
          'W aplikacji od 25.11.2026 · ostatnio wczoraj 20:00 · wersja 1.9.20');
      expect(memberStatus(member(DateTime(2026, 11, 20, 8, 0)), now),
          'W aplikacji od 25.11.2026 · ostatnio 20.11.2026 · wersja 1.9.20');
    });

    test('zaproszony, który jeszcze nie dołączył', () {
      expect(memberStatus(const UnitMember(email: 'c@gmail.com'), now),
          'Zaproszony — jeszcze nie dołączył');
    });

    test('rekord bez dat — samo „W aplikacji"', () {
      expect(memberStatus(const UnitMember(email: 'd@gmail.com', uid: 'd'), now),
          'W aplikacji');
    });
  });

  testWidgets('lista: kto dołączył, od kiedy i z jaką wersją; zaproszony '
      'osobno', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sync = fakeSync();
    when(() => sync.listMembers()).thenAnswer((_) async => [
          const UnitMember(email: 'dawid@gmail.com', uid: 'd', isOwner: true),
          UnitMember(
            email: 'anna@gmail.com',
            uid: 'a',
            joinedAt: DateTime(2026, 11, 25, 9),
            lastSyncAt: DateTime(2026, 11, 20, 8),
            appVersion: '1.9.20',
          ),
          const UnitMember(email: 'jan@gmail.com'),
        ]);

    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: UnitMembersSection())),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith((ref) => FixedSyncState(
            ref.watch(syncServiceProvider),
            const SyncState(
              status: SyncStatus.idle,
              userEmail: 'dawid@gmail.com',
              unitId: 'unit',
              founderEmail: 'dawid@gmail.com',
            ))),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pokaż członków'));
    await tester.pumpAndSettle();

    expect(
        find.text('W aplikacji od 25.11.2026 · ostatnio 20.11.2026 · '
            'wersja 1.9.20'),
        findsOneWidget);
    expect(find.text('Zaproszony — jeszcze nie dołączył'), findsOneWidget);
    expect(find.textContaining('Brak śladu'), findsNothing,
        reason: 'napis z czasów Dysku — na serwerze każdy członek ma rekord');
  });
}
