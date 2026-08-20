/// Budowanie nazw plików bezpiecznych dla systemu plików i Dysku Google.
///
/// Wydzielone, bo sanityzacja była powielona w czterech miejscach —
/// i to **trzema różnymi wyrażeniami regularnymi**. Jedno usuwało tylko
/// znaki zabronione w Windows, drugie wszystko poza znakami słowa, trzecie
/// jeszcze inaczej. Efekt: ta sama miejscowość dawała różne nazwy plików
/// w zależności od tego, który dokument się zapisywało.
class FileNames {
  FileNames._();

  /// Zamienia na podkreślenie wszystko, co nie jest literą, cyfrą, myślnikiem
  /// ani podkreśleniem.
  ///
  /// Celowo agresywniej niż sama lista znaków zabronionych w Windows: nazwy
  /// trafiają też na Dysk Google i do udostępniania, gdzie spacje i polskie
  /// znaki potrafią się rozjechać w zależności od klienta.
  static String sanitize(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^\w\-]+'), '_');
    // Podkreślenia na brzegach i ich ciągi tylko zaśmiecają nazwę.
    return cleaned.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Data w formacie `2026-08-19` — sortowalna leksykograficznie, więc pliki
  /// w folderze układają się chronologicznie bez dodatkowej logiki.
  static String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Rok i miesiąc: `2026-08`.
  static String yearMonth(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}
