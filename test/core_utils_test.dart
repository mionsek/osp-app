import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/core/utils/file_names.dart';
import 'package:osp_app/core/utils/polish_text.dart';
import 'package:osp_app/core/utils/time_format.dart';
import 'package:osp_app/services/pdf_output.dart';

/// Testy wspólnych funkcji pomocniczych z `core/utils` i `PdfOutput`.
///
/// Wszystkie są czyste i deterministyczne, a mimo to **żadna nie miała testu** —
/// mimo że dwie z nich powstały właśnie dlatego, że ich powielone wersje się
/// rozjechały i dawały różne wyniki w różnych miejscach aplikacji:
/// odmiana liczebników miała błąd dla 12–14, a sanityzacja nazw plików istniała
/// w trzech różnych wariantach. Wydzielenie naprawiło objaw; test pilnuje,
/// żeby nie wrócił.
void main() {
  group('PolishText.plural', () {
    test('liczba pojedyncza tylko dla dokladnie jednego', () {
      expect(PolishText.trips(1), 'przejazd');
      expect(PolishText.seats(1), 'miejsce');
    });

    test('koncowki 2-4 biora forme mnoga', () {
      expect(PolishText.trips(2), 'przejazdy');
      expect(PolishText.trips(3), 'przejazdy');
      expect(PolishText.trips(4), 'przejazdy');
      expect(PolishText.trips(22), 'przejazdy');
      expect(PolishText.trips(34), 'przejazdy');
      expect(PolishText.trips(102), 'przejazdy');
    });

    test('nastki 12-14 biora dopelniacz mimo koncowki 2-4', () {
      // Ten przypadek był realnym błędem w powielonych kopiach sprzed
      // refactor/034: „12 miejsca" zamiast „12 miejsc". Nieszkodliwy tylko
      // dlatego, że pojazd ma najwyżej 6 miejsc — ale przejazdów w miesiącu
      // bywa kilkanaście i wtedy widać go od razu.
      expect(PolishText.trips(12), 'przejazdów');
      expect(PolishText.trips(13), 'przejazdów');
      expect(PolishText.trips(14), 'przejazdów');
      expect(PolishText.seats(12), 'miejsc');
      // 112–114 to te same nastki o setkę dalej.
      expect(PolishText.trips(112), 'przejazdów');
      expect(PolishText.trips(113), 'przejazdów');
    });

    test('zero i reszta biora dopelniacz', () {
      expect(PolishText.trips(0), 'przejazdów');
      expect(PolishText.trips(5), 'przejazdów');
      expect(PolishText.trips(11), 'przejazdów');
      expect(PolishText.trips(25), 'przejazdów');
      // 101 nie jest „jeden" — liczebnik złożony bierze dopełniacz.
      expect(PolishText.trips(101), 'przejazdów');
    });
  });

  group('PolishText.monthLabel', () {
    test('numeruje miesiace od jedynki', () {
      expect(PolishText.monthLabel(1, 2026), 'styczeń 2026');
      expect(PolishText.monthLabel(8, 2026), 'sierpień 2026');
      expect(PolishText.monthLabel(12, 2026), 'grudzień 2026');
    });

    test('ma dokladnie dwanascie nazw', () {
      expect(PolishText.monthNames, hasLength(12));
    });
  });

  group('FileNames.sanitize', () {
    test('zwykla nazwa przechodzi bez zmian', () {
      expect(FileNames.sanitize('Kielno'), 'Kielno');
      expect(FileNames.sanitize('GBA-2'), 'GBA-2');
    });

    test('spacje i znaki zabronione staja sie podkresleniem', () {
      expect(FileNames.sanitize('Kielno Oliwska'), 'Kielno_Oliwska');
      expect(FileNames.sanitize('a/b\\c:d'), 'a_b_c_d');
    });

    test('ciagi podkreslen sklejaja sie w jedno', () {
      expect(FileNames.sanitize('a   b'), 'a_b');
      expect(FileNames.sanitize('a---b'), 'a---b');
    });

    test('podkreslenia z brzegow znikaja', () {
      expect(FileNames.sanitize(' Kielno '), 'Kielno');
      expect(FileNames.sanitize('///Kielno///'), 'Kielno');
    });

    test('ta sama nazwa daje zawsze ten sam wynik', () {
      // Sedno wydzielenia: przed refactor/034 ta sama miejscowość dawała różne
      // nazwy pliku w PDF-ie i na Dysku, bo każde miejsce sanityzowało inaczej.
      const input = 'Kielno, Oliwska 12';
      expect(FileNames.sanitize(input), FileNames.sanitize(input));
      expect(FileNames.sanitize(input), 'Kielno_Oliwska_12');
    });

    test('pusty tekst nie wywala sie', () {
      expect(FileNames.sanitize(''), '');
      expect(FileNames.sanitize('   '), '');
    });
  });

  group('FileNames — daty w nazwach', () {
    test('data jest sortowalna leksykograficznie', () {
      expect(FileNames.date(DateTime(2026, 8, 9)), '2026-08-09');
      expect(FileNames.date(DateTime(2026, 12, 31)), '2026-12-31');
      // Właśnie po to jest dopełnianie zerami: napisy układają się
      // chronologicznie bez dodatkowej logiki sortowania.
      final sorted = [
        FileNames.date(DateTime(2026, 10, 1)),
        FileNames.date(DateTime(2026, 2, 1)),
        FileNames.date(DateTime(2026, 1, 15)),
      ]..sort();
      expect(sorted, ['2026-01-15', '2026-02-01', '2026-10-01']);
    });

    test('rok z miesiacem', () {
      expect(FileNames.yearMonth(2026, 8), '2026-08');
      expect(FileNames.yearMonth(2026, 11), '2026-11');
    });
  });

  group('TimeFormat', () {
    test('godzina zawsze dwucyfrowa', () {
      expect(TimeFormat.hhmm(DateTime(2026, 8, 9, 7, 5)), '07:05');
      expect(TimeFormat.hhmm(DateTime(2026, 8, 9, 14, 30)), '14:30');
      expect(TimeFormat.hhmm(DateTime(2026, 8, 9, 0, 0)), '00:00');
    });

    test('ta sama postac dla TimeOfDay', () {
      expect(TimeFormat.hhmmOf(const TimeOfDay(hour: 7, minute: 5)), '07:05');
      expect(TimeFormat.hhmmOf(const TimeOfDay(hour: 23, minute: 59)), '23:59');
    });

    test('data po polsku', () {
      expect(TimeFormat.date(DateTime(2026, 8, 9)), '09.08.2026');
      expect(TimeFormat.date(DateTime(2026, 12, 31)), '31.12.2026');
    });

    test('zakres bez godziny powrotu konczy sie myslnikiem', () {
      // Wyjazd bez wpisanego powrotu to normalny stan, nie błąd — kreator
      // celowo zostawia to pole puste.
      final dep = DateTime(2026, 8, 9, 14, 30);
      expect(TimeFormat.range(dep, null), '14:30 – —');
      expect(TimeFormat.range(dep, DateTime(2026, 8, 9, 16, 0)), '14:30 – 16:00');
    });
  });

  group('PdfOutput.wrapText', () {
    test('krotki tekst dopelnia sie pustymi liniami', () {
      final lines = PdfOutput.wrapText('Kielno', 3, charsPerLine: 20);
      expect(lines, hasLength(3));
      expect(lines.first, 'Kielno');
      expect(lines[1], '');
      expect(lines[2], '');
    });

    test('pusty tekst daje same puste linie', () {
      expect(PdfOutput.wrapText('', 4), ['', '', '', '']);
    });

    test('dzieli po slowach, nie w srodku wyrazu', () {
      final lines =
          PdfOutput.wrapText('Budynek gospodarczy za posesją', 3, charsPerLine: 12);
      expect(lines.every((l) => !l.startsWith(' ')), isTrue);
      expect(lines.join(' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty),
          ['Budynek', 'gospodarczy', 'za', 'posesją']);
    });

    test('nadmiar dokladany do ostatniej linii zamiast obcinany', () {
      // Formularz ma stałą liczbę wykropkowanych linii, ale zgubienie
      // końcówki opisu mienia byłoby gorsze niż ciasny ostatni wiersz.
      final lines = PdfOutput.wrapText(
        'jeden dwa trzy cztery piec szesc siedem osiem',
        2,
        charsPerLine: 10,
      );
      expect(lines, hasLength(2));
      expect(lines.join(' '), contains('osiem'));
    });

    test('zawsze zwraca dokladnie tyle linii, ile zamowiono', () {
      for (final maxLines in [1, 2, 5, 10]) {
        expect(PdfOutput.wrapText('Kielno Oliwska 12', maxLines), hasLength(maxLines));
      }
    });
  });
}
