/// Budowanie nazw plików bezpiecznych dla systemu plików i Dysku Google.
///
/// Wydzielone, bo sanityzacja była powielona w czterech miejscach —
/// i to **trzema różnymi wyrażeniami regularnymi**. Jedno usuwało tylko
/// znaki zabronione w Windows, drugie wszystko poza znakami słowa, trzecie
/// jeszcze inaczej. Efekt: ta sama miejscowość dawała różne nazwy plików
/// w zależności od tego, który dokument się zapisywało.
class FileNames {
  FileNames._();

  /// Polskie znaki i ich odpowiedniki bez ogonków.
  ///
  /// Nazwy plików trzymamy w czystym ASCII, bo trafiają mailem do gminy i KP PSP,
  /// na Dysk Google i do okna udostępniania Androida — a starsze klienty poczty
  /// potrafią poprzestawiać znaki w nazwie załącznika. Transliteracja daje
  /// nazwę odporną na to wszystko i **nadal czytelną**.
  ///
  /// Dotyczy wyłącznie nazw plików. Treść dokumentów — w tym nazwiska —
  /// idzie na wydruk bez żadnych zamian, czcionką z pełnym polskim zestawem.
  static const Map<String, String> _polishLetters = {
    'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n',
    'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
    'Ą': 'A', 'Ć': 'C', 'Ę': 'E', 'Ł': 'L', 'Ń': 'N',
    'Ó': 'O', 'Ś': 'S', 'Ź': 'Z', 'Ż': 'Z',
  };

  /// Zamienia polskie znaki na ich odpowiedniki bez ogonków, a wszystko poza
  /// literą, cyfrą, myślnikiem i podkreśleniem — na podkreślenie.
  ///
  /// Transliteracja **musi** iść przed czyszczeniem: `\w` w Darcie to tylko
  /// ASCII, więc bez niej „Żukowo" dawało `ukowo`, a „Łódź" — samo `d`.
  /// Dla aplikacji, w której miejscowości rutynowo mają ą, ę, ł czy ż, nazwy
  /// plików robiły się nieczytelne.
  static String sanitize(String s) {
    final transliterated = s.split('').map((c) => _polishLetters[c] ?? c).join();
    final cleaned = transliterated.replaceAll(RegExp(r'[^\w\-]+'), '_');
    // Podkreślenia na brzegach i ich ciągi tylko zaśmiecają nazwę.
    return cleaned.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Sanityzacja sprzed wprowadzenia transliteracji — polskie znaki lądowały
  /// jako podkreślenia i znikały z brzegów nazwy.
  ///
  /// Potrzebna **wyłącznie** do odnalezienia na Dysku plików zapisanych
  /// starszą wersją aplikacji, żeby przy najbliższej synchronizacji zmienić im
  /// nazwę zamiast utworzyć obok drugi plik z tą samą treścią. Do niczego
  /// nowego jej nie używamy.
  static String sanitizeLegacy(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^\w\-]+'), '_');
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
