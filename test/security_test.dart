import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/fake_drive.dart';

/// Atrapa Dysku zapisująca każde miejsce, w którym aplikacja coś tworzy
/// albo zmienia.
class _AuditedDrive extends FakeDrive {
  final writeTargets = <String>[];

  @override
  Future<String> createSubfolder(String parentId, String name) async {
    writeTargets.add(parentId);
    return super.createSubfolder(parentId, name);
  }

  @override
  Future<String> findOrCreateYearFolder(String reportsFolderId, int year) {
    writeTargets.add(reportsFolderId);
    return super.findOrCreateYearFolder(reportsFolderId, year);
  }

  @override
  Future<({String id, DateTime? modifiedTime})> createJsonFile(
    String folderId,
    String fileName,
    Map<String, dynamic> data,
  ) {
    writeTargets.add(folderId);
    return super.createJsonFile(folderId, fileName, data);
  }

  @override
  Future<({String id, DateTime? modifiedTime})> updateJsonFile(
    String fileId,
    Map<String, dynamic> data, {
    String? fileName,
  }) {
    writeTargets.add(fileId);
    return super.updateJsonFile(fileId, data, fileName: fileName);
  }

  bool isInside(String id, String rootId) {
    String? current = id;
    while (current != null) {
      if (current == rootId) return true;
      current = files[current]?.parent;
    }
    return false;
  }
}

