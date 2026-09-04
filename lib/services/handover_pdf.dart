import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../core/constants/handover_property_kinds.dart';
import '../core/constants/handover_recipient_types.dart';
import '../core/utils/file_names.dart';
import '../models/models.dart';
import 'pdf_output.dart';
import '../core/utils/time_format.dart';

/// „Potwierdzenie przekazania terenu, obiektu lub mienia objętego działaniem
/// ratowniczym" — § 21 ust. 2 pkt 2 rozp. MSWiA z 17.09.2021 r.
///
/// Jak potwierdzenie udziału: dwa egzemplarze A5 obok siebie na A4 poziomo.
class HandoverPdf {
  HandoverPdf._();

  static Future<void> generateAndPrint(
    PropertyHandover handover,
    UnitConfig config,
    Firefighter? handoverFirefighter,
  ) async {
    final pdf = await _build(handover, config, handoverFirefighter);
    await PdfOutput.layoutPdf(pdf, _fileName(handover), format: PdfPageFormat.a4.landscape);
  }

  static Future<void> generateAndShare(
    PropertyHandover handover,
    UnitConfig config,
    Firefighter? handoverFirefighter,
  ) async {
    final pdf = await _build(handover, config, handoverFirefighter);
    await PdfOutput.sharePdf(pdf, _fileName(handover));
  }

  /// Surowe bajty PDF przekazania mienia — potrzebne przy druku przez
  /// Bluetooth, gdzie stronę renderujemy do bitmapy zamiast oddawać ją
  /// systemowemu oknu drukowania.
  static Future<Uint8List> bytes(
    PropertyHandover handover,
    UnitConfig config,
    Firefighter? handoverFirefighter,
  ) async {
    final pdf = await _build(handover, config, handoverFirefighter);
    return Uint8List.fromList(await pdf.save());
  }

  static String _fileName(PropertyHandover handover) {
    final dateStr = DateFormat('yyyy-MM-dd').format(handover.eventDate);
    final locality = FileNames.sanitize(
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

  static Future<pw.Document> _build(
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

    final eventDateStr = TimeFormat.date(handover.eventDate);
    final eventTimeStr =
        TimeFormat.hhmm(handover.eventTime);
    final signDateStr = TimeFormat.date(handover.signDate);

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

    final propertyLines = PdfOutput.wrapText(handover.propertyDescription, 3, charsPerLine: 70);
    // Puste uwagi -> jedna pusta linia kropek do ręcznego wypełnienia,
    // zamiast kilku gęsto upakowanych pustych linii.
    final notesLines = (handover.notes == null || handover.notes!.trim().isEmpty)
        ? ['']
        : PdfOutput.wrapText(handover.notes!, 4, charsPerLine: 70);

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
