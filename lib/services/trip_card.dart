import 'package:intl/intl.dart';

import '../core/utils/polish_text.dart';
import '../core/utils/time_format.dart';
import '../models/models.dart';
import 'card_sheet.dart';
import 'equipment_usage.dart';
import 'pdf_output.dart';
import 'trip_labels.dart';

/// Miesięczna karta drogowa pożarniczego pojazdu samochodowego — odwzorowana
/// ze zdjęć kart OSP Kielno (Dawid, 9.11.2026): kartka A4 składana na pół.
///
/// Strona zewnętrzna: z lewej rozliczenie materiałów pędnych (tył okładki),
/// z prawej okładka z danymi pojazdu. Strona wewnętrzna: tabela przejazdów
/// na całą szerokość, 24 wiersze — dwa na przejazd (wyjazd i „Powrót"),
/// bez kolumny „Lp.", której papier nie ma. Więcej przejazdów — kolejne
/// strony wewnętrzne.
///
/// **Zasada wypełniania:** wpisujemy tylko to, co aplikacja naprawdę wie.
/// Pobrane paliwo, stany z poprzedniego miesiąca i dodatek zimowy zostają
/// puste do wpisania ręcznie.
class TripCard {
  TripCard._();

  /// Wiersze tabeli przejazdów na stronę.
  static const int rowsPerPage = 24;

  /// Jednostka w nagłówku karty: „OSP KIELNO" (ze zdjęć), a bez miejscowości
  /// — pełna nazwa z Ustawień.
  static String unitName(UnitConfig config) => config.locality.trim().isEmpty
      ? config.fullName
      : 'OSP ${config.locality.trim()}';

  /// „Listopad 2026" — miesiąc wpisywany na kartach.
  static String month(int month, int year) {
    final m = PolishText.monthLabel(month, year);
    return m.isEmpty ? m : m[0].toUpperCase() + m.substring(1);
  }

  /// Kolumna paliwa pojazdu w rozliczeniu: ET dla benzyny, inaczej ON.
  static bool _petrol(Vehicle v) =>
      RegExp(r'ET|PB|BENZ').hasMatch(v.fuelType.toUpperCase());

  static List<CardPage> pages({
    required List<VehicleTrip> trips,
    required Vehicle vehicle,
    required UnitConfig config,
    required int year,
    required int month,
    List<Equipment> equipment = const [],
    Report? Function(String reportId)? reportOf,
  }) {
    final outer = CardPage('Okładka ${vehicle.name}');
    _settlement(outer, trips, vehicle, equipment);
    _cover(outer, vehicle, config, year, month);

    final rows = [
      for (final t in trips)
        ...tripRowTexts(
          t,
          equipmentMinutes: EquipmentUsage.vehicleCardMinutes(t, equipment),
          stationAddress: config.stationAddress,
          report: t.reportId == null ? null : reportOf?.call(t.reportId!),
        ),
    ];
    final inner = <CardPage>[];
    for (var i = 0; i == 0 || i < rows.length; i += rowsPerPage) {
      final page = CardPage('Przejazdy ${vehicle.name}'
          '${i == 0 ? '' : ' ${i ~/ rowsPerPage + 1}'}');
      _tripTable(page, rows.skip(i).take(rowsPerPage).toList());
      inner.add(page);
    }
    return [outer, ...inner];
  }

  // ── Okładka (prawa połowa strony zewnętrznej) ─────────────────────────

