import '../models/models.dart';

/// Powtórzone numery wyjazdów — który zatrzymuje numer, a który dostaje
/// nowy.
///
/// Dwa telefony bez zasięgu (albo w tych samych minutach) nadają ten sam
/// numer, bo żaden nie widzi wyjazdu drugiego. Zasada ustalona z Dawidem po
/// teście 1.7.4: wcześniejszy wyjazd zatrzymuje numer, późniejszy dostaje
/// pierwszy wolny w swoim roku. Wyjazdy, których numer nie był w konflikcie,
/// zostają nietknięte — mogły już trafić na wydruk albo do PSP.
class ReportNumbers {
  ReportNumbers._();

  /// Najdłuższy odstęp między wyjazdami, przy którym mogą być tą samą akcją.
  static const sameIncidentWindow = Duration(hours: 1);

  /// Wyjazdy, które powinny dostać nowy numer: w każdej grupie z tym samym
  /// numerem wszystkie poza najwcześniejszym.
  ///
  /// „Wcześniejszy" to wcześniejsza godzina wyjazdu, a przy równej —
  /// wcześniej zapisany. Kolejność jest ta sama na każdym telefonie, więc
  /// każdy wskaże te same wyjazdy.
  ///
  /// Pomija wyjazdy podobne do wcześniejszego z grupy ([looksLikeSameIncident])
  /// — dwa raporty z tej samej akcji to nie dwa wyjazdy i nowy numer
  /// dopisałby do ewidencji wyjazd, którego nie było.
  static List<Report> laterDuplicates(Iterable<Report> reports) {
    final groups = <String, List<Report>>{};
    for (final r in reports) {
      groups.putIfAbsent(r.reportNumber, () => []).add(r);
    }
    final later = <Report>[];
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort(_earlierFirst);
      for (var i = 1; i < group.length; i++) {
        final r = group[i];
        if (group.take(i).any((e) => looksLikeSameIncident(e, r))) continue;
        later.add(r);
      }
    }
    return later;
  }

  /// Czy dwa wyjazdy wyglądają na tę samą akcję zapisaną dwa razy: wyjazd
  /// w odstępie do godziny i ten sam rodzaj zagrożenia albo ta sama
  /// miejscowość. Liczy się sama godzina wyjazdu, nie dzień — akcja
  /// z 23:50 i z 0:05 to wciąż może być ta sama.
  static bool looksLikeSameIncident(Report a, Report b) {
    if (a.departureTime.difference(b.departureTime).abs() >
        sameIncidentWindow) {
      return false;
    }
    return _same(a.threatCategory, b.threatCategory) ||
        _same(a.addressLocality, b.addressLocality);
  }

  static bool _same(String a, String b) {
    final x = a.trim().toLowerCase();
    return x.isNotEmpty && x == b.trim().toLowerCase();
  }

  static int _earlierFirst(Report a, Report b) {
    final byDeparture = a.departureTime.compareTo(b.departureTime);
    if (byDeparture != 0) return byDeparture;
    final byCreation = a.createdAt.compareTo(b.createdAt);
    if (byCreation != 0) return byCreation;
    return a.id.compareTo(b.id);
  }
}
