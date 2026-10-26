import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/settings/settings_screen.dart';
import 'package:osp_app/services/google_auth_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_app.dart';

class _MockAuth extends Mock implements GoogleAuthService {}

/// Stan konta ustalony z góry — ekran dostaje dokładnie ten przypadek,
/// który badamy, bez logowania i bez Dysku.
class _FixedSyncState extends SyncStateNotifier {
  _FixedSyncState(super.syncService, SyncState initial) {
    state = initial;
  }
}

/// Sekcja konta Google w Ustawieniach.
///
/// Zgłoszenie z testów 1.7.1: „niby jest »zalogowano«, ale nie ma żadnych
/// informacji o koncie i nie da się wylogować ani przełączyć konta". Ekran
/// znał tylko dwa stany — w jednostce i poza nią — więc zalogowany bez
/// jednostki wyglądał tak samo jak niezalogowany.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
    PackageInfo.setMockInitialValues(
      appName: 'Raporty OSP',
      packageName: 'pl.osp.osp_app',
      version: '1.7.2',
      buildNumber: '15',
      buildSignature: '',
    );
  });

  tearDown(() => disposeTestHive(tempDir));

  const founderInUnit = SyncState(
    status: SyncStatus.idle,
    userEmail: 'ospkielno@gmail.com',
    unitFolderId: 'folder',
    unitInviteCode: 'ABC234',
    founderEmail: 'ospkielno@gmail.com',
  );

  Future<void> pumpSettings(WidgetTester tester, SyncState state) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _MockAuth();
    when(() => auth.displayName).thenReturn('Dawid Mionskowski');
    final sync = fakeSync();
    when(() => sync.authService).thenReturn(auth);

    await tester.pumpWidget(testApp(
      const SettingsScreen(),
      sync: sync,
      overrides: [
        syncStateProvider.overrideWith(
            (ref) => _FixedSyncState(ref.watch(syncServiceProvider), state)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('niezalogowany widzi logowanie, a nie konto', (tester) async {
    await pumpSettings(tester, const SyncState());

    expect(find.text('Zaloguj się kontem Google'), findsOneWidget);
    expect(find.text('Zalogowano jako'), findsNothing);
    expect(find.text('Wyloguj'), findsNothing);
  });

  testWidgets(
      'zalogowany bez jednostki widzi konto, zmianę konta, wylogowanie '
      'i dołączenie kodem', (tester) async {
    await pumpSettings(tester, const SyncState(userEmail: 'dawid@gmail.com'));

    expect(find.text('Zalogowano jako'), findsOneWidget);
    expect(find.text('dawid@gmail.com'), findsOneWidget);
    expect(find.text('Dawid Mionskowski'), findsOneWidget);
    expect(find.text('Zmień konto'), findsOneWidget);
    expect(find.text('Wyloguj'), findsOneWidget);
    expect(find.text('Dołącz do jednostki kodem'), findsOneWidget);
    expect(find.text('Utwórz jednostkę na Dysku'), findsOneWidget);
    expect(find.text('Zaloguj się kontem Google'), findsNothing);
  });

  testWidgets('założyciel w jednostce dostaje propozycję przejścia na '
      'własne konto', (tester) async {
    await pumpSettings(tester, founderInUnit);

    expect(find.text('ospkielno@gmail.com'), findsOneWidget);
    expect(find.text('ABC234'), findsOneWidget);
    expect(find.text('Przełącz na swoje konto'), findsOneWidget);
    expect(find.text('Dołącz do jednostki kodem'), findsNothing);
  });

  testWidgets('członek jednostki nie dostaje propozycji przejścia',
      (tester) async {
    await pumpSettings(
      tester,
      const SyncState(
        status: SyncStatus.idle,
        userEmail: 'jan@gmail.com',
        unitFolderId: 'folder',
        unitInviteCode: 'ABC234',
        founderEmail: 'ospkielno@gmail.com',
      ),
    );

    expect(find.text('jan@gmail.com'), findsOneWidget);
    expect(find.text('Przełącz na swoje konto'), findsNothing);
  });

  testWidgets('wylogowanie przypomina kod potrzebny do powrotu',
      (tester) async {
    await pumpSettings(tester, founderInUnit);

    await tester.ensureVisible(find.text('Wyloguj'));
    await tester.tap(find.text('Wyloguj'));
    await tester.pumpAndSettle();

    expect(find.textContaining('dołącz kodem ABC234'), findsOneWidget);

    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dołącz kodem ABC234'), findsNothing);
  });
}
