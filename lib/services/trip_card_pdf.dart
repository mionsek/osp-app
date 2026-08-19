import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

/// Miesięczna karta drogowa pożarniczego pojazdu samochodowego.
///
/// Układ kolumn odtworzony z druku gminnego (załącznik do zarządzenia wójta):
/// data, dysponent, trasa, cel, kierowca, odjazd (godzina i licznik),
/// przyjazd (godzina i licznik), minuty pracy urządzeń specjalnych, podpis.
///
/// Osobny plik, a nie kolejne 250 linii w `PdfService` — karta drogowa nie
/// dzieli niczego z formularzami KP PSP poza samą biblioteką `pdf`.
class TripCardPdf {
  TripCardPdf._();

  static Future<void> printCard({
    required List<VehicleTrip> trips,
    required Vehicle vehicle,
    required UnitConfig config,
    required int year,
    required int month,
  }) async {
    final doc = await _build(trips, vehicle, config, year, month);
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: _fileName(vehicle, year, month),
    );
  }

  static Future<void> shareCard({
    required List<VehicleTrip> trips,
    required Vehicle vehicle,
    required UnitConfig config,
    required int year,
    required int month,
  }) async {
    final doc = await _build(trips, vehicle, config, year, month);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: _fileName(vehicle, year, month),
    );
  }

  static const List<String> monthNames = [
    'styczeń', 'luty', 'marzec', 'kwiecień', 'maj', 'czerwiec',
    'lipiec', 'sierpień', 'wrzesień', 'październik', 'listopad', 'grudzień',
  ];

  /// Minimalna liczba wierszy tabeli.
  ///
  /// Karta z trzema przejazdami też musi wyglądać jak formularz, a nie jak
  /// urwana kartka — reszta zostaje pusta do dopisania długopisem, dokładnie
  /// tak jak papierowy druk z gminy.
  static const int minRows = 16;

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^\w\-]+'), '_');

  static String _fileName(Vehicle vehicle, int year, int month) {
    final mm = month.toString().padLeft(2, '0');
    return 'karta_drogowa_${_sanitize(vehicle.name)}_$year-$mm.pdf';
  }

  static String _hhmm(DateTime? t) =>
      t == null ? '' : DateFormat('HH:mm').format(t);

  static Future<pw.Document> _build(
    List<VehicleTrip> trips,
    Vehicle vehicle,
    UnitConfig config,
    int year,
    int month,
  ) async {
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final italicFont = await PdfGoogleFonts.openSansItalic();
    final pageTheme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: italicFont,
    );

    final monthLabel = '${monthNames[month - 1]} $year';
    final pdf = pw.Document(
      title: 'Karta drogowa ${vehicle.name} - $monthLabel',
      author: config.fullName,
    );

    var totalKm = 0;
    var totalEquipment = 0;
    for (final t in trips) {
      final d = t.distance;
      if (d != null && d > 0) totalKm += d;
      totalEquipment += t.specialEquipmentMinutes ?? 0;
    }

    pw.Widget hdr(String text) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          alignment: pw.Alignment.center,
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        );

    pw.Widget cell(
      String text, {
      pw.Alignment align = pw.Alignment.centerLeft,
    }) =>
        pw.Container(
          height: 18,
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          alignment: align,
          child: pw.Text(
            text,
            style: const pw.TextStyle(fontSize: 7),
            maxLines: 1,
          ),
        );

    // Szerokości dobrane pod A4 poziomo: trasa i cel dostają najwięcej, bo to
    // jedyne kolumny z tekstem opisowym; godziny i liczniki są wąskie.
    const widths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(20),
      1: pw.FixedColumnWidth(42),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(2.6),
      4: pw.FlexColumnWidth(1.6),
      5: pw.FlexColumnWidth(1.5),
      6: pw.FixedColumnWidth(32),
      7: pw.FixedColumnWidth(40),
      8: pw.FixedColumnWidth(32),
      9: pw.FixedColumnWidth(40),
      10: pw.FixedColumnWidth(34),
      11: pw.FlexColumnWidth(1.2),
    };

    final rows = <pw.TableRow>[
      pw.TableRow(children: [
        hdr('Lp.'),
        hdr('Data'),
        hdr('Nazwisko\ndysponenta'),
        hdr('Trasa jazdy\n(skad - dokad)'),
        hdr('Cel jazdy'),
        hdr('Nazwisko\nkierowcy'),
        hdr('Odjazd\ngodz.'),
        hdr('Odjazd\nlicznik'),
        hdr('Przyjazd\ngodz.'),
        hdr('Przyjazd\nlicznik'),
        hdr('Praca urz.\nspec. (min)'),
        hdr('Podpis\ndysponenta'),
      ]),
    ];

    for (var i = 0; i < trips.length; i++) {
      final t = trips[i];
      rows.add(pw.TableRow(children: [
        cell('${i + 1}', align: pw.Alignment.center),
        cell(DateFormat('dd.MM').format(t.date), align: pw.Alignment.center),
        cell(t.dispatcherName),
        cell(t.routeLabel),
        cell(t.purpose),
        cell(t.driverName),
        cell(_hhmm(t.departureTime), align: pw.Alignment.center),
        cell(t.odometerStart?.toString() ?? '',
            align: pw.Alignment.centerRight),
        cell(_hhmm(t.returnTime), align: pw.Alignment.center),
        cell(t.odometerEnd?.toString() ?? '', align: pw.Alignment.centerRight),
        cell(t.specialEquipmentMinutes?.toString() ?? '',
            align: pw.Alignment.center),
        cell(''),
      ]));
    }

    for (var i = trips.length; i < minRows; i++) {
      rows.add(pw.TableRow(children: [
        cell('${i + 1}', align: pw.Alignment.center),
        for (var c = 0; c < 11; c++) cell(''),
      ]));
    }

    pw.Widget signature(String label) => pw.Container(
          width: 150,
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 0.7)),
          ),
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pageTheme,
        margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 18),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  config.fullName,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Text(
                monthLabel,
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              'MIESIĘCZNA KARTA DROGOWA POŻARNICZEGO POJAZDU SAMOCHODOWEGO',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Text('Pojazd: ', style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
              vehicle.name,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 24),
            pw.Text('Przejechano w miesiącu: ',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
              '$totalKm km',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            if (totalEquipment > 0) ...[
              pw.SizedBox(width: 24),
              pw.Text('Praca urządzeń specjalnych: ',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                '$totalEquipment min',
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ]),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: widths,
            children: rows,
          ),
          pw.SizedBox(height: 10),
          // Rozliczenie zużycia paliwa zostaje puste do wypełnienia ręcznego.
          // Normy i liczba linii różnią się między gminami (porównane Kielno,
          // Osielsko i Świętajno), a aplikacja ich jeszcze nie zna —
          // wydrukowanie zmyślonych wartości byłoby gorsze niż puste miejsce.
          pw.Text(
            'Rozliczenie zużycia paliwa',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(children: [
                hdr('Wyszczególnienie'),
                hdr('Norma'),
                hdr('Ilość'),
                hdr('Zużycie'),
              ]),
              for (var i = 0; i < 5; i++)
                pw.TableRow(
                    children: [cell(''), cell(''), cell(''), cell('')]),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              signature('Sporządził'),
              signature('Sprawdził'),
              signature('Zatwierdził'),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }
}
