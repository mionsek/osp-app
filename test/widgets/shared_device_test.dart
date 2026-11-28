import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/onboarding/onboarding_screen.dart';
import 'package:osp_app/screens/settings/unit_members_section.dart';
import 'package:osp_app/models/unit_member.dart';

import '../helpers/test_app.dart';

/// Wspólne urządzenie przy dowolnym koncie i imiona na liście członków
/// (Dawid, 27.11.2026): „jak w samochodzie jednostki loguję się na
/// tablecie, to kontem jednostki, a jak ze swojego telefonu, to swoim
/// kontem i tyle", „skoro i tak jest logowanie Google, to można by dodać
/// imię i nazwisko, kto dołączył".
void main() {
  late Directory tempDir;
  late FakeSyncService sync;

  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() => disposeTestHive(tempDir));

  const admin = SyncState(
    status: SyncStatus.idle,
    userEmail: 'dawid@gmail.com',
    unitId: 'folder',
    unitInviteCode: 'ABC234',
    founderEmail: 'dawid@gmail.com',
  );

  Future<void> pumpMembers(WidgetTester tester, SyncState state) async {
    sync = fakeSync();
    when(() => sync.listMembers()).thenAnswer((_) async => const [
          UnitMember(
              email: 'dawid@gmail.com',
              uid: 'd',
              isOwner: true,
              name: 'Dawid Mionskowski'),
          UnitMember(email: 'ospkielno@gmail.com', uid: 't', name: 'OSP Kielno'),
          UnitMember(email: 'jan@gmail.com'),
        ]);
    when(() => sync.setSharedDevice(any(), any())).thenAnswer((_) async {});

    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: UnitMembersSection())),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith(
            (ref) => FixedSyncState(ref.watch(syncServiceProvider), state)),
      ],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokaż członków'));
    await tester.pumpAndSettle();
  }

  Finder menuOf(String title) => find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Card))
            .first,
        matching: find.byTooltip('Rola i dostęp'),
      );

  testWidgets('lista: imię z konta Google, pod nim adres, i ile osób '
      'dołączyło', (tester) async {
    await pumpMembers(tester, admin);

    expect(find.text('Dawid Mionskowski  (Ty)'), findsOneWidget);
    expect(find.text('dawid@gmail.com'), findsOneWidget);
    expect(find.text('OSP Kielno'), findsOneWidget);
    expect(find.text('ospkielno@gmail.com'), findsOneWidget);
    // Zaproszony nie ma jeszcze imienia — sam adres.
    expect(find.text('jan@gmail.com'), findsOneWidget);
    expect(
        find.text(
            'W jednostce: 2 · zaproszeni, którzy jeszcze nie dołączyli: 1'),
        findsOneWidget);
  });

  testWidgets('administrator robi z konta jednostki wspólne urządzenie, '
      'choć to nie ono zakładało jednostkę', (tester) async {
    await pumpMembers(tester, admin);

    await tester.tap(menuOf('OSP Kielno'));
    await tester.pumpAndSettle();
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Odbierz dostęp'), findsOneWidget);
    await tester.tap(find.text('Wspólne urządzenie (tablet)'));
    await tester.pumpAndSettle();
    expect(find.text('Wspólne urządzenie jednostki?'), findsOneWidget);
    expect(find.textContaining('OSP Kielno będzie działać jak konto zwykłego'),
        findsOneWidget);

    await tester.tap(find.text('Włącz'));
    await tester.pumpAndSettle();
    verify(() => sync.setSharedDevice('ospkielno@gmail.com', true)).called(1);
  });

  testWidgets('wspólne urządzenie na liście: rola i wyłączenie', (tester) async {
    await pumpMembers(
        tester,
        const SyncState(
          status: SyncStatus.idle,
          userEmail: 'dawid@gmail.com',
          unitId: 'folder',
          unitInviteCode: 'ABC234',
          founderEmail: 'dawid@gmail.com',
          sharedEmails: ['ospkielno@gmail.com'],
        ));

    expect(
        find.text('Wspólne urządzenie — jak zwykły członek, pyta, kto wpisuje'),
        findsOneWidget);
    await tester.tap(menuOf('OSP Kielno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wspólne urządzenie (tablet)'));
    await tester.pumpAndSettle();
    expect(find.text('Wyłączyć wspólne urządzenie?'), findsOneWidget);
    await tester.tap(find.text('Wyłącz'));
    await tester.pumpAndSettle();
    verify(() => sync.setSharedDevice('ospkielno@gmail.com', false)).called(1);
  });

  testWidgets('zaproszenie od razu jako wspólne urządzenie', (tester) async {
    await pumpMembers(tester, admin);
    when(() => sync.inviteMember(any(),
            sharedDevice: any(named: 'sharedDevice')))
        .thenAnswer((_) async => 'Zaproszenie');

    await tester.tap(find.text('Zaproś do jednostki'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'ospkielno@gmail.com',
    );
    await tester.tap(find.text('Wspólne urządzenie jednostki'));
    await tester.pump();
    await tester.tap(find.text('Zaproś'));
    await tester.pumpAndSettle();

    verify(() => sync.inviteMember('ospkielno@gmail.com', sharedDevice: true))
        .called(1);
  });

  test('podsumowanie bez zaproszonych — sama liczba', () {
    expect(
      membersSummary(const [
        UnitMember(email: 'a@x.pl', uid: 'a', isOwner: true),
      ]),
      'W jednostce: 1',
    );
  });

  group('którym kontem zalogować to urządzenie', () {
    Future<void> pumpHint(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                AccountForDeviceHint(tablet: isTabletLayout(context)),
          ),
        ),
      ));
    }

    FontWeight? weightOf(WidgetTester tester, String start) => tester
        .widget<Text>(find.textContaining(start))
        .style
        ?.fontWeight;

    testWidgets('na tablecie pogrubione konto jednostki', (tester) async {
      await pumpHint(tester, const Size(1280, 800));
      expect(weightOf(tester, 'Tablet lub telefon jednostki'), FontWeight.w600);
      expect(weightOf(tester, 'Swój telefon'), FontWeight.normal);
    });

    testWidgets('na telefonie pogrubione swoje konto', (tester) async {
      await pumpHint(tester, const Size(400, 800));
      expect(weightOf(tester, 'Tablet lub telefon jednostki'),
          FontWeight.normal);
      expect(weightOf(tester, 'Swój telefon'), FontWeight.w600);
    });
  });
}
