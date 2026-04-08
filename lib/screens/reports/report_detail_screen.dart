import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/pdf_service.dart';

class ReportDetailScreen extends ConsumerWidget {
  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final report = db.getReport(reportId);
    final firefighters = ref.watch(firefightersProvider);
    final config = ref.watch(unitConfigProvider);

    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Raport')),
        body: const Center(child: Text('Nie znaleziono raportu')),
      );
    }

    Firefighter? findFF(String? id) {
      if (id == null || id.isEmpty) return null;
      return firefighters.where((f) => f.id == id).firstOrNull;
    }

    String formatTime(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Wyjazd ${report.reportNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/reports/edit/${report.id}'),
            tooltip: 'Edytuj',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, ref, report),
            tooltip: 'Usuń',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('Nr ewidencyjny', report.reportNumber),
                    _Row('Data',
                        DateFormat('dd.MM.yyyy').format(report.date)),
                    _Row(
                      'Godziny',
                      '${formatTime(report.departureTime)} – ${report.returnTime != null ? formatTime(report.returnTime!) : "—"}',
                    ),
                    _Row(
                      'Adres',
                      [report.addressLocality, report.addressStreet]
                          .where((s) => s.isNotEmpty)
                          .join(', '),
                    ),
                    _Row(
                      'Zagrożenie',
                      [report.threatCategory, report.threatSubtype]
                          .where((s) => s != null && s.isNotEmpty)
                          .join(' → '),
                    ),
                    _Row('Pojazdy', '${report.vehicleCount}'),
                    _Row('Ratownicy', '${report.totalFirefighters}'),
                    if (report.operationCommanderId != null)
                      _Row('KDR',
                          findFF(report.operationCommanderId)?.fullName ?? '—'),
                    if (report.notes != null && report.notes!.isNotEmpty)
                      _Row('Uwagi', report.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            ...report.crewAssignments.map((crew) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.fire_truck,
                                color: Color(0xFFE65100)),
                            const SizedBox(width: 8),
                            Text(crew.vehicleName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                        const Divider(),
                        if (crew.driverId != null)
                          _Row('🚗 Kierowca',
                              findFF(crew.driverId)?.fullName ?? '—'),
                        if (crew.commanderId != null)
                          _Row('🎖️ Dowódca',
                              findFF(crew.commanderId)?.fullName ?? '—'),
                        ...crew.crewMemberIds
                            .where((id) => id.isNotEmpty)
                            .map((id) => _Row(
                                '   Ratownik', findFF(id)?.fullName ?? '—')),
                      ],
                    ),
                  ),
                )),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () =>
                  PdfService.generateAndPrint(report, config, firefighters),
              icon: const Icon(Icons.print),
              label: const Text('Drukuj (2 egzemplarze)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  PdfService.generateAndShare(report, config, firefighters),
              icon: const Icon(Icons.share),
              label: const Text('Udostępnij / Wyślij'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Report report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń raport'),
        content: Text(
            'Czy na pewno chcesz usunąć raport ${report.reportNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C)),
            onPressed: () {
              ref.read(reportsProvider.notifier).delete(report.id);
              Navigator.pop(ctx);
              context.go('/reports');
            },
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
