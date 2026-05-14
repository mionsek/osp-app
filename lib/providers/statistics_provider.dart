import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'providers.dart';

// ---------------------------------------------------------------------------
// Modele pomocnicze
// ---------------------------------------------------------------------------

class FirefighterStats {
  final Firefighter firefighter;
  final int tripCount;

  const FirefighterStats({
    required this.firefighter,
    required this.tripCount,
  });
}

class YearStats {
  final int year;

  /// Strażacy z ≥1 wyjazdem, posortowani malejąco wg liczby wyjazdów.
  final List<FirefighterStats> firefighterStats;

  /// Liczba wyjazdów per kategoria zagrożenia.
  final Map<String, int> threatCategoryCounts;

  /// Suma czasów trwania wyjazdów (tylko dla raportów z uzupełnionym returnTime).
  final Duration totalDuration;

  /// Numery raportów bez uzupełnionego czasu zakończenia.
  final List<String> incompleteReports;

  const YearStats({
    required this.year,
    required this.firefighterStats,
    required this.threatCategoryCounts,
    required this.totalDuration,
    required this.incompleteReports,
  });

  int get totalTrips =>
      threatCategoryCounts.values.fold(0, (sum, v) => sum + v);
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Aktualnie wybrany rok filtrowania. Domyślnie bieżący rok.
final statisticsYearProvider =
    StateProvider<int>((ref) => DateTime.now().year);

/// Lista dostępnych lat (z istniejących raportów + bieżący rok), posortowana malejąco.
final availableYearsProvider = Provider<List<int>>((ref) {
  final reports = ref.watch(reportsProvider);
  final years = reports.map((r) => r.year).toSet();
  years.add(DateTime.now().year);
  final sorted = years.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
});

/// Statystyki dla wybranego roku.
final yearStatsProvider = Provider<YearStats>((ref) {
  final reports = ref.watch(reportsProvider);
  final firefighters = ref.watch(firefightersProvider);
  final year = ref.watch(statisticsYearProvider);
  return computeYearStats(reports, firefighters, year);
});

// ---------------------------------------------------------------------------
// Czysta funkcja obliczeniowa — testowalana bez Riverpod
// ---------------------------------------------------------------------------

YearStats computeYearStats(
  List<Report> reports,
  List<Firefighter> firefighters,
  int year,
) {
  final filtered = reports.where((r) => r.year == year).toList();

  // --- Statystyki strażaków ---
  // Jeden strażak w jednym raporcie = 1 wyjazd (nawet jeśli był w wielu pojazdach)
  final tripCounts = <String, int>{};
  for (final report in filtered) {
    final ids = <String>{};
    for (final crew in report.crewAssignments) {
      ids.addAll(crew.allAssignedIds);
    }
    for (final id in ids) {
      tripCounts[id] = (tripCounts[id] ?? 0) + 1;
    }
  }

  final firefighterStats = firefighters
      .where((ff) => (tripCounts[ff.id] ?? 0) > 0)
      .map((ff) => FirefighterStats(
            firefighter: ff,
            tripCount: tripCounts[ff.id]!,
          ))
      .toList()
    ..sort((a, b) => b.tripCount.compareTo(a.tripCount));

  // --- Statystyki kategorii zagrożeń ---
  final threatCounts = <String, int>{};
  for (final report in filtered) {
    threatCounts[report.threatCategory] =
        (threatCounts[report.threatCategory] ?? 0) + 1;
  }

  // --- Łączny czas + niekompletne raporty ---
  var totalDuration = Duration.zero;
  final incompleteReports = <String>[];
  for (final report in filtered) {
    if (report.returnTime == null) {
      incompleteReports.add(report.reportNumber);
    } else {
      final duration = report.returnTime!.difference(report.departureTime);
      if (duration.isNegative) {
        incompleteReports.add(report.reportNumber);
      } else {
        totalDuration += duration;
      }
    }
  }

  return YearStats(
    year: year,
    firefighterStats: firefighterStats,
    threatCategoryCounts: threatCounts,
    totalDuration: totalDuration,
    incompleteReports: incompleteReports,
  );
}
