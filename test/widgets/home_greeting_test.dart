import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/home/home_screen.dart';

import '../helpers/test_app.dart';

/// Powitanie na ekranie głównym: kto jest zalogowany i z jakimi
/// uprawnieniami w jakiej jednostce.
///
/// Zgłoszenie Dawida: nazwę jednostki było widać na pasku, ale nie to, kto
/// jest zalogowany i czy jest administratorem, członkiem, czy w ogóle
/// połączony z jednostką.
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
    await tester.pumpWidget(testApp(
      const HomeScreen(),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith(
            (ref) => FixedSyncState(ref.watch(syncServiceProvider), state)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  const founder = SyncState(
    status: SyncStatus.idle,
    userEmail: 'mionskowski.dawid@gmail.com',
    unitFolderId: 'folder',
    founderEmail: 'mionskowski.dawid@gmail.com',
  );

  testWidgets('administrator: imię z konta Google i rola w jednostce',
      (tester) async {
    await pump(tester, founder, displayName: 'Dawid Mionskowski');

    expect(find.text('Witaj, Dawid'), findsOneWidget);
    expect(find.text('OSP w Kielnie · administrator'), findsOneWidget);
  });

  testWidgets('członek jednostki bez nazwy konta — adres e-mail',
      (tester) async {
    await pump(
      tester,
      founder.copyWith(userEmail: 'wojtek@gmail.com'),
    );

    expect(find.text('Witaj, wojtek@gmail.com'), findsOneWidget);
    expect(find.text('OSP w Kielnie · członek jednostki'), findsOneWidget);
  });

  testWidgets('zalogowany bez jednostki — gdzie dołączyć', (tester) async {
    await pump(
      tester,
      const SyncState(status: SyncStatus.idle, userEmail: 'jan@gmail.com'),
      displayName: 'Jan Nowak',
    );

    expect(find.text('Witaj, Jan'), findsOneWidget);
    expect(
      find.text('Dane tylko na tym telefonie — dołącz do jednostki '
          'w Ustawieniach'),
      findsOneWidget,
    );
  });

  testWidgets('bez konta Google', (tester) async {
    await pump(tester, const SyncState());

    expect(find.text('Witaj'), findsOneWidget);
    expect(find.text('Dane tylko na tym telefonie'), findsOneWidget);
  });
}
