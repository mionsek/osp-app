/// Odmiana polskich rzeczowników po liczebniku i nazwy miesięcy.
///
/// Wydzielone, bo ta sama logika była powielona w trzech ekranach (miejsca
/// w pojeździe dwa razy, przejazdy raz), a nazwy miesięcy w dwóch miejscach —
/// w liście ewidencji i na wydruku karty drogowej. Rozjechanie się takich
/// kopii daje różne napisy w różnych miejscach tej samej aplikacji.
class PolishText {
  PolishText._();

  /// Wybiera formę rzeczownika pasującą do liczebnika.
  ///
  /// Polski ma trzy formy: pojedynczą (1 miejsce), mnogą „lekką" dla końcówek
  /// 2–4 (3 miejsca) i dopełniaczową dla reszty (5 miejsc). Wyjątkiem są
  /// nastki: 12, 13, 14 biorą formę dopełniaczową mimo końcówki 2–4.
  static String plural(
    int count, {
    required String one,
    required String few,
    required String many,
  }) {
    if (count == 1) return one;
    final lastTwo = count % 100;
    if (lastTwo >= 12 && lastTwo <= 14) return many;
    final last = count % 10;
    if (last >= 2 && last <= 4) return few;
    return many;
  }

  /// „miejsce / miejsca / miejsc" — liczba miejsc w pojeździe.
  static String seats(int count) =>
      plural(count, one: 'miejsce', few: 'miejsca', many: 'miejsc');

  /// „przejazd / przejazdy / przejazdów" — ewidencja przejazdów.
  static String trips(int count) =>
      plural(count, one: 'przejazd', few: 'przejazdy', many: 'przejazdów');

  /// Nazwy miesięcy w mianowniku, indeksowane od zera (styczeń = 0).
  ///
  /// Do etykiet w rodzaju „sierpień 2026". Do zdań typu „na miesiąc…"
  /// używa się tej samej formy, bo taki jest zwyczaj na drukach.
  static const List<String> monthNames = [
    'styczeń',
    'luty',
    'marzec',
    'kwiecień',
    'maj',
    'czerwiec',
    'lipiec',
    'sierpień',
    'wrzesień',
    'październik',
    'listopad',
    'grudzień',
  ];

  /// „sierpień 2026" — etykieta miesiąca dla numeru 1–12.
  static String monthLabel(int month, int year) =>
      '${monthNames[month - 1]} $year';
}
