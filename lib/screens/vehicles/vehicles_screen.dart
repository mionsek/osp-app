import '../../core/utils/bottom_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/polish_text.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_only_notice.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final syncState = ref.watch(syncStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pojazdy'),
      ),
      // Bez uprawnień administratora nie ma czego dodawać — zamiast
      // wyłączonego przycisku pokazujemy wyjaśnienie nad listą.
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/vehicles/add'),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj pojazd'),
            )
          : null,
      body: Column(
        children: [
          if (!isAdmin)
            AdminOnlyNotice(
              what: 'Listę pojazdów',
              adminEmail: syncState.founderEmail,
            ),
          Expanded(child: _buildList(context, ref, vehicles, isAdmin)),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<Vehicle> vehicles,
    bool isAdmin,
  ) {
    return vehicles.isEmpty
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
              padding: EdgeInsets.only(top: 8, bottom: 80 + context.bottomInset()),
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
                        '${vehicle.seats} ${PolishText.seats(vehicle.seats)}'),
                    trailing: !isAdmin
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Color(0xFF1565C0)),
                                onPressed: () => context
                                    .push('/vehicles/edit/${vehicle.id}'),
                                tooltip: 'Edytuj',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Color(0xFFB71C1C)),
                                onPressed: () => _confirmDelete(
                                    context, ref, vehicle.id, vehicle.name),
                                tooltip: 'Usuń',
                              ),
                            ],
                          ),
                  ),
                );
              },
            );
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
