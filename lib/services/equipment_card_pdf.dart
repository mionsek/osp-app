import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/utils/file_names.dart';
import '../core/utils/polish_text.dart';
import '../models/models.dart';
import 'equipment_card.dart';
import 'pdf_output.dart';

/// Miesięczna karta pracy sprzętu silnikowego.
///
/// Układ ze zdjęć druku OSP Kielno (karta motopompy pływającej Niagara,
/// listopad 2026): A4 w pionie, dwie strony jak dwie strony kartki. Z przodu
/// dane urządzenia i tabela pracy, z tyłu rozliczenie materiałów pędnych.
///
/// Zasada jak na karcie drogowej: wpisujemy tylko to, co aplikacja wie.
/// Paliwo pobrane z kanistrów, stany z poprzedniego miesiąca i licznik
/// motogodzin zostają puste do wypełnienia długopisem.
class EquipmentCardPdf {
  EquipmentCardPdf._();

  static const PdfPageFormat format = PdfPageFormat.a4;

  static Future<void> generateAndPrint({
    required Equipment device,
    required List<EquipmentCardRow> rows,
    required UnitConfig config,
    required int year,
    required int month,
  }) async {
    final doc = await _build(device, rows, config, year, month);
    await PdfOutput.layoutPdf(doc, _fileName(device, year, month),
        format: format);
  }

  static Future<void> generateAndShare({
    required Equipment device,
    required List<EquipmentCardRow> rows,
    required UnitConfig config,
    required int year,
    required int month,
  }) async {
    final doc = await _build(device, rows, config, year, month);
    await PdfOutput.sharePdf(doc, _fileName(device, year, month));
  }

  /// Surowe bajty PDF — druk przez Bluetooth. Strona jest w pionie, więc
  /// drukuje się bez obrotu.
  static Future<Uint8List> bytes({
    required Equipment device,
    required List<EquipmentCardRow> rows,
    required UnitConfig config,
    required int year,
    required int month,
  }) async {
    final doc = await _build(device, rows, config, year, month);
    return Uint8List.fromList(await doc.save());
  }

  /// Minimalna liczba wierszy tabeli pracy — papierowa karta ma ich ok. 20.
  static const int minRows = 22;

  /// Wiersze „Pobrano w litrach" — tyle, ile na druku.
  static const int fuelIntakeRows = 5;

  static String _fileName(Equipment e, int year, int month) =>
      'karta_pracy_${FileNames.sanitize(e.name)}_'
      '${FileNames.yearMonth(year, month)}.pdf';

  static const _dots = '..............................';

