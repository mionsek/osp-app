import 'dart:typed_data';

import '../core/utils/file_names.dart';
import '../core/utils/polish_text.dart';
import '../models/models.dart';
import 'equipment_usage.dart';
import 'trip_card_pdf.dart';
import 'xlsx_writer.dart';

/// Karta drogowa w Excelu — do poprawienia na komputerze przed wysłaniem.
///
/// Prośba Dawida z 6.11.2026: kartę trzeba czasem wysłać do gminy albo
/// poprawić przed wysłaniem, „bo paliwo się nie zgadza", choć w aplikacji
/// wszystko jest dobrze. Dlatego układ i treść są te same co na wydruku
/// ([TripCardPdf] — te same wiersze z [TripCardPdf.tripRowTexts]), ale
/// rozliczenie paliwa to **formuły**: poprawiony licznik, minuty sprzętu,
/// postój albo norma przeliczają kilometry i litry same.
///
/// Rozliczenie liczy też to, czego wydruk nie liczy, bo nie zna danych
/// wejściowych: pozycję 2 z tabeli „Pobrano", pozycję 3 (1 + 2) i 11
/// (3 − 9). Dopóki nikt nie wpisze stanu z poprzedniego miesiąca ani
/// pobranego paliwa, zostają puste — jak na wydruku.
class TripCardXlsx {
  TripCardXlsx._();

  static String fileName(Vehicle v, int year, int month) =>
      'karta_drogowa_${FileNames.sanitize(v.name)}_'
      '${FileNames.yearMonth(year, month)}.xlsx';

  /// Kolumny tabeli przejazdów — jak na karcie, plus kolumna pomocnicza
  /// z kilometrami, która się nie drukuje.
  static const int _columns = 14;
  static const int _kmColumn = 14;

  // Kolumny tabeli przejazdów, od zera.
  static const int _odometerStart = 7;
  static const int _odometerEnd = 9;
  static const int _equipmentMinutes = 10;
  static const int _idleMinutes = 12;

  /// Kolumny z liczbami — w arkuszu liczby, nie tekst, żeby dało się je
  /// sumować i poprawiać.
  static const Set<int> _numeric = {0, 7, 9, 10, 12};

  /// Wyrównanie jak na wydruku: Lp., data, godziny i minuty na środku,
  /// liczniki do prawej, teksty do lewej.
  static XlsxStyle _cellStyle(int c, XlsxStyle box) => switch (c) {
        0 || 1 || 6 || 8 || 10 || 12 => box.copyWith(align: XlsxAlign.center),
        7 || 9 => box.copyWith(align: XlsxAlign.right),
        _ => box,
      };

