/// Predefiniowane kategorie zagrożeń i ich podopcje.
class ThreatTypes {
  ThreatTypes._();

  static const Map<String, List<String>> defaults = {
    'Miejscowe Zagrożenie': [
      'Kolizja',
      'Wypadek',
      'Plama oleju',
      'Zalanie mieszkania',
      'Powalone drzewo',
      'Uwięzienie zwierzęcia',
    ],
    'Pożar': [
      'Pożar budynku',
      'Pożar traw',
      'Pożar lasu',
      'Pożar samochodu',
      'Pożar śmietnika',
    ],
    'Fałszywy Alarm': <String>[],
  };

  static const List<String> categories = [
    'Miejscowe Zagrożenie',
    'Pożar',
    'Fałszywy Alarm',
  ];
}
