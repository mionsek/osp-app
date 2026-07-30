import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/core/utils/firefighter_search.dart';
import 'package:osp_app/models/models.dart';

Firefighter ff(String firstName, String lastName) => Firefighter(
      id: '$firstName-$lastName',
      firstName: firstName,
      lastName: lastName,
      rank: '',
    );

void main() {
  final wiktoriaDaleka = ff('Wiktoria', 'Daleka');
  final janWisniewski = ff('Jan', 'Wiśniewski');
  final annaKowalska = ff('Anna', 'Kowalska');
  final all = [wiktoriaDaleka, janWisniewski, annaKowalska];

  group('FirefighterSearch.filter', () {
    test('empty query returns everyone sorted by surname', () {
      final result = FirefighterSearch.filter(all, '');
      expect(result.map((f) => f.lastName), ['Daleka', 'Kowalska', 'Wiśniewski']);
    });

    test('whitespace-only query behaves like an empty one', () {
      expect(FirefighterSearch.filter(all, '   ').length, all.length);
    });

    test('surname matches rank above first-name matches', () {
      // „Wi" pasuje do nazwiska Wiśniewski i do imienia Wiktoria —
      // nazwisko ma być pierwsze, bo tak zgłaszamy skład do PSP.
      final result = FirefighterSearch.filter(all, 'Wi');
      expect(result.first, janWisniewski);
      expect(result, contains(wiktoriaDaleka));
    });

    test('searching by first name still finds the person', () {
      final result = FirefighterSearch.filter(all, 'Wiktoria');
      expect(result, [wiktoriaDaleka]);
    });

    test('matches in the middle of a name are included last', () {
      final result = FirefighterSearch.filter(all, 'owalsk');
      expect(result, [annaKowalska]);
    });

    test('search is case-insensitive', () {
      expect(FirefighterSearch.filter(all, 'kOwAlSkA'), [annaKowalska]);
    });

    test('no match returns an empty list', () {
      expect(FirefighterSearch.filter(all, 'Zzz'), isEmpty);
    });
  });
}
