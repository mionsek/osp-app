/// Predefiniowane kategorie zagrożeń i ich podopcje.
///
/// Lista kategorii jest zamknięta (nie można dodawać własnych),
/// a jej kolejność jest istotna — tak ma wyświetlać się w UI.
class ThreatTypes {
  ThreatTypes._();

  static const Map<String, List<String>> defaults = {
    'Miejscowe Zagrożenie': [
      'Kolizja',
      'Wypadek',
      'Plama ropopochodna',
      'Powalone drzewo',
      'Zalana posesja',
    ],
    'Pożar': [
      'Pożar budynku',
      'Pożar samochodu',
      'Pożar sadzy w kominie',
      'Pożar lasu',
    ],
    'Fałszywy Alarm': <String>[],
  };

  static const List<String> categories = [
    'Miejscowe Zagrożenie',
    'Pożar',
    'Fałszywy Alarm',
  ];

  /// Podtypy z wcześniejszych wersji domyślnych list — usuwane przy
  /// migracji (w odróżnieniu od podtypów dodanych ręcznie przez użytkownika).
  static const List<String> retiredSubtypes = [
    'Plama oleju',
    'Zalanie mieszkania',
    'Uwięzienie zwierzęcia',
    'Pożar traw',
    'Pożar śmietnika',
  ];
}