  static void _cover(
      CardPage p, Vehicle v, UnitConfig config, int year, int monthNo) {
    const x = 158.5, w = 126.5;
    const bold = CardText(size: 11, bold: true);
    p.text(x, 11, 90, 6, unitName(config).toUpperCase(), bold);
    p.text(x, 25, 50, 6, 'Jednostka m..p.', const CardText(size: 10));
    p.table(220, 23, [65], [5, 5], const [
      Cell(0, 0, 'NUMER EWIDENCYJNY KARTY PRACY'),
      Cell(1, 0, 'SERIA            A/               /'),
    ], style: const CardText(size: 7.5));
    p.text(x, 39, w, 6, 'MIESIĘCZNA KARTA DROGOWA', bold);
    p.text(x, 46, w, 6, 'POŻARNICZEGO POJAZDU SAMOCHODOWEGO',
        bold.copyWith(align: CardAlign.right));
    p.text(x, 53, 66, 6, 'na miesiąc', bold.copyWith(size: 10, align: CardAlign.right));
    p.text(x + 67, 53, 59, 6, '${month(monthNo, year)} r.',
        const CardText(size: 10));

    String n(double? value, String unit) =>
        value == null ? '' : '${PdfOutput.number(value)}$unit';
    const value = CardText(size: 10, bold: true, align: CardAlign.center);
    const label = CardText(size: 9.5);
    const y = 62.0;
    const cols = [25.0, 38.0, 20.5, 43.0];
    const rows = [6.5, 6.5, 6.5, 9.0, 6.5, 6.5, 6.5, 9.0];
    p.table(x, y, cols, rows, [
      const Cell(0, 0, 'Marka'),
      Cell(0, 1, v.make, style: value, fit: true),
      const Cell(0, 2, 'Typ'),
      Cell(0, 3, v.model, style: value, fit: true),
      const Cell(1, 0, 'Rodzaj'),
      Cell(1, 1, v.kind.trim().isEmpty ? v.name : v.kind,
          style: value, fit: true),
      const Cell(1, 2, 'Nr rej.'),
      Cell(1, 3, v.plate, style: value, fit: true),
      const Cell(2, 0, 'Numer operacyjny', cs: 2),
      Cell(2, 2, v.operationalNumber, cs: 2, style: value, fit: true),
      const Cell(3, 0, ''),
      const Cell(3, 1, 'Norma zużycia paliwa\nna 100 km przebiegu',
          style: CardText(size: 9, align: CardAlign.center)),
      Cell(3, 2, n(v.fuelPer100Km, 'L'), cs: 2, style: value),
      const Cell(4, 0, 'Norma zużycia paliwa autopompy', cs: 2),
      // Na karcie norma autopompy jest na minutę, w aplikacji — na godzinę.
      Cell(4, 2,
          n(v.pumpFuelPerHour == null ? null : v.pumpFuelPerHour! / 60, 'L/MIN'),
          cs: 2, style: value),
      const Cell(5, 0, 'Zużycie -praca na postoju silnika l/min', cs: 2),
      Cell(5, 2, n(v.idleFuelPerMinute, 'L/MIN'), cs: 2, style: value),
      const Cell(6, 0, '', cs: 2),
      Cell(6, 2, n(v.startupFuelPerMonth, '/M-C'), cs: 2, style: value),
      const Cell(7, 0, 'Stan licznika autopompy', cs: 2,
          style: CardText(size: 9.5, top: true)),
      const Cell(7, 2, '', cs: 2),
    ], style: label);
    // Dwie linijki w jednej kratce i wcięty „Rozruch" — osobne napisy.
    p.text(x, y + 19.5, 25, 4.5, 'Rodzaj paliwa',
        const CardText(size: 9, align: CardAlign.center));
    p.text(x, y + 24, 25, 4.5, 'ON/ET',
        const CardText(size: 9, bold: true, align: CardAlign.center));
    p.text(x + 6, y + 41.5, 57, 6.5, 'Rozruch silnika 1/m - c', label);
    p.text(x + 64, y + 48.5, 30, 8, 'Na początku\nmiesiąca',
        const CardText(size: 9));
    p.text(x + 96, y + 48.5, 30, 8, 'Koniec\nmiesiąca', const CardText(size: 9));

    p.table(x, 119, const [126.5], const [11, 58], const [
      Cell(0, 0, 'ZAPISY DOTYCZĄCE OBSŁUG TECHNICZNYCH I TP.\n'
          'Remontu , zakupu, wymiany podzespołów',
          style: CardText(size: 10, align: CardAlign.center)),
    ]);
    p.text(x + 15, 189, 111, 4, dots(111), const CardText(size: 9), true);
    p.text(x + 15, 193.5, 111, 4,
        '(miejscowość, data i podpis osoby wydającej kartę)',
        const CardText(size: 7.5, align: CardAlign.center));
  }

