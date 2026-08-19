import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../core/constants/handover_property_kinds.dart';
import '../core/constants/handover_recipient_types.dart';
import '../models/models.dart';
import '../providers/statistics_provider.dart';

class PdfService {
  PdfService._();

  // ---------------------------------------------------------------------------
  // Wspólne metody druku / udostępniania
  // ---------------------------------------------------------------------------

  /// Otwiera systemowe okno druku.
  ///
  /// [format] jest **obowiązkowy i musi odpowiadać stronie w dokumencie**.
  /// Bez niego `Printing.layoutPdf` przyjmuje domyślne `PdfPageFormat.standard`
  /// (US Letter, pionowo), więc okno druku startuje w pionie i wciska naszą
  /// poziomą stronę na pionową kartkę — wydruk wychodzi zmniejszony
  /// i nieczytelny, zamiast wypełnić arkusz.
  static Future<void> _layoutPdf(
    pw.Document doc,
    String filename, {
    required PdfPageFormat format,
  }) async {
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: filename,
      format: format,
    );
  }

  static Future<void> _sharePdf(pw.Document doc, String filename) async {
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
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
    await _layoutPdf(pdf, _fileName(report), format: PdfPageFormat.a4.landscape);
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
    await _layoutPdf(pdf, _statsFileName(stats), format: PdfPageFormat.a4);
  }

  static Future<void> generateAndShareStats(
    YearStats stats,
    UnitConfig config,
  ) async {
    final pdf = await _buildStatsPdf(stats, config);
    await _sharePdf(pdf, _statsFileName(stats));
  }

  // ---------------------------------------------------------------------------
  // Przekazanie mienia — drukuj / udostępnij
  // ---------------------------------------------------------------------------

  static Future<void> generateAndPrintHandover(
    PropertyHandover handover,
    UnitConfig config,
    Firefighter? handoverFirefighter,
  ) async {
    final pdf = await _buildHandoverPdf(handover, config, handoverFirefighter);
    await _layoutPdf(pdf, _handoverFileName(handover), format: PdfPageFormat.a4.landscape);
  }

  static Future<void> generateAndShareHandover(
    PropertyHandover handover,
    UnitConfig config,
    Firefighter? handoverFirefighter,
  ) async {
    final pdf = await _buildHandoverPdf(handover, config, handoverFirefighter);
    await _sharePdf(pdf, _handoverFileName(handover));
  }

  /// Surowe bajty PDF potwierdzenia udziału w działaniu ratowniczym —
  /// jak [handoverPdfBytes], na potrzeby druku przez Bluetooth.
  static Future<Uint8List> reportPdfBytes(
    Report report,
    UnitConfig config,
    List<Firefighter> allFirefighters,
  ) async {
    final pdf = await _buildPdf(report, config, allFirefighters);
    return Uint8List.fromList(await pdf.save());
  }

  /// Surowe bajty PDF przekazania mienia — potrzebne przy druku przez
  /// Bluetooth, gdzie stronę renderujemy do bitmapy zamiast oddawać ją
  /// systemowemu oknu drukowania.
  static Future<Uint8List> handoverPdfBytes(
    PropertyHandover handover,
    UnitConfig config,
    Firefighter? handoverFirefighter,
  ) async {
    final pdf = await _buildHandoverPdf(handover, config, handoverFirefighter);
    return Uint8List.fromList(await pdf.save());
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
          '${ff.fullName}${role.isNotEmpty ? " ($role)" : ""}',
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
                return ['$i', item.firefighter.fullName, '${item.tripCount}'];
              }).toList(),
            ),
        ],
      ),
    );

    return pdf;
  }

  // ---------------------------------------------------------------------------
  // Nazwa pliku przekazania mienia
  // ---------------------------------------------------------------------------

  static String _handoverFileName(PropertyHandover handover) {
    final dateStr = DateFormat('yyyy-MM-dd').format(handover.eventDate);
    final locality = _sanitizeFilename(
      handover.eventLocation.isNotEmpty ? handover.eventLocation : 'mienie',
    );
    return 'przekazanie_mienia_${dateStr}_$locality.pdf';
  }

  // ---------------------------------------------------------------------------
  // Budowanie PDF przekazania mienia (A4) — wzorowane na formularzu
  // „Potwierdzenie przekazania terenu, obiektu lub mienia objętego
  // działaniem ratowniczym" (§ 21 ust. 2 pkt 2 rozp. MSWiA z 17.09.2021 r.)
  // ---------------------------------------------------------------------------

  /// Wielkość drobnego druku podstawy prawnej wraz z rozpiską podmiotów.
  /// Podniesiona z 6 do 7 pkt (tyle, co reszta treści formularza), bo przy
  /// 203 DPI drukarki termicznej 6 pkt było na granicy czytelności.
  static const double _handoverLegalFontSize = 7;

  /// Klauzule podmiotu przejmującego w formie z formularza (celownik) wraz
  /// z zestawem wartości [PropertyHandover.recipientType], które je wybierają.
  /// Dwie ostatnie opcje z listy zamkniętej dzielą jedną klauzulę na
  /// formularzu ("przedstawicielowi ... lub samorządu terytorialnego").
  static final List<(String, Set<String>)> _recipientClauses = [
    ('właścicielowi', {HandoverRecipientTypes.owner}),
    ('zarządcy', {HandoverRecipientTypes.manager}),
    ('użytkownikowi', {HandoverRecipientTypes.user}),
    (
      'przedstawicielowi organu administracji rządowej lub samorządu terytorialnego',
      {
        HandoverRecipientTypes.governmentAdminRep,
        HandoverRecipientTypes.localGovRep,
      },
    ),
    ('Policji', {HandoverRecipientTypes.police}),
    ('straży gminnej/miejskiej', {HandoverRecipientTypes.municipalGuard}),
  ];

  /// Buduje rozpiskę „(właścicielowi, zarządcy, ...)" z klauzulą wybraną
  /// pogrubioną i podkreśloną, a pozostałymi przekreślonymi — tak jak
  /// ręczne „niepotrzebne skreślić" na papierowym formularzu. Gdy nic nie
  /// wybrano ([PropertyHandover.recipientType] == null), żadna pozycja nie
  /// jest przekreślona — formularz zostaje jak pusty oryginał, do ręcznego
  /// skreślenia długopisem.
  static List<pw.InlineSpan> _recipientClauseSpans(PropertyHandover handover) {
    final spans = <pw.InlineSpan>[];
    final hasSelection = handover.recipientType != null;
    final isOther = handover.recipientType == HandoverRecipientTypes.other;
    for (var i = 0; i < _recipientClauses.length; i++) {
      final (label, matches) = _recipientClauses[i];
      final selected =
          hasSelection && !isOther && matches.contains(handover.recipientType);
      spans.add(
        pw.TextSpan(
          text: label,
          style: pw.TextStyle(
            fontSize: _handoverLegalFontSize,
            fontWeight: selected ? pw.FontWeight.bold : pw.FontWeight.normal,
            decoration: selected
                ? pw.TextDecoration.underline
                : (hasSelection ? pw.TextDecoration.lineThrough : null),
          ),
        ),
      );
      if (i < _recipientClauses.length - 1) {
        spans.add(const pw.TextSpan(
          text: ', ',
          style: pw.TextStyle(fontSize: _handoverLegalFontSize),
        ));
      }
    }
    if (isOther) {
      spans.add(pw.TextSpan(
        text: ' (${handover.recipientTypeOther ?? handover.recipientType})',
        style: pw.TextStyle(
          fontSize: _handoverLegalFontSize,
          fontWeight: pw.FontWeight.bold,
        ),
      ));
    }
    return spans;
  }

  /// Rodzaje przekazywanego przedmiotu w dwóch formach gramatycznych: tytuł
  /// (dopełniacz, wielkie litery — "TERENU") i treść zdania (mianownik —
  /// "teren"). Ta sama logika skreślania co [_recipientClauseSpans].
  static const List<(String key, String titleLabel, String bodyLabel)>
      _propertyKindClauses = [
    (HandoverPropertyKinds.teren, 'TERENU', 'teren'),
    (HandoverPropertyKinds.obiekt, 'OBIEKTU', 'obiekt'),
    (HandoverPropertyKinds.mienie, 'MIENIA', 'mienie'),
  ];

  static List<pw.InlineSpan> _propertyKindSpans(
    String? selectedKind, {
    required bool title,
  }) {
    final spans = <pw.InlineSpan>[];
    final fontSize = title ? 9.0 : 7.0;
    final baseWeight = title ? pw.FontWeight.bold : pw.FontWeight.normal;
    for (var i = 0; i < _propertyKindClauses.length; i++) {
      final (key, titleLabel, bodyLabel) = _propertyKindClauses[i];
      final selected = selectedKind == key;
      spans.add(
        pw.TextSpan(
          text: title ? titleLabel : bodyLabel,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: selected ? pw.FontWeight.bold : baseWeight,
            decoration: selected
                ? pw.TextDecoration.underline
                : (selectedKind != null ? pw.TextDecoration.lineThrough : null),
          ),
        ),
      );
      if (i == _propertyKindClauses.length - 2) {
        spans.add(pw.TextSpan(
          text: title ? ' LUB ' : ' lub ',
          style: pw.TextStyle(fontSize: fontSize, fontWeight: baseWeight),
        ));
      } else if (i < _propertyKindClauses.length - 2) {
        spans.add(pw.TextSpan(
          text: ', ',
          style: pw.TextStyle(fontSize: fontSize, fontWeight: baseWeight),
        ));
      }
    }
    return spans;
  }

  /// Prosty zawijacz tekstu na potrzeby wykropkowanych linii formularza —
  /// dzieli po słowach, a nadmiar (ponad [maxLines]) dokłada do ostatniej
  /// linii zamiast go obcinać.
  static List<String> _wrapText(
    String text,
    int maxLines, {
    int charsPerLine = 100,
  }) {
    if (text.isEmpty) return List.filled(maxLines, '');
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length > charsPerLine && current.isNotEmpty) {
        lines.add(current);
        current = word;
      } else {
        current = candidate;
      }
    }
    if (current.isNotEmpty) lines.add(current);

    if (lines.length > maxLines) {
      final overflow = lines.sublist(maxLines - 1).join(' ');
      final trimmed = lines.sublist(0, maxLines - 1)..add(overflow);
      return trimmed;
    }
    while (lines.length < maxLines) {
      lines.add('');
    }
    return lines;
  }

  static Future<pw.Document> _buildHandoverPdf(
    PropertyHandover handover,
    UnitConfig config,
    Firefighter? handoverFirefighter,
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
      title: 'Potwierdzenie przekazania mienia',
      author: config.fullName,
    );

    final eventDateStr = DateFormat('dd.MM.yyyy').format(handover.eventDate);
    final eventTimeStr =
        '${handover.eventTime.hour.toString().padLeft(2, '0')}:${handover.eventTime.minute.toString().padLeft(2, '0')}';
    final signDateStr = DateFormat('dd.MM.yyyy').format(handover.signDate);

    pw.Widget dottedLine(String text, {double size = 6, bool bold = false}) {
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

    pw.Widget caption(String text) => pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 5, fontStyle: pw.FontStyle.italic),
        );

    final propertyLines = _wrapText(handover.propertyDescription, 3, charsPerLine: 70);
    // Puste uwagi -> jedna pusta linia kropek do ręcznego wypełnienia,
    // zamiast kilku gęsto upakowanych pustych linii.
    final notesLines = (handover.notes == null || handover.notes!.trim().isEmpty)
        ? ['']
        : _wrapText(handover.notes!, 4, charsPerLine: 70);

    // Pojedynczy egzemplarz formularza w formacie A5 — drukowany 2 razy
    // obok siebie na poziomej kartce A4 (jeden dla przekazującego, drugi
    // zostaje u przejmującego), tak samo jak potwierdzenie udziału w
    // działaniu ratowniczym.
    pw.Widget buildCopy() => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ---- HEADER: podmiot ksrg ----
            dottedLine(config.fullName, size: 6),
            caption('(podmiot ksrg)'),
            pw.SizedBox(height: 12),

            // ---- TITLE ----
            pw.Center(
              child: pw.Text(
                'POTWIERDZENIE',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.RichText(
              textAlign: pw.TextAlign.center,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'PRZEKAZANIA ',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  ..._propertyKindSpans(handover.propertyKind, title: true),
                  pw.TextSpan(
                    text: '*',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.Center(
              child: pw.Text(
                'OBJĘTEGO DZIAŁANIEM RATOWNICZYM',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 11),

            // ---- Dotyczy zdarzenia w... ----
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Dotyczy zdarzenia w ',
                    style: const pw.TextStyle(fontSize: 7)),
                pw.Expanded(child: dottedLine(handover.eventLocation, size: 7)),
              ],
            ),
            caption('(miejscowość, adres)'),
            pw.SizedBox(height: 8),

            // ---- W dniu... o godzinie... ----
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('W dniu ', style: const pw.TextStyle(fontSize: 7)),
                pw.SizedBox(
                    width: 65, child: dottedLine(eventDateStr, size: 7, bold: true)),
                pw.Text('  o godzinie ', style: const pw.TextStyle(fontSize: 7)),
                pw.SizedBox(
                    width: 42, child: dottedLine(eventTimeStr, size: 7, bold: true)),
                pw.Expanded(child: dottedLine('', size: 7)),
              ],
            ),
            pw.SizedBox(height: 7),

            // ---- Podstawa prawna + rodzaj przejmującego (niepotrzebne skreślić) ----
            pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: _handoverLegalFontSize),
                children: [
                  const pw.TextSpan(
                    text: 'zgodnie z § 21 ust. 2 pkt 2 rozporządzenia Ministra '
                        'Spraw Wewnętrznych i Administracji z dnia 17 września '
                        '2021 r. w sprawie szczegółowej organizacji krajowego '
                        'systemu ratowniczo-gaśniczego przekazuję ',
                  ),
                  const pw.TextSpan(text: '('),
                  ..._recipientClauseSpans(handover),
                  const pw.TextSpan(text: ')*'),
                ],
              ),
            ),
            pw.SizedBox(height: 7),

            // ---- imię i nazwisko przejmującego ----
            dottedLine(handover.recipientName, size: 7),
            caption('(imię i nazwisko)'),
            pw.SizedBox(height: 6),

            pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 7),
                children: [
                  const pw.TextSpan(
                      text: 'do nadzorowania i zabezpieczenia następujący/ce '),
                  ..._propertyKindSpans(handover.propertyKind, title: false),
                  const pw.TextSpan(text: '*:'),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            for (final line in propertyLines) ...[
              dottedLine(line, size: 7),
              pw.SizedBox(height: 5),
            ],
            pw.Text(
              'które objęte były działaniami ratowniczymi.',
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Uwagi szczegółowe:', style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(height: 4),
            for (final line in notesLines) ...[
              dottedLine(line, size: 7),
              pw.SizedBox(height: 5),
            ],
            pw.SizedBox(height: 10),

            // ---- Przekazujący / Przejmujący ----
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Center(
                        child: pw.Text('Przekazujący',
                            style: pw.TextStyle(
                                fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ),
                      caption('(stopień służbowy, imię i nazwisko)'),
                      pw.SizedBox(height: 6),
                      dottedLine(handoverFirefighter?.fullNameWithRank ?? '',
                          size: 7),
                      pw.SizedBox(height: 8),
                      dottedLine('', size: 7),
                      pw.SizedBox(height: 8),
                      dottedLine('', size: 7),
                      pw.SizedBox(height: 3),
                      caption('(podpis)'),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Center(
                        child: pw.Text('Przejmujący',
                            style: pw.TextStyle(
                                fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ),
                      caption(
                          '(imię i nazwisko, adres służbowy lub zamieszkania '
                          'oraz numer telefonu)'),
                      pw.SizedBox(height: 6),
                      dottedLine(handover.recipientName, size: 7),
                      pw.SizedBox(height: 8),
                      dottedLine(
                        [handover.recipientAddress, handover.recipientPhone]
                            .where((s) => s.isNotEmpty)
                            .join(', tel. '),
                        size: 7,
                      ),
                      pw.SizedBox(height: 8),
                      dottedLine('', size: 7),
                      pw.SizedBox(height: 3),
                      caption('(podpis)'),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // ---- Miejscowość... dnia... ----
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Miejscowość ', style: const pw.TextStyle(fontSize: 7)),
                pw.SizedBox(
                  width: 110,
                  child: dottedLine(handover.signLocality, size: 7, bold: true),
                ),
                pw.Text(' dnia ', style: const pw.TextStyle(fontSize: 7)),
                pw.Expanded(child: dottedLine(signDateStr, size: 7, bold: true)),
              ],
            ),
            pw.SizedBox(height: 7),

            pw.Text(
              '* Niepotrzebne skreślić',
              style: pw.TextStyle(fontSize: 5, fontStyle: pw.FontStyle.italic),
            ),
          ],
        );

    // Dwa egzemplarze obok siebie na A4 poziomo (format A5 każdy) — jeden
    // zostaje u przekazującego, drugi u przejmującego — rozcinane wzdłuż
    // przerywanej linii pośrodku kartki, tak jak potwierdzenie udziału w
    // działaniu ratowniczym.
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pageTheme,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: buildCopy(),
              ),
            ),
            pw.Container(
              width: 0,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  left: pw.BorderSide(width: 0.5, style: pw.BorderStyle.dashed),
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: buildCopy(),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf;
  }
}
