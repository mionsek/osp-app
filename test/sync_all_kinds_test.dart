import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_json.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/server_phones.dart';

/// Każdy rodzaj danych od kolegi dociera do jednostki i na drugi telefon.
///
/// Zgłoszenie z testu 1.7.6: „kolega dodał przekazanie mienia, a ja go dalej
/// nie widzę". Testy dwóch telefonów sprawdzały wcześniej tylko wyjazdy
/// i listy.
void main() {
  late Directory root;
  late ServerPhones phones;
  final db = DatabaseService();
  late String code;

  setUpAll(DatabaseService.registerAdapters);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_sync_all_kinds');
    phones = ServerPhones(root);
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<SyncService> phone(String name) => phones.phone(name);

  /// A (ospkielno) zakłada jednostkę, B (wojtek) dołącza.
  Future<void> unit() async => code =
      await phones.unitWith('ospkielno', 'wojtek', unitName: 'OSP Kielno');

  Future<List<String>> idsOnServer(String collection) async =>
      [for (final d in await phones.live(code, collection)) d['id'] as String];

  PropertyHandover handover(String id, {String location = 'Kielno'}) {
    final at = DateTime(2026, 10, 27, 17, 30);
    return PropertyHandover(
      id: id,
      eventLocation: location,
      eventDate: DateTime(2026, 10, 27),
      eventTime: at,
      recipientName: 'Jan Właściciel',
      recipientAddress: 'Kielno, Szkolna 1',
      recipientPhone: '600 100 200',
      propertyDescription: 'Samochód osobowy po kolizji',
      signDate: DateTime(2026, 10, 27),
      createdAt: at,
      updatedAt: at,
      createdBy: 'wojtek@gmail.com',
    );
  }

  VehicleTrip trip(String id) {
    final at = DateTime(2026, 10, 27, 17, 10);
    return VehicleTrip(
      id: id,
      vehicleId: 'v1',
      date: DateTime(2026, 10, 27),
      departureTime: at,
      routeFrom: 'Kielno',
      routeTo: 'Gdynia',
      createdAt: at,
      updatedAt: at,
      createdBy: 'wojtek@gmail.com',
    );
  }

  test('przekazanie mienia od kolegi trafia na serwer i do drugiego telefonu',
      () async {
    await unit();
    final b = await phone('wojtek');
    await db.addHandover(handover('h-w'));
    await b.syncAll();

    expect(b.state.status, SyncStatus.idle);
    expect(await idsOnServer('handovers'), ['h-w']);

    final a = await phone('ospkielno');
    await a.syncAll();
    expect(db.getHandover('h-w')?.recipientName, 'Jan Właściciel');
  });

  test('poprawione i usunięte przekazanie też dociera', () async {
    await unit();
    var b = await phone('wojtek');
    await db.addHandover(handover('h-w'));
    await b.syncAll();
    var a = await phone('ospkielno');
    await a.syncAll();

    b = await phone('wojtek');
    final edited = db.getHandover('h-w')!
      ..propertyDescription = 'Samochód osobowy i przyczepa'
      ..updatedAt = DateTime(2026, 10, 27, 18);
    await db.updateHandover(edited);
    await b.syncAll();
    a = await phone('ospkielno');
    await a.syncAll();
    expect(db.getHandover('h-w')?.propertyDescription,
        'Samochód osobowy i przyczepa');

    b = await phone('wojtek');
    await db.deleteHandover('h-w');
    await b.syncAll();
    a = await phone('ospkielno');
    await a.syncAll();
    expect(db.getHandover('h-w'), isNull);
  });

  test('przejazd z ewidencji od kolegi trafia na serwer i do drugiego '
      'telefonu', () async {
    await unit();
    final b = await phone('wojtek');
    await db.addTrip(trip('t-w'));
    await b.syncAll();
    expect(await idsOnServer('trips'), contains('t-w'));

    final a = await phone('ospkielno');
    await a.syncAll();
    expect(db.getTrip('t-w')?.routeTo, 'Gdynia');
  });

  test('rozruch sprzętu od kolegi trafia na serwer i do drugiego telefonu; '
      'usunięcie też', () async {
    await unit();
    var b = await phone('wojtek');
    final at = DateTime(2026, 11, 1, 10);
    await db.addEquipmentWork(EquipmentWork(
      id: 'w-rozruch',
      equipmentId: 'e-niagara',
      equipmentName: 'Motopompa pływająca',
      date: DateTime(2026, 11, 1),
      minutes: 15,
      isStartup: true,
      purpose: EquipmentWork.startupPurpose,
      operatorName: 'Wojtek Kolega',
      createdAt: at,
      updatedAt: at,
      createdBy: 'wojtek@gmail.com',
    ));
    await b.syncAll();
    expect(await idsOnServer('equipmentWork'), ['w-rozruch']);

    var a = await phone('ospkielno');
    await a.syncAll();
    expect(db.getEquipmentWork('w-rozruch')?.operatorName, 'Wojtek Kolega');

    b = await phone('wojtek');
    await db.deleteEquipmentWork('w-rozruch');
    await b.syncAll();
    a = await phone('ospkielno');
    await a.syncAll();
    expect(db.getEquipmentWork('w-rozruch'), isNull);
  });

  test('ratownik i pojazd od administratora docierają do kolegi', () async {
    await unit();
    final a = await phone('ospkielno');
    await db.addFirefighter(Firefighter(
      id: 'f1',
      firstName: 'Dawid',
      lastName: 'Testowy',
      rank: '',
      updatedAt: DateTime(2026, 10, 27, 12),
    ));
    await db.addVehicle(Vehicle(
      id: 'v1',
      name: 'GBA 2,5/16',
      seats: 6,
      updatedAt: DateTime(2026, 10, 27, 12),
    ));
    await a.syncAll();

    final b = await phone('wojtek');
    await b.syncAll();
    expect(db.getFirefighter('f1')?.lastName, 'Testowy');
    expect(db.getVehicle('v1')?.name, 'GBA 2,5/16');
  });

  test('otwarcie listy pobiera zmiany kolegi, ale nie częściej niż co pół '
      'minuty', () async {
    // Test 1.7.6: „raz nie pokazało, dopiero po naciśnięciu chmurki".
    await unit();
    final b = await phone('wojtek');
    await db.addHandover(handover('h-w'));
    await b.syncAll();

    final a = await phone('ospkielno');
    await a.syncIfStale();
    expect(db.getHandover('h-w'), isNotNull);

    await phones.fs
        .doc('units/${await phones.unitIdOf(code)}/handovers/h-2')
        .set({
      'data': SyncJson.handoverToJson(handover('h-2')),
      'author': 'wojtek@gmail.com',
      'deleted': false,
      'serverAt': FieldValue.serverTimestamp(),
      'by': 'wojtek@gmail.com',
    });
    await a.syncIfStale();
    expect(db.getHandover('h-2'), isNull,
        reason: 'przed chwilą była synchronizacja — nie pytamy serwera znowu');
    await a.syncAll();
    expect(db.getHandover('h-2'), isNotNull);
  });

  test('przekazanie czeka na wysłanie, a po synchronizacji jest na serwerze',
      () async {
    await unit();
    final b = await phone('wojtek');
    await db.addHandover(handover('h-w'));
    expect(b.handoversAwaitingUpload(db.getAllHandovers()), {'h-w'});

    await b.syncAll();
    expect(b.handoversAwaitingUpload(db.getAllHandovers()), isEmpty);
  });

  group('sprzęt', () {
    Equipment saw({String name = 'Pilarka Stihl'}) => Equipment(
          id: 'e-saw',
          name: name,
          vehicleId: 'v1',
          fuelType: EquipmentFuel.mix,
          fuelPerHour: 1.2,
          updatedAt: DateTime(2026, 11, 5, 12),
        );

    test('sprzęt od administratora — dodanie, zmiana i usunięcie — dociera '
        'do kolegi', () async {
      await unit();
      var a = await phone('ospkielno');
      await db.addEquipment(saw());
      await a.syncAll();

      var b = await phone('wojtek');
      await b.syncAll();
      expect(db.getEquipment('e-saw')?.fuelType, EquipmentFuel.mix);

      a = await phone('ospkielno');
      await db.updateEquipment(saw(name: 'Pilarka Stihl MS 462')
        ..updatedAt = DateTime(2026, 11, 5, 13));
      await a.syncAll();
      b = await phone('wojtek');
      await b.syncAll();
      expect(db.getEquipment('e-saw')?.name, 'Pilarka Stihl MS 462');

      a = await phone('ospkielno');
      await db.deleteEquipment('e-saw');
      await a.syncAll();
      b = await phone('wojtek');
      await b.syncAll();
      expect(db.getEquipment('e-saw'), isNull);
    });

    test('telefon bez uprawnień nie wysyła swojej listy sprzętu', () async {
      await unit();
      final b = await phone('wojtek');
      await db.addEquipment(saw());
      await b.syncAll();

      final a = await phone('ospkielno');
      await a.syncAll();
      expect(db.getEquipment('e-saw'), isNull);
    });
  });

  test('własny podtyp zagrożenia od kolegi trafia do jednostki', () async {
    await unit();
    final b = await phone('wojtek');
    await db.ensureDefaultThreats();
    final fire = db.threatsBox.get('Pożar')!;
    fire.subtypes.add('Pożar trawy przy torach');
    await db.addThreat(fire);
    await b.syncAll();

    final a = await phone('ospkielno');
    await a.syncAll();
    expect(db.threatsBox.get('Pożar')!.subtypes,
        contains('Pożar trawy przy torach'));
  });
}