  // ── Rozliczenie materiałów pędnych (lewa połowa strony zewnętrznej) ───

  static void _settlement(CardPage p, List<VehicleTrip> trips, Vehicle v,
      List<Equipment> equipment) {
    const x = 12.0, w = 126.0;
    p.text(x, 11, w, 7, 'ROZLICZENIE MATERIAŁÓW PĘDNYCH',
        const CardText(size: 11, bold: true, align: CardAlign.center));

    const center = CardText(size: 9, align: CardAlign.center);
    p.table(x, 21, const [14, 27, 21, 21, 21.5, 21.5],
        const [6, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 6], const [
      Cell(0, 0, 'Pobrano (w litrach)', cs: 4, style: CardText(size: 9.5, align: CardAlign.center)),
      Cell(0, 4, 'Podpis\nkierowcy', rs: 2, style: center),
      Cell(0, 5, 'Podpis\nmagazyniera', rs: 2, style: center),
      Cell(1, 0, 'dnia', style: center),
      Cell(1, 1, 'Stan licznika', style: center),
      Cell(1, 2, 'ON', style: CardText(size: 9.5, bold: true, align: CardAlign.center)),
      Cell(1, 3, 'ET', style: center),
      Cell(7, 0, 'Ogółem', cs: 2,
          style: CardText(size: 10, bold: true, align: CardAlign.center)),
      Cell(7, 4, '', cs: 2),
    ]);

    // Sumy z przejazdów i zużycie z norm pojazdu — każda pozycja tylko
    // wtedy, gdy pojazd ma swoją normę.
    var km = 0, deviceMinutes = 0, idle = 0;
    for (final t in trips) {
      final d = t.distance;
      if (d != null && d > 0) km += d;
      deviceMinutes += EquipmentUsage.vehicleCardMinutes(t, equipment);
      idle += t.idleMinutes ?? 0;
    }
    final hours = deviceMinutes / 60;
    double? times(num amount, double? norm) =>
        norm == null || amount == 0 ? null : amount * norm;
    final kmFuel = v.fuelPer100Km == null ? null : km * v.fuelPer100Km! / 100;
    final pumpFuel = times(hours, v.pumpFuelPerHour);
    final idleFuel = times(idle, v.idleFuelPerMinute);
    final startupFuel = v.startupFuelPerMonth;
    final known = [kmFuel, pumpFuel, idleFuel, startupFuel].whereType<double>();
    final total = known.isEmpty ? null : known.reduce((a, b) => a + b);
    String n(num? value) => value == null || value == 0 ? '' : PdfOutput.number(value);

    // Kolumny: numer | pozycja | km/min | „zużyto" | litry | ON | ET.
    const data = CardText(size: 9.5, align: CardAlign.center);
    final fuelCol = _petrol(v) ? 6 : 5;
    Cell no(int r, int n) => Cell(r, 0, '$n', open: 'r', style: center);
    List<Cell> wide(int r, int n, String label) =>
        [no(r, n), Cell(r, 1, label, cs: 3, open: 'l')];
    List<Cell> used(int r, int n, String label, String amount, String litres) => [
          no(r, n),
          Cell(r, 1, label, open: 'l'),
          Cell(r, 2, amount, style: data, fit: true),
          Cell(r, 3, 'zużyto'),
          Cell(r, 4, litres, style: data, fit: true),
        ];

    p.table(x, 72, const [7, 29, 22.5, 14.5, 23, 15.5, 14.5], const [
      6.5, 6.5, 6.5, 6.5, 9, 6.5, 10, 6.5, 6.5, 6.5, 6.5, 6.5, 6.5, 6.5,
    ], [
      const Cell(0, 0, '', cs: 4),
      const Cell(0, 4, 'Litry', style: CardText(size: 9.5, align: CardAlign.center)),
      const Cell(0, 5, 'ON', style: CardText(size: 9.5, bold: true, align: CardAlign.center)),
      const Cell(0, 6, 'ET', style: CardText(size: 9.5, align: CardAlign.center)),
      ...wide(1, 1, 'Pozostało z ubiegłego miesiąca'),
      ...wide(2, 2, 'Pobrano w ciągu miesiąca bieżącego'),
      ...wide(3, 3, 'razem'),
      const Cell(4, 0, '', cs: 2),
      const Cell(4, 2, 'km/min', style: CardText(size: 9.5, bold: true, align: CardAlign.center)),
      const Cell(4, 4, 'Ilość\nlitrów', style: CardText(size: 9.5, bold: true, align: CardAlign.center)),
      ...used(5, 4, 'Przebyto km', n(km), n(kmFuel)),
      ...used(6, 5, 'Przepracowano\no godz.', n(hours), n(pumpFuel)),
      ...used(7, 6, 'Dodatek zimowy', '', ''),
      ...used(8, 7, 'Praca na postoju', n(idle), n(idleFuel)),
      ...used(9, 8, 'Wyk. rozruch.', '', n(startupFuel)),
      ...wide(10, 9, 'Zużyto paliwa w ciągu miesiąca razem:'),
      Cell(10, fuelCol, n(total), style: data, fit: true),
      ...wide(11, 10, 'Przysługuje wg norm wraz z dodat.'),
      ...wide(12, 11, 'Pozostało na miesiąc następny'),
      ...wide(13, 12, 'Oszczędzono- przechowano'),
    ], style: const CardText(size: 9.5));

    const sign = CardText(size: 9.5);
    p.text(x + 5, 171, 40, 5, 'Obliczył', sign);
    p.text(x + 5, 176, 100, 4, dots(100), sign, true);
    p.text(x + 5, 180, 100, 3.5, '(imię i nazwisko)',
        const CardText(size: 7.5, align: CardAlign.center));
    p.text(x + 5, 186, 18, 5, 'Sprawdził', sign);
    p.text(x + 23, 186.5, 103, 4, dots(103), sign, true);
    p.text(x + 23, 191, 103, 3.5, '(imię i nazwisko, podpis, data)',
        const CardText(size: 7.5, align: CardAlign.center));
  }

