import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/server_phones.dart';

/// Zmiana konta i treść zaproszenia.
///
/// Zgłoszenie z testów 1.7.1: po zalogowaniu w Ustawieniach nie było widać
/// konta ani wylogowania, a dołączenie kodem z innego konta nie działało.
void main() {
  late Directory root;
  late ServerPhones phones;
  final db = DatabaseService();

  setUpAll(DatabaseService.registerAdapters);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('osp_account_switch');
    phones = ServerPhones(root);
  });

  tearDown(() async {
    await Hive.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('zaproszenie podaje jednostkę, kod, konto do zalogowania i stronę '
      'aplikacji', () {
    final message = SyncService.inviteMessage(
      unitName: 'Ochotnicza Straż Pożarna w Kielnie',
      code: 'ABC234',
      email: 'jan.kowalski@gmail.com',
    );
    expect(message, contains('Ochotnicza Straż Pożarna w Kielnie'));
    expect(message, contains('ABC234'));
    expect(message, contains('jan.kowalski@gmail.com'));
    expect(message, contains('https://mionsek.github.io/osp-app/'),
        reason: 'skąd pobrać aplikację — także w SMS-ie');
  });

  test('zaproszenie zwraca tę treść z kodem jednostki i adresem małymi '
      'literami', () async {
    final a = await phones.phone('a');
    final code = await phones.create(a, 'OSP w Kielnie');
    final message = await a.inviteMember(' Jan.Kowalski@Gmail.com ');
    expect(message, contains(code));
    expect(message, contains('OSP w Kielnie'));
    expect(message, contains('jan.kowalski@gmail.com'));
  });

  group('zmiana konta', () {
    test('konto spoza jednostki zostaje w niej z komunikatem, kogo zaprosić',
        () async {
      final a = await phones.phone('a');
      await phones.create(a);
      final unitId = a.state.unitId;
      phones.auth.nextAccount = (uid: 'obcy', email: 'obcy@gmail.com');

      expect(await a.switchAccount(), isTrue);

      expect(a.state.status, SyncStatus.error);
      expect(a.state.errorMessage, contains('obcy@gmail.com'));
      expect(a.state.unitId, unitId);
    });

    test('zamknięcie wyboru konta wylogowuje, ale nie odłącza jednostki',
        () async {
      final a = await phones.phone('a');
      await phones.create(a);
      final unitId = a.state.unitId;
      phones.auth.nextAccount = null;

      expect(await a.switchAccount(), isFalse);
      expect(a.state.userEmail, isNull);

      // Po zalogowaniu jednostka wraca sama, bez ponownego kodu.
      phones.auth.nextAccount = (uid: 'a', email: 'a@gmail.com');
      expect(await a.signIn(), isTrue);
      expect(a.state.unitId, unitId);
      expect(a.state.status, SyncStatus.idle);
    });

    test('bez jednostki zmienia samo konto', () async {
      final solo = await phones.phone('a');
      phones.auth.nextAccount = (uid: 'jan', email: 'jan@gmail.com');

      expect(await solo.switchAccount(), isTrue);

      expect(solo.state.userEmail, 'jan@gmail.com');
      expect(solo.state.unitId, isNull);
      expect(solo.state.status, SyncStatus.disconnected);
      expect(db.getConfig().ownerEmail, isEmpty);
    });
  });
}
