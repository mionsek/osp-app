import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/report_numbers.dart';

/// Który z wyjazdów o tym samym numerze zatrzymuje numer.
///
/// Zasada Dawida po teście 1.7.4: wcześniejszy wyjazd zatrzymuje numer,
/// późniejszy dostaje następny. Wyjątek: dwa raporty z tej samej akcji —
/// wtedy nowy numer dopisałby do ewidencji wyjazd, którego nie było.
void main() {
  Report r(
    String id,
    String number,
    DateTime departure, {
    String locality = 'Kielno',
    String threat = 'Pożar',
    DateTime? createdAt,
  }) =>
      Report(
        id: id,
        reportNumber: number,
        year: departure.year,
        date: DateTime(departure.year, departure.month, departure.day),
        departureTime: departure,
        addressLocality: locality,
        addressStreet: '',
        addressDescription: '',
        threatCategory: threat,
        createdAt: createdAt ?? departure,
        updatedAt: departure,
      );

  final day = DateTime(2026, 10, 27);
  DateTime at(int h, int m) => day.add(Duration(hours: h, minutes: m));

  group('laterDuplicates', () {
    test('test z dwóch telefonów: późniejszy wypadek, nie wcześniejszy '
        'alarm', () {
      final alarm = r('r-a', '0002/2026', at(16, 35),
          locality: 'Gdynia', threat: 'Fałszywy Alarm');
      final accident = r('r-w', '0002/2026', at(17, 10),
          threat: 'Miejscowe Zagrożenie');

      // Kolejność na liście nie ma znaczenia — każdy telefon wskaże ten sam.
      expect(ReportNumbers.laterDuplicates([accident, alarm]), [accident]);
      expect(ReportNumbers.laterDuplicates([alarm, accident]), [accident]);
    });

    test('przy tej samej godzinie wyjazdu — później zapisany', () {
      final first = r('r-1', '0002/2026', at(16, 35),
          locality: 'Gdynia', createdAt: at(16, 40));
      final second = r('r-2', '0002/2026', at(16, 35),
          locality: 'Kielno', threat: 'Inne', createdAt: at(16, 45));

      expect(ReportNumbers.laterDuplicates([second, first]), [second]);
    });

    test('trzy z tym samym numerem — dwa późniejsze; pojedyncze numery '
        'nietknięte', () {
      final a = r('a', '0002/2026', at(8, 0), locality: 'A', threat: 'X');
      final b = r('b', '0002/2026', at(12, 0), locality: 'B', threat: 'Y');
      final c = r('c', '0002/2026', at(18, 0), locality: 'C', threat: 'Z');
      final alone = r('d', '0003/2026', at(19, 0));

      expect(ReportNumbers.laterDuplicates([c, alone, a, b]),
          unorderedEquals([b, c]));
    });

    test('ta sama akcja zapisana dwa razy zostaje z numerem', () {
      final a = r('a', '0002/2026', at(16, 35));
      final b = r('b', '0002/2026', at(16, 50));

      expect(ReportNumbers.laterDuplicates([a, b]), isEmpty);
    });
  });

  group('looksLikeSameIncident', () {
    test('w ciągu godziny, ten sam rodzaj zagrożenia', () {
      expect(
        ReportNumbers.looksLikeSameIncident(
          r('a', '1', at(16, 35), locality: 'Kielno'),
          r('b', '1', at(17, 30), locality: 'Szemud'),
        ),
        isTrue,
      );
    });

    test('w ciągu godziny, ta sama miejscowość (wielkość liter i spacje '
        'bez znaczenia)', () {
      expect(
        ReportNumbers.looksLikeSameIncident(
          r('a', '1', at(16, 35), locality: 'Kielno', threat: 'Pożar'),
          r('b', '1', at(16, 40),
              locality: ' kielno ', threat: 'Miejscowe Zagrożenie'),
        ),
        isTrue,
      );
    });

    test('po północy to wciąż może być ta sama akcja', () {
      expect(
        ReportNumbers.looksLikeSameIncident(
          r('a', '1', at(23, 50)),
          r('b', '1', at(24, 5)),
        ),
        isTrue,
      );
    });

    test('ponad godzinę różnicy — dwa wyjazdy', () {
      expect(
        ReportNumbers.looksLikeSameIncident(
          r('a', '1', at(16, 0)),
          r('b', '1', at(17, 1)),
        ),
        isFalse,
      );
    });

    test('inna miejscowość i inne zagrożenie — dwa wyjazdy, nawet o tej '
        'samej godzinie (test 1.7.4)', () {
      expect(
        ReportNumbers.looksLikeSameIncident(
          r('a', '1', at(16, 35), locality: 'Gdynia', threat: 'Fałszywy Alarm'),
          r('b', '1', at(16, 35),
              locality: 'Kielno', threat: 'Miejscowe Zagrożenie'),
        ),
        isFalse,
      );
    });

    test('puste pola nie są „tym samym"', () {
      expect(
        ReportNumbers.looksLikeSameIncident(
          r('a', '1', at(16, 35), locality: '', threat: 'Pożar'),
          r('b', '1', at(16, 40), locality: '', threat: 'Inne'),
        ),
        isFalse,
      );
    });
  });
}