  static Uint8List bytes({
    required List<VehicleTrip> trips,
    required Vehicle vehicle,
    required UnitConfig config,
    required int year,
    required int month,
    List<Equipment> equipment = const [],
    Report? Function(String reportId)? reportOf,
  }) {
    final book = XlsxWorkbook();
    final s = book.addSheet('Karta drogowa')
      ..landscape = true
      ..printColumns = _columns;

    const List<double> widths = [
      4.5, 7, 16, 20, 11, 16, 7.5, 9, 7.5, 9, 13, 9, 9, 12, 11,
    ];
    for (var c = 0; c < widths.length; c++) {
      s.width(c, widths[c]);
    }

    const text = XlsxStyle(size: 9);
    const box = XlsxStyle(size: 9, border: true);
    final boxBold = box.copyWith(bold: true);
    final number = box.copyWith(align: XlsxAlign.right);
    final litres = number.copyWith(numberFormat: '0.00');
    final header = box.copyWith(
        bold: true, shaded: true, wrap: true, align: XlsxAlign.center, size: 8);
    final small = text.copyWith(size: 7.5, italic: true);
    String abs(int r, int c) =>
        '\$${XlsxWorkbook.column(c)}\$${r + 1}';
    String at(int r, int c) => XlsxWorkbook.ref(r, c);

    // ══ NAGŁÓWEK ═══════════════════════════════════════════════════════
    s.merge(0, 0, 0, 3, config.fullName, text.copyWith(bold: true, size: 11));
    s.merge(1, 0, 1, 3, 'Jednostka  m.p.', text.copyWith(size: 8));
    final title = text.copyWith(bold: true, align: XlsxAlign.center);
    s.merge(0, 4, 0, 11, 'MIESIĘCZNA KARTA DROGOWA', title.copyWith(size: 13));
    s.merge(1, 4, 1, 11, 'POŻARNICZEGO POJAZDU SAMOCHODOWEGO',
        title.copyWith(size: 11));
    s.merge(2, 4, 2, 11, 'na miesiąc  ${PolishText.monthLabel(month, year)}',
        text.copyWith(align: XlsxAlign.center));

    // ── Dane pojazdu i normy ─────────────────────────────────────────
    // Normy jako liczby w osobnych komórkach — formuły rozliczenia biorą je
    // stąd, więc poprawiona norma przelicza litry.
    void info(int r, String l1, Object? v1, String l2, Object? v2) {
      s.merge(r, 0, r, 2, l1, box);
      s.merge(r, 3, r, 5, v1, v1 is num ? number.copyWith(bold: true) : boxBold);
      s.merge(r, 6, r, 9, l2, box);
      s.merge(r, 10, r, 13, v2, v2 is num ? number.copyWith(bold: true) : boxBold);
    }

    const info0 = 4;
    info(info0, 'Marka', vehicle.make, 'Model', vehicle.model);
    info(info0 + 1, 'Typ', vehicle.kind, 'Nr rej.', vehicle.plate);
    info(info0 + 2, 'Numer operacyjny', vehicle.operationalNumber,
        'Rodzaj paliwa', vehicle.fuelType);
    info(info0 + 3, 'Norma zużycia paliwa na 100 km (l)', vehicle.fuelPer100Km,
        'Norma zużycia paliwa autopompy (l/godz.)', vehicle.pumpFuelPerHour);
    info(info0 + 4, 'Praca na postoju silnika (l/min)',
        vehicle.idleFuelPerMinute, 'Rozruch silnika (l/m-c)',
        vehicle.startupFuelPerMonth);
    info(info0 + 5, 'Stan autopompy na początek miesiąca', null,
        'Stan autopompy na koniec miesiąca', null);
    final normKm = abs(info0 + 3, 3);
    final normPump = abs(info0 + 3, 10);
    final normIdle = abs(info0 + 4, 3);
    final normStartup = abs(info0 + 4, 10);

    s.merge(11, 0, 11, 13,
        'ZAPISY DOTYCZĄCE OBSŁUG TECHNICZNYCH I TP. '
        '(remontu, zakupu, wymiany podzespołów)',
        text.copyWith(bold: true, size: 8));
    s.merge(12, 0, 12, 13, null, box);
    s.height(12, 30);
    s.merge(13, 8, 13, 13,
        '.......................................................\n'
        '(miejscowość, data i podpis osoby wydającej kartę)',
        small.copyWith(align: XlsxAlign.center, wrap: true));
    s.height(13, 26);

    // ══ TABELA PRZEJAZDÓW ══════════════════════════════════════════════
    const head = 15;
    const headers = [
      'Lp.',
      'Data',
      'Nazwisko dysponenta',
      'Trasy jazdy\nSkąd - dokąd',
      'Cel jazdy',
      'Nazwisko kierowcy',
      'Odjazdy\nGodz.Min.',
      'Odjazdy\nStan licznika',
      'Przyjazdy\nGodz.Min.',
      'Przyjazdy\nStan licznika',
      'Minuty pracy\nurządzeń\nspecjalistycznych',
      'Dodatki*',
      'Praca silnika na postoju min.',
      'Podpis dysponenta',
      'Przebyto km\n(nie drukuje się)',
    ];
    for (var c = 0; c < headers.length; c++) {
      s.set(head, c, headers[c],
          c == _kmColumn ? header.copyWith(italic: true) : header);
    }
    s.height(head, 48);

    final first = head + 1;
    var r = first;
    var totalKm = 0;
    var equipmentTotal = 0;
    var idleTotal = 0;
    for (var i = 0; i < trips.length; i++) {
      final t = trips[i];
      final minutes = EquipmentUsage.vehicleCardMinutes(t, equipment);
      final rows = TripCardPdf.tripRowTexts(
        t,
        i + 1,
        equipmentMinutes: minutes,
        stationAddress: config.stationAddress,
        report: t.reportId == null ? null : reportOf?.call(t.reportId!),
      );
      for (var k = 0; k < rows.length; k++) {
        for (var c = 0; c < _columns; c++) {
          final v = rows[k][c];
          final n = _numeric.contains(c) ? int.tryParse(v) : null;
          s.set(r + k, c, n ?? v, _cellStyle(c, box));
        }
      }
      // Kilometry przejazdu: licznik po powrocie (drugi wiersz) minus licznik
      // przed wyjazdem (pierwszy) — jak [VehicleTrip.distance] na wydruku.
      final d = t.distance;
      if (d != null && d > 0) totalKm += d;
      final start = at(r, _odometerStart);
      final end = at(r + rows.length - 1, _odometerEnd);
      s.set(
        r,
        _kmColumn,
        XlsxFormula('IF(AND(ISNUMBER($start),ISNUMBER($end)),'
            'MAX(0,$end-$start),"")', d == null ? '' : (d > 0 ? d : 0)),
        number,
      );
      for (var k = 1; k < rows.length; k++) {
        s.set(r + k, _kmColumn, null, number);
      }
      equipmentTotal += minutes;
      idleTotal += t.idleMinutes ?? 0;
      r += rows.length;
    }
    // Puste wiersze do dopisania długopisem — albo w Excelu.
    while (r - first < TripCardPdf.minRows) {
      for (var c = 0; c <= _kmColumn; c++) {
        s.set(r, c, null, c == _kmColumn ? number : _cellStyle(c, box));
      }
      r++;
    }
    final last = r - 1;
    String column(int c) => '${abs(first, c)}:${abs(last, c)}';
    s.set(r, 0, '* np. dodatek zimowy', small);

    // ══ ROZLICZENIE MATERIAŁÓW PĘDNYCH — odwrót kartki ═════════════════
    var y = r + 2;
    s.pageBreakBefore(y);
    s.merge(y, 0, y, 13, 'ROZLICZENIE MATERIAŁÓW PĘDNYCH',
        text.copyWith(bold: true, size: 11));
    y += 2;

    // ── Pobrano (w litrach) — z kwitów, aplikacja tego nie zna ──────────
    s.merge(y, 0, y, 5, 'Pobrano (w litrach)', text.copyWith(bold: true));
    y++;
    s.merge(y, 0, y, 1, 'dnia', header);
    s.set(y, 2, 'Stan licznika', header);
    s.set(y, 3, 'ON', header);
    s.set(y, 4, 'ET', header);
    s.merge(y, 5, y, 7, 'Podpis kierowcy', header);
    s.merge(y, 8, y, 11, 'Podpis magazyniera', header);
    y++;
    final intakeFirst = y;
    for (var i = 0; i < TripCardPdf.fuelIntakeRows; i++, y++) {
      s.merge(y, 0, y, 1, null, box);
      s.set(y, 2, null, number);
      s.set(y, 3, null, litres);
      s.set(y, 4, null, litres);
      s.merge(y, 5, y, 7, null, box);
      s.merge(y, 8, y, 11, null, box);
    }
    String sumIfAny(String range) => 'IF(COUNT($range)=0,"",SUM($range))';
    final intakeOn = '${abs(intakeFirst, 3)}:${abs(y - 1, 3)}';
    final intakeEt = '${abs(intakeFirst, 4)}:${abs(y - 1, 4)}';
    final intakeTotal = y;
    s.merge(y, 0, y, 2, 'Ogółem', boxBold);
    s.set(y, 3, XlsxFormula(sumIfAny(intakeOn), ''), litres.copyWith(bold: true));
    s.set(y, 4, XlsxFormula(sumIfAny(intakeEt), ''), litres.copyWith(bold: true));
    s.merge(y, 5, y, 7, null, box);
    s.merge(y, 8, y, 11, null, box);
    y += 2;

    // ── 12 pozycji rozliczenia ───────────────────────────────────────
    // Lp. | pozycja (B:E) | Ilość (F) | ON (G:H) | ET (I:J)
    s.set(y, 0, null, header);
    s.merge(y, 1, y, 4, null, header);
    s.set(y, 5, 'Ilość', header);
    s.merge(y, 6, y, 7, 'ON', header);
    s.merge(y, 8, y, 9, 'ET', header);
    y++;
    final p1 = y; // pozycja n jest w wierszu p1 + n - 1
    int row(int no) => p1 + no - 1;
    String on(int no) => abs(row(no), 6);
    String et(int no) => abs(row(no), 8);
    String amount(int no) => abs(row(no), 5);

    void settle(int no, String label,
        {Object? qty, String? qtyFormat, Object? onValue, Object? etValue,
        bool bold = false}) {
      final yy = row(no);
      s.set(yy, 0, '$no.', box.copyWith(align: XlsxAlign.center, bold: bold));
      s.merge(yy, 1, yy, 4, label, bold ? boxBold : box);
      s.set(yy, 5, qty, number.copyWith(numberFormat: qtyFormat));
      s.merge(yy, 6, yy, 7, onValue, litres.copyWith(bold: bold));
      s.merge(yy, 8, yy, 9, etValue, litres.copyWith(bold: bold));
    }

    // Te same wyliczenia co na wydruku — wartości do podglądu bez Excela.
    final kmFuel = vehicle.fuelPer100Km == null
        ? null
        : totalKm * vehicle.fuelPer100Km! / 100;
    final hours = equipmentTotal / 60.0;
    final pumpFuel = vehicle.pumpFuelPerHour == null || equipmentTotal == 0
        ? null
        : hours * vehicle.pumpFuelPerHour!;
    final idleFuel = vehicle.idleFuelPerMinute == null || idleTotal == 0
        ? null
        : idleTotal * vehicle.idleFuelPerMinute!;
    final startupFuel = vehicle.startupFuelPerMonth;
    final known = [kmFuel, pumpFuel, idleFuel, startupFuel].whereType<double>();
    final totalFuel = known.isEmpty ? null : known.reduce((a, b) => a + b);

    settle(1, 'Pozostało z ubiegłego miesiąca');
    settle(2, 'Pobrano w ciągu miesiąca bieżącego',
        onValue: XlsxFormula(
            'IF(ISNUMBER(${abs(intakeTotal, 3)}),${abs(intakeTotal, 3)},"")', ''),
        etValue: XlsxFormula(
            'IF(ISNUMBER(${abs(intakeTotal, 4)}),${abs(intakeTotal, 4)},"")', ''));
    settle(3, 'razem',
        onValue: XlsxFormula(
            'IF(COUNT(${on(1)},${on(2)})=0,"",SUM(${on(1)},${on(2)}))', ''),
        etValue: XlsxFormula(
            'IF(COUNT(${et(1)},${et(2)})=0,"",SUM(${et(1)},${et(2)}))', ''));
    settle(4, 'Przebyto km',
        qty: XlsxFormula('SUM(${column(_kmColumn)})', totalKm),
        qtyFormat: '0" km"',
        onValue: XlsxFormula(
            'IF(ISNUMBER($normKm),${amount(4)}*$normKm/100,"")', kmFuel ?? ''));
    settle(5, 'Przepracowano godz. urządzeń',
        qty: XlsxFormula(
            'IF(SUM(${column(_equipmentMinutes)})=0,"",'
            'SUM(${column(_equipmentMinutes)})/60)',
            equipmentTotal == 0 ? '' : hours),
        qtyFormat: '0.00" godz."',
        onValue: XlsxFormula(
            'IF(AND(ISNUMBER(${amount(5)}),ISNUMBER($normPump)),'
            '${amount(5)}*$normPump,"")',
            pumpFuel ?? ''));
    settle(6, 'Dodatek zimowy');
    settle(7, 'Praca na postoju',
        qty: XlsxFormula(
            'IF(SUM(${column(_idleMinutes)})=0,"",SUM(${column(_idleMinutes)}))',
            idleTotal == 0 ? '' : idleTotal),
        qtyFormat: '0" min"',
        onValue: XlsxFormula(
            'IF(AND(ISNUMBER(${amount(7)}),ISNUMBER($normIdle)),'
            '${amount(7)}*$normIdle,"")',
            idleFuel ?? ''));
    settle(8, 'Wyk. rozruch.',
        onValue: XlsxFormula(
            'IF(ISNUMBER($normStartup),$normStartup,"")', startupFuel ?? ''));
    // Razem z dodatkiem zimowym, jeśli ktoś go wpisze — wydruk go nie zna.
    settle(9, 'Zużyto paliwa w ciągu miesiąca razem',
        bold: true,
        onValue: XlsxFormula(
            sumIfAny('${on(4)}:${abs(row(8), 6)}'), totalFuel ?? ''),
        etValue: XlsxFormula(sumIfAny('${et(4)}:${abs(row(8), 8)}'), ''));
    settle(10, 'Przysługuje wg norm wraz z dodat.');
    settle(11, 'Pozostało na miesiąc następny',
        onValue: XlsxFormula(
            'IF(AND(ISNUMBER(${on(3)}),ISNUMBER(${on(9)})),${on(3)}-${on(9)},"")',
            ''),
        etValue: XlsxFormula(
            'IF(AND(ISNUMBER(${et(3)}),ISNUMBER(${et(9)})),${et(3)}-${et(9)},"")',
            ''));
    settle(12, 'Oszczędzono - przechowano');

    // ── Podpisy ─────────────────────────────────────────────────────────
    y = row(12) + 3;
    final sign = small.copyWith(align: XlsxAlign.center, wrap: true);
    s.merge(y, 1, y, 5,
        '.......................................................\n'
        '(imię i nazwisko)', sign);
    s.merge(y, 8, y, 13,
        '.......................................................\n'
        '(imię i nazwisko, podpis, data)', sign);
    s.height(y, 26);
    final bold = text.copyWith(bold: true, align: XlsxAlign.center);
    s.merge(y + 1, 1, y + 1, 5, 'Obliczył', bold);
    s.merge(y + 1, 8, y + 1, 13, 'Sprawdził', bold);

    return book.save();
  }
}
