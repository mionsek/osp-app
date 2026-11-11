import 'package:flutter/widgets.dart';

/// Ikony, których nie ma we wbudowanych `Icons` — rysunki z Material Design
/// Icons (Pictogrammers, Apache 2.0), wybrane przez Dawida 11.11.2026.
///
/// Siedzą w małej czcionce `assets/fonts/OspIcons.otf` (cztery znaki zamiast
/// pakietu z kilkoma tysiącami ikon), więc używa się ich jak `Icons.*`:
/// `Icon(OspIcons.alarmLight)`. Czcionkę i kody znaków składa
/// `tool/osp_icons/build_font.py` — nowa ikona to plik SVG tam i stała tutaj.
@staticIconProvider
abstract final class OspIcons {
  static const String fontFamily = 'OspIcons';

  /// Kogut — wyjazd alarmowy w ewidencji przejazdów.
  static const IconData alarmLight = IconData(0xE000, fontFamily: fontFamily);

  /// Osoba przy tablicy — ćwiczenia w ewidencji przejazdów.
  static const IconData humanMaleBoard =
      IconData(0xE001, fontFamily: fontFamily);

  /// Samochód z kluczem — przegląd / naprawa w ewidencji przejazdów.
  static const IconData carWrench = IconData(0xE002, fontFamily: fontFamily);

  /// Piła tarczowa — sprzęt w menu głównym.
  static const IconData circularSaw = IconData(0xE003, fontFamily: fontFamily);
}
