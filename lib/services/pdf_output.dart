import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Wspólne wyjście dokumentów PDF — druk, udostępnianie i zawijanie tekstu.
///
/// Cztery dokumenty aplikacji (potwierdzenie udziału, statystyki, przekazanie
/// mienia, karta drogowa) nie dzielą ze sobą **nic** poza tymi trzema
/// czynnościami. Wcześniej trzy pierwsze siedziały w jednym pliku na 1197
/// linii, a karta drogowa — wydzielona później — powielała obsługę druku
/// u siebie, razem z ostrzeżeniem w komentarzu. Stąd osobne miejsce na to,
/// co naprawdę wspólne, i osobny plik na każdy dokument.
class PdfOutput {
  PdfOutput._();

  static pw.ThemeData? _theme;

  /// Motyw z czcionką Open Sans — z polskimi znakami, których wbudowana
  /// Helvetica biblioteki `pdf` nie ma.
  ///
  /// Czcionki są w paczce aplikacji. Wcześniej pobierał je `PdfGoogleFonts`,
  /// który trzyma je tylko w pamięci, więc po każdym uruchomieniu aplikacji
  /// pierwszy wydruk potrzebował internetu — bez zasięgu na miejscu zdarzenia
  /// nie drukował się żaden dokument.
  static Future<pw.ThemeData> theme() async {
    final cached = _theme;
    if (cached != null) return cached;
    Future<pw.Font> load(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/OpenSans-$name.ttf'));
    return _theme = pw.ThemeData.withFont(
      base: await load('Regular'),
      bold: await load('Bold'),
      italic: await load('Italic'),
    );
  }

  /// Otwiera systemowe okno druku.
  ///
  /// [format] jest **obowiązkowy i musi odpowiadać stronie w dokumencie**.
  /// Bez niego `Printing.layoutPdf` przyjmuje domyślne `PdfPageFormat.standard`
  /// (US Letter, pionowo), więc okno druku startuje w pionie i wciska naszą
  /// poziomą stronę na pionową kartkę — wydruk wychodzi zmniejszony
  /// i nieczytelny, zamiast wypełnić arkusz. Kosztowało to trzy wydruki
  /// (raport, przekazanie mienia i kartę drogową) naraz, zanim ktokolwiek
  /// zauważył, że winny jest brakujący parametr, a nie ustawienia drukarki.
  static Future<void> layoutPdf(
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

  static Future<void> sharePdf(pw.Document doc, String filename) async {
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  /// Liczba po polsku: przecinek dziesiętny, bez zbędnych zer; `null` — pusto.
  /// Rozliczenia paliwa na kartach drogowej i pracy sprzętu.
  static String number(num? v, {int decimals = 2}) {
    if (v == null) return '';
    final s = v.toDouble().toStringAsFixed(decimals);
    return s
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }

  /// Linia do podpisu z podpowiedzią pod spodem i etykietą („Obliczył").
  static pw.Widget signatureLine(String label, String hint) => pw.Column(
        children: [
          pw.Container(
            width: 190,
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 0.7)),
            ),
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(hint,
                style: const pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.center),
          ),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style:
                  pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        ],
      );

  /// Prosty zawijacz tekstu na potrzeby wykropkowanych linii formularza —
  /// dzieli po słowach, a nadmiar (ponad [maxLines]) dokłada do ostatniej
  /// linii zamiast go obcinać.
  static List<String> wrapText(
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
}
