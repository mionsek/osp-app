import '../../core/utils/bottom_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';

class HandoversListScreen extends ConsumerWidget {
  const HandoversListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handovers = ref.watch(handoversProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Przekazania mienia'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final firefighters = ref.read(firefightersProvider);
          if (firefighters.isEmpty) {
            _showNoFirefightersDialog(context);
          } else {
            context.push('/handovers/new');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nowe przekazanie'),
      ),
      body: handovers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Brak przekazań mienia',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(top: 8, bottom: 80 + context.bottomInset()),
              itemCount: handovers.length,
              itemBuilder: (context, index) {
                final h = handovers[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF6D4C41),
                      child: Icon(Icons.inventory_2, color: Colors.white),
                    ),
                    title: Text(
                      h.eventLocation.isNotEmpty
                          ? h.eventLocation
                          : 'Bez lokalizacji',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd.MM.yyyy').format(h.eventDate)} • '
                      'Przejmujący: ${h.recipientName.isNotEmpty ? h.recipientName : "—"}'
                      '${h.recipientTypeLabel.isNotEmpty ? " (${h.recipientTypeLabel})" : ""}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/handovers/view/${h.id}'),
                  ),
                );
              },
            ),
    );
  }

  void _showNoFirefightersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brak ratowników'),
        content: const Text(
          'Nie masz dodanych żadnych ratowników. Dodaj przynajmniej jednego, '
          'aby wskazać przekazującego na potwierdzeniu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/firefighters');
            },
            child: const Text('Dodaj ratownika'),
          ),
        ],
      ),
    );
  }
}
