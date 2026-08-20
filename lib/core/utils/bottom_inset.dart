import 'package:flutter/material.dart';

/// Zapas na dole przewijanej treści.
///
/// Źródłem pomyłek jest to, że trzeba uwzględnić **dwie różne rzeczy naraz**,
/// a każda z nich to inne pole `MediaQuery`:
///
/// * `viewInsets.bottom` — klawiatura. Zero, gdy schowana.
/// * `viewPadding.bottom` — systemowy pasek nawigacji telefonu. Stały.
///
/// Użycie tylko `viewInsets` zostawia ostatni element pod paskiem nawigacji
/// przy schowanej klawiaturze — dokładnie to zgłoszenie („przycisk »Zapisz
/// zmiany« zasłonięty przez przyciski telefonu"). Użycie tylko `viewPadding`
/// chowa go z kolei pod klawiaturą podczas pisania.
///
/// Bierzemy większą z dwóch wartości, a nie ich sumę: gdy klawiatura jest
/// otwarta, przykrywa pasek nawigacji, więc dodawanie obu dawałoby zbędną
/// pustą przestrzeń.
extension BottomInset on BuildContext {
  /// Zapas na dole = [extra] plus miejsce na klawiaturę albo pasek nawigacji.
  double bottomInset({double extra = 0}) {
    final media = MediaQuery.of(this);
    final keyboard = media.viewInsets.bottom;
    final navigationBar = media.viewPadding.bottom;
    return extra + (keyboard > navigationBar ? keyboard : navigationBar);
  }

  /// Gotowy `EdgeInsets` dla przewijanej treści formularza.
  EdgeInsets scrollPadding({
    double horizontal = 16,
    double top = 16,
    double bottom = 24,
  }) =>
      EdgeInsets.fromLTRB(
        horizontal,
        top,
        horizontal,
        bottomInset(extra: bottom),
      );
}
