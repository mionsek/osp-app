import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/sync_state.dart';

SyncState connected({
  String? me,
  String? founder,
  List<String> admins = const [],
}) =>
    SyncState(
      status: SyncStatus.idle,
      userEmail: me,
      unitFolderId: 'folder-1',
      founderEmail: founder,
      adminEmails: admins,
    );

void main() {
  group('isCurrentUserAdmin', () {
    test('praca bez jednostki to wlasne dane — wszystko dozwolone', () {
      const offline = SyncState(status: SyncStatus.disconnected);
      expect(offline.isCurrentUserAdmin, isTrue);
    });

    test('zalozyciel jest administratorem', () {
      final s = connected(me: 'szef@osp.pl', founder: 'szef@osp.pl');
      expect(s.isCurrentUserAdmin, isTrue);
    });

    test('osoba z listy administratorow ma uprawnienia', () {
      final s = connected(
        me: 'jan@osp.pl',
        founder: 'szef@osp.pl',
        admins: ['jan@osp.pl'],
      );
      expect(s.isCurrentUserAdmin, isTrue);
    });

    test('zwykly uzytkownik nie ma uprawnien', () {
      final s = connected(me: 'anna@osp.pl', founder: 'szef@osp.pl');
      expect(s.isCurrentUserAdmin, isFalse);
    });

    test('wielkosc liter i spacje nie maja znaczenia', () {
      final s = connected(
        me: '  JAN@osp.pl ',
        founder: 'szef@osp.pl',
        admins: ['jan@OSP.pl'],
      );
      expect(s.isCurrentUserAdmin, isTrue);
    });

    test('brak zalogowanego konta to brak uprawnien', () {
      final s = connected(me: null, founder: 'szef@osp.pl');
      expect(s.isCurrentUserAdmin, isFalse);
    });
  });

  group('canEditDocument', () {
    test('autor moze edytowac swoj dokument', () {
      final s = connected(me: 'anna@osp.pl', founder: 'szef@osp.pl');
      expect(s.canEditDocument('anna@osp.pl'), isTrue);
    });

    test('zwykly uzytkownik nie edytuje cudzego dokumentu', () {
      final s = connected(me: 'anna@osp.pl', founder: 'szef@osp.pl');
      expect(s.canEditDocument('jan@osp.pl'), isFalse);
    });

    test('administrator edytuje kazdy dokument', () {
      final s = connected(me: 'szef@osp.pl', founder: 'szef@osp.pl');
      expect(s.canEditDocument('jan@osp.pl'), isTrue);
    });

    test('dokument bez autora zostaje edytowalny', () {
      // Starsze zapisy i te utworzone offline nie maja autora — gdyby
      // blokowac, nikt nie moglby ich juz poprawic ani usunac.
      final s = connected(me: 'anna@osp.pl', founder: 'szef@osp.pl');
      expect(s.canEditDocument(null), isTrue);
      expect(s.canEditDocument('   '), isTrue);
    });
  });

  group('isFounder', () {
    test('rozpoznaje zalozyciela niezaleznie od wielkosci liter', () {
      final s = connected(me: 'x@osp.pl', founder: 'Szef@OSP.pl');
      expect(s.isFounder('szef@osp.pl'), isTrue);
      expect(s.isFounder('jan@osp.pl'), isFalse);
    });
  });
}