/// Próby ataku na synchronizację z Dyskiem.
///
/// Od fix/046 aplikacja ma pełny dostęp do Dysku, a ograniczenie do folderu
/// jednostki istnieje wyłącznie w jej kodzie. Te testy pilnują, że żadne
/// dane podrzucone przez innego członka jednostki nie wyprowadzą zapisu poza
/// ten folder, że zepsuta konfiguracja nie zatrzyma synchronizacji i że
/// obcy, który zna kod zaproszenia, nie podsunie ofierze własnego folderu.
/// Dwa ostatnie przypadki znalazł właśnie ten test, zanim powstała obrona.
void main() {
  late Directory root;
  late _AuditedDrive drive;
  final db = DatabaseService();

  setUpAll(() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(VehicleAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(FirefighterAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CrewAssignmentAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ThreatEntryAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ReportAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(UnitConfigAdapter());
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(PropertyHandoverAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(VehicleTripAdapter());
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(TripEquipmentUseAdapter());
    }
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_security');
    drive = _AuditedDrive();
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<SyncService> phone(String name) async {
    await Hive.close();
    final dir = Directory('${root.path}/$name')..createSync(recursive: true);
    Hive.init(dir.path);
    await Future.wait([
      Hive.openBox<Vehicle>('vehicles'),
      Hive.openBox<Firefighter>('firefighters'),
      Hive.openBox<Report>('reports'),
      Hive.openBox<UnitConfig>('config'),
      Hive.openBox<ThreatEntry>('threats'),
      Hive.openBox<dynamic>('settings'),
      Hive.openBox<PropertyHandover>('property_handovers'),
      Hive.openBox<VehicleTrip>('vehicle_trips'),
    ]);
    final sync = SyncService(db, FakeAuth('$name@gmail.com'), drive);
    await sync.restoreState();
    return sync;
  }

  Report report(String id) => Report(
        id: id,
        reportNumber: '0001/2026',
        year: 2026,
        date: DateTime(2026, 8, 10),
        departureTime: DateTime(2026, 8, 10, 14, 30),
        addressLocality: 'Kielno',
        addressStreet: '',
        addressDescription: '',
        threatCategory: 'Pożar',
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      );

  test(
      'spreparowane pliki od członka jednostki nie wyprowadzają zapisu poza '
      'folder jednostki', () async {
    // Prywatny plik ofiary poza jednostką — z identyfikatorem prawdziwego
    // raportu, żeby kusił do „aktualizacji".
    drive.files['prywatny'] =
        FakeFile('prywatny', 'Moje dokumenty', null, isFolder: true);
    final privateFile =
        drive.putRaw('prywatny', 'umowa.json', '{"id":"r1","kind":"report"}');
    final privateBefore = drive.files[privateFile]!.content;

    var a = await phone('a');
    await db.addReport(report('r1'));
    await db.addFirefighter(Firefighter(
        id: 'f1', firstName: 'Jan', lastName: 'Kowalski', rank: ''));
    final code = await a.createUnit('OSP Test');
    final unit = a.state.unitFolderId!;

    // Nieuczciwy członek podrzuca do wspólnego folderu śmieci i dane
    // o złych typach — także w miejsca, które aplikacja czyta przy każdej
    // synchronizacji.
    final year = drive.files.values
        .firstWhere((f) => f.isFolder && f.name == '2026')
        .id;
    drive
      ..putRaw(year, 'zly.json', '{to nie jest json')
      ..putRaw(year, 'typy.json',
          '{"id":["r2"],"reportNumber":7,"year":"dwa","date":false}')
      ..putRaw(year, 'pusty.json', '')
      ..putRaw(year, 'zagniezdzony.json', '[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]');

    final b = await phone('b');
    expect(await b.joinUnit(code), isTrue);
    await db.addReport(report('r3'));
    await db.deleteReport('r1');
    await b.syncAll();

    a = await phone('a');
    await a.syncAll();
    await a.syncAll();

    final outside = drive.writeTargets
        .where((t) => !drive.isInside(t, unit))
        .toList();
    expect(outside, isEmpty,
        reason: 'zapis poza folderem jednostki: $outside');
    expect(drive.files[privateFile]!.content, privateBefore,
        reason: 'prywatny plik nietknięty');
    expect(a.state.skippedFiles, greaterThan(0),
        reason: 'śmieci pominięte, a nie przerywające synchronizację');
  });

  test('zepsuty plik konfiguracji nie zatrzymuje synchronizacji', () async {
    final a = await phone('a');
    await a.createUnit('OSP Test');
    final config = drive.folderIdByName('config')!;
    final admins = drive.files.values
        .firstWhere((f) => f.parent == config && f.name == 'admins.json',
            orElse: () => FakeFile('', '', null))
        .id;
    if (admins.isEmpty) {
      drive.putRaw(config, 'admins.json', '{"admins":"wszyscy"}');
    } else {
      drive.files[admins]!.content = '{"admins":"wszyscy"}';
    }
    final unitConfig = drive.files.values
        .firstWhere((f) => f.parent == config && f.name == 'unit_config.json');
    unitConfig.content = unitConfig.content!
        .replaceFirst(RegExp(r'"createdBy":"[^"]*"'), '"createdBy":42');

    await db.addReport(report('r5'));
    await a.syncAll();

    expect(a.state.errorMessage, isNull,
        reason: 'synchronizacja przerwana: ${a.state.errorMessage}');
    expect(drive.jsonIn('2026').any((j) => j['id'] == 'r5'), isTrue,
        reason: 'nowy raport dotarł na Dysk mimo zepsutej konfiguracji');
  });

  /// Obcy folder udający jednostkę: z podanym kodem i nazwą prawdziwej
  /// jednostki, a nawet z jej założycielem wpisanym w pliku.
  void plantDecoy(String code) {
    drive.files.addAll({
      'wabik': FakeFile('wabik', 'OSP_App_OSP Kielno', null,
          isFolder: true, owner: 'obcy@gmail.com'),
      'wabik_config':
          FakeFile('wabik_config', 'config', 'wabik', isFolder: true),
      'wabik_unit': FakeFile('wabik_unit', 'unit_config.json', 'wabik_config')
        ..content = '{"unitName":"OSP Kielno","inviteCode":"$code",'
            '"createdBy":"a@gmail.com"}',
    });
  }

  bool leakedTo(String folderId, String text) => drive.files.values.any((f) =>
      !f.isFolder &&
      drive.isInside(f.id, folderId) &&
      (f.content ?? '').contains(text));

  test(
      'wabik z kodem prawdziwej jednostki: aplikacja nie zgaduje i nie '
      'dołącza', () async {
    final a = await phone('a');
    final code = await a.createUnit('OSP Kielno');

    // Obcy zna kod (np. z grupowego czatu) i udostępnia ofierze własny
    // folder z takim samym unit_config.json. Dysk nie gwarantuje kolejności
    // wyników, więc wcześniej mógł wygrać którykolwiek z nich.
    plantDecoy(code);

    final b = await phone('b');
    await db.addFirefighter(Firefighter(
        id: 'f9', firstName: 'Anna', lastName: 'Nowak', rank: ''));

    expect(await b.lookupUnit(code), isA<UnitAmbiguous>());
    expect(await b.joinUnit(code), isFalse);
    expect(b.state.unitFolderId, isNull);
    expect(leakedTo('wabik', 'Nowak'), isFalse,
        reason: 'dane ofiary nie trafiły do folderu obcego');
  });

  test(
      'podsunięty kod obcego folderu: przed dołączeniem widać prawdziwego '
      'właściciela, a nie to, co wpisano w pliku', () async {
    // Obcy podaje kod własnego folderu, podpisanego nazwą i założycielem
    // prawdziwej jednostki. Treść pliku może wpisać każdy — właściciela
    // folderu ustala Dysk.
    plantDecoy('OBC123');

    final b = await phone('b');
    final lookup = await b.lookupUnit('obc123');

    expect(lookup, isA<UnitFound>());
    final unit = (lookup as UnitFound).unit;
    expect(unit.unitName, 'OSP Kielno');
    expect(unit.ownerEmail, 'obcy@gmail.com');
    expect(b.state.unitFolderId, isNull,
        reason: 'samo wyszukanie niczego nie zmienia');
  });
}
