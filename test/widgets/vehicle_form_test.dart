import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/screens/vehicles/vehicle_form_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Dane pojazdu do karty drogowej: Marka, Model i Typ.
///
/// Uwaga Dawida z 6.11.2026: „Marka — np. Mitsubishi, Model — np. L200,
/// Typ — np. GCBA / SLRt". Dotąd model był podpisany „Typ", a typ —
/// „Rodzaj", jak na starych drukach. Pola w bazie zostają te same, więc
/// pojazdy wpisane wcześniej pokazują się już pod nowymi podpisami.
void main() {
  late Directory tempDir;
  final db = DatabaseService();

  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() => disposeTestHive(tempDir));

  Future<void> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testRouterApp(GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Text('LISTA'),
          routes: [
            GoRoute(path: 'add', builder: (c, s) => const VehicleFormScreen()),
            GoRoute(
              path: 'edit/:id',
              builder: (c, s) =>
                  VehicleFormScreen(vehicleId: s.pathParameters['id']),
            ),
          ],
        ),
      ],
    )));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('nowy pojazd: Marka, Model i Typ trafiają do swoich pól',
      (tester) async {
    await pump(tester, '/add');
    await tester.enterText(field('Nazwa pojazdu'), 'GCBA 5/32');
    await tester.tap(find.text('Dane do karty drogowej'));
    await tester.pumpAndSettle();

    expect(field('Rodzaj'), findsNothing,
        reason: '„Rodzaj" został tylko przy paliwie');
    await tester.enterText(field('Marka'), 'MITSUBISHI');
    await tester.enterText(field('Model'), 'L200');
    await tester.enterText(field('Typ'), 'SLRt');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Dodaj pojazd'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Dodaj pojazd'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final saved = db.getAllVehicles().single;
    expect(saved.make, 'MITSUBISHI');
    expect(saved.model, 'L200');
    expect(saved.kind, 'SLRt');
    expect(find.text('LISTA'), findsOneWidget);
  });

  testWidgets('pojazd wpisany wcześniej — model pod „Model", typ pod „Typ"',
      (tester) async {
    await tester.runAsync(() => db.addVehicle(Vehicle(
          id: 'v1',
          name: 'GBA 2,5/16',
          seats: 6,
          make: 'MAN',
          model: 'TGM 13.290',
          kind: 'GBA',
        )));
    await pump(tester, '/edit/v1');

    String text(String label) => tester
        .widget<TextFormField>(field(label))
        .controller!
        .text;
    expect(text('Marka'), 'MAN');
    expect(text('Model'), 'TGM 13.290');
    expect(text('Typ'), 'GBA');
  });
}