  static Future<pw.Document> _build(
    Equipment device,
    List<EquipmentCardRow> rows,
    UnitConfig config,
    int year,
    int month,
  ) async {
    final theme = await PdfOutput.theme();
    final monthLabel = PolishText.monthLabel(month, year);
    final totals = EquipmentCard.totals(device, rows);
    final column = device.settlementColumn;

    final pdf = pw.Document(
      title: 'Karta pracy ${device.name} - $monthLabel',
      author: config.fullName,
    );

    pw.Widget hdr(String text) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          alignment: pw.Alignment.center,
          child: pw.Text(text,
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
        );

    pw.Widget cell(
      String text, {
      pw.Alignment align = pw.Alignment.centerLeft,
      bool bold = false,
      double height = 19,
    }) =>
        pw.Container(
          height: height,
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          alignment: align,
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 7.5, fontWeight: bold ? pw.FontWeight.bold : null),
              maxLines: 2),
        );

    /// „Marka  NIAGARA" — pusta wartość to kropki do wypełnienia.
    pw.Widget field(String label, String value) => pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: '$label  ', style: const pw.TextStyle(fontSize: 9)),
            pw.TextSpan(
              text: value.trim().isEmpty ? _dots : value,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
          ]),
        );

    String litres(double? v, int minutes, String col) =>
        v == null || minutes == 0 || column != col
            ? ''
            : PdfOutput.number(v);

    pw.TableRow settle(String label, String amount,
            {double? fuel, int minutes = 0, bool bold = false}) =>
        pw.TableRow(children: [
          cell(label, bold: bold, height: 17),
          cell(amount, align: pw.Alignment.centerRight, height: 17),
          cell(litres(fuel, minutes, 'ET'),
              align: pw.Alignment.centerRight, bold: bold, height: 17),
          cell(litres(fuel, minutes, 'ON'),
              align: pw.Alignment.centerRight, bold: bold, height: 17),
        ]);

    final allMinutes = totals.workMinutes + totals.startupMinutes;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        build: (context) => [
          // ══ PRZÓD: dane urządzenia ═════════════════════════════════════
          field('Jednostka', config.fullName),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Column(children: [
              pw.Text('MIESIĘCZNA KARTA PRACY',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('SPRZĘTU SILNIKOWEGO',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              field('Na miesiąc', monthLabel),
            ]),
          ),
          pw.SizedBox(height: 12),
          pw.Row(children: [
            pw.Expanded(child: field('Marka', device.brand)),
            pw.Expanded(child: field('Model', device.model)),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(child: field('Rodzaj', device.name)),
            pw.Expanded(child: field('Stan licznika', '')),
          ]),
          pw.SizedBox(height: 6),
          field(
            'Norma eksploatacyjna na 1 godz. pracy',
            device.fuelPerHour == null
                ? ''
                : '${PdfOutput.number(device.fuelPerHour)} litrów',
          ),
          pw.SizedBox(height: 10),

          // ══ TABELA PRACY ═══════════════════════════════════════════════
          pw.Table(
            border: pw.TableBorder.all(width: 0.6),
            columnWidths: const {
              0: pw.FixedColumnWidth(48),
              1: pw.FlexColumnWidth(2.3),
              2: pw.FixedColumnWidth(42),
              3: pw.FlexColumnWidth(2.6),
              4: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(children: [
                hdr('Data'),
                hdr('Nazwisko i imię\nobsługującego'),
                hdr('Minut\npracy'),
                hdr('Cel użycia'),
                hdr('Podpis\ndysponenta'),
              ]),
              for (final r in rows)
                pw.TableRow(children: [
                  cell(DateFormat('dd.MM').format(r.date),
                      align: pw.Alignment.center),
                  cell(r.operatorName),
                  cell('${r.minutes}', align: pw.Alignment.center),
                  cell(r.purpose),
                  cell(''),
                ]),
              for (var i = rows.length; i < minRows; i++)
                pw.TableRow(children: [for (var c = 0; c < 5; c++) cell('')]),
            ],
          ),

          // ══ TYŁ: licznik i rozliczenie ═════════════════════════════════
          pw.NewPage(),
          pw.Table(
            border: pw.TableBorder.all(width: 0.6),
            children: [
              pw.TableRow(children: [
                hdr('Data'),
                hdr('Stan licznika'),
                hdr('Minuty pracy'),
                hdr('Stan licznika'),
                hdr('Zużycie paliwa'),
              ]),
              for (var i = 0; i < 2; i++)
                pw.TableRow(children: [for (var c = 0; c < 5; c++) cell('')]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text('ROZLICZANIE MATERIAŁÓW PĘDNYCH',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Pobrano w litrach',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Table(
            border: pw.TableBorder.all(width: 0.6),
            children: [
              pw.TableRow(children: [
                hdr('Dnia'),
                hdr('Nr kwitu'),
                hdr('paliwa'),
                hdr('oleju'),
                hdr('Podpis\nmechanika'),
                hdr('Podpis\nmagazyn.'),
              ]),
              for (var i = 0; i < fuelIntakeRows; i++)
                pw.TableRow(children: [for (var c = 0; c < 6; c++) cell('')]),
              pw.TableRow(children: [
                cell('Razem', bold: true),
                for (var c = 0; c < 5; c++) cell(''),
              ]),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(3.6),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FixedColumnWidth(70),
              3: pw.FixedColumnWidth(70),
            },
            children: [
              pw.TableRow(children: [
                cell('LITRÓW:', bold: true, height: 17),
                cell('', height: 17),
                hdr('ET'),
                hdr('ON'),
              ]),
              settle('1. pozostało z ubiegłego mies.', ''),
              settle('2. pobrano w mies. bieżącym', ''),
              settle('3. Razem', ''),
              settle(
                '4. Przepracowano godz. i min.',
                totals.workMinutes == 0
                    ? ''
                    : EquipmentCard.hoursAndMinutes(totals.workMinutes),
              ),
              settle('5. zużyto', '',
                  fuel: totals.workFuel, minutes: totals.workMinutes),
              settle(
                '6. zużyto na rozruchy i kontrole',
                totals.startupMinutes == 0
                    ? ''
                    : EquipmentCard.hoursAndMinutes(totals.startupMinutes),
                fuel: totals.startupFuel,
                minutes: totals.startupMinutes,
              ),
              settle('7. zużyto w ciągu mies. Razem', '',
                  fuel: totals.totalFuel, minutes: allMinutes, bold: true),
              settle('8. POZOSTAŁO NA MIESIĄC NASTĘPNY', '', bold: true),
            ],
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              PdfOutput.signatureLine('Obliczył', '(imię i nazwisko)'),
              PdfOutput.signatureLine(
                  'Sprawdził', '(imię i nazwisko, podpis, data)'),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }
}
