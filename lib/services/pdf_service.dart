import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/statistics_provider.dart';

class PdfService {
  PdfService._();

  // ---------------------------------------------------------------------------
  // Wspólne metody druku / udostępniania
  // ---------------------------------------------------------------------------

  static Future<void> _layoutPdf(pw.Document doc, String filename) async {
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: filename,
    );
  }

  static Future<void> _sharePdf(pw.Document doc, String filename) async {
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: filename,
    );
  }

  // ---------------------------------------------------------------------------
  // Wyjazd — drukuj / udostępnij
  // ---------------------------------------------------------------------------

  static Future<void> generateAndPrint(
    Report report,
    UnitConfig config,
    List<Firefighter> allFirefighters,
  ) async {
    final pdf = await _buildPdf(report, config, allFirefighters);
    await _layoutPdf(pdf, _fileName(report));
  }

  static Future<void> generateAndShare(
    Report report,
    UnitConfig config,
    List<Firefighter> allFirefighters,
  ) async {
    final pdf = await _buildPdf(report, config, allFirefighters);
    await _sharePdf(pdf, _fileName(report));
  }

  // ---------------------------------------------------------------------------
  // Statystyki — drukuj / udostępnij
  // ---------------------------------------------------------------------------

  static Future<void> generateAndPrintStats(
    YearStats stats,
    UnitConfig config,
  ) async {
    final pdf = await _buildStatsPdf(stats, config);
    await _layoutPdf(pdf, _statsFileName(stats));
  }

  static Future<void> generateAndShareStats(
    YearStats stats,
    UnitConfig config,
  ) async {
    final pdf = await _buildStatsPdf(stats, config);
    await _sharePdf(pdf, _statsFileName(stats));
  }

  static String _sanitizeFilename(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  static String _fileName(Report report) {
    final dateStr = DateFormat('yyyy-MM-dd').format(report.date);
    final depStr =
        '${report.departureTime.hour.toString().padLeft(2, '0')}${report.departureTime.minute.toString().padLeft(2, '0')}';
    final num = _sanitizeFilename(report.reportNumber.replaceAll('/', '_'));
    final locality = _sanitizeFilename(report.addressLocality);
    return '${num}_${dateStr}_${depStr}_$locality.pdf';
  }

  static Firefighter? _findFF(String? id, List<Firefighter> all) {
    if (id == null || id.isEmpty) return null;
    return all.where((f) => f.id == id).firstOrNull;
  }

  static Future<pw.Document> _buildPdf(
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

    final operationCommander =
        _findFF(report.operationCommanderId, allFirefighters);

    // Address + threat on one line: "Miejscowość, ul. X; Kategoria: rodzaj"
    final addressParts = <String>[
      report.addressLocality,
      if (report.addressStreet.isNotEmpty) report.addressStreet,
      if (report.addressDescription != null &&
          report.addressDescription!.isNotEmpty)
        report.addressDescription!,
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
          '${ff.fullName}${role.isNotEmpty ? " ($role)" : ""}',
          '$depTime – $retTime',
          '',
        ]);
        lp++;
      }
    }

    // Local helper — text with underline below
    pw.Widget underlined(String text, {bool bold = false, double size = 8}) {
      return pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
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

    // Two copies (A5)
    for (var copy = 0; copy < 2; copy++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          theme: pageTheme,
          margin: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ---- HEADER ----
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Left: unit name + (podmiot ksrg)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                  bottom: pw.BorderSide(width: 0.5)),
                            ),
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Text(
                              config.fullName,
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                          ),
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
                    pw.SizedBox(width: 16),
                    // Right: report number in box + label
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(width: 0.5),
                          ),
                          child: pw.Text(
                            report.reportNumber,
                            style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Text(
                          'nr ewidencyjny zdarzenia*',
                          style: pw.TextStyle(
                            fontSize: 6,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),

                // ---- TITLE ----
                pw.Center(
                  child: pw.Text(
                    'POTWIERDZENIE',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'udziału sił i środków podmiotu ratowniczego'
                    ' w działaniu ratowniczym',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 4),

                // "w dniu [data] w godzinach** [od – do]"
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('w dniu  ', style: const pw.TextStyle(fontSize: 8)),
                    underlined(dateStr, bold: true),
                    pw.Text('  w godzinach**  ',
                        style: const pw.TextStyle(fontSize: 8)),
                    underlined('$depTime – $retTime', bold: true),
                  ],
                ),
                pw.SizedBox(height: 8),

                // ---- ADDRESS LINE ----
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border:
                        pw.Border(bottom: pw.BorderSide(width: 0.5)),
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
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
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
                      decoration:
                          pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        '${report.vehicleCount}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      'liczba ratowników  ',
                      style: const pw.TextStyle(fontSize: 7),
                    ),
                    pw.Container(
                      width: 28,
                      height: 14,
                      decoration:
                          pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
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
                        width: 160,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(width: 0.5)),
                        ),
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          operationCommander?.fullName ?? '',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 7),
                        ),
                      ),
                      pw.Text(
                        '(imię, nazwisko i stopień kierującego'
                        ' działaniem ratowniczym)',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 6,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // ---- FOOTNOTES ----
                pw.Text(
                  '* Wpisać numer ewidencyjny zdarzenia z ewidencji zdarzeń.',
                  style: pw.TextStyle(
                      fontSize: 6, fontStyle: pw.FontStyle.italic),
                ),
                pw.Text(
                  '** Czas interwencji (dla społecznych organizacji ratowniczych'
                  ' można uwzględnić również czas podwyższonej gotowości operacyjnej).',
                  style: pw.TextStyle(
                      fontSize: 6, fontStyle: pw.FontStyle.italic),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }

  // ---------------------------------------------------------------------------
  // Nazwa pliku statystyk
  // ---------------------------------------------------------------------------

  static String _statsFileName(YearStats stats) =>
      'statystyki_${stats.year}.pdf';

  // ---------------------------------------------------------------------------
  // Budowanie PDF statystyk (A4)
  // ---------------------------------------------------------------------------

  static Future<pw.Document> _buildStatsPdf(
    YearStats stats,
    UnitConfig config,
  ) async {
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final italicFont = await PdfGoogleFonts.openSansItalic();
    final pageTheme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: italicFont,
    );

    final pdf = pw.Document(
      title: 'Statystyki wyjazdów ${stats.year}',
      author: config.fullName,
    );

    final hours = stats.totalDuration.inHours;
    final minutes = stats.totalDuration.inMinutes.remainder(60);
    final generatedOn =
        DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pageTheme,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
        build: (context) => [
          // ---- NAGŁÓWEK ----
          pw.Text(
            config.fullName,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Statystyki wyjazdów — rok ${stats.year}',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.Text(
            'Wygenerowano: $generatedOn',
            style: pw.TextStyle(
                fontSize: 8, fontStyle: pw.FontStyle.italic),
          ),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 8),

          // ---- SEKCJA: Kategorie zagrożeń ----
          pw.Text(
            'Wyjazdy według kategorii zagrożeń',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headerStyle:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellHeight: 20,
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FixedColumnWidth(60),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
            },
            headers: ['Kategoria zagrożenia', 'Liczba wyjazdów'],
            data: [
              ...(stats.threatCategoryCounts.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .map((e) => [e.key, '${e.value}']),
              ['Łącznie', '${stats.totalTrips}'],
            ],
          ),
          pw.SizedBox(height: 12),

          // ---- SEKCJA: Łączny czas ----
          pw.Text(
            'Łączny czas działań ratowniczych',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$hours godz. $minutes min.',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          if (stats.incompleteReports.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Uwaga: następujące wyjazdy nie mają uzupełnionego czasu '
              'zakończenia i nie są wliczone do powyższej sumy:\n'
              '${stats.incompleteReports.join(', ')}',
              style: pw.TextStyle(
                  fontSize: 8, fontStyle: pw.FontStyle.italic),
            ),
          ],
          pw.SizedBox(height: 12),

          // ---- SEKCJA: Strażacy ----
          pw.Text(
            'Udział strażaków w wyjazdach',
            style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          if (stats.firefighterStats.isEmpty)
            pw.Text('Brak danych.',
                style: const pw.TextStyle(fontSize: 9))
          else
            pw.TableHelper.fromTextArray(
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              cellHeight: 18,
              columnWidths: {
                0: const pw.FixedColumnWidth(28),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FixedColumnWidth(80),
              },
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
              },
              headers: ['Lp.', 'Imię i nazwisko', 'Liczba wyjazdów'],
              data: stats.firefighterStats.asMap().entries.map((e) {
                final i = e.key + 1;
                final item = e.value;
                return ['$i', item.firefighter.fullName, '${item.tripCount}'];
              }).toList(),
            ),
        ],
      ),
    );

    return pdf;
  }
}
