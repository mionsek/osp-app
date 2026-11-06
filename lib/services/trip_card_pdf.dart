import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../core/utils/file_names.dart';
import '../core/utils/polish_text.dart';
import '../core/utils/time_format.dart';
import '../models/models.dart';
import 'equipment_usage.dart';
import 'pdf_output.dart';
import 'trip_labels.dart';

/// Miesięczna karta drogowa pożarniczego pojazdu samochodowego.
///
/// Układ odtworzony ze zdjęć **druku obowiązującego w OSP Kielno** — nie
/// z wzoru innej gminy. Trzy części, tak jak na papierze:
/// nagłówek z danymi pojazdu i normami, tabela przejazdów (13 kolumn),
/// rozliczenie materiałów pędnych (12 pozycji + „Pobrano").
///
/// Tabela jak na wypełnionej karcie Kielna: dwa wiersze na przejazd
/// (wyjazd i „Powrót"), „OSP" zamiast adresu remizy, sama miejscowość
/// i skrót zdarzenia w celu jazdy (MZ, P, AF) — [TripLabels].
///
/// **Zasada wypełniania:** wpisujemy tylko to, co aplikacja naprawdę wie.
/// Pozycje, których nie zna — ilości pobranego paliwa, dodatek zimowy —
/// zostają puste do wypełnienia długopisem. Wydrukowanie zmyślonej liczby
/// w dokumencie idącym do gminy byłoby gorsze niż puste pole.
class TripCardPdf {
  TripCardPdf._();

  static Future<void> generateAndPrint({
    required List<VehicleTrip> trips,
    required Vehicle vehicle,
    required UnitConfig config,
    required int year,
    required int month,
    List<Equipment> equipment = const [],
    Report? Function(String reportId)? reportOf,
  }) async {
    final doc = await _build(
        trips, vehicle, config, year, month, equipment, reportOf);
    await PdfOutput.layoutPdf(
      doc,
      _fileName(vehicle, year, month),
      format: PdfPageFormat.a4.landscape,
    );
  }

  static Future<void> generateAndShare({
    required List<VehicleTrip> trips,
    required Vehicle vehicle,
    required UnitConfig config,
    required int year,
    required int month,
    List<Equipment> equipment = const [],
    Report? Function(String reportId)? reportOf,
  }) async {
    final doc = await _build(
        trips, vehicle, config, year, month, equipment, reportOf);
    await PdfOutput.sharePdf(doc, _fileName(vehicle, year, month));
  }

  /// Surowe bajty PDF karty — na potrzeby druku przez Bluetooth, gdzie stronę
  /// renderujemy do bitmapy zamiast oddawać ją systemowemu oknu drukowania.
  ///
  /// Karta jest w A4 poziomo, a drukarka termiczna ma 1664 punkty przy 201 DPI,
  /// czyli dokładnie szerokość A4. Obrót o 90° przy druku układa kartę wzdłuż
  /// taśmy — tak samo, jak dzieje się to z raportem i przekazaniem mienia.
  static Future<Uint8List> bytes({
    required List<VehicleTrip> trips,
    required Vehicle vehicle,
    required UnitConfig config,
    required int year,
    required int month,
    List<Equipment> equipment = const [],
    Report? Function(String reportId)? reportOf,
  }) async {
    final doc = await _build(
        trips, vehicle, config, year, month, equipment, reportOf);
    return Uint8List.fromList(await doc.save());
  }

  /// Minimalna liczba wierszy tabeli przejazdów.
  static const int minRows = 16;

  /// Niewidoczny zapas szerokości dla tabel w `Expanded`.
  ///
  /// Tabela z kolumnami elastycznymi dzieli miejsce co do punktu, ale suma
  /// szerokości kolumn potrafi wyjść o ułamek rzędu 1e-13 pt większa niż
  /// przydział `Expanded` — błąd zaokrąglenia. Biblioteka `pdf` sprawdza to
  /// asercją, więc w trybie debug karta w ogóle się nie generowała.
  static const double _floatSlack = 0.05;

