import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_json.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/fake_drive.dart';
import 'helpers/phone_db.dart';

/// Każdy rodzaj danych od kolegi dociera do jednostki i na drugi telefon.
///
/// Zgłoszenie z testu 1.7.6: „kolega dodał przekazanie mienia, a ja go dalej
/// nie widzę, na Dysku też nic". Testy dwóch telefonów sprawdzały dotąd
/// wyjazdy i listy — przekazania i ewidencji przejazdów żaden.
void main() {
  late Directory root;
  late FakeDrive drive;
  final db = DatabaseService();

  setUpAll(DatabaseService.registerAdapters);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_sync_all_kinds');
    drive = FakeDrive();
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<SyncService> phone(String name) async {
    await openPhoneDb(root, name);
    drive.account = '$name@gmail.com';
    final sync = SyncService(db, FakeAuth('$name@gmail.com'), drive);
    await sync.restoreState();
    return sync;
  }

  /// A (ospkielno) zakłada jednostkę, B (wojtek) dołącza.
  Future<void> unit() async {
    final a = await phone('ospkielno');
    final code = await a.createUnit('OSP Kielno');
    final b = await phone('wojtek');
    expect(await b.joinUnit(code), isTrue);
  }

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

  test('przekazanie mienia od kolegi trafia na Dysk i do drugiego telefonu',
      () async {
    await unit();
    final b = await phone('wojtek');
    await db.addHandover(handover('h-w'));
    await b.syncAll();

    expect(b.state.status, SyncStatus.idle);
    expect(drive.jsonIn('handovers').map((j) => j['id']), ['h-w']);

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

  test('przejazd z ewidencji od kolegi trafia na Dysk i do drugiego '
      'telefonu', () async {
    await unit();
    final b = await phone('wojtek');
    await db.addTrip(trip('t-w'));
    await b.syncAll();
    expect(drive.jsonIn('trips').map((j) => j['id']), contains('t-w'));

    final a = await phone('ospkielno');
    await a.syncAll();
    expect(db.getTrip('t-w')?.routeTo, 'Gdynia');
  });

  test('ratownik i pojazd od administratora docierają do kolegi', () async {
    await unit();
    var a = await phone('ospkielno');
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

  group('dwa foldery o tej samej nazwie', () {
    /// Drugi folder [name] w folderze jednostki — jak po dwóch telefonach,
    /// które w tej samej chwili zapisały pierwszy wpis i oba go założyły.
    Future<String> secondFolder(SyncService a, String name) =>
        drive.createSubfolder(a.state.unitFolderId!, name);

    test('przekazanie z drugiego folderu handovers dociera', () async {
      await unit();
      final a = await phone('ospkielno');
      final second = await secondFolder(a, 'handovers');
      drive.putRaw(second, 'h.json',
          jsonEncode(SyncJson.handoverToJson(handover('h-w'))));

      await a.syncAll();
      expect(db.getHandover('h-w'), isNotNull);
    });

    test('przejazd z drugiego folderu trips dociera, a nowy zapis idzie do '
        'najstarszego', () async {
      await unit();
      var b = await phone('wojtek');
      await db.addTrip(trip('t-1'));
      await b.syncAll();
      final oldest = drive.folderIdByName('trips')!;

      final a = await phone('ospkielno');
      final second = await secondFolder(a, 'trips');
      drive.putRaw(second, 't2.json',
          jsonEncode(SyncJson.tripToJson(trip('t-2'))));
      await a.syncAll();
      expect(db.getTrip('t-1'), isNotNull);
      expect(db.getTrip('t-2'), isNotNull);

      b = await phone('wojtek');
      await db.addTrip(trip('t-3'));
      await b.syncAll();
      final t3 = drive.files.values.singleWhere(
          (f) => f.content?.contains('"t-3"') ?? false);
      expect(t3.parent, oldest, reason: 'każdy telefon pisze do tego samego');
    });

    test('wyjazd z drugiego folderu reports dociera', () async {
      await unit();
      final a = await phone('ospkielno');
      final second = await secondFolder(a, 'reports');
      final year = await drive.createSubfolder(second, '2026');
      drive.putRaw(year, 'r.json', jsonEncode(SyncJson.reportToJson(Report(
        id: 'r-w',
        reportNumber: '0005/2026',
        year: 2026,
        date: DateTime(2026, 10, 27),
        departureTime: DateTime(2026, 10, 27, 17, 10),
        addressLocality: 'Kielno',
        addressStreet: '',
        addressDescription: '',
        threatCategory: 'Pożar',
        createdAt: DateTime(2026, 10, 27, 17, 10),
        updatedAt: DateTime(2026, 10, 27, 17, 10),
        createdBy: 'wojtek@gmail.com',
      ))));

      await a.syncAll();
      expect(db.getReport('r-w'), isNotNull);
    });
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

    drive.putRaw(drive.folderIdByName('handovers')!, 'h2.json',
        jsonEncode(SyncJson.handoverToJson(handover('h-2'))));
    await a.syncIfStale();
    expect(db.getHandover('h-2'), isNull,
        reason: 'przed chwilą była synchronizacja — nie pytamy Dysku znowu');
    await a.syncAll();
    expect(db.getHandover('h-2'), isNotNull);
  });

  test('przekazanie czeka na wysłanie, a po synchronizacji jest na Dysku',
      () async {
    await unit();
    final b = await phone('wojtek');
    await db.addHandover(handover('h-w'));
    expect(b.handoversAwaitingUpload(db.getAllHandovers()), {'h-w'});

    await b.syncAll();
    expect(b.handoversAwaitingUpload(db.getAllHandovers()), isEmpty);
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
