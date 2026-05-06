import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/sync_state.dart';
import '../../providers/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(unitConfigProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final firefighters = ref.watch(firefightersProvider);
    final reports = ref.watch(reportsProvider);
    final syncState = ref.watch(syncStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(config.locality.isNotEmpty
            ? 'OSP ${config.locality}'
            : 'OSP'),
        actions: [
          _SyncIndicator(syncState: syncState, onTap: () {
            ref.read(syncStateProvider.notifier).syncNow();
          }),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
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
                icon: Icons.list_alt,
                label: 'Lista wyjazdów (${reports.length})',
                color: const Color(0xFF1565C0),
                onTap: () => context.push('/reports'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                icon: Icons.fire_truck,
                label: 'Wozy bojowe (${vehicles.length})',
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
