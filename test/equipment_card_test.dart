import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/equipment_card.dart';
import 'package:osp_app/services/sync_json.dart';

/// Miesięczna karta pracy sprzętu silnikowego — wzór z OSP Kielno
/// (motopompa pływająca Niagara) i odpowiedzi Deringa z listopada 2026:
/// karta miesięczna, minuty, rozruch 15 min albo czas pracy przy akcji,
/// paliwo z kanistrów rozpisywane na całość sprzętu (nie na tej karcie).
void main() {
  final pump = Equipment(
    id: 'e-niagara',
    name: 'Motopompa pływająca',
    brand: 'Niagara',
    model: 'GXV160',
    fuelType: EquipmentFuel.petrol,
    fuelPerHour: 2,
  );
  final saw = Equipment(id: 'e-saw', name: 'Pilarka', vehicleId: 'gba');
  final all = [pump, saw];

  final report = Report(
    id: 'r1',
    reportNumber: '0007/2026',
    year: 2026,
    date: DateTime(2026, 11, 3),
    departureTime: DateTime(2026, 11, 3, 14),
    addressLocality: 'Kielno',
    addressStreet: '',
    threatCategory: 'Miejscowe zagrożenie',
    createdAt: DateTime(2026, 11, 3),
    updatedAt: DateTime(2026, 11, 3),
  );

  VehicleTrip trip(
    String id,
    DateTime at,
    List<TripEquipmentUse> uses, {
    String? reportId,
    String purpose = TripPurposes.training,
    String routeTo = 'Szemud',
  }) =>
      VehicleTrip(
        id: id,
        vehicleId: 'gba',
        date: DateTime(at.year, at.month, at.day),
        departureTime: at,
        purpose: purpose,
        routeTo: routeTo,
        reportId: reportId,
        equipmentUse: uses,
        createdAt: at,
        updatedAt: at,
      );

  EquipmentWork startup(String id, DateTime day, {String equipmentId = 'e-niagara'}) =>
      EquipmentWork(
        id: id,
        equipmentId: equipmentId,
        equipmentName: 'Motopompa pływająca',
        date: day,
        minutes: 15,
        isStartup: true,
        operatorName: 'Nowak Adam',
        createdAt: day,
        updatedAt: day,
      );

  group('wiersze karty', () {
    final trips = [
      trip('t-akcja', DateTime(2026, 11, 3, 14), [
        TripEquipmentUse(
            name: 'Motopompa pływająca',
            minutes: 90,
            equipmentId: pump.id,
            operatorName: 'Kowalski Jan'),
        TripEquipmentUse(name: 'Pilarka', minutes: 20, equipmentId: saw.id),
      ], reportId: 'r1', purpose: TripPurposes.alarm),
      // Wpis sprzed listy sprzętu — sama nazwa.
      trip('t-cwiczenia', DateTime(2026, 11, 10, 18),
          [TripEquipmentUse(name: 'motopompa pływająca', minutes: 30)]),
      trip('t-pazdziernik', DateTime(2026, 10, 30, 9),
          [TripEquipmentUse(name: 'x', minutes: 40, equipmentId: pump.id)]),
      trip('t-zero', DateTime(2026, 11, 12, 9),
          [TripEquipmentUse(name: 'x', minutes: 0, equipmentId: pump.id)]),
    ];
    final work = [
      startup('w-rozruch', DateTime(2026, 11, 1)),
      startup('w-pilarka', DateTime(2026, 11, 1), equipmentId: saw.id),
    ];

    List<EquipmentCardRow> rows() => EquipmentCard.rows(
          device: pump,
          year: 2026,
          month: 11,
          trips: trips,
          work: work,
          equipment: all,
          reportOf: (id) => id == 'r1' ? report : null,
        );

    test('praca z przejazdów i rozruch, po kolei, tylko tego urządzenia '
        'i miesiąca', () {
      expect(rows().map((r) => r.minutes), [15, 90, 30]);
      expect(rows().map((r) => r.tripId ?? r.workId),
          ['w-rozruch', 't-akcja', 't-cwiczenia']);
    });

    test('cel użycia: zdarzenie z wyjazdu, cel przejazdu, rozruch', () {
      expect(rows().map((r) => r.purpose), [
        'Rozruch kontrolny',
        'Miejscowe zagrożenie, Kielno',
        'Ćwiczenia, Szemud',
      ]);
    });

    test('obsługujący z przejazdu i z rozruchu', () {
      expect(rows().map((r) => r.operatorName),
          ['Nowak Adam', 'Kowalski Jan', '']);
    });

    test('rozliczenie: praca i rozruchy osobno, normą urządzenia', () {
      final t = EquipmentCard.totals(pump, rows());
      expect(t.workMinutes, 120);
      expect(t.startupMinutes, 15);
      expect(t.workFuel, 4.0, reason: '2 godz. × 2 l/godz.');
      expect(t.startupFuel, 0.5);
      expect(t.totalFuel, 4.5);
    });

    test('bez normy paliwo zostaje puste', () {
      final t = EquipmentCard.totals(saw, [
        EquipmentCardRow(
            date: DateTime(2026, 11, 3), operatorName: '', minutes: 20,
            purpose: ''),
      ]);
      expect(t.workMinutes, 20);
      expect(t.workFuel, isNull);
      expect(t.totalFuel, isNull);
    });

    test('miesiące z pracą urządzenia — od najnowszego', () {
      expect(
        EquipmentCard.months(
            device: pump, trips: trips, work: work, equipment: all),
        [(year: 2026, month: 11), (year: 2026, month: 10)],
      );
    });
  });

  test('godziny i minuty do pozycji 4', () {
    expect(EquipmentCard.hoursAndMinutes(45), '45 min');
    expect(EquipmentCard.hoursAndMinutes(120), '2 godz.');
    expect(EquipmentCard.hoursAndMinutes(95), '1 godz. 35 min');
  });

  test('kolumna rozliczenia: benzyna i mieszanka — ET, olej napędowy — ON',
      () {
    Equipment fuel(String f) => Equipment(id: 'e', name: 'e', fuelType: f);
    expect(fuel(EquipmentFuel.petrol).settlementColumn, 'ET');
    expect(fuel(EquipmentFuel.mix).settlementColumn, 'ET');
    expect(fuel(EquipmentFuel.diesel).settlementColumn, 'ON');
    expect(fuel('').settlementColumn, isNull);
    expect(Equipment(id: 'p', name: 'Autopompa', poweredByVehicle: true)
        .hasWorkCard, isFalse);
  });

  group('zapis na Dysk', () {
    test('praca sprzętu — tam i z powrotem bez strat', () {
      final w = startup('w1', DateTime(2026, 11, 1))
        ..operatorId = 'f1'
        ..createdBy = 'wojtek@gmail.com';
      final json = SyncJson.equipmentWorkToJson(w);
      final back = SyncJson.equipmentWorkFromJson(json);
      expect(SyncJson.equipmentWorkToJson(back), json);
      expect(json.keys.toSet(), {
        'id', 'equipmentId', 'equipmentName', 'date', 'minutes', 'isStartup',
        'purpose', 'operatorName', 'operatorId', 'createdAt', 'updatedAt',
        'createdBy',
      });
    });

    test('obsługujący w przejeździe przeżywa zapis, a wpis bez niego ma tę '
        'samą treść co dawniej', () {
      final t = trip('t', DateTime(2026, 11, 3, 14), [
        TripEquipmentUse(
            name: 'Pilarka',
            minutes: 20,
            equipmentId: saw.id,
            operatorName: 'Kowalski Jan',
            operatorId: 'f2'),
        TripEquipmentUse(name: 'Pilarka', minutes: 5, equipmentId: saw.id),
      ]);
      final json = SyncJson.tripToJson(t);
      final back = SyncJson.tripFromJson(json).equipmentUse;
      expect(back.first.operatorName, 'Kowalski Jan');
      expect(back.first.operatorId, 'f2');
      expect((json['equipmentUse'] as List).last,
          {'name': 'Pilarka', 'minutes': 5, 'equipmentId': saw.id});
    });

    test('marka sprzętu przeżywa zapis; plik bez marki wczytuje się', () {
      final back = SyncJson.equipmentFromJson(SyncJson.equipmentToJson(pump));
      expect(back.brand, 'Niagara');
      expect(back.model, 'GXV160');
      expect(
          SyncJson.equipmentFromJson({'id': 'e', 'name': 'Agregat'}).brand, '');
    });
  });

  group('baza', () {
    late Directory dir;
    final db = DatabaseService();

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('osp_equipment_work');
      Hive.init(dir.path);
      DatabaseService.registerAdapters();
      await DatabaseService.openBoxes();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('od najnowszego; usunięcie zostawia znacznik dla kolegów', () async {
      await db.addEquipmentWork(startup('w1', DateTime(2026, 11, 1)));
      await db.addEquipmentWork(startup('w2', DateTime(2026, 11, 20)));
      expect(db.getAllEquipmentWork().map((w) => w.id), ['w2', 'w1']);

      await db.deleteEquipmentWork('w1');
      expect(db.getEquipmentWork('w1'), isNull);
      expect(db.tombstoneOf(SyncKind.equipmentWork, 'w1'), isNotNull);
    });

    test('obsługujący w przejeździe przeżywa zapis w telefonie', () async {
      await db.addTrip(trip('t', DateTime(2026, 11, 3, 14), [
        TripEquipmentUse(
            name: 'Pilarka', minutes: 20, operatorName: 'Kowalski Jan'),
      ]));
      await Hive.close();
      await DatabaseService.openBoxes();
      expect(db.getTrip('t')!.equipmentUse.single.operatorName,
          'Kowalski Jan');
    });

    test('„Wyloguj i usuń dane" usuwa też pracę sprzętu', () async {
      await db.addEquipmentWork(startup('w1', DateTime(2026, 11, 1)));
      await db.wipeUnitData();
      expect(db.getAllEquipmentWork(), isEmpty);
    });
  });
}
