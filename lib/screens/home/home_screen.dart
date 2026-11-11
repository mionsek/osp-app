import '../../core/utils/bottom_inset.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/constants.dart';
import '../../models/sync_state.dart';
import '../../providers/providers.dart';
import '../../core/theme/osp_icons.dart';
import '../../core/theme/osp_theme.dart';
import '../../widgets/sync_feedback.dart';

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

  Future<void> _openCoffee() async {
    if (kCoffeeUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kCoffeeNotReadyMessage)),
        );
      }
      return;
    }
    final ok = await launchUrl(
      Uri.parse(kCoffeeUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się otworzyć strony')),
      );
    }
  }

  Future<void> _dismissGettingStarted() async {
    await ref.read(databaseServiceProvider).dismissGettingStarted();
    if (mounted) setState(() => _gettingStartedDismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(unitConfigProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final equipment = ref.watch(equipmentProvider);
    final firefighters = ref.watch(firefightersProvider);
    final reports = ref.watch(reportsProvider);
    final handovers = ref.watch(handoversProvider);
    final syncState = ref.watch(syncStateProvider);

    // Pasek tylko przy nowych duplikatach. Każda synchronizacja zwraca nową
    // listę, więc przy porównaniu samych obiektów pasek wracał po każdej —
    // i przez 6 sekund zasłaniał wynik „Synchronizuj teraz". Na stałe
    // duplikaty są oznaczone na liście wyjazdów.
    final duplicates = syncState.duplicateReportNumbers;
    if (duplicates.isEmpty) _lastKnownDuplicates = const [];
    if (duplicates.isNotEmpty &&
        !setEquals(duplicates.toSet(), _lastKnownDuplicates.toSet())) {
      _lastKnownDuplicates = duplicates;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: OspTheme.attention,
            duration: const Duration(seconds: 6),
            content: Text(
              'Ten sam numer mają dwa wyjazdy: ${duplicates.join(', ')}. '
              'Późniejszy dostanie nowy numer przy synchronizacji telefonu, '
              'z którego go dodano.',
            ),
            action: SnackBarAction(
              label: 'Pokaż',
              textColor: Colors.white,
              onPressed: () => context.push('/reports'),
            ),
          ),
        );
      });
    }

    final greeting = _Greeting(
      displayName: ref.read(syncStateProvider.notifier).displayName,
      syncState: syncState,
      // Nazwa jednostki bywa długa („Ochotnicza Straż Pożarna
      // w Kielnie"), więc na pasku skracamy ją do samej końcówki —
      // pełna wersja i tak jest w Ustawieniach oraz na wydrukach.
      unitLabel: _shortUnitLabel(config.fullName),
    );

    return Scaffold(
      appBar: AppBar(
        // Powitanie na czerwonym pasku, razem z nazwą jednostki (prośba
        // Dawida z 6.11.2026) — wcześniej nazwa była na pasku, a „Witaj"
        // pod nim na białym tle, więc jednostka stała na ekranie dwa razy.
        toolbarHeight: _Greeting.barHeight,
        centerTitle: false,
        title: greeting,
        actions: [
          _SyncIndicator(
            syncState: syncState,
            onTap: () => runManualSync(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (greeting.needsUnit) ...[
                const _JoinUnitHint(),
                const SizedBox(height: 16),
              ],
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
                color: OspTheme.sectionReports,
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
                color: OspTheme.sectionHandovers,
                onTap: () => context.push('/handovers/new'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _MenuButton(
                icon: Icons.list_alt,
                label: 'Wyjazdy (${reports.length})',
                color: OspTheme.sectionReports,
                onTap: () => context.push('/reports'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.inventory_2,
                label: 'Przekazania mienia (${handovers.length})',
                color: OspTheme.sectionHandovers,
                onTap: () => context.push('/handovers'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.edit_road,
                label: 'Ewidencja przejazdów',
                color: OspTheme.sectionTrips,
                onTap: () => context.push('/trips'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.fire_truck,
                label: 'Pojazdy (${vehicles.length})',
                color: OspTheme.sectionVehicles,
                onTap: () => context.push('/vehicles'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: OspIcons.circularSaw,
                label: 'Sprzęt (${equipment.length})',
                color: OspTheme.neutral,
                onTap: () => context.push('/equipment'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.people,
                label: 'Ratownicy (${firefighters.length})',
                color: OspTheme.sectionFirefighters,
                onTap: () => context.push('/firefighters'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.bar_chart,
                label: 'Statystyki',
                color: OspTheme.sectionStatistics,
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
              const SizedBox(height: 24),
              _CoffeeCard(onTap: _openCoffee),
              const SizedBox(height: 16),
              // Podpis autora zostaje ostatni — najdrobniejszy element strony,
              // pod wszystkim innym.
              Text(
                'Aplikację stworzył Dawid Mionskowski',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              // Zapas na systemowy pasek nawigacji — bez tego ostatnie
              // elementy listy chowają się za przyciskami telefonu.
              SizedBox(height: 12 + context.bottomInset()),
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

/// Pasek ekranu głównego: „Witaj, Dawid", a pod spodem jednostka i rola.
///
/// Zgłoszenie Dawida: na ekranie głównym nie było widać, kto jest
/// zalogowany i z jakimi uprawnieniami. Nazwa jednostki to ta zapisana
/// w telefonie, także gdy telefon nie jest połączony z żadną.
/// „Administrator" i „członek jednostki" zamiast „jesteś administratorem":
/// aplikacja nie wie, czy pisze do kobiety, czy do mężczyzny.
class _Greeting extends StatelessWidget {
  /// Wysokość paska z dwiema liniami (zwykły pasek ma 56).
  static const double barHeight = 72;

  /// Nazwa z konta Google („Dawid Mionskowski").
  final String? displayName;
  final SyncState syncState;

  /// „OSP w Kielnie" — skrócona nazwa jednostki.
  final String unitLabel;

  const _Greeting({
    required this.displayName,
    required this.syncState,
    required this.unitLabel,
  });

  /// Pierwsze słowo nazwy konta — imię.
  static String? firstName(String? displayName) {
    final first = displayName?.trim().split(RegExp(r'\s+')).first ?? '';
    return first.isEmpty ? null : first;
  }

  /// Zalogowany, ale bez jednostki — dane zostają na telefonie, a nikt
  /// poza nim ich nie zobaczy. Podpowiedź, gdzie dołączyć, jest pod paskiem.
  bool get needsUnit =>
      syncState.isConnected && syncState.unitFolderId == null;

  String get _role {
    if (!syncState.isConnected || syncState.unitFolderId == null) {
      return 'dane tylko na tym telefonie';
    }
    return syncState.isCurrentUserAdmin ? 'administrator' : 'członek jednostki';
  }

  @override
  Widget build(BuildContext context) {
    final name = firstName(displayName) ?? syncState.userEmail;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null ? 'Witaj' : 'Witaj, $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          '$unitLabel · $_role',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// Zalogowany bez jednostki: gdzie dołączyć. Na pasku zmieści się tylko
/// „dane tylko na tym telefonie", więc wskazówka stoi pod nim i od razu
/// prowadzi do Ustawień.
class _JoinUnitHint extends StatelessWidget {
  const _JoinUnitHint();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.blue[50],
      child: ListTile(
        leading: Icon(Icons.group_add, color: Colors.blue[700]),
        title: const Text('Dołącz do jednostki w Ustawieniach'),
        subtitle: const Text('Wtedy wyjazdy zobaczą też inni z jednostki'),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[500]),
        onTap: () => context.push('/settings'),
      ),
    );
  }
}

/// Karta „postaw mi kawę" w stopce ekranu głównego.
///
/// Świadomie **nie** jest kafelkiem menu: kafelki to czynności (dodaj wyjazd,
/// ewidencja, ustawienia), a prośba o wsparcie nie należy do tej samej
/// kategorii i nie powinna stać w jednym rzędzie z „Dodaj wyjazd".
/// Stąd miejsce na samym dole, pod przyciskiem wyjścia.
///
/// Klikalna jest cała karta, nie osobny przycisk w środku — większy cel
/// i mniej elementów na ekranie, który i tak jest długi.
class _CoffeeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CoffeeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OspTheme.coffeeSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OspTheme.coffee.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: OspTheme.coffee.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.coffee, size: 20, color: OspTheme.coffee),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aplikacja jest w pełni darmowa i bez reklam.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Podoba Ci się? Postaw mi kawę!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: OspTheme.coffee,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.open_in_new, size: 16, color: OspTheme.coffee),
            ],
          ),
        ),
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

    // Konto w podpowiedzi — po przytrzymaniu ikony widać, na czym się pracuje.
    final email = syncState.userEmail;
    if (email != null && email.isNotEmpty) tooltip = '$tooltip\n$email';

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
