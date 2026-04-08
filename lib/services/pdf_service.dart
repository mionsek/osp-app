import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PdfService {
  PdfService._();

  static Future<void> generateAndPrint(
    Report report,
    UnitConfig config,
    List<Firefighter> allFirefighters,
  ) async {
    final pdf = await _buildPdf(report, config, allFirefighters);
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: _fileName(report),
    );
  }

  static Future<void> generateAndShare(
    Report report,
    UnitConfig config,
    List<Firefighter> allFirefighters,
  ) async {
    final pdf = await _buildPdf(report, config, allFirefighters);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: _fileName(report),
    );
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

    // Two copies
    for (var copy = 0; copy < 2; copy++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(config.fullName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Nr ewid.: ${report.reportNumber}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Title
                pw.Center(
                  child: pw.Text(
                    'POTWIERDZENIE',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'udziału w działaniu ratowniczym w dniu $dateStr '
                    'w godzinach $depTime – $retTime',
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    '${report.addressLocality}'
                    '${report.addressStreet.isNotEmpty ? ", ${report.addressStreet}" : ""}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    '(adres miejsca zdarzenia)',
                    style: pw.TextStyle(
                        fontSize: 8, fontStyle: pw.FontStyle.italic),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Zagrożenie: ${report.threatCategory}'
                    '${report.threatSubtype != null ? " — ${report.threatSubtype}" : ""}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 16),

                // Table
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  cellHeight: 24,
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.center,
                    4: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                  },
                  headers: [
                    'Lp.',
                    'Podmiot',
                    'Osoby uczestniczące',
                    'Czas udziału',
                    'Uwagi',
                  ],
                  data: tableRows,
                ),
                pw.SizedBox(height: 20),

                // Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        'Liczba pojazdów ratowniczych: ${report.vehicleCount}'),
                    pw.Text(
                        'Liczba ratowników: ${report.totalFirefighters}'),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(width: 0.5),
                          ),
                        ),
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                          operationCommander != null
                              ? operationCommander.fullName
                              : '',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Text(
                        '(imię, nazwisko i stopień kierującego\ndziałaniem ratowniczym)',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                if (report.notes != null && report.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('Uwagi: ${report.notes}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }
}
