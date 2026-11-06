import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/equipment/equipment_form_screen.dart';
import 'package:osp_app/screens/equipment/equipment_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Lista sprzętu i jej formularz.
void main() {
  late Directory tempDir;
  final db = DatabaseService();

  setUp(() async {
    tempDir = await setUpTestHive();
    seededDb(vehicles: [
      Vehicle(id: 'v1', name: 'GBA 2,5/16', seats: 6),
      Vehicle(id: 'v2', name: 'GLM 8', seats: 4),
    ]);
  });

  tearDown(() => disposeTestHive(tempDir));

  const member = SyncState(
    status: SyncStatus.idle,
    userEmail: 'wojtek@gmail.com',
    unitFolderId: 'folder',
    founderEmail: 'ospkielno@gmail.com',
  );

  Future<void> pump(WidgetTester tester, Widget screen,
      {SyncState state = const SyncState(),
      List<Equipment> equipment = const []}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Zapis pliku Hive to prawdziwe operacje na dysku — na prawdziwym czasie.
    await tester.runAsync(() async {
      for (final e in equipment) {
        await db.addEquipment(e);
      }
    });
    await tester.pumpWidget(testApp(
      screen,
      overrides: [
        syncStateProvider.overrideWith(
            (ref) => FixedSyncState(ref.watch(syncServiceProvider), state)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  // Funkcje, nie gotowe obiekty — obiekt Hive pamięta bazę, do której
  // trafił, i nie da się go zapisać w bazie następnego testu.
  Equipment pump16() => Equipment(
      id: 'e1', name: 'Autopompa A16/8', vehicleId: 'v1', poweredByVehicle: true);
  Equipment saw() => Equipment(
        id: 'e2',
        name: 'Pilarka',
        vehicleId: 'v1',
        fuelType: EquipmentFuel.mix,
        fuelPerHour: 1.2,
        model: 'Stihl MS 462',
      );
  Equipment generator() =>
      Equipment(id: 'e3', name: 'Agregat', vehicleId: 'gone');

  testWidgets('sprzęt pogrupowany według wozów; usunięty wóz — „bez '
      'przypisanego"', (tester) async {
    await pump(tester, const EquipmentScreen(),
        equipment: [pump16(), saw(), generator()]);

    expect(find.text('GBA 2,5/16'), findsOneWidget);
    expect(find.text('GLM 8'), findsNothing, reason: 'wóz bez sprzętu');
    expect(find.text('Bez przypisanego wozu'), findsOneWidget);
    expect(find.text('Napędzany silnikiem wozu'), findsOneWidget);
    expect(find.text('Mieszanka · 1,2 l/godz. · Stihl MS 462'), findsOneWidget);
    expect(find.text('Dodaj sprzęt'), findsOneWidget,
        reason: 'bez jednostki wszystko wolno');
  });

  testWidgets('członek jednostki widzi listę, ale nie może jej zmieniać',
      (tester) async {
    await pump(tester, const EquipmentScreen(),
        state: member, equipment: [saw()]);

    expect(find.text('Pilarka'), findsOneWidget);
    expect(find.textContaining('Listę sprzętu może zmieniać tylko'),
        findsOneWidget);
    expect(find.text('Dodaj sprzęt'), findsNothing);
    expect(find.byTooltip('Usuń'), findsNothing);
  });

  testWidgets('sprzęt napędzany silnikiem wozu nie pyta o paliwo i normę',
      (tester) async {
    await pump(tester, const EquipmentFormScreen());
    expect(find.text('Rodzaj paliwa'), findsOneWidget);

    await tester.tap(find.text('Napędzany silnikiem wozu'));
    await tester.pumpAndSettle();
    expect(find.text('Rodzaj paliwa'), findsNothing);
    expect(find.text('Norma zużycia paliwa (litry na godzinę)'), findsNothing);
  });

  testWidgets('nowy sprzęt z wozem, paliwem i normą', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testRouterApp(GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Text('LISTA'),
          routes: [
            GoRoute(
                path: 'add', builder: (c, s) => const EquipmentFormScreen()),
          ],
        ),
      ],
    )));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nazwa'), 'Agregat Honda');
    await tester.tap(find.text('Bez przypisanego wozu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GLM 8').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('—'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(EquipmentFuel.petrol).last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(
            TextFormField, 'Norma zużycia paliwa (litry na godzinę)'),
        '1,5');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Marka (opcjonalnie)'), 'Honda');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Model (opcjonalnie)'), 'EU22i');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Dodaj sprzęt'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Dodaj sprzęt'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final saved = db.getAllEquipment().single;
    expect(saved.name, 'Agregat Honda');
    expect(saved.vehicleId, 'v2');
    expect(saved.fuelType, EquipmentFuel.petrol);
    expect(saved.fuelPerHour, 1.5);
    expect(saved.poweredByVehicle, isFalse);
    expect(saved.brand, 'Honda');
    expect(saved.model, 'EU22i', reason: 'pole „Model" — dawniej „Typ"');
  });
}
