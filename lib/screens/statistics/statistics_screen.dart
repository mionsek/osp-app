import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../providers/statistics_provider.dart';
import '../../services/pdf_service.dart';
import '../../widgets/banner_ad_widget.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(yearStatsProvider);
    final availableYears = ref.watch(availableYearsProvider);
    final selectedYear = ref.watch(statisticsYearProvider);
    final config = ref.watch(unitConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statystyki'),
      ),
      bottomNavigationBar: const BannerAdWidget(),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Wybór roku ---
            _YearSelector(
              selectedYear: selectedYear,
              availableYears: availableYears,
              onChanged: (year) =>
                  ref.read(statisticsYearProvider.notifier).state = year,
            ),
            const SizedBox(height: 16),

            // --- Ostrzeżenia o niekompletnych raportach ---
            if (stats.incompleteReports.isNotEmpty)
              _IncompleteReportsWarning(
                  reportNumbers: stats.incompleteReports),

            // --- Brak danych ---
            if (stats.totalTrips == 0)
              _EmptyState(year: selectedYear)
            else ...[
              // --- Sekcja: Wyjazdy wg kategorii ---
              _SectionCard(
                title: 'Wyjazdy w $selectedYear roku',
                child: _ThreatStatsTable(stats: stats),
              ),
              const SizedBox(height: 12),

              // --- Sekcja: Łączny czas ---
              _SectionCard(
                title: 'Łączny czas działań',
                child: _TotalDurationTile(duration: stats.totalDuration),
              ),
              const SizedBox(height: 12),

              // --- Sekcja: Strażacy ---
              _SectionCard(
                title: 'Udział strażaków',
                child: _FirefighterStatsList(stats: stats),
              ),
              const SizedBox(height: 24),

              // --- Przyciski drukuj / udostępnij ---
              ElevatedButton.icon(
                onPressed: () =>
                    PdfService.generateAndPrintStats(stats, config),
                icon: const Icon(Icons.print),
                label: const Text('Drukuj statystyki'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    PdfService.generateAndShareStats(stats, config),
                icon: const Icon(Icons.share),
                label: const Text('Udostępnij / Wyślij'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wybór roku
// ---------------------------------------------------------------------------

class _YearSelector extends StatelessWidget {
  final int selectedYear;
  final List<int> availableYears;
  final ValueChanged<int> onChanged;

  const _YearSelector({
    required this.selectedYear,
    required this.availableYears,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        const Text('Rok:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: selectedYear,
          items: availableYears
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
          onChanged: (y) {
            if (y != null) onChanged(y);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ostrzeżenie o niekompletnych raportach
// ---------------------------------------------------------------------------

class _IncompleteReportsWarning extends StatelessWidget {
  final List<String> reportNumbers;

  const _IncompleteReportsWarning({required this.reportNumbers});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Następujące wyjazdy nie mają uzupełnionego czasu zakończenia '
              'i nie są wliczone do łącznego czasu działań:\n'
              '${reportNumbers.map((n) => '• $n').join('\n')}',
              style: TextStyle(fontSize: 13, color: Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stan pusty
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final int year;

  const _EmptyState({required this.year});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Brak wyjazdów w $year roku',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Karta sekcji
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tabela kategorii zagrożeń
// ---------------------------------------------------------------------------

class _ThreatStatsTable extends StatelessWidget {
  final YearStats stats;

  const _ThreatStatsTable({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = stats.threatCategoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _threatIcon(e.key),
                const SizedBox(width: 10),
                Expanded(child: Text(e.key)),
                Text(
                  '${e.value}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text('Łącznie',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Text(
              '${stats.totalTrips}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _threatIcon(String category) {
    final lower = category.toLowerCase();
    if (lower == 'pożar') {
      return const CircleAvatar(
        radius: 14,
        backgroundColor: Color(0xFFB71C1C),
        child: Icon(Icons.local_fire_department, color: Colors.white, size: 16),
      );
    } else if (lower == 'miejscowe zagrożenie') {
      return const CircleAvatar(
        radius: 14,
        backgroundColor: Color(0xFFF9A825),
        child: Icon(Icons.warning, color: Colors.white, size: 16),
      );
    } else if (lower == 'fałszywy alarm') {
      return const CircleAvatar(
        radius: 14,
        backgroundColor: Colors.grey,
        child: Icon(Icons.block, color: Colors.white, size: 16),
      );
    }
    return const CircleAvatar(
      radius: 14,
      backgroundColor: Color(0xFF1565C0),
      child: Icon(Icons.help_outline, color: Colors.white, size: 16),
    );
  }
}

// ---------------------------------------------------------------------------
// Łączny czas działań
// ---------------------------------------------------------------------------

class _TotalDurationTile extends StatelessWidget {
  final Duration duration;

  const _TotalDurationTile({required this.duration});

  @override
  Widget build(BuildContext context) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Row(
      children: [
        const Icon(Icons.timer, color: Color(0xFF1565C0), size: 28),
        const SizedBox(width: 12),
        Text(
          '$hours godz. $minutes min.',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Lista strażaków
// ---------------------------------------------------------------------------

class _FirefighterStatsList extends StatelessWidget {
  final YearStats stats;

  const _FirefighterStatsList({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.firefighterStats.isEmpty) {
      return const Text('Brak przypisanych strażaków do wyjazdów.',
          style: TextStyle(color: Colors.grey));
    }

    return Column(
      children: stats.firefighterStats.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF2E7D32),
                child: Text(
                  item.firefighter.firstName.isNotEmpty
                      ? item.firefighter.firstName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.firefighter.fullName),
              ),
              Chip(
                label: Text(
                  '${item.tripCount}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                backgroundColor: _chipColor(i),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _chipColor(int rank) {
    if (rank == 0) return const Color(0xFFFFD700); // złoty
    if (rank == 1) return const Color(0xFFB0BEC5); // srebrny
    if (rank == 2) return const Color(0xFFBCAAA4); // brązowy
    return const Color(0xFFE3F2FD); // niebieski pastelowy
  }
}
