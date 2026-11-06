import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../core/utils/file_names.dart';
import '../core/utils/polish_text.dart';
import '../models/models.dart';
import 'equipment_card.dart';
import 'equipment_card_pdf.dart';
import 'xlsx_writer.dart';

/// Karta pracy sprzętu silnikowego w Excelu — z tego samego powodu co karta
/// drogowa ([TripCardXlsx]): żeby przed wysłaniem dało się poprawić minuty
/// albo paliwo na komputerze.
///
/// Układ jak na wydruku ([EquipmentCardPdf]), rozliczenie na formułach.
/// Kolumna pomocnicza „Rozruch" (poza wydrukiem) mówi, które minuty idą do
/// pozycji 6 zamiast 4 — dopisany w Excelu wiersz z „tak" liczy się jako
/// rozruch kontrolny.
class EquipmentCardXlsx {
  EquipmentCardXlsx._();

  static String fileName(Equipment e, int year, int month) =>
      'karta_pracy_${FileNames.sanitize(e.name)}_'
      '${FileNames.yearMonth(year, month)}.xlsx';

  static const int _columns = 6;
  static const int _startupColumn = 6;
  static const String _startupMark = 'tak';

  static Uint8List bytes({
    required Equipment device,
    required List<EquipmentCardRow> rows,
    required UnitConfig config,
    required int year,
    required int month,
  }) {
    final book = XlsxWorkbook();
    final s = book.addSheet('Karta pracy')..printColumns = _columns;
    const List<double> widths = [8, 24, 12, 18, 12, 14, 11];
    for (var c = 0; c < widths.length; c++) {
      s.width(c, widths[c]);
    }

    const text = XlsxStyle(size: 10);
    const box = XlsxStyle(size: 10, border: true);
    final boxBold = box.copyWith(bold: true);
    final center = box.copyWith(align: XlsxAlign.center);
    final number = box.copyWith(align: XlsxAlign.right);
    final litres = number.copyWith(numberFormat: '0.00');
    final header = box.copyWith(
        bold: true, shaded: true, wrap: true, align: XlsxAlign.center, size: 9);
    final small = text.copyWith(size: 8, italic: true);
    final title =
        text.copyWith(bold: true, size: 13, align: XlsxAlign.center);
    String abs(int r, int c) => '\$${XlsxWorkbook.column(c)}\$${r + 1}';

    // ══ PRZÓD: dane urządzenia ═════════════════════════════════════════
    s.set(0, 0, 'Jednostka', text);
    s.merge(0, 1, 0, 5, config.fullName, text.copyWith(bold: true));
    s.merge(2, 0, 2, 5, 'MIESIĘCZNA KARTA PRACY', title);
    s.merge(3, 0, 3, 5, 'SPRZĘTU SILNIKOWEGO', title);
    s.merge(4, 0, 4, 5, 'Na miesiąc  ${PolishText.monthLabel(month, year)}',
        text.copyWith(align: XlsxAlign.center));

    s.set(6, 0, 'Marka', box);
    s.set(6, 1, device.brand, boxBold);
    s.set(6, 2, 'Model', box);
    s.merge(6, 3, 6, 5, device.model, boxBold);
    s.set(7, 0, 'Rodzaj', box);
    s.set(7, 1, device.name, boxBold);
    s.set(7, 2, 'Stan licznika', box);
    s.merge(7, 3, 7, 5, null, box);
    s.merge(8, 0, 8, 1, 'Norma eksploatacyjna na 1 godz. pracy (litrów)',
        box.copyWith(wrap: true));
    s.height(8, 28);
    s.set(8, 2, device.fuelPerHour, number.copyWith(bold: true));
    s.set(8, 3, 'Rodzaj paliwa', box);
    s.merge(8, 4, 8, 5, device.fuelType, boxBold);
    final norm = abs(8, 2);

    // ══ TABELA PRACY ═══════════════════════════════════════════════════
    const head = 10;
    s.set(head, 0, 'Data', header);
    s.set(head, 1, 'Nazwisko i imię obsługującego', header);
    s.set(head, 2, 'Minut pracy', header);
    s.merge(head, 3, head, 4, 'Cel użycia', header);
    s.set(head, 5, 'Podpis dysponenta', header);
    s.set(head, _startupColumn, 'Rozruch\n(nie drukuje się)',
        header.copyWith(italic: true));
    s.height(head, 30);

    final first = head + 1;
    var r = first;
    void line(EquipmentCardRow? row) {
      s.set(r, 0, row == null ? null : DateFormat('dd.MM').format(row.date),
          center);
      s.set(r, 1, row?.operatorName, box);
      s.set(r, 2, row?.minutes, center);
      s.merge(r, 3, r, 4, row?.purpose, box);
      s.set(r, 5, null, box);
      s.set(r, _startupColumn, row != null && row.isStartup ? _startupMark : null,
          center);
      r++;
    }

    rows.forEach(line);
    while (r - first < EquipmentCardPdf.minRows) {
      line(null);
    }
    final minutes = '${abs(first, 2)}:${abs(r - 1, 2)}';
    final marks = '${abs(first, _startupColumn)}:${abs(r - 1, _startupColumn)}';

    // ══ TYŁ: licznik i rozliczenie ═════════════════════════════════════
    var y = r + 1;
    s.pageBreakBefore(y);
    s.set(y, 0, 'Data', header);
    s.set(y, 1, 'Stan licznika', header);
    s.set(y, 2, 'Minuty pracy', header);
    s.merge(y, 3, y, 4, 'Stan licznika', header);
    s.set(y, 5, 'Zużycie paliwa', header);
    for (var i = 1; i <= 2; i++) {
      for (var c = 0; c < _columns; c++) {
        s.set(y + i, c, null, box);
      }
      s.merge(y + i, 3, y + i, 4, null, box);
    }
    y += 4;
    s.merge(y, 0, y, 5, 'ROZLICZANIE MATERIAŁÓW PĘDNYCH',
        title.copyWith(size: 11));
    y += 2;

    // ── Pobrano w litrach ────────────────────────────────────────────
    s.merge(y, 0, y, 2, 'Pobrano w litrach', text.copyWith(bold: true));
    y++;
    const intakeHeaders = [
      'Dnia', 'Nr kwitu', 'paliwa', 'oleju', 'Podpis mechanika',
      'Podpis magazyn.',
    ];
    for (var c = 0; c < intakeHeaders.length; c++) {
      s.set(y, c, intakeHeaders[c], header);
    }
    y++;
    final intakeFirst = y;
    for (var i = 0; i < EquipmentCardPdf.fuelIntakeRows; i++, y++) {
      for (var c = 0; c < _columns; c++) {
        s.set(y, c, null, c == 2 || c == 3 ? litres : box);
      }
    }
    String sumIfAny(String range) => 'IF(COUNT($range)=0,"",SUM($range))';
    final fuelIn = '${abs(intakeFirst, 2)}:${abs(y - 1, 2)}';
    final oilIn = '${abs(intakeFirst, 3)}:${abs(y - 1, 3)}';
    final intakeTotal = abs(y, 2);
    s.set(y, 0, 'Razem', boxBold);
    s.set(y, 1, null, box);
    s.set(y, 2, XlsxFormula(sumIfAny(fuelIn), ''), litres.copyWith(bold: true));
    s.set(y, 3, XlsxFormula(sumIfAny(oilIn), ''), litres.copyWith(bold: true));
    s.set(y, 4, null, box);
    s.set(y, 5, null, box);
    y += 2;

    // ── Rozliczenie: pozycja (A:B) | ilość (C:D) | ET (E) | ON (F) ──────
    s.merge(y, 0, y, 1, 'LITRÓW:', boxBold);
    s.merge(y, 2, y, 3, null, box);
    s.set(y, 4, 'ET', header);
    s.set(y, 5, 'ON', header);
    y++;
    final p1 = y;
    int row(int no) => p1 + no - 1;
    String amount(int no) => abs(row(no), 2);

    // Litry trafiają do kolumny paliwa urządzenia; bez rodzaju paliwa obie
    // zostają puste, jak na wydruku.
    final column = device.settlementColumn;
    String fuelAt(int no, String col) => abs(row(no), col == 'ET' ? 4 : 5);

    final totals = EquipmentCard.totals(device, rows);
    void settle(int no, String label,
        {Object? qty,
        Object? Function(String col)? fuel,
        bool bold = false}) {
      final yy = row(no);
      s.merge(yy, 0, yy, 1, label, bold ? boxBold : box);
      s.merge(yy, 2, yy, 3, qty,
          number.copyWith(numberFormat: '[h]" godz. "mm" min"'));
      for (final (c, col) in [(4, 'ET'), (5, 'ON')]) {
        s.set(yy, c, fuel?.call(col), litres.copyWith(bold: bold));
      }
    }

    Object? onlyDeviceColumn(String col, Object? value) =>
        col == column ? value : null;

    // Minuty jako ułamek doby — Excel pokaże „1 godz. 35 min" jak wydruk.
    XlsxFormula time(String sumExpr, int cachedMinutes) => XlsxFormula(
        'IF($sumExpr=0,"",$sumExpr/1440)',
        cachedMinutes == 0 ? '' : cachedMinutes / 1440);
    XlsxFormula used(int no, double? cached) => XlsxFormula(
        'IF(AND(ISNUMBER(${amount(no)}),ISNUMBER($norm)),'
        '${amount(no)}*24*$norm,"")',
        cached ?? '');

    settle(1, '1. pozostało z ubiegłego mies.');
    settle(2, '2. pobrano w mies. bieżącym',
        fuel: (col) => onlyDeviceColumn(col,
            XlsxFormula('IF(ISNUMBER($intakeTotal),$intakeTotal,"")', '')));
    settle(3, '3. Razem',
        fuel: (col) => XlsxFormula(
            'IF(COUNT(${fuelAt(1, col)},${fuelAt(2, col)})=0,"",'
            'SUM(${fuelAt(1, col)},${fuelAt(2, col)}))',
            ''));
    settle(4, '4. Przepracowano godz. i min.',
        qty: time('SUMIF($marks,"<>$_startupMark",$minutes)',
            totals.workMinutes));
    // Litry pozycji 5 liczą się z ilości pozycji 4; pozycja 6 ma ilość
    // i litry w jednym wierszu — jak na druku.
    settle(5, '5. zużyto',
        fuel: (col) => onlyDeviceColumn(
            col,
            used(4, totals.workMinutes == 0 ? null : totals.workFuel)));
    settle(6, '6. zużyto na rozruchy i kontrole',
        qty: time('SUMIF($marks,"$_startupMark",$minutes)',
            totals.startupMinutes),
        fuel: (col) => onlyDeviceColumn(
            col,
            used(6, totals.startupMinutes == 0 ? null : totals.startupFuel)));
    final allMinutes = totals.workMinutes + totals.startupMinutes;
    settle(7, '7. zużyto w ciągu mies. Razem',
        bold: true,
        fuel: (col) => onlyDeviceColumn(
            col,
            XlsxFormula(sumIfAny('${fuelAt(5, col)},${fuelAt(6, col)}'),
                allMinutes == 0 ? '' : (totals.totalFuel ?? ''))));
    settle(8, '8. POZOSTAŁO NA MIESIĄC NASTĘPNY',
        bold: true,
        fuel: (col) => XlsxFormula(
            'IF(AND(ISNUMBER(${fuelAt(3, col)}),ISNUMBER(${fuelAt(7, col)})),'
            '${fuelAt(3, col)}-${fuelAt(7, col)},"")',
            ''));

    // ── Podpisy ─────────────────────────────────────────────────────────
    y = row(8) + 3;
    final sign = small.copyWith(align: XlsxAlign.center, wrap: true);
    s.merge(y, 0, y, 1,
        '.......................................................\n'
        '(imię i nazwisko)', sign);
    s.merge(y, 3, y, 5,
        '.......................................................\n'
        '(imię i nazwisko, podpis, data)', sign);
    s.height(y, 28);
    final bold = text.copyWith(bold: true, align: XlsxAlign.center);
    s.merge(y + 1, 0, y + 1, 1, 'Obliczył', bold);
    s.merge(y + 1, 3, y + 1, 5, 'Sprawdził', bold);

    return book.save();
  }
}
