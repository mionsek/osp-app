import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/screens/settings/unit_members_section.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/fake_drive.dart';
import 'helpers/phone_db.dart';

/// Kto naprawdę dołączył do jednostki (feature/080, Dawid 25.11.2026).
///
/// Uprawnienia do folderu mówią tylko, kogo zaproszono. Telefon, który
/// dołączył, zapisuje w `members/` notatkę o swoim koncie: adres, kiedy
/// dołączył, kiedy ostatnio się synchronizował i wersję aplikacji.
void main() {
  late Directory root;
  late FakeDrive drive;
  final db = DatabaseService();

  setUpAll(DatabaseService.registerAdapters);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_members');
    drive = FakeDrive();
    SyncService.appVersion = '1.9.20';
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<SyncService> phone(String name, {String? account}) async {
    await openPhoneDb(root, name);
    final email = account ?? '$name@gmail.com';
    drive.account = email;
    final sync = SyncService(db, FakeAuth(email), drive);
    await sync.restoreState();
    return sync;
  }

  List<Map<String, dynamic>> notes() => drive.jsonIn('members');
  Map<String, dynamic> noteOf(String email) =>
      notes().firstWhere((n) => n['email'] == email);

  Future<String> unitWithMember() async {
    final a = await phone('a');
    final code = await a.createUnit('OSP Test');
    final b = await phone('b');
    expect(await b.joinUnit(code), isTrue);
    return code;
  }

  test('założyciel i dołączający zostawiają notatkę — adres, daty, wersja',
      () async {
    await unitWithMember();
    expect(notes().map((n) => n['email']),
        unorderedEquals(['a@gmail.com', 'b@gmail.com']));
    final b = noteOf('b@gmail.com');
    expect(b['appVersion'], '1.9.20');
    expect(DateTime.tryParse(b['joinedAt'] as String), isNotNull);
    expect(DateTime.tryParse(b['lastSyncAt'] as String), isNotNull);
    expect(b.keys,
        unorderedEquals(
            ['email', 'joinedAt', 'lastSyncAt', 'appVersion', 'updatedAt']),
        reason: 'nic poza tym — bez modelu telefonu czy lokalizacji');
    expect(drive.fileIdOf('members', 'b@gmail.com.json'), isNotEmpty);
  });

  test('synchronizacja odświeża notatkę najwyżej co 6 godzin albo po zmianie '
      'wersji', () async {
    await unitWithMember();
    var b = await phone('b');
    final file = drive.fileIdOf('members', 'b@gmail.com.json');
    final first = drive.files[file]!.modified;

    await b.syncAll();
    expect(drive.files[file]!.modified, first,
        reason: 'świeża notatka — bez zapisu przy każdej synchronizacji');

    // 7 godzin później.
    final saved = Map<String, dynamic>.from(
        db.settingsBox.get('memberNote') as Map);
    saved['at'] = DateTime.now()
        .subtract(const Duration(hours: 7))
        .toIso8601String();
    await db.settingsBox.put('memberNote', saved);
    await b.syncAll();
    expect(drive.files[file]!.modified, isNot(first));

    final before = drive.files[file]!.modified;
    SyncService.appVersion = '1.9.21';
    b = await phone('b');
    await b.syncAll();
    expect(drive.files[file]!.modified, isNot(before));
    expect(noteOf('b@gmail.com')['appVersion'], '1.9.21');
  });

  test('data dołączenia zostaje po ponownej instalacji', () async {
    final code = await unitWithMember();
    final joined = noteOf('b@gmail.com')['joinedAt'];

    final again = await phone('b-nowy-telefon', account: 'b@gmail.com');
    expect(await again.joinUnit(code), isTrue);
    expect(noteOf('b@gmail.com')['joinedAt'], joined);
    expect(notes().where((n) => n['email'] == 'b@gmail.com'), hasLength(1));
  });

  test('lista dla administratora: notatki członków, bez podrobionych',
      () async {
    await unitWithMember();
    // Ktoś wrzuca na Dysku notatkę „za kolegę".
    final folder = drive.folderIdByName('members')!;
    drive.account = 'm@gmail.com';
    drive.putRaw(folder, 'c@gmail.com.json',
        '{"email":"c@gmail.com","joinedAt":"2026-11-01T10:00:00.000"}');

    final a = await phone('a');
    final list = await a.memberNotes();
    expect(list.keys, unorderedEquals(['a@gmail.com', 'b@gmail.com']));
    expect(list['b@gmail.com']!.appVersion, '1.9.20');
  });

  test('„Wyloguj i usuń dane" usuwa własną notatkę, cudzych nie', () async {
    await unitWithMember();
    final b = await phone('b');
    await b.removeOwnMemberNote();
    expect(notes().map((n) => n['email']), ['a@gmail.com']);
    expect(db.settingsBox.get('memberNote'), isNull);
  });

  group('napis na liście członków', () {
    final now = DateTime(2026, 11, 27, 15, 30);

    test('bez notatki — mówi o obu możliwościach', () {
      expect(memberStatus(null, now),
          'Brak śladu w aplikacji — zaproszenie nieprzyjęte albo starsza '
          'wersja aplikacji');
    });

    test('dziś, wczoraj, wcześniej', () {
      MemberNote note(DateTime last) => MemberNote(
            email: 'b@gmail.com',
            joinedAt: DateTime(2026, 11, 25, 9),
            lastSyncAt: last,
            appVersion: '1.9.20',
          );
      expect(memberStatus(note(DateTime(2026, 11, 27, 14, 5)), now),
          'W aplikacji od 25.11.2026 · ostatnio dziś 14:05 · wersja 1.9.20');
      expect(memberStatus(note(DateTime(2026, 11, 26, 20, 0)), now),
          'W aplikacji od 25.11.2026 · ostatnio wczoraj 20:00 · wersja 1.9.20');
      expect(memberStatus(note(DateTime(2026, 11, 20, 8, 0)), now),
          'W aplikacji od 25.11.2026 · ostatnio 20.11.2026 · wersja 1.9.20');
    });

    test('zapis i odczyt notatki; śmieci pomijane', () {
      final n = MemberNote(
          email: 'b@gmail.com',
          joinedAt: DateTime(2026, 11, 25),
          lastSyncAt: DateTime(2026, 11, 27),
          appVersion: '1.9.20');
      final back = MemberNote.fromJson(n.toJson())!;
      expect(back.email, n.email);
      expect(back.joinedAt, n.joinedAt);
      expect(back.lastSyncAt, n.lastSyncAt);
      expect(back.appVersion, n.appVersion);
      expect(MemberNote.fromJson({'email': 42}), isNull);
      expect(MemberNote.fromJson('tekst'), isNull);
      expect(MemberNote.fileName(' B@Gmail.com '), 'b@gmail.com.json');
    });
  });
}