  // ── Tabela przejazdów (strona wewnętrzna) ─────────────────────────────

  static const _serif = CardText(size: 9.5, font: CardFont.serif);

  /// Wyrównanie kolumn: liczby, godziny i cel na środku, nazwiska i trasa
  /// do lewej.
  static const _left = {1, 2, 4};

  static void _tripTable(CardPage p, List<List<String>> rows) {
    const head = CardText(
        size: 9, font: CardFont.serif, align: CardAlign.center, top: true);
    const mid = CardText(size: 9, font: CardFont.serif, align: CardAlign.center);
    p.table(
      12,
      14,
      const [13.5, 24, 38, 23, 26, 16, 19, 18, 19.5, 23, 14.5, 19.5, 19],
      [6, 7, for (var i = 0; i < rowsPerPage; i++) 7],
      [
        const Cell(0, 0, 'Data', rs: 2, style: head),
        const Cell(0, 1, 'Nazwisko\ndysponenta', rs: 2, style: head),
        const Cell(0, 2, 'Trasy jazdy Skąd-dokąd', rs: 2, style: head),
        const Cell(0, 3, 'Cel jazdy', rs: 2, style: head),
        const Cell(0, 4, 'Nazwisko\nkierowcy', rs: 2, style: head),
        const Cell(0, 5, 'Odjazdy', cs: 2, style: mid),
        const Cell(1, 5, 'Godz.Min.', style: mid),
        const Cell(1, 6, 'Stan licznika', style: mid),
        const Cell(0, 7, 'Przyjazdy', cs: 2, style: mid),
        const Cell(1, 7, 'Godz.Min', style: mid),
        const Cell(1, 8, 'Stan licznika', style: mid),
        const Cell(0, 9, 'Minuty pracy\nurządzeń\nspecjalistycznych', rs: 2,
            style: CardText(size: 8, font: CardFont.serif, align: CardAlign.center, top: true)),
        const Cell(0, 10, 'Dodatki*', rs: 2, style: head),
        const Cell(0, 11, 'Praca silnika\nna postoju\nmin.', rs: 2,
            style: CardText(size: 8.5, font: CardFont.serif, align: CardAlign.center, top: true)),
        const Cell(0, 12, 'Podpis\ndysponenta', rs: 2, style: head),
        for (var r = 0; r < rows.length; r++)
          for (var c = 0; c < rows[r].length; c++)
            Cell(r + 2, c, rows[r][c],
                fit: true,
                style: _serif.copyWith(
                    align: _left.contains(c) ? CardAlign.left : CardAlign.center)),
      ],
    );
    p.text(12, 196, 150, 5, '* np.. P-30 (praca silnika na postoju - 30 min)',
        _serif.copyWith(size: 10));
  }

