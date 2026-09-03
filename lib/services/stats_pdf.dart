import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/statistics_provider.dart';
import 'pdf_output.dart';

/// Roczne statystyki jednostki — A4 pionowo.
///
/// Liczba wyjazdów per ratownik, rozbicie na kategorie zagrożeń i łączny czas
/// działań ratowniczych.
class StatsPdf {
  StatsPdf._();

  static Future<void> generateAndPrint(
    YearStats stats,
    UnitConfig config,
  ) async {
    final pdf = await _build(stats, config);
    await PdfOutput.layoutPdf(pdf, _fileName(stats), format: PdfPageFormat.a4);
  }

  static Future<void> generateAndShare(
    YearStats stats,
    UnitConfig config,
  ) async {
    final pdf = await _build(stats, config);
    await PdfOutput.sharePdf(pdf, _fileName(stats));
  }

  static String _fileName(YearStats stats) =>
      'statystyki_${stats.year}.pdf';

  static Future<pw.Document> _build(
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
    final generatedOn = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

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
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
          ),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 8),

          // ---- SEKCJA: Kategorie zagrożeń ----
          pw.Text(
            'Wyjazdy według kategorii zagrożeń',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
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
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
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
              style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
            ),
          ],
          pw.SizedBox(height: 12),

          // ---- SEKCJA: Strażacy ----
          pw.Text(
            'Udział strażaków w wyjazdach',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          if (stats.firefighterStats.isEmpty)
            pw.Text('Brak danych.', style: const pw.TextStyle(fontSize: 9))
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
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
                return ['$i', item.firefighter.lastNameFirst, '${item.tripCount}'];
              }).toList(),
            ),
        ],
      ),
    );

    return pdf;
  }
}
