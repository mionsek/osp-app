import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/home/home_screen.dart';

import '../helpers/test_app.dart';

/// Powitanie na czerwonym pasku ekranu głównego: kto jest zalogowany
/// i z jakimi uprawnieniami w jakiej jednostce.
///
/// Zgłoszenie Dawida: nazwę jednostki było widać na pasku, ale nie to, kto
/// jest zalogowany i czy jest administratorem, członkiem, czy w ogóle
/// połączony z jednostką. Potem (6.11.2026): „Witaj" ma stać na pasku,
/// razem z nazwą jednostki, a nie pod nim na białym tle.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
    seededDb(
      vehicles: [Vehicle(id: 'v1', name: 'GBA', seats: 6)],
      firefighters: [firefighter('f1', 'Jan', 'Kowalski')],
      config: UnitConfig(
        unitFullName: 'Ochotnicza Straż Pożarna w Kielnie',
        onboardingCompleted: true,
      ),
    );
  });

  tearDown(() => disposeTestHive(tempDir));

  Future<void> pump(
    WidgetTester tester,
    SyncState state, {
    String? displayName,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = FakeAuthService();
    when(() => auth.displayName).thenReturn(displayName);
    when(() => auth.userEmail).thenReturn(state.userEmail);
    final sync = fakeSync();
    when(() => sync.authService).thenReturn(auth);
    await tester.pumpWidget(testRouterApp(
      GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
        GoRoute(path: '/settings', builder: (c, s) => const Text('USTAWIENIA')),
      ]),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith(
            (ref) => FixedSyncState(ref.watch(syncServiceProvider), state)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  /// Tekst na czerwonym pasku, nie pod nim.
  Finder onBar(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  const founder = SyncState(
    status: SyncStatus.idle,
    userEmail: 'mionskowski.dawid@gmail.com',
    unitFolderId: 'folder',
    founderEmail: 'mionskowski.dawid@gmail.com',
  );

  const joinHint = 'Dołącz do jednostki w Ustawieniach';

  testWidgets('administrator: imię z konta Google i rola w jednostce — '
      'na pasku, nazwa jednostki tylko raz', (tester) async {
    await pump(tester, founder, displayName: 'Dawid Mionskowski');

    expect(onBar('Witaj, Dawid'), findsOneWidget);
    expect(onBar('OSP w Kielnie · administrator'), findsOneWidget);
    expect(find.text('OSP w Kielnie'), findsNothing,
        reason: 'nazwa jednostki jest już w drugiej linii powitania');
    expect(find.text(joinHint), findsNothing);
  });

  testWidgets('członek jednostki bez nazwy konta — adres e-mail',
      (tester) async {
    await pump(
      tester,
      founder.copyWith(userEmail: 'wojtek@gmail.com'),
    );

    expect(onBar('Witaj, wojtek@gmail.com'), findsOneWidget);
    expect(onBar('OSP w Kielnie · członek jednostki'), findsOneWidget);
  });

  testWidgets('zalogowany bez jednostki — pod paskiem podpowiedź, która '
      'prowadzi do Ustawień', (tester) async {
    await pump(
      tester,
      const SyncState(status: SyncStatus.idle, userEmail: 'jan@gmail.com'),
      displayName: 'Jan Nowak',
    );

    expect(onBar('Witaj, Jan'), findsOneWidget);
    expect(onBar('OSP w Kielnie · dane tylko na tym telefonie'),
        findsOneWidget);

    await tester.tap(find.text(joinHint));
    await tester.pumpAndSettle();
    expect(find.text('USTAWIENIA'), findsOneWidget);
  });

  testWidgets('bez konta Google', (tester) async {
    await pump(tester, const SyncState());

    expect(onBar('Witaj'), findsOneWidget);
    expect(onBar('OSP w Kielnie · dane tylko na tym telefonie'),
        findsOneWidget);
    expect(find.text(joinHint), findsNothing,
        reason: 'bez konta Google do jednostki i tak się nie dołączy');
  });

  testWidgets('bez nazwy jednostki — samo „OSP"', (tester) async {
    // Zapis Hive to prawdziwe operacje na dysku — na prawdziwym czasie.
    await tester.runAsync(() => seededDb().configBox.put(
        'main', UnitConfig(unitFullName: '', onboardingCompleted: true)));
    await pump(tester, founder, displayName: 'Dawid Mionskowski');

    expect(onBar('OSP · administrator'), findsOneWidget);
  });
}
