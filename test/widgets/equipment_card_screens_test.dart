import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/equipment/equipment_card_screen.dart';
import 'package:osp_app/screens/equipment/equipment_screen.dart';
import 'package:osp_app/screens/equipment/equipment_work_form_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Karta pracy urządzenia na ekranie i wpisy rozruchów kontrolnych.
void main() {
  late Directory tempDir;
  final db = DatabaseService();
  final now = DateTime.now();
  final firstOfMonth = DateTime(now.year, now.month, 1, 10);

  setUp(() async {
    tempDir = await setUpTestHive();
    seededDb(
      vehicles: [Vehicle(id: 'v1', name: 'GBA 2,5/16', seats: 6)],
      firefighters: [firefighter('ff1', 'Jan', 'Kowalski')],
    );
  });

  tearDown(() => disposeTestHive(tempDir));

  // Funkcje, nie gotowe obiekty — obiekt Hive pamięta bazę, do której trafił.
  Equipment niagara() => Equipment(
        id: 'e-niagara',
        name: 'Motopompa pływająca',
        brand: 'Niagara',
        fuelType: EquipmentFuel.petrol,
        fuelPerHour: 2,
      );
  Equipment saw() => Equipment(id: 'e-saw', name: 'Pilarka');
  Equipment pump() => Equipment(
      id: 'e-pump', name: 'Autopompa', vehicleId: 'v1', poweredByVehicle: true);

  Future<void> seed(WidgetTester tester, {
    List<Equipment> equipment = const [],
    List<VehicleTrip> trips = const [],
    List<EquipmentWork> work = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Zapis Hive to prawdziwe operacje na dysku — na prawdziwym czasie.
    await tester.runAsync(() async {
      for (final e in equipment) {
        await db.addEquipment(e);
      }
      for (final t in trips) {
        await db.addTrip(t);
      }
      for (final w in work) {
        await db.addEquipmentWork(w);
      }
    });
  }

  Widget app(Widget screen) => testApp(screen, overrides: [
        syncStateProvider.overrideWith((ref) => FixedSyncState(
            ref.watch(syncServiceProvider), const SyncState())),
      ]);

  /// Ekran z trasą, z której da się wrócić (`context.pop`).
  Widget routed(String location, Widget screen) => testRouterApp(GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/',
            builder: (c, s) => const Text('LISTA'),
            routes: [GoRoute(path: 'form', builder: (c, s) => screen)],
          ),
        ],
      ));

  testWidgets('karta zbiera pracę z przejazdu i rozruch, z podsumowaniem '
      'rozliczenia', (tester) async {
    await seed(
      tester,
      equipment: [niagara()],
      trips: [
        VehicleTrip(
          id: 't1',
          vehicleId: 'v1',
          date: DateTime(now.year, now.month, 1),
          departureTime: firstOfMonth.add(const Duration(hours: 4)),
          purpose: TripPurposes.training,
          routeTo: 'Szemud',
          equipmentUse: [
            TripEquipmentUse(
                name: 'Motopompa pływająca',
                minutes: 90,
                equipmentId: 'e-niagara',
                operatorName: 'Kowalski Jan'),
          ],
          createdAt: firstOfMonth,
          updatedAt: firstOfMonth,
        ),
      ],
      work: [
        EquipmentWork(
          id: 'w1',
          equipmentId: 'e-niagara',
          date: DateTime(now.year, now.month, 1),
          minutes: 15,
          isStartup: true,
          createdAt: firstOfMonth,
          updatedAt: firstOfMonth,
        ),
      ],
    );
    await tester.pumpWidget(
        app(const EquipmentCardScreen(equipmentId: 'e-niagara')));
    await tester.pumpAndSettle();

    expect(find.text('Ćwiczenia, Szemud'), findsOneWidget);
    expect(find.text('Rozruch kontrolny'), findsOneWidget);
    expect(find.text('praca 1 godz. 30 min'), findsOneWidget);
    expect(find.text('rozruchy 15 min'), findsOneWidget);
    expect(find.text('paliwo 3,5 l'), findsOneWidget);
    expect(find.textContaining('rozliczenie paliwa na karcie zostanie puste'),
        findsNothing);
  });

  testWidgets('bez normy i rodzaju paliwa — ostrzeżenie przed drukiem',
      (tester) async {
    await seed(tester, equipment: [saw()]);
    await tester.pumpWidget(app(const EquipmentCardScreen(equipmentId: 'e-saw')));
    await tester.pumpAndSettle();

    expect(
        find.textContaining(
            'Brak normy zużycia paliwa i rodzaju paliwa — rozliczenie'),
        findsOneWidget);
    expect(find.text('Brak pracy w tym miesiącu'), findsOneWidget);
  });

  testWidgets('rozruch całego sprzętu: zaznaczone urządzenia z własnym '
      'silnikiem, 15 min, jeden wpis na urządzenie', (tester) async {
    await seed(tester, equipment: [niagara(), saw(), pump()]);
    await tester.pumpWidget(routed(
        '/form', const EquipmentWorkFormScreen(startupForAll: true)));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNWidgets(2),
        reason: 'autopompa jest na karcie wozu');
    expect(find.text('Odznacz wszystkie'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '15'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Obsługujący'), 'Kowalski Jan');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Zapisz'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Zapisz'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final saved = db.getAllEquipmentWork();
    expect(saved.map((w) => w.equipmentId).toSet(), {'e-niagara', 'e-saw'});
    expect(saved.every((w) => w.isStartup && w.minutes == 15), isTrue);
    expect(saved.map((w) => w.purpose).toSet(), {'Rozruch kontrolny'});
    expect(saved.map((w) => w.operatorId).toSet(), {'ff1'});
    expect(saved.map((w) => w.equipmentName).toSet(),
        {'Motopompa pływająca', 'Pilarka'});
    expect(find.text('LISTA'), findsOneWidget, reason: 'formularz zamknięty');
  });

  testWidgets('z karty urządzenia: inna praca, z celem użycia', (tester) async {
    await seed(tester, equipment: [niagara(), saw()]);
    await tester.pumpWidget(routed('/form',
        const EquipmentWorkFormScreen(equipmentId: 'e-saw')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Minut pracy'), '40');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Cel użycia'), 'Ćwiczenia w remizie');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Zapisz'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Zapisz'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final saved = db.getAllEquipmentWork().single;
    expect(saved.equipmentId, 'e-saw');
    expect(saved.isStartup, isFalse);
    expect(saved.minutes, 40);
    expect(saved.purpose, 'Ćwiczenia w remizie');
  });

  testWidgets('lista sprzętu: urządzenie z własnym silnikiem otwiera kartę, '
      'zasilane z wozu — nie', (tester) async {
    await seed(tester, equipment: [saw(), pump()]);
    await tester.pumpWidget(testRouterApp(GoRouter(
      initialLocation: '/equipment',
      routes: [
        GoRoute(
          path: '/equipment',
          builder: (c, s) => const EquipmentScreen(),
          routes: [
            GoRoute(
              path: 'card/:id',
              builder: (c, s) => Text('KARTA ${s.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    )));
    await tester.pumpAndSettle();

    // Podpis pod ikoną na pasku akcji, a nie sama ikona obok tytułu.
    expect(find.text('Rozruch kontrolny'), findsOneWidget);
    await tester.tap(find.text('Autopompa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('KARTA'), findsNothing);

    await tester.tap(find.text('Pilarka'));
    await tester.pumpAndSettle();
    expect(find.text('KARTA e-saw'), findsOneWidget);
  });
}
