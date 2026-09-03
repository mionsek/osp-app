import 'package:flutter/material.dart';

/// Paleta i motyw aplikacji.
///
/// **To jedyne miejsce w `lib/`, w którym wolno zapisać wartość koloru.**
/// Reguły pilnuje `test/theme_palette_test.dart` — samo istnienie palety
/// nie wystarczyło, bo przez trzydzieści kilka gałęzi kod i tak wpisywał
/// `0xFFB71C1C` z ręki (31 razy), więc zmiana odcienia wymagała przejścia
/// po dwudziestu plikach zamiast po jednej linijce.
///
/// Nazwy mówią, **do czego** kolor służy, a nie jak wygląda: `sectionVehicles`,
/// a nie `orange`. Inaczej za rok nie da się stwierdzić, czy wolno ruszyć
/// „pomarańczowy", nie psując przy okazji czegoś zupełnie innego.
class OspTheme {
  OspTheme._();

  // ---------------------------------------------------------------------------
  // Kolor wiodący i tło
  // ---------------------------------------------------------------------------

  static const Color primaryRed = Color(0xFFB71C1C);
  static const Color darkRed = Color(0xFF7F0000);
  static const Color lightRed = Color(0xFFFF5252);

  /// Kolor uzupełniający motywu (`ColorScheme.secondary`).
  static const Color accentOrange = Color(0xFFFF6F00);

  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;

  // ---------------------------------------------------------------------------
  // Kolory sekcji — kafelki ekranu głównego, ikony i nagłówki modułów
  // ---------------------------------------------------------------------------

  /// Wyjazdy ratownicze — sekcja wiodąca, stąd kolor wiodący aplikacji.
  static const Color sectionReports = primaryRed;

  /// Lista wyjazdów, a poza nią wszystko, co tylko informuje: przycisk edycji,
  /// czas trwania działań, nieznana kategoria zagrożenia.
  static const Color sectionReportsList = Color(0xFF1565C0);

  static const Color sectionHandovers = Color(0xFF6D4C41);
  static const Color sectionTrips = Color(0xFF00695C);
  static const Color sectionVehicles = Color(0xFFE65100);
  static const Color sectionFirefighters = Color(0xFF2E7D32);
  static const Color sectionStatistics = Color(0xFF6A1B9A);

  // ---------------------------------------------------------------------------
  // Znaczenie komunikatu
  //
  // Trzy z nich to te same wartości, co kolory sekcji — czerwień wyjazdu jest
  // od początku czerwienią błędu, a zieleń ratowników zielenią potwierdzenia.
  // Dostają mimo to własne nazwy, żeby dało się je kiedyś rozdzielić przez
  // zmianę jednej linijki, a nie przez szukanie po całym kodzie, które
  // wystąpienie znaczyło co.
  // ---------------------------------------------------------------------------

  /// Błąd, usunięcie, brak ważnych badań — wszystko, co ma zatrzymać wzrok.
  static const Color danger = primaryRed;

  /// Potwierdzenie zapisu, ważne uprawnienie, zalecany wybór.
  static const Color success = sectionFirefighters;

  /// Informacja neutralna i akcje bezpieczne (edycja).
  static const Color info = sectionReportsList;

  /// Miejscowe zagrożenie i ostrzeżenia, które nie są błędem.
  static const Color warning = Color(0xFFF9A825);

  /// Wpis niedokończony — przejazd bez godziny powrotu, bez stanu licznika.
  /// Nie błąd, tylko coś, co zostało do uzupełnienia; stąd osobno od [warning],
  /// które w tej aplikacji znaczy „miejscowe zagrożenie".
  static const Color attention = sectionVehicles;

  /// Stan bez wyróżnienia — np. przejazd gospodarczy obok alarmowego.
  static const Color neutral = Color(0xFF546E7A);

  // ---------------------------------------------------------------------------
  // Tła pastelowe — wypełnienia ramek i kart pod kolorami wyżej
  // ---------------------------------------------------------------------------

  static const Color handoversSurface = Color(0xFFF5EFEB);
  static const Color successSurface = Color(0xFFE8F5E9);
  static const Color infoSurface = Color(0xFFE3F2FD);
  static const Color vehiclesSurface = Color(0xFFFFF3E0);
  static const Color vehiclesBorder = Color(0xFFFFCC80);

  // ---------------------------------------------------------------------------
  // Medale Top 3 w statystykach
  // ---------------------------------------------------------------------------

  static const Color medalGold = Color(0xFFFFD700);
  static const Color medalSilver = Color(0xFFB0BEC5);
  static const Color medalBronze = Color(0xFFBCAAA4);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryRed,
        primary: primaryRed,
        secondary: accentOrange,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: primaryRed),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
      ),
    );
  }
}