  /// Przejazd jako dwa wiersze, jak na karcie Kielna: wyjazd
  /// („OSP – Kielno · MZ": odjazd z remizy, przyjazd na miejsce) i powrót
  /// („Kielno – OSP · Powrót": wyjazd z miejsca, przyjazd do remizy) —
  /// teksty 13 kolumn tabeli.
  ///
  /// Minuty sprzętu, dodatki i postój — w wierszu wyjazdu, bo to praca na
  /// miejscu. Pobyt na miejscu, którego nikt nie wpisał, zostaje pusty do
  /// uzupełnienia długopisem.
  static List<List<String>> tripRowTexts(
    VehicleTrip t, {
    required int equipmentMinutes,
    required String stationAddress,
    Report? report,
  }) {
    final from = TripLabels.place(t.routeFrom, stationAddress: stationAddress);
    final to = report != null
        ? report.addressLocality.trim()
        : TripLabels.place(t.routeTo, stationAddress: stationAddress);
    final sceneOdometer = t.sceneOdometer?.toString() ?? '';
    String day(DateTime d) => DateFormat('dd.MM').format(d);
    String hhmm(DateTime? d) => d == null ? '' : TimeFormat.hhmm(d);

    return [
      [
        day(t.date),
        t.dispatcherName,
        TripLabels.route(from, to),
        TripLabels.purpose(t, report),
        t.driverName,
        hhmm(t.departureTime),
        t.odometerStart?.toString() ?? '',
        hhmm(t.sceneArrivalTime),
        sceneOdometer,
        equipmentMinutes == 0 ? '' : '$equipmentMinutes',
        t.extras,
        t.idleMinutes?.toString() ?? '',
        '',
      ],
      [
        day(t.sceneDepartureTime ?? t.returnTime ?? t.date),
        t.dispatcherName,
        TripLabels.route(to, from),
        TripLabels.returnLeg,
        t.driverName,
        hhmm(t.sceneDepartureTime),
        sceneOdometer,
        hhmm(t.returnTime),
        t.odometerEnd?.toString() ?? '',
        '',
        '',
        '',
        '',
      ],
    ];
  }

  /// Wykropkowana linia do podpisu na szerokość [mm] milimetrów.
  static String dots(double mm) => '.' * mm.floor();
}
