import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../core/utils/file_names.dart';
import '../models/models.dart';
import 'pdf_output.dart';

/// „Potwierdzenie udziału sił i środków podmiotu ratowniczego w działaniu
/// ratowniczym" — formularz KP PSP.
///
/// Dwa egzemplarze A5 obok siebie na jednej kartce A4 poziomo, z przerywaną
/// linią cięcia pośrodku; kartkę przecina się po wydruku.
class ReportPdf {
  ReportPdf._();

  static Future<void> generateAndPrint(
    Report report,
    UnitConfig config,
    List<Firefighter> allFirefighters,
  ) async {
    final pdf = await _build(report, config, allFirefighters);
    await PdfOutput.layoutPdf(pdf, _fileName(report), format: PdfPageFormat.a4.landscape);
  }

  static Future<void> generateAndShare(
    Report report,
    UnitConfig config,
    List<Firefighter> allFirefighters,
  ) async {
    final pdf = await _build(report, config, allFirefighters);
    await PdfOutput.sharePdf(pdf, _fileName(report));
  }

  /// Surowe bajty PDF potwierdzenia udziału w działaniu ratowniczym —
  /// jak `HandoverPdf.bytes`, na potrzeby druku przez Bluetooth, gdzie stronę
  /// renderujemy do bitmapy zamiast oddawać ją systemowemu oknu drukowania.
  static Future<Uint8List> bytes(
    Report report,
    UnitConfig config,
    List<Firefighter> allFirefighters,
  ) async {
    final pdf = await _build(report, config, allFirefighters);
    return Uint8List.fromList(await pdf.save());
  }

  static String _fileName(Report report) {
    final dateStr = DateFormat('yyyy-MM-dd').format(report.date);
    final depStr =
        '${report.departureTime.hour.toString().padLeft(2, '0')}${report.departureTime.minute.toString().padLeft(2, '0')}';
    final num = FileNames.sanitize(report.reportNumber.replaceAll('/', '_'));
    final locality = FileNames.sanitize(report.addressLocality);
    return '${num}_${dateStr}_${depStr}_$locality.pdf';
  }

  static Firefighter? _findFF(String? id, List<Firefighter> all) {
    if (id == null || id.isEmpty) return null;
    return all.where((f) => f.id == id).firstOrNull;
  }

  static Future<pw.Document> _build(
    Report report,
    UnitConfig config,
    List<Firefighter> allFirefighters,
  ) async {
    // Fonts with full Polish character support
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final italicFont = await PdfGoogleFonts.openSansItalic();
    final pageTheme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: italicFont,
    );

    final pdf = pw.Document(
      title: 'Potwierdzenie udziału ${report.reportNumber}',
      author: config.fullName,
    );

    final dateStr = DateFormat('dd.MM.yyyy').format(report.date);
    final depTime =
        '${report.departureTime.hour.toString().padLeft(2, '0')}:${report.departureTime.minute.toString().padLeft(2, '0')}';
    final retTime = report.returnTime != null
        ? '${report.returnTime!.hour.toString().padLeft(2, '0')}:${report.returnTime!.minute.toString().padLeft(2, '0')}'
        : '—';


    // Address + threat on one line: "Miejscowość, ul. X; Kategoria: rodzaj"
    final addressParts = <String>[
      report.addressLocality,
      if (report.addressStreet.isNotEmpty) report.addressStreet,
      if (report.addressDescription.isNotEmpty) report.addressDescription,
    ];
    final threatParts = <String>[
      report.threatCategory,
      if (report.threatSubtype != null && report.threatSubtype!.isNotEmpty)
        report.threatSubtype!,
    ];
    final addressLine = [
      addressParts.join(', '),
      if (threatParts.isNotEmpty) threatParts.join(': '),
    ].join(';  ');

    // Build participant rows for the table
    final tableRows = <List<String>>[];
    int lp = 1;
    for (final crew in report.crewAssignments) {
      for (final id in crew.allAssignedIds) {
        final ff = _findFF(id, allFirefighters);
        if (ff == null) continue;

        String role = '';
        if (id == crew.driverId) role = 'Kierowca';
        if (id == crew.commanderId) role = 'Dowódca';

        tableRows.add([
          '$lp',
          crew.vehicleName,
          '${ff.lastNameFirst}${role.isNotEmpty ? " ($role)" : ""}',
          '$depTime – $retTime',
          '',
        ]);
        lp++;
      }
    }

    // Puste wiersze dopełniające tabelę — jak na papierowym formularzu
    while (tableRows.length < 10) {
      tableRows.add(List.filled(5, ''));
    }

