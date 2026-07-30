import '../../models/firefighter.dart';

/// Wspólne wyszukiwanie i porządkowanie ratowników.
///
/// Skład zgłaszamy do PSP telefonicznie, zaczynając od nazwiska, więc
/// wszędzie listujemy „Nazwisko Imię" i po nazwisku sortujemy. Szukanie
/// obejmuje jednak **oba** człony — ktoś może pamiętać tylko imię.
class FirefighterSearch {
  FirefighterSearch._();

  /// Filtruje i porządkuje [all] według [query].
  ///
  /// Kolejność wyników jest trzypoziomowa, żeby najtrafniejsze dopasowania
  /// były na wierzchu:
  /// 1. początek nazwiska („Wi" → Wiśniewski),
  /// 2. początek imienia („Wi" → Wiktoria),
  /// 3. dopasowanie w środku wyrazu.
  ///
  /// Pusty [query] zwraca wszystkich, posortowanych po nazwisku.
  static List<Firefighter> filter(
    Iterable<Firefighter> all,
    String query,
  ) {
    int byLastNameFirst(Firefighter a, Firefighter b) =>
        a.lastNameFirst.toLowerCase().compareTo(b.lastNameFirst.toLowerCase());

    final sorted = all.toList()..sort(byLastNameFirst);

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return sorted;

    final lastNameStarts = <Firefighter>[];
    final firstNameStarts = <Firefighter>[];
    final contains = <Firefighter>[];

    for (final ff in sorted) {
      final lastName = ff.lastName.toLowerCase();
      final firstName = ff.firstName.toLowerCase();
      if (lastName.startsWith(q)) {
        lastNameStarts.add(ff);
      } else if (firstName.startsWith(q)) {
        firstNameStarts.add(ff);
      } else if (ff.lastNameFirst.toLowerCase().contains(q)) {
        contains.add(ff);
      }
    }

    return [...lastNameStarts, ...firstNameStarts, ...contains];
  }
}
