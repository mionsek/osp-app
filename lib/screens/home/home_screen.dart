import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/sync_state.dart';
import '../../providers/providers.dart';
import '../../widgets/banner_ad_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<String> _lastKnownDuplicates = const [];
  bool _gettingStartedDismissed = false;

  @override
  void initState() {
    super.initState();
    _gettingStartedDismissed =
        ref.read(databaseServiceProvider).isGettingStartedDismissed;
  }

  Future<void> _dismissGettingStarted() async {
    await ref.read(databaseServiceProvider).dismissGettingStarted();
    if (mounted) setState(() => _gettingStartedDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(unitConfigProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final firefighters = ref.watch(firefightersProvider);
    final reports = ref.watch(reportsProvider);
    final handovers = ref.watch(handoversProvider);
    final syncState = ref.watch(syncStateProvider);

    // Pokaż SnackBar gdy po sync pojawią się duplikaty
    final duplicates = syncState.duplicateReportNumbers;
    if (duplicates.isNotEmpty && duplicates != _lastKnownDuplicates) {
      _lastKnownDuplicates = duplicates;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange[800],
            duration: const Duration(seconds: 6),
            content: Text(
              'Wykryto ${duplicates.length} '
              '${duplicates.length == 1 ? 'duplikat' : 'duplikaty/duplikatów'} '
              'numerów wyjazdów: ${duplicates.join(', ')}. '
              'Sprawdź listę raportów.',
            ),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        // Nazwa jednostki bywa długa („Ochotnicza Straż Pożarna
        // w Kielnie"), więc na pasku skracamy ją do samej końcówki —
        // pełna wersja i tak jest w Ustawieniach oraz na wydrukach.
        title: Text(
          _shortUnitLabel(config.fullName),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          _SyncIndicator(syncState: syncState, onTap: () {
            ref.read(syncStateProvider.notifier).syncNow();
          }),
        ],
      ),
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Podpowiedź pierwszych kroków — znika sama, gdy jednostka ma
              // już wprowadzone pojazdy i ratowników, więc nie wymaga
              // zapamiętywania „zamknięcia" ani nie zawadza na stałe.
              if (!_gettingStartedDismissed &&
                  (vehicles.isEmpty || firefighters.isEmpty)) ...[
                _GettingStartedCard(
                  hasVehicles: vehicles.isNotEmpty,
                  hasFirefighters: firefighters.isNotEmpty,
                  onDismiss: _dismissGettingStarted,
                ),
                const SizedBox(height: 16),
              ],
              _MenuButton(
                icon: Icons.add_circle,
                label: 'Dodaj wyjazd',
                color: const Color(0xFFB71C1C),
                onTap: () {
                  if (vehicles.isEmpty) {
                    _showNoVehiclesDialog(context);
                  } else {
                    context.push('/reports/new');
                  }
                },
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.add_box,
                label: 'Dodaj przekazanie mienia',
                color: const Color(0xFF6D4C41),
                onTap: () => context.push('/handovers/new'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _MenuButton(
                icon: Icons.list_alt,
                label: 'Lista wyjazdów (${reports.length})',
                color: const Color(0xFF1565C0),
                onTap: () => context.push('/reports'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.inventory_2,
                label: 'Przekazania mienia (${handovers.length})',
                color: const Color(0xFF6D4C41),
                onTap: () => context.push('/handovers'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.fire_truck,
                label: 'Pojazdy (${vehicles.length})',
                color: const Color(0xFFE65100),
                onTap: () => context.push('/vehicles'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.people,
                label: 'Ratownicy (${firefighters.length})',
                color: const Color(0xFF2E7D32),
                onTap: () => context.push('/firefighters'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.bar_chart,
                label: 'Statystyki',
                color: const Color(0xFF6A1B9A),
                onTap: () => context.push('/statistics'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.settings,
                label: 'Ustawienia',
                color: Colors.grey[700]!,
                onTap: () => context.push('/settings'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.info_outline,
                label: 'O aplikacji',
                color: Colors.indigo,
                onTap: () => context.push('/info'),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  SystemNavigator.pop();
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Wyjście'),
              ),
              const SizedBox(height: 20),
              Text(
                'Aplikację stworzył Dawid Mionskowski',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              // Zapas na systemowy pasek nawigacji — bez tego ostatnie
              // elementy listy chowają się za przyciskami telefonu.
              SizedBox(height: 12 + MediaQuery.viewPaddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }

  /// Skraca pełną nazwę jednostki do etykiety na pasku tytułu:
  /// „Ochotnicza Straż Pożarna w Kielnie" → „OSP w Kielnie".
  /// Nazwy, których nie rozpoznajemy, zostawiamy bez zmian.
  static String _shortUnitLabel(String fullName) {
    final name = fullName.trim();
    if (name.isEmpty) return 'OSP';
    final match = RegExp(
      r'^Ochotnicza\s+Stra[żz]\s+Po[żz]arna\s*',
      caseSensitive: false,
    ).firstMatch(name);
    if (match == null) return name;
    final rest = name.substring(match.end).trim();
    return rest.isEmpty ? 'OSP' : 'OSP $rest';
  }

  void _showNoVehiclesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brak pojazdów'),
        content: const Text(
          'Nie masz dodanych żadnych pojazdów bojowych. '
          'Dodaj przynajmniej jeden pojazd, aby utworzyć wyjazd.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/vehicles');
            },
            child: const Text('Dodaj pojazd'),
          ),
        ],
      ),
    );
  }
}

/// Krótka podpowiedź dla nowej jednostki: co trzeba uzupełnić, zanim da
/// się dodać pierwszy wyjazd. Znika automatycznie, gdy komplet jest już
/// wprowadzony.
class _GettingStartedCard extends StatelessWidget {
  final bool hasVehicles;
  final bool hasFirefighters;
  final VoidCallback onDismiss;

  const _GettingStartedCard({
    required this.hasVehicles,
    required this.hasFirefighters,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pierwsze kroki',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Nie pokazuj ponownie',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Zanim dodasz pierwszy wyjazd, uzupełnij dane jednostki:',
              style: TextStyle(color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            _Step(
              done: hasVehicles,
              label: 'Dodaj pojazdy',
              onTap: () => context.push('/vehicles'),
            ),
            _Step(
              done: hasFirefighters,
              label: 'Dodaj ratowników',
              onTap: () => context.push('/firefighters'),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => context.push('/info'),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Jak działa aplikacja?'),
                  ),
                ),
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Nie pokazuj ponownie'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final bool done;
  final String label;
  final VoidCallback onTap;

  const _Step({required this.done, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: done ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: done ? Colors.green[700] : Colors.grey[500],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: done ? Colors.grey[600] : null,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (!done)
              Icon(Icons.chevron_right, size: 20, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  final SyncState syncState;
  final VoidCallback onTap;

  const _SyncIndicator({required this.syncState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!syncState.isConnected) {
      return const SizedBox.shrink();
    }

    IconData icon;
    Color color;
    String tooltip;

    switch (syncState.status) {
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Colors.white;
        tooltip = 'Synchronizacja...';
      case SyncStatus.idle:
        icon = Icons.cloud_done;
        color = Colors.white;
        tooltip = syncState.lastSyncTime != null
            ? 'Zsynchronizowano'
            : 'Połączono';
      case SyncStatus.error:
        icon = Icons.cloud_off;
        color = Colors.orange;
        tooltip = 'Błąd synchronizacji';
      case SyncStatus.disconnected:
        icon = Icons.cloud_off;
        color = Colors.grey;
        tooltip = 'Brak połączenia';
    }

    return IconButton(
      icon: syncState.isSyncing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: syncState.isSyncing ? null : onTap,
    );
  }
}