  static pw.Widget _withFloatSlack(pw.Widget child) => pw.Padding(
        padding: const pw.EdgeInsets.only(right: _floatSlack),
        child: child,
      );

  /// Liczba pustych wierszy w tabeli „Pobrano (w litrach)".
  static const int fuelIntakeRows = 6;

  static String _fileName(Vehicle v, int year, int month) =>
      'karta_drogowa_${FileNames.sanitize(v.name)}_'
      '${FileNames.yearMonth(year, month)}.pdf';

  /// Godzina w komórce tabeli; pusta dla przejazdu bez wpisanego powrotu —
  /// na papierowej karcie taka rubryka też zostaje pusta.
  static String _hhmm(DateTime? t) => t == null ? '' : TimeFormat.hhmm(t);

  static Future<pw.Document> _build(
    List<VehicleTrip> trips,
    Vehicle vehicle,
    UnitConfig config,
    int year,
    int month,
    List<Equipment> equipment,
    Report? Function(String reportId)? reportOf,
  ) async {
    final theme = await PdfOutput.theme();

    final monthLabel = PolishText.monthLabel(month, year);
    final pdf = pw.Document(
      title: 'Karta drogowa ${vehicle.name} - $monthLabel',
      author: config.fullName,
    );

    // ── Sumy z przejazdów ────────────────────────────────────────────────
    var totalKm = 0;
    var equipmentMinutes = 0;
    var idleMinutes = 0;
    for (final t in trips) {
      final d = t.distance;
      if (d != null && d > 0) totalKm += d;
      equipmentMinutes += EquipmentUsage.vehicleCardMinutes(t, equipment);
      idleMinutes += t.idleMinutes ?? 0;
    }
    final equipmentHours = equipmentMinutes / 60.0;

    // ── Zużycie wyliczone z norm pojazdu ─────────────────────────────────
    // Każda pozycja liczona tylko wtedy, gdy pojazd ma wpisaną swoją normę.
    final kmFuel =
        vehicle.fuelPer100Km == null ? null : totalKm * vehicle.fuelPer100Km! / 100;
    final pumpFuel = vehicle.pumpFuelPerHour == null
        ? null
        : equipmentHours * vehicle.pumpFuelPerHour!;
    final idleFuel = vehicle.idleFuelPerMinute == null
        ? null
        : idleMinutes * vehicle.idleFuelPerMinute!;
    final startupFuel = vehicle.startupFuelPerMonth;

    final known = [kmFuel, pumpFuel, idleFuel, startupFuel].whereType<double>();
    // Suma ma sens tylko wtedy, gdy cokolwiek policzyliśmy. Dodatek zimowy
    // jej nie obejmuje — nie znamy reguły naliczania i nie zgadujemy.
    final totalFuel = known.isEmpty ? null : known.reduce((a, b) => a + b);

    // ── Wspólne elementy ─────────────────────────────────────────────────
    pw.Widget hdr(String text, {double size = 6}) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 1.5, vertical: 3),
          alignment: pw.Alignment.center,
          child: pw.Text(text,
              style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
        );

