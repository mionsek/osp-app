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

  static void _back(
      CardPage p, double ox, (Equipment, List<EquipmentCardRow>) card) {
    final (device, rows) = card;
    final x = ox + 12;
    const center = CardText(size: 9, align: CardAlign.center);
    p.table(x, 14, const [19, 30, 22, 30, 23.5], const [8, 7, 7], const [
      Cell(0, 0, 'Data', style: center),
      Cell(0, 1, 'Stan licznika', style: center),
      Cell(0, 2, 'Minuty pracy', style: center),
      Cell(0, 3, 'Stan licznika', style: center),
      Cell(0, 4, 'Zużycie paliwa', style: center),
    ]);
    p.text(x, 40, 124.5, 6, 'ROZLICZANIE MATERIAŁÓW PĘDNYCH',
        const CardText(size: 11, bold: true, align: CardAlign.center));
    p.text(x, 50, 60, 5, 'Pobrano w litrach',
        const CardText(size: 9.5, bold: true));
    p.table(x, 55.5, const [18, 22, 18, 18, 24, 24.5],
        const [8, 6, 6, 6, 6, 6, 6.5], const [
      Cell(0, 0, 'Dnia', style: center),
      Cell(0, 1, 'Nr kwitu', style: center),
      Cell(0, 2, 'paliwa', style: center),
      Cell(0, 3, 'oleju', style: center),
      Cell(0, 4, 'Podpis\nmechanika', style: center),
      Cell(0, 5, 'Podpis\nmagazyn.', style: center),
      Cell(6, 0, 'Razem', style: CardText(size: 9.5, bold: true)),
    ]);

    // Litry w kolumnie paliwa urządzenia (ET albo ON); bez rodzaju paliwa
    // albo normy — puste, do wpisania ręcznie.
    final totals = EquipmentCard.totals(device, rows);
    final column = device.settlementColumn;
    const value = CardText(size: 9.5, align: CardAlign.center);
    List<Cell> litres(int r, double? fuel, int minutes, {bool bold = false}) => [
          for (final (c, col) in [(2, 'ET'), (3, 'ON')])
            if (fuel != null && minutes > 0 && column == col)
              Cell(r, c, PdfOutput.number(fuel),
                  style: value.copyWith(bold: bold)),
        ];
    String time(int minutes) =>
        minutes == 0 ? '' : EquipmentCard.hoursAndMinutes(minutes);
    const strong = CardText(size: 9.5, bold: true);
    final all = totals.workMinutes + totals.startupMinutes;
    p.table(x, 106, const [70, 20.5, 17, 17],
        [for (var i = 0; i < 9; i++) 6.5], [
      const Cell(0, 0, 'LITRÓW:', style: strong),
      const Cell(0, 2, 'ET', style: value),
      const Cell(0, 3, 'ON', style: value),
      const Cell(1, 0, '1. pozostało z ubiegłego mies.'),
      const Cell(2, 0, '2. pobrano w mies. bieżącym'),
      const Cell(3, 0, '3. Razem'),
      const Cell(4, 0, '4. Przepracowano godz. i min.'),
      Cell(4, 1, time(totals.workMinutes), style: value, fit: true),
      const Cell(5, 0, '5. zużyto'),
      ...litres(5, totals.workFuel, totals.workMinutes),
      const Cell(6, 0, '6. zużyto na rozruchy i kontrole'),
      Cell(6, 1, time(totals.startupMinutes), style: value, fit: true),
      ...litres(6, totals.startupFuel, totals.startupMinutes),
      const Cell(7, 0, '7. zużyto w ciągu mies. Razem', style: strong),
      ...litres(7, totals.totalFuel, all, bold: true),
      const Cell(8, 0, '8. POZOSTAŁO NA MIESIĄC NASTĘPNY', style: strong),
    ], style: const CardText(size: 9.5));

    const sign = CardText(size: 9.5);
    const hint = CardText(size: 7.5, align: CardAlign.center);
    p.text(x + 5, 172, 40, 5, 'Obliczył', sign);
    p.text(x + 5, 177, 100, 4, TripCard.dots(100), sign, true);
    p.text(x + 5, 181, 100, 3.5, '(imię i nazwisko)', hint);
    p.text(x + 5, 187, 18, 5, 'Sprawdził', sign);
    p.text(x + 23, 187.5, 100, 4, TripCard.dots(100), sign, true);
    p.text(x + 23, 192, 100, 3.5, '(imię i nazwisko, podpis, data)', hint);
  }
}
