import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/equipment_usage.dart';
import 'package:osp_app/services/sync_json.dart';

/// Sprzęt jednostki i to, co z jego pracy trafia na kartę drogową wozu.
///
/// Ustalenia z Dawidem po rozmowie z Deringiem: sprzęt z własnym silnikiem
/// (agregat, pilarka) ma w gminie osobną kartę, a karta drogowa wozu liczy
/// w kolumnie 10 i pozycji 5 tylko sprzęt zasilany z wozu — normą
/// autopompy. Wcześniej karta liczyła minuty pilarki normą autopompy.
void main() {
  Equipment device(
    String id,
    String name, {
    String? vehicleId,
    bool poweredByVehicle = false,
  }) =>
      Equipment(
        id: id,
        name: name,
        vehicleId: vehicleId,
        poweredByVehicle: poweredByVehicle,
      );

  final pump = device('e-pump', 'Autopompa A16/8',
      vehicleId: 'gba', poweredByVehicle: true);
  final saw = device('e-saw', 'Pilarka Stihl', vehicleId: 'gba');
  final generator = device('e-gen', 'Agregat Honda');
  final all = [pump, saw, generator];

  VehicleTrip trip(List<TripEquipmentUse> uses, {int? legacyMinutes}) =>
      VehicleTrip(
        id: 't1',
        vehicleId: 'gba',
        date: DateTime(2026, 11, 5),
        departureTime: DateTime(2026, 11, 5, 10),
        equipmentUse: uses,
        specialEquipmentMinutes: legacyMinutes,
        createdAt: DateTime(2026, 11, 5),
        updatedAt: DateTime(2026, 11, 5),
      );

  group('karta drogowa wozu — kolumna 10', () {
    test('autopompa się liczy, pilarka i agregat (własny silnik) — nie', () {
      final t = trip([
        TripEquipmentUse(name: pump.name, minutes: 60, equipmentId: pump.id),
        TripEquipmentUse(name: saw.name, minutes: 30, equipmentId: saw.id),
        TripEquipmentUse(
            name: generator.name, minutes: 45, equipmentId: generator.id),
      ]);
      expect(EquipmentUsage.vehicleCardMinutes(t, all), 60);
      expect(t.totalEquipmentMinutes, 135, reason: 'suma wszystkiego zostaje');
    });

    test('wpisy sprzed listy sprzętu: autopompa i wyciągarka tak, agregat, '
        'piła i wentylator nie', () {
      final t = trip([
        TripEquipmentUse(name: SpecialEquipment.pump, minutes: 60),
        TripEquipmentUse(name: SpecialEquipment.winch, minutes: 10),
        TripEquipmentUse(name: SpecialEquipment.generator, minutes: 45),
        TripEquipmentUse(name: SpecialEquipment.saw, minutes: 30),
        TripEquipmentUse(name: SpecialEquipment.fan, minutes: 20),
      ]);
      expect(EquipmentUsage.vehicleCardMinutes(t, const []), 70);
    });

    test('nazwa spoza listy liczy się jak dawniej', () {
      final t = trip([TripEquipmentUse(name: 'Maszt oświetleniowy', minutes: 15)]);
      expect(EquipmentUsage.vehicleCardMinutes(t, all), 15);
    });

    test('przejazd sprzed rozbicia na urządzenia — cała dawna liczba', () {
      expect(
        EquipmentUsage.vehicleCardMinutes(trip(const [], legacyMinutes: 40), all),
        40,
      );
    });

    test('usunięte z listy urządzenie rozpoznane po nazwie, najpierw z tego '
        'wozu', () {
      final otherSaw = device('e-saw2', 'Pilarka Stihl',
          vehicleId: 'glm', poweredByVehicle: true);
      final use = TripEquipmentUse(name: 'pilarka stihl ', minutes: 30);

      expect(
          EquipmentUsage.resolve(use, [otherSaw, saw], vehicleId: 'gba'), saw);
      expect(EquipmentUsage.resolve(use, [otherSaw], vehicleId: 'gba'),
          otherSaw);
      expect(
          EquipmentUsage.resolve(
              TripEquipmentUse(name: 'Pompa szlamowa', minutes: 5), all),
          isNull);
    });
  });

  group('zapis na Dysk', () {
    test('sprzęt — tam i z powrotem bez strat', () {
      final e = Equipment(
        id: 'e1',
        name: 'Agregat Honda',
        vehicleId: 'gba',
        fuelType: EquipmentFuel.petrol,
        fuelPerHour: 1.2,
        model: 'Honda EU 22i',
        serialNumber: 'ABC-123',
        updatedAt: DateTime(2026, 11, 5, 12),
      );
      final back = SyncJson.equipmentFromJson(SyncJson.equipmentToJson(e));
      expect(SyncJson.equipmentToJson(back), SyncJson.equipmentToJson(e));
      expect(back.updatedAt, DateTime(2026, 11, 5, 12));
    });

    test('przejazd zapamiętuje urządzenie, a wpis bez niego ma tę samą '
        'treść co dawniej — nie jest wysyłany ponownie', () {
      final withDevice = trip([
        TripEquipmentUse(name: saw.name, minutes: 30, equipmentId: saw.id),
      ]);
      final back = SyncJson.tripFromJson(SyncJson.tripToJson(withDevice));
      expect(back.equipmentUse.single.equipmentId, saw.id);

      final legacy = SyncJson.tripToJson(
          trip([TripEquipmentUse(name: 'Autopompa', minutes: 60)]));
      expect((legacy['equipmentUse'] as List).single,
          {'name': 'Autopompa', 'minutes': 60});
    });
  });

  group('baza', () {
    late Directory dir;
    final db = DatabaseService();

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('osp_equipment');
      Hive.init(dir.path);
      DatabaseService.registerAdapters();
      await DatabaseService.openBoxes();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('alfabetycznie, a usunięcie zostawia znacznik dla kolegów',
        () async {
      await db.addEquipment(device('e2', 'pilarka'));
      await db.addEquipment(device('e1', 'Agregat'));
      expect(db.getAllEquipment().map((e) => e.name), ['Agregat', 'pilarka']);

      await db.deleteEquipment('e1');
      expect(db.getEquipment('e1'), isNull);
      expect(db.tombstoneOf(SyncKind.equipment, 'e1'), isNotNull);
    });

    test('„Wyloguj i usuń dane" usuwa też sprzęt', () async {
      await db.addEquipment(device('e1', 'Agregat'));
      await db.wipeUnitData();
      expect(db.getAllEquipment(), isEmpty);
    });

    test('po dołączeniu zostaje tylko sprzęt z listy jednostki', () async {
      await db.addEquipment(device('e1', 'Agregat'));
      await db.addEquipment(device('local', 'Testowa piła'));
      await db.keepOnlyListEntries(SyncKind.equipment, {'e1'});
      expect(db.getAllEquipment().map((e) => e.id), ['e1']);
    });
  });
}
