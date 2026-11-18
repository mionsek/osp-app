import 'package:intl/intl.dart';

import '../models/models.dart';
import 'card_sheet.dart';
import 'equipment_card.dart';
import 'pdf_output.dart';
import 'trip_card.dart';

/// Karty pracy sprzętu na kartkach — układ ze zdjęć kart OSP Kielno
/// (Dawid, 9.11.2026): dwie karty A5 w pionie obok siebie na kartce A4
/// w poziomie. Przód — dane urządzenia i tabela pracy, tył — rozliczenie.
///
/// Tył kartki ma karty w odwrotnej kolejności: po druku dwustronnym
/// (obracanie wzdłuż krótszej krawędzi) rozliczenie wypada za swoją kartą.
class EquipmentCardSheet {
  EquipmentCardSheet._();

  static List<CardPage> pages({
    required List<(Equipment, List<EquipmentCardRow>)> cards,
    required UnitConfig config,
    required int year,
    required int month,
  }) {
    final unit = TripCard.unitName(config);
    final monthLabel = TripCard.month(month, year);
    final pages = <CardPage>[];
    for (var i = 0; i < cards.length; i += 2) {
      final a = cards[i];
      final b = i + 1 < cards.length ? cards[i + 1] : null;
      final name = b == null ? a.$1.name : '${a.$1.name} i ${b.$1.name}';
      final front = CardPage('Praca $name');
      _front(front, 0, a, unit, monthLabel);
      if (b != null) _front(front, CardPage.width / 2, b, unit, monthLabel);
      final back = CardPage('Tył $name');
      if (b != null) _back(back, 0, b);
      _back(back, CardPage.width / 2, a);
      pages.addAll([front, back]);
    }
    return pages;
  }

  static const _bold = CardText(size: 10, bold: true);
  static const _plain = CardText(size: 10);

  static void _front(CardPage p, double ox,
      (Equipment, List<EquipmentCardRow>) card, String unit, String month) {
    final (device, rows) = card;
    final x = ox + 12;
    p.text(x, 12, 22, 6, 'Jednostka', _bold);
    p.text(x + 22, 12, 80, 6, unit, _bold);
    const title = CardText(size: 10, bold: true, align: CardAlign.center);
    p.text(ox + 30, 18, 106, 5.5, 'MIESIĘCZNA KARTA PRACY', title);
    p.text(ox + 30, 23.5, 106, 5.5, 'SPRZĘTU SILNIKOWEGO', title);
    p.text(x + 38, 32, 22, 6, 'Na miesiąc', _plain);
    p.text(x + 60, 32, 64, 6, month, _plain);
    p.text(x + 8, 41, 13, 6, 'Marka', _plain);
    p.text(x + 21, 41, 31, 6, device.brand, _bold, true);
    p.text(x + 53, 41, 10, 6, 'Typ', _plain);
    p.text(x + 63, 41, 61, 6, device.model, _bold, true);
    p.text(x + 8, 50, 13, 6, 'Rodzaj', _plain);
    p.text(x + 21, 50, 61, 6, device.name, _bold, true);
    p.text(x + 83, 50, 41, 6, 'Stan Licznika ..............', _plain);
    p.text(x + 8, 59, 66, 6, 'Norma eksploatacyjna na 1 godz. Pracy', _plain);
    p.text(
        x + 74,
        59,
        10,
        6,
        device.fuelPerHour == null ? '' : PdfOutput.number(device.fuelPerHour),
        _bold.copyWith(align: CardAlign.center));
    p.text(x + 85, 59, 15, 6, 'litrów', _plain);

    // 20 wierszy jak na papierze; więcej wpisów — gęściej.
    final count = rows.length > 20 ? rows.length : 20;
    const head = CardText(size: 9.5, align: CardAlign.center);
    const top = CardText(size: 9.5, align: CardAlign.center, top: true);
    const data = CardText(size: 9.5);
    const mid = CardText(size: 9.5, align: CardAlign.center);
    p.table(x, 67, const [19, 35, 17.5, 33.5, 19.5],
        [10, for (var i = 0; i < count; i++) 116 / count], [
      const Cell(0, 0, 'Data', style: top),
      const Cell(0, 1, 'Nazwisko i imię\nobsługującego', style: head),
      const Cell(0, 2, 'Minut\npracy', style: head),
      const Cell(0, 3, 'Cel użycia', style: top),
      const Cell(0, 4, 'Podpis\ndysponenta', style: head),
      for (var i = 0; i < rows.length; i++) ...[
        Cell(i + 1, 0, DateFormat('dd.MM').format(rows[i].date), style: mid),
        Cell(i + 1, 1, rows[i].operatorName, style: data, fit: true),
        Cell(i + 1, 2, '${rows[i].minutes}', style: mid),
        Cell(i + 1, 3, rows[i].purpose, style: data, fit: true),
      ],
    ]);
  }

