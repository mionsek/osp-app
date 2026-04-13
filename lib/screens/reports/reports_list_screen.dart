import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';

class ReportsListScreen extends ConsumerWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista wyjazdów'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final vehicles = ref.read(vehiclesProvider);
          if (vehicles.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dodaj przynajmniej jeden pojazd bojowy'),
                backgroundColor: Color(0xFFB71C1C),
              ),
            );
            return;
          }
          context.push('/reports/new');
        },
        icon: const Icon(Icons.add),
        label: const Text('Nowy wyjazd'),
      ),
      body: reports.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Brak wyjazdów',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Card(
                  child: ListTile(
                    leading: _threatIcon(report.threatCategory),
                    title: Text(
                      '${report.reportNumber} — ${report.addressLocality}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd.MM.yyyy').format(report.date)} • '
                      '${report.threatCategory}'
                      '${report.threatSubtype != null ? " → ${report.threatSubtype}" : ""}'
                      ' • ${report.totalFirefighters} ratowników',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/reports/view/${report.id}'),
                  ),
                );
              },
            ),
    );
  }

  Widget _threatIcon(String category) {
    final lower = category.toLowerCase();
    if (lower == 'pożar') {
      return const CircleAvatar(
        backgroundColor: Color(0xFFB71C1C),
        child: Icon(Icons.local_fire_department, color: Colors.white),
      );
    } else if (lower == 'miejscowe zagrożenie') {
      return const CircleAvatar(
        backgroundColor: Color(0xFFF9A825),
        child: Icon(Icons.warning, color: Colors.white),
      );
    } else if (lower == 'fałszywy alarm') {
      return const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.block, color: Colors.white),
      );
    } else {
      return const CircleAvatar(
        backgroundColor: Color(0xFF1565C0),
        child: Icon(Icons.help_outline, color: Colors.white),
      );
    }
  }
}
