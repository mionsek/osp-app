import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_service.dart';

import 'helpers/fake_drive.dart';

/// Konto Google, zaproszenia i przejście z konta jednostki na własne.
///
/// Zgłoszenie z testów 1.7.1: po zalogowaniu w Ustawieniach nie było widać
/// konta ani wylogowania, a dołączenie kodem z innego konta nie działało.
/// Uprawnień Dysku między kontami atrapa nie sprawdzi — to zostaje do testu
/// na dwóch telefonach — ale cała reszta przepływu tak.
void main() {
  late Directory dir;
  late FakeDrive drive;
  late FakeAuth auth;
  late SyncService sync;
  final db = DatabaseService();

  setUpAll(() {
    DatabaseService.registerAdapters();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('osp_account_switch');
    Hive.init(dir.path);
    await DatabaseService.openBoxes();
    drive = FakeDrive();
    auth = FakeAuth('ospkielno@gmail.com');
    sync = SyncService(db, auth, drive);
    await sync.restoreState();
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('zaproszenie e-mailem', () {
    test('treść podaje jednostkę, kod i konto, którym trzeba się zalogować',
        () {
      final message = SyncService.inviteMessage(
        unitName: 'Ochotnicza Straż Pożarna w Kielnie',
        code: 'ABC234',
        email: 'jan.kowalski@gmail.com',
      );
      expect(message, contains('Ochotnicza Straż Pożarna w Kielnie'));
      expect(message, contains('ABC234'));
      expect(message, contains('jan.kowalski@gmail.com'));
    });

    test('zaproszenie kolegi wysyła e-mail z kodem tej jednostki', () async {
      await db.saveConfig(
          db.getConfig().copyWith(unitFullName: 'OSP w Kielnie'));
      final code = await sync.createUnit('OSP w Kielnie');

      await sync.inviteMember('  jan@gmail.com ');

      final share = drive.shares.single;
      expect(share.folderId, sync.state.unitFolderId);
      expect(share.email, 'jan@gmail.com');
      expect(share.message, contains(code));
      expect(share.message, contains('OSP w Kielnie'));
    });
  });

  group('przejście na własne konto', () {
    test('udostępnia jednostkę bez e-maila, nadaje administratora '
        'i zostaje w tej samej jednostce', () async {
      final code = await sync.createUnit('OSP w Kielnie');
      final folderId = sync.state.unitFolderId;
      auth.nextAccount = 'dawid@gmail.com';

      final result = await sync.switchToPersonalAccount('Dawid@gmail.com');

      expect(result, AccountSwitchResult.done);
      // Siebie nie zaprasza się mailem — i tak zaraz zmienia się konto.
      expect(drive.shares.single.email, 'Dawid@gmail.com');
      expect(drive.shares.single.message, isNull);
      expect(sync.state.userEmail, 'dawid@gmail.com');
      expect(sync.state.unitFolderId, folderId);
      expect(sync.state.unitInviteCode, code);
      expect(sync.state.status, SyncStatus.idle);
      // Konto jednostki zostaje założycielem, a nowe konto ma uprawnienia
      // administratora — inaczej po przejściu nie dałoby się zarządzać.
      expect(sync.state.founderEmail, 'ospkielno@gmail.com');
      expect(sync.state.isCurrentUserAdmin, isTrue);
    });

    test('adres konta, na którym już się jest, niczego nie zmienia', () async {
      await sync.createUnit('OSP w Kielnie');

      final result =
          await sync.switchToPersonalAccount(' OSPkielno@gmail.com ');

      expect(result, AccountSwitchResult.sameAccount);
      expect(drive.shares, isEmpty);
      expect(sync.state.userEmail, 'ospkielno@gmail.com');
    });

    test('wybranie innego konta niż podane', () async {
      await sync.createUnit('OSP w Kielnie');
      auth.nextAccount = 'ktos.inny@gmail.com';

      final result = await sync.switchToPersonalAccount('dawid@gmail.com');

      expect(result, AccountSwitchResult.otherAccount);
      expect(sync.state.userEmail, 'ktos.inny@gmail.com');
    });

    test('zamknięcie wyboru konta wylogowuje, ale nie odłącza jednostki',
        () async {
      await sync.createUnit('OSP w Kielnie');
      final folderId = sync.state.unitFolderId;
      auth.nextAccount = null;

      final result = await sync.switchToPersonalAccount('dawid@gmail.com');

      expect(result, AccountSwitchResult.cancelled);
      expect(sync.state.userEmail, isNull);

      // Po zalogowaniu jednostka wraca sama, bez ponownego kodu.
      auth.nextAccount = 'dawid@gmail.com';
      expect(await sync.signIn(), isTrue);
      expect(sync.state.unitFolderId, folderId);
      expect(sync.state.status, SyncStatus.idle);
    });
  });

  group('zmiana konta', () {
    test('konto bez dostępu do jednostki zostaje w niej z komunikatem, '
        'kogo zaprosić', () async {
      await sync.createUnit('OSP w Kielnie');
      final folderId = sync.state.unitFolderId!;
      drive.inaccessible.add(folderId);
      auth.nextAccount = 'obcy@gmail.com';

      expect(await sync.switchAccount(), isTrue);

      expect(sync.state.status, SyncStatus.error);
      expect(sync.state.errorMessage, contains('obcy@gmail.com'));
      expect(sync.state.unitFolderId, folderId);
    });

    test('bez jednostki zmienia samo konto', () async {
      auth.nextAccount = 'jan@gmail.com';

      expect(await sync.switchAccount(), isTrue);

      expect(sync.state.userEmail, 'jan@gmail.com');
      expect(sync.state.unitFolderId, isNull);
      expect(sync.state.status, SyncStatus.disconnected);
    });
  });
}
