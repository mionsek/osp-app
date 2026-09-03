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
