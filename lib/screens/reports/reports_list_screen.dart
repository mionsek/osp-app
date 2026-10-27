import '../../core/utils/bottom_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../widgets/sync_feedback.dart';
import '../../widgets/upload_status.dart';
import '../../core/theme/osp_theme.dart';
import '../../core/utils/time_format.dart';
import '../../widgets/navigation.dart';

class ReportsListScreen extends ConsumerWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);
    final awaitingUpload = ref.watch(reportsAwaitingUploadProvider);
    // Ten sam numer na dwóch wyjazdach — oznaczony przy każdym z nich, aż
    // ktoś nada jednemu nowy.
    final numberCounts = <String, int>{};
    for (final r in reports) {
      numberCounts[r.reportNumber] = (numberCounts[r.reportNumber] ?? 0) + 1;
    }

    return SyncOnOpen(child: Scaffold(
      appBar: AppBar(
        title: const Text('Lista wyjazdów'),
        actions: const [HomeButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final vehicles = ref.read(vehiclesProvider);
          if (vehicles.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dodaj przynajmniej jeden pojazd bojowy'),
                backgroundColor: OspTheme.danger,
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
              padding: EdgeInsets.only(top: 8, bottom: 80 + context.bottomInset()),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final duplicated = (numberCounts[report.reportNumber] ?? 0) > 1;
                return Card(
                  child: ListTile(
                    leading: _threatIcon(report.threatCategory),
                    title: Text(
                      '${report.reportNumber} — ${report.addressLocality}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${TimeFormat.date(report.date)} • '
                          '${report.threatCategory}'
                          '${report.threatSubtype != null ? " → ${report.threatSubtype}" : ""}'
                          ' • ${report.totalFirefighters} ratowników',
                        ),
                        if (duplicated)
                          const Text(
                            'Ten sam numer ma inny wyjazd',
                            style: TextStyle(
                              color: OspTheme.attention,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (awaitingUpload.contains(report.id))
                          const AwaitingUploadIcon(),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => context.push('/reports/view/${report.id}'),
                  ),
                );
              },
            ),
    ));
  }

  Widget _threatIcon(String category) {
    final lower = category.toLowerCase();
    if (lower == 'pożar') {
      return const CircleAvatar(
        backgroundColor: OspTheme.danger,
        child: Icon(Icons.local_fire_department, color: Colors.white),
      );
    } else if (lower == 'miejscowe zagrożenie') {
      return const CircleAvatar(
        backgroundColor: OspTheme.warning,
        child: Icon(Icons.warning, color: Colors.white),
      );
    } else if (lower == 'fałszywy alarm') {
      return const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.block, color: Colors.white),
      );
    } else {
      return const CircleAvatar(
        backgroundColor: OspTheme.info,
        child: Icon(Icons.help_outline, color: Colors.white),
      );
    }
  }
}