  /// Tył karty ze zdjęcia karty motopompy Niagara (5.11.2026): ciąg dalszy
  /// tabeli pracy („Z przeniesienia") z tabelą licznika pod spodem,
  /// „POBRANO W LITRACH" i rozliczenie w litrach. Szerokości kolumn
  /// i wysokości wierszy odmierzone ze zdjęcia w proporcji do szerokości
  /// tabeli, krój 9 pt jak na papierze. Pola bez danych z aplikacji zostają
  /// puste — do wypełnienia długopisem.
  static void _back(
      CardPage p, double ox, (Equipment, List<EquipmentCardRow>) card) {
    final (device, rows) = card;
    final x = ox + 12;
    const plain = CardText(size: 9);
    const center = CardText(size: 9, align: CardAlign.center);
    const centerTop = CardText(size: 9, align: CardAlign.center, top: true);
    const bold = CardText(size: 9, bold: true);
    const boldTop = CardText(size: 9, bold: true, top: true);

    // Ciąg dalszy tabeli z przodu i tabela licznika — wspólne kolumny.
    const cols = [16.0, 33.5, 18.5, 32.5, 24.0];
    p.table(x, 12, cols, const [8.5, 4.75, 4.75, 4.75, 4.75, 9.5, 4.75], const [
      Cell(0, 0, 'Data', style: centerTop),
      Cell(0, 1, 'Nazwisko i imię\nobsługującego', style: center),
      Cell(0, 2, 'Minut\npracy', style: center),
      Cell(0, 3, 'Cel użycia', style: centerTop),
      Cell(0, 4, 'Podpis\ndysponenta', style: center),
      Cell(1, 0, 'Z przeniesienia', cs: 2),
      Cell(1, 3, 'xxxxxx', cs: 2, style: CardText(size: 8, align: CardAlign.center)),
      Cell(5, 0, 'Data', style: bold),
      Cell(5, 1, 'Stan Licznika', style: boldTop),
      Cell(5, 2, 'Minuty\npracy', style: bold),
      Cell(5, 3, 'Stan Licznika', style: boldTop),
      Cell(5, 4, 'Zużycie\npaliwa', style: bold),
    ], style: plain);
    // Ostatni wiersz tylko pod trzema pierwszymi kolumnami, jak na papierze.
    p.table(x, 53.75, [cols[0] + cols[1], cols[2]], const [5], const []);

    p.text(x, 62, 124.5, 6, 'ROZLICZANIE MATERIAŁÓW PĘDNYCH',
        const CardText(size: 11, bold: true, align: CardAlign.center));

    const fuelCol = 124.5 / 6;
    p.table(x, 73.5, const [fuelCol, fuelCol, fuelCol, fuelCol, fuelCol, fuelCol],
        const [4.5, 5, 5.25, 5.25, 5.25, 5.25, 5.25], const [
      Cell(0, 0, 'POBRANO W LITRACH', cs: 4,
          style: CardText(size: 9.5, align: CardAlign.center)),
      Cell(0, 4, 'Podpis\nmechanika', rs: 2, style: center),
      Cell(0, 5, 'Podpis\nmagazyn.', rs: 2, style: center),
      Cell(1, 0, 'Dnia', style: center),
      Cell(1, 1, 'Nr kwitu', style: center),
      Cell(1, 2, 'paliwa', style: center),
      Cell(1, 3, 'oleju', style: center),
    ]);
    // „Razem" tylko pod czterema kolumnami litrów, bez rubryk podpisów.
    p.table(x, 109.25, const [fuelCol * 2, fuelCol, fuelCol], const [6], const [
      Cell(0, 0, 'Razem', style: plain),
    ]);

    // Litry w kolumnie paliwa urządzenia (ET albo ON); bez rodzaju paliwa
    // albo normy — puste, do wpisania ręcznie. Czas rozruchów nie ma na
    // papierze swojej rubryki — tylko litry w pozycji 6.
    final totals = EquipmentCard.totals(device, rows);
    final column = device.settlementColumn;
    List<Cell> litres(int r, double? fuel, int minutes) => [
          for (final (c, col) in [(3, 'ET'), (4, 'ON')])
            if (fuel != null && minutes > 0 && column == col)
              Cell(r, c, PdfOutput.number(fuel), style: center),
        ];
    final work = totals.workMinutes;
    final all = totals.workMinutes + totals.startupMinutes;
    p.table(x, 123, const [45.5, 16, 21.5, 21, 20.5],
        const [4.75, 4.5, 4.5, 4.5, 4.5, 4.5, 4.5, 5.25], [
      // Wiersz nagłówka bez pionowych linii — „ET" i „ON" nad kolumnami.
      const Cell(0, 0, 'LITRÓW :', cs: 3, open: 'r'),
      const Cell(0, 3, 'ET', style: center, open: 'lr'),
      const Cell(0, 4, 'ON', style: center, open: 'l'),
      const Cell(1, 0, '1. pozostało z ubiegłego mies.', cs: 3),
      const Cell(2, 0, '2. pobrano w mies. bieżącym', cs: 3),
      const Cell(3, 0, '3. Razem', cs: 3),
      // Pozycje 4 i 5 w jednym wierszu: czas pracy w okienku, litry z prawej.
      const Cell(4, 0, '4. Przepracowano godz. i min.'),
      Cell(4, 1, work == 0 ? '' : EquipmentCard.hoursAndMinutes(work),
          style: center, fit: true),
      const Cell(4, 2, '5.  zużyto'),
      ...litres(4, totals.workFuel, work),
      const Cell(5, 0, '6. zużyto na rozruchy i kontrole', cs: 3),
      ...litres(5, totals.startupFuel, totals.startupMinutes),
      const Cell(6, 0, '7. zużyto w ciągu mies. Razem', cs: 3),
      ...litres(6, totals.totalFuel, all),
      const Cell(7, 0, '8 POZOSTAŁO NA MIESIĄC NASTĘPNY', cs: 3),
    ], style: plain);

    const sign = CardText(size: 9.5);
    p.text(x + 1, 170, 15, 5, 'Obliczył', sign);
    p.text(x + 16, 170, 97, 5, TripCard.dots(97), sign, true);
    p.text(x + 1, 178.5, 18, 5, 'Sprawdził', sign);
    p.text(x + 19, 178.5, 94, 5, TripCard.dots(94), sign, true);
  }
}