    pw.Widget cell(
      String text, {
      pw.Alignment align = pw.Alignment.centerLeft,
      double height = 16,
      double size = 6.5,
      bool boldText = false,
    }) =>
        pw.Container(
          height: height,
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          alignment: align,
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: size,
                  fontWeight: boldText ? pw.FontWeight.bold : null),
              maxLines: 1),
        );

    /// Wiersz danych pojazdu: etykieta + wartość, wartość pusta = kratka
    /// do wypełnienia ręcznie.
    pw.TableRow infoRow(String l1, String v1, String l2, String v2) =>
        pw.TableRow(children: [
          cell(l1, size: 7),
          cell(v1, size: 7, boldText: true),
          cell(l2, size: 7),
          cell(v2, size: 7, boldText: true),
        ]);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
        build: (context) => [
          // ══ NAGŁÓWEK ══════════════════════════════════════════════════
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(config.fullName,
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Jednostka  m.p.',
                        style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Column(children: [
                  pw.Text('MIESIĘCZNA KARTA DROGOWA',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('POŻARNICZEGO POJAZDU SAMOCHODOWEGO',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text('na miesiąc  $monthLabel',
                      style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
              pw.Expanded(child: pw.SizedBox()),
            ],
          ),
          pw.SizedBox(height: 8),

          // ── Dane pojazdu i normy ────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.6),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1.4),
            },
            children: [
              infoRow('Marka', vehicle.make, 'Model', vehicle.model),
              infoRow('Typ', vehicle.kind, 'Nr rej.', vehicle.plate),
              infoRow('Numer operacyjny', vehicle.operationalNumber,
                  'Rodzaj paliwa', vehicle.fuelType),
              infoRow(
                'Norma zużycia paliwa na 100 km',
                vehicle.fuelPer100Km == null
                    ? ''
                    : '${PdfOutput.number(vehicle.fuelPer100Km)} l',
                'Norma zużycia paliwa autopompy',
                vehicle.pumpFuelPerHour == null
                    ? ''
                    : '${PdfOutput.number(vehicle.pumpFuelPerHour)} l/godz.',
              ),
              infoRow(
                'Praca na postoju silnika',
                vehicle.idleFuelPerMinute == null
                    ? ''
                    : '${PdfOutput.number(vehicle.idleFuelPerMinute)} l/min',
                'Rozruch silnika',
                vehicle.startupFuelPerMonth == null
                    ? ''
                    : '${PdfOutput.number(vehicle.startupFuelPerMonth)} l/m-c',
              ),
              pw.TableRow(children: [
                cell('Stan autopompy', size: 7),
                cell('na początek miesiąca', size: 6.5),
                cell('', size: 7),
                cell('koniec miesiąca', size: 6.5),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text('ZAPISY DOTYCZĄCE OBSŁUG TECHNICZNYCH I TP.',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.Text('(remontu, zakupu, wymiany podzespołów)',
              style: const pw.TextStyle(fontSize: 6)),
          pw.Container(
            height: 26,
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          ),
          pw.SizedBox(height: 3),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '.......................................................\n'
              '(miejscowość, data i podpis osoby wydającej kartę)',
              style: const pw.TextStyle(fontSize: 6),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 8),

          // ══ TABELA PRZEJAZDÓW ═════════════════════════════════════════
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(16),   // Lp.
              1: pw.FixedColumnWidth(34),   // Data
              2: pw.FlexColumnWidth(1.4),   // Dysponent
              3: pw.FlexColumnWidth(1.9),   // Trasa — „OSP – Kielno"
              4: pw.FlexColumnWidth(1.1),   // Cel — „MZ", „Powrót"
              5: pw.FlexColumnWidth(1.4),   // Kierowca
              6: pw.FixedColumnWidth(36),   // Odjazd godz.
              7: pw.FixedColumnWidth(36),   // Odjazd licznik
              8: pw.FixedColumnWidth(36),   // Przyjazd godz.
              9: pw.FixedColumnWidth(36),   // Przyjazd licznik
              10: pw.FixedColumnWidth(38),  // Minuty urządzeń
              11: pw.FixedColumnWidth(34),  // Dodatki
              12: pw.FixedColumnWidth(30),  // Postój
              13: pw.FlexColumnWidth(1.1),  // Podpis
            },
            children: [
              // Nagłówek: grupy „Odjazdy" i „Przyjazdy" zapisane w dwóch
              // liniach zamiast scalanych komórek — biblioteka nie obsługuje
              // scalania, a czytelność wychodzi ta sama.
              pw.TableRow(children: [
                hdr('Lp.'),
                hdr('Data'),
                hdr('Nazwisko\ndysponenta'),
                hdr('Trasy jazdy\nSkąd - dokąd'),
                hdr('Cel jazdy'),
                hdr('Nazwisko\nkierowcy'),
                hdr('Odjazdy\nGodz.Min.'),
                hdr('Odjazdy\nStan licznika'),
                hdr('Przyjazdy\nGodz.Min.'),
                hdr('Przyjazdy\nStan licznika'),
                hdr('Minuty pracy\nurządzeń\nspecjalistycznych', size: 5.2),
                hdr('Dodatki*'),
                hdr('Praca silnika\nna postoju\nmin.', size: 5.2),
                hdr('Podpis\ndysponenta'),
              ]),
              for (var i = 0; i < trips.length; i++)
                for (final texts in tripRowTexts(
                  trips[i],
                  i + 1,
                  equipmentMinutes:
                      EquipmentUsage.vehicleCardMinutes(trips[i], equipment),
                  stationAddress: config.stationAddress,
                  report: trips[i].reportId == null
                      ? null
                      : reportOf?.call(trips[i].reportId!),
                ))
                  pw.TableRow(children: [
                    for (var c = 0; c < texts.length; c++)
                      cell(texts[c], align: _columnAlign[c]),
                  ]),
              for (var i = trips.length * 2; i < minRows; i++)
                pw.TableRow(children: [for (var c = 0; c < 14; c++) cell('')]),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text('* np. dodatek zimowy',
              style: const pw.TextStyle(fontSize: 6)),

          // ══ ROZLICZENIE MATERIAŁÓW PĘDNYCH ════════════════════════════
          //
          // Zawsze od nowej strony — i tak nie mieści się pod tabelą
          // przejazdów, a na papierowym druku jest po drugiej stronie kartki.
          // Bez tego nagłówek zostawał sam na dole poprzedniej strony.
          pw.NewPage(),
          pw.Text('ROZLICZENIE MATERIAŁÓW PĘDNYCH',
              style:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Lewa: pobrano paliwo (z kwitów — aplikacja tego nie zna)
              pw.Expanded(
                flex: 5,
                child: _withFloatSlack(pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Pobrano (w litrach)',
                        style: pw.TextStyle(
                            fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Table(
                      border: pw.TableBorder.all(width: 0.5),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1),
                        1: pw.FlexColumnWidth(1.3),
                        2: pw.FlexColumnWidth(0.8),
                        3: pw.FlexColumnWidth(0.8),
                        4: pw.FlexColumnWidth(1.5),
                        5: pw.FlexColumnWidth(1.5),
                      },
                      children: [
                        pw.TableRow(children: [
                          hdr('dnia'),
                          hdr('Stan licznika'),
                          hdr('ON'),
                          hdr('ET'),
                          hdr('Podpis\nkierowcy'),
                          hdr('Podpis\nmagazyniera'),
                        ]),
                        for (var i = 0; i < fuelIntakeRows; i++)
                          pw.TableRow(children: [
                            for (var c = 0; c < 6; c++) cell('')
                          ]),
                        pw.TableRow(children: [
                          cell('Ogółem', boldText: true),
                          cell(''),
                          cell(''),
                          cell(''),
                          cell(''),
                          cell(''),
                        ]),
                      ],
                    ),
                  ],
                )),
              ),
              pw.SizedBox(width: 10),
              // Prawa: 12 pozycji rozliczenia
              pw.Expanded(
                flex: 7,
                child: _withFloatSlack(pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(16),
                    1: pw.FlexColumnWidth(3.2),
                    2: pw.FlexColumnWidth(1.3),
                    3: pw.FlexColumnWidth(1),
                    4: pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(children: [
                      hdr(''),
                      hdr(''),
                      hdr('Ilość'),
                      hdr('ON'),
                      hdr('ET'),
                    ]),
                    _settle(1, 'Pozostało z ubiegłego miesiąca', '', cell),
                    _settle(2, 'Pobrano w ciągu miesiąca bieżącego', '', cell),
                    _settle(3, 'razem', '', cell),
                    _settle(4, 'Przebyto km', '$totalKm km', cell,
                        fuel: PdfOutput.number(kmFuel)),
                    _settle(5, 'Przepracowano godz. urządzeń',
                        equipmentMinutes == 0 ? '' : '${PdfOutput.number(equipmentHours)} godz.',
                        cell,
                        fuel: PdfOutput.number(pumpFuel)),
                    _settle(6, 'Dodatek zimowy', '', cell),
                    _settle(7, 'Praca na postoju',
                        idleMinutes == 0 ? '' : '$idleMinutes min', cell,
                        fuel: PdfOutput.number(idleFuel)),
                    _settle(8, 'Wyk. rozruch.', '', cell,
                        fuel: PdfOutput.number(startupFuel)),
                    _settle(9, 'Zużyto paliwa w ciągu miesiąca razem', '', cell,
                        fuel: PdfOutput.number(totalFuel), boldRow: true),
                    _settle(10, 'Przysługuje wg norm wraz z dodat.', '', cell),
                    _settle(11, 'Pozostało na miesiąc następny', '', cell),
                    _settle(12, 'Oszczędzono - przechowano', '', cell),
                  ],
                )),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              PdfOutput.signatureLine('Obliczył', '(imię i nazwisko)'),
              PdfOutput.signatureLine('Sprawdził', '(imię i nazwisko, podpis, data)'),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Przejazd jako dwa wiersze, jak na karcie Kielna: wyjazd
  /// („OSP – Kielno · MZ": odjazd z remizy, przyjazd na miejsce) i powrót
  /// („Kielno – OSP · Powrót": wyjazd z miejsca, przyjazd do remizy) —
  /// teksty 14 kolumn tabeli.
  ///
  /// Minuty sprzętu, dodatki i postój — w wierszu wyjazdu, bo to praca na
  /// miejscu (tak jest na wypełnionej karcie). Pobyt na miejscu, którego
  /// nikt nie wpisał, zostaje pusty do uzupełnienia długopisem.
  static List<List<String>> tripRowTexts(
    VehicleTrip t,
    int lp, {
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

    return [
      [
        '$lp',
        day(t.date),
        t.dispatcherName,
        TripLabels.route(from, to),
        TripLabels.purpose(t, report),
        t.driverName,
        _hhmm(t.departureTime),
        t.odometerStart?.toString() ?? '',
        _hhmm(t.sceneArrivalTime),
        sceneOdometer,
        equipmentMinutes == 0 ? '' : '$equipmentMinutes',
        t.extras,
        t.idleMinutes?.toString() ?? '',
        '',
      ],
      [
        '',
        day(t.sceneDepartureTime ?? t.returnTime ?? t.date),
        t.dispatcherName,
        TripLabels.route(to, from),
        TripLabels.returnLeg,
        t.driverName,
        _hhmm(t.sceneDepartureTime),
        sceneOdometer,
        _hhmm(t.returnTime),
        t.odometerEnd?.toString() ?? '',
        '',
        '',
        '',
        '',
      ],
    ];
  }

  /// Wyrównanie kolejnych kolumn tabeli przejazdów: godziny i minuty na
  /// środku, liczniki do prawej, teksty do lewej.
  static const List<pw.Alignment> _columnAlign = [
    pw.Alignment.center, // Lp.
    pw.Alignment.center, // Data
    pw.Alignment.centerLeft, // Dysponent
    pw.Alignment.centerLeft, // Trasa
    pw.Alignment.centerLeft, // Cel
    pw.Alignment.centerLeft, // Kierowca
    pw.Alignment.center, // Odjazd godz.
    pw.Alignment.centerRight, // Odjazd licznik
    pw.Alignment.center, // Przyjazd godz.
    pw.Alignment.centerRight, // Przyjazd licznik
    pw.Alignment.center, // Minuty urządzeń
    pw.Alignment.centerLeft, // Dodatki
    pw.Alignment.center, // Postój
    pw.Alignment.centerLeft, // Podpis
  ];

  /// Wiersz rozliczenia. [amount] to wielkość (km, godziny, minuty),
  /// [fuel] to wyliczone zużycie w litrach — puste, gdy pojazd nie ma normy.
  static pw.TableRow _settle(
    int no,
    String label,
    String amount,
    pw.Widget Function(String,
            {pw.Alignment align, double height, double size, bool boldText})
        cell, {
    String fuel = '',
    bool boldRow = false,
  }) =>
      pw.TableRow(children: [
        cell('$no.', align: pw.Alignment.center, boldText: boldRow),
        cell(label, boldText: boldRow),
        cell(amount, align: pw.Alignment.centerRight),
        cell(fuel, align: pw.Alignment.centerRight, boldText: boldRow),
        cell(''),
      ]);
}
