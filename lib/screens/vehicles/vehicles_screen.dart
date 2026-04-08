import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wozy bojowe'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vehicles/add'),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj wóz'),
      ),
      body: vehicles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fire_truck, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Brak pojazdów bojowych',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dodaj swój pierwszy pojazd',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.fire_truck,
                        color: Color(0xFFE65100), size: 32),
                    title: Text(
                      vehicle.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                        '${vehicle.seats} ${_seatsLabel(vehicle.seats)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.edit, color: Color(0xFF1565C0)),
                          onPressed: () =>
                              context.push('/vehicles/edit/${vehicle.id}'),
                          tooltip: 'Edytuj',
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete, color: Color(0xFFB71C1C)),
                          onPressed: () =>
                              _confirmDelete(context, ref, vehicle.id, vehicle.name),
                          tooltip: 'Usuń',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _seatsLabel(int count) {
    if (count == 1) return 'miejsce';
    if (count >= 2 && count <= 4) return 'miejsca';
    return 'miejsc';
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń pojazd'),
        content: Text('Czy na pewno chcesz usunąć "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
            ),
            onPressed: () {
              ref.read(vehiclesProvider.notifier).delete(id);
              Navigator.pop(ctx);
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }
}