    // Local helper — text over a dotted line (jak wykropkowane pole formularza)
    pw.Widget underlined(String text, {bool bold = false, double size = 8}) {
      return pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(width: 0.7, style: pw.BorderStyle.dotted),
          ),
        ),
        padding: const pw.EdgeInsets.only(bottom: 1),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    // Kratki na pojedyncze znaki numeru ewidencyjnego (jak na formularzu)
    pw.Widget charBoxes(String text) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (final ch in text.split(''))
            pw.Container(
              width: 11,
              height: 14,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
              child: pw.Text(
                ch,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
        ],
      );
    }

    // Numer ewidencyjny "NNNN/RRRR" → kratki, myślnik, kratki
    final numberParts = report.reportNumber.split('/');
    final numberBoxes = pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        charBoxes(numberParts.first),
        if (numberParts.length > 1) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2),
            child: pw.Text('-', style: const pw.TextStyle(fontSize: 8)),
          ),
          charBoxes(numberParts.sublist(1).join('/')),
        ],
      ],
    );

    // Pojedynczy egzemplarz formularza (zawartość w formacie A5)
    pw.Widget buildCopy() {
      return pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ---- HEADER (jak na szkicu: kratki numeru u góry po prawej,
            // nazwa podmiotu nad wykropkowaną linią po lewej) ----
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 8),
                      underlined(config.fullName, size: 7),
                      pw.Text(
                        '(podmiot ksrg)',
                        style: pw.TextStyle(
                          fontSize: 6,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 24),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    numberBoxes,
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'nr ewidencyjny zdarzenia *',
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // ---- TITLE ----
            pw.Center(
              child: pw.Text(
                'POTWIERDZENIE',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),

            // "udziału w działaniu ratowniczym w dniu... w godzinach**..."
            pw.Row(
              children: [
                pw.Text(
                  'udziału w działaniu ratowniczym w dniu ',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                underlined(' $dateStr ', bold: true),
                pw.Text(
                  ' w godzinach** ',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Expanded(
                  child: underlined(' $depTime – $retTime', bold: true),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // ---- ADDRESS LINE ----
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(
                    width: 0.7,
                    style: pw.BorderStyle.dotted,
                  ),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                addressLine,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Center(
              child: pw.Text(
                '(adres miejsca zdarzenia)',
                style: pw.TextStyle(
                  fontSize: 6,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
            pw.SizedBox(height: 8),

            // ---- TABLE ----
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerAlignment: pw.Alignment.center,
              cellHeight: 18,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerLeft,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(18),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(1.5),
              },
              headers: [
                'Lp.',
                'Podmiot',
                'Osoby uczestniczące',
                'Czas udziału\nw działaniach\nratowniczych**',
                'Uwagi',
              ],
              data: tableRows,
            ),
            pw.SizedBox(height: 8),

            // ---- FOOTER COUNTS ----
            pw.Row(
              children: [
                pw.Text(
                  'Liczba pojazdów ratowniczych  ',
                  style: const pw.TextStyle(fontSize: 7),
                ),
                pw.Container(
                  width: 28,
                  height: 14,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '${report.vehicleCount}',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 48),
                pw.Text(
                  'liczba ratowników  ',
                  style: const pw.TextStyle(fontSize: 7),
                ),
                pw.Container(
                  width: 28,
                  height: 14,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.5),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '${report.totalFirefighters}',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.Spacer(),

            // ---- SIGNATURE ----
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 190,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          width: 0.7,
                          style: pw.BorderStyle.dotted,
                        ),
                      ),
                    ),
                    padding: const pw.EdgeInsets.only(bottom: 1),
                    // Linia zostaje pusta do wpisania odręcznie: PSP
                    // uzupełnia kierującego działaniem po swojemu, a przy
                    // raporcie na własny użytek to pole i tak nie jest
                    // potrzebne. Dlatego usunęliśmy je z kreatora.
                    child: pw.Text(
                      '',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                  ),
                  pw.SizedBox(
                    width: 190,
                    child: pw.Text(
                      '(imię, nazwisko i stopień kierującego'
                      ' działaniem ratowniczym)',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // ---- FOOTNOTES (wysunięte gwiazdki jak na formularzu) ----
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 22,
                  child: pw.Text('*', style: const pw.TextStyle(fontSize: 6)),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'wpisać numer ewidencyjny zdarzenia z ewidencji zdarzeń',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                ),
              ],
            ),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 22,
                  child: pw.Text('**', style: const pw.TextStyle(fontSize: 6)),
                ),
                pw.Expanded(
                  child: pw.Text(
                    'czas interwencji (dla społecznych organizacji'
                    ' ratowniczych można uwzględnić również czas'
                    ' podwyższonej gotowości operacyjnej)',
                    style: const pw.TextStyle(fontSize: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Dwa egzemplarze obok siebie na A4 poziomo, rozcinane wzdłuż
    // przerywanej linii pośrodku kartki.
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pageTheme,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(child: buildCopy()),
            pw.Container(
              width: 0,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(width: 0.5, style: pw.BorderStyle.dashed),
                ),
              ),
            ),
            pw.Expanded(child: buildCopy()),
          ],
        ),
      ),
    );

    return pdf;
  }
}
