import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/osp_theme.dart';
import '../../core/utils/bottom_inset.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/admin_only_notice.dart';
import '../../widgets/navigation.dart';

/// Sprzęt jednostki pogrupowany według wozów — agregaty, pilarki, autopompy.
///
/// Z tej listy formularz przejazdu podpowiada, co pracowało. Prowadzi ją
/// administrator, jak listę pojazdów.
class EquipmentScreen extends ConsumerWidget {
  const EquipmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipment = ref.watch(equipmentProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final syncState = ref.watch(syncStateProvider);
    final withCards = equipment.where((e) => e.hasWorkCard).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprzęt'),
        actions: [
          if (withCards > 0)
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'Rozruch kontrolny',
              onPressed: () => context.push('/equipment/work/new?startup=all'),
            ),
          const HomeButton(),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/equipment/add'),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj sprzęt'),
            )
          : null,
      body: Column(
        children: [
          if (!isAdmin)
            AdminOnlyNotice(
              what: 'Listę sprzętu',
              adminEmail: syncState.founderEmail,
            ),
          if (withCards > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                'Dotknij urządzenia z własnym silnikiem, żeby zobaczyć i '
                'wydrukować jego miesięczną kartę pracy.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
              ),
            ),
          Expanded(
            child: equipment.isEmpty
                ? const _EmptyList()
                : ListView(
                    padding: EdgeInsets.only(
                        top: 8, bottom: 80 + context.bottomInset()),
                    children: [
                      for (final group in _groups(equipment, vehicles)) ...[
                        _GroupHeader(group.title),
                        for (final e in group.items)
                          _EquipmentTile(equipment: e, isAdmin: isAdmin),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Najpierw sprzęt kolejnych wozów, na końcu nieprzypisany — także ten,
  /// którego wóz usunięto.
  static List<({String title, List<Equipment> items})> _groups(
    List<Equipment> equipment,
    List<Vehicle> vehicles,
  ) {
    final vehicleIds = vehicles.map((v) => v.id).toSet();
    return [
      for (final v in vehicles)
        if (equipment.any((e) => e.vehicleId == v.id))
          (
            title: v.name,
            items: equipment.where((e) => e.vehicleId == v.id).toList(),
          ),
      if (equipment.any((e) => !vehicleIds.contains(e.vehicleId)))
        (
          title: 'Bez przypisanego wozu',
          items: equipment
              .where((e) => !vehicleIds.contains(e.vehicleId))
              .toList(),
        ),
    ];
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handyman, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Brak sprzętu',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Agregaty, pilarki, autopompy — przy przejeździe będzie '
              'można wybrać, co pracowało i jak długo.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: OspTheme.neutral,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
}

class _EquipmentTile extends ConsumerWidget {
  final Equipment equipment;
  final bool isAdmin;
  const _EquipmentTile({required this.equipment, required this.isAdmin});

  /// „Napędzany silnikiem wozu" albo „Mieszanka · 1,2 l/godz. · Stihl MS 462".
  static String details(Equipment e) => [
        if (e.poweredByVehicle) 'Napędzany silnikiem wozu',
        if (!e.poweredByVehicle && e.fuelType.isNotEmpty) e.fuelType,
        if (!e.poweredByVehicle && e.fuelPerHour != null)
          '${e.fuelPerHour.toString().replaceAll('.', ',')} l/godz.',
        if ('${e.brand} ${e.model}'.trim().isNotEmpty)
          '${e.brand} ${e.model}'.trim(),
      ].join(' · ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = details(equipment);
    return Card(
      child: ListTile(
        // Sprzęt zasilany z wozu nie ma własnej karty — jego minuty są na
        // karcie drogowej wozu.
        onTap: equipment.hasWorkCard
            ? () => context.push('/equipment/card/${equipment.id}')
            : null,
        leading: Icon(
          equipment.poweredByVehicle
              ? Icons.settings_input_component
              : Icons.handyman,
          color: OspTheme.neutral,
          size: 30,
        ),
        title: Text(
          equipment.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: !isAdmin
            ? (equipment.hasWorkCard ? const Icon(Icons.chevron_right) : null)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: OspTheme.info),
                    onPressed: () =>
                        context.push('/equipment/edit/${equipment.id}'),
                    tooltip: 'Edytuj',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: OspTheme.danger),
                    onPressed: () => _confirmDelete(context, ref),
                    tooltip: 'Usuń',
                  ),
                ],
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń sprzęt'),
        content: Text(
          'Czy na pewno usunąć „${equipment.name}"? Wpisy w ewidencji '
          'przejazdów zostaną z jego nazwą.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: OspTheme.danger),
            onPressed: () {
              ref.read(equipmentProvider.notifier).delete(equipment.id);
              Navigator.pop(ctx);
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }
}
