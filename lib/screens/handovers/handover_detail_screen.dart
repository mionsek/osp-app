import '../../core/utils/bottom_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/handover_pdf.dart';
import '../../widgets/action_strip.dart';
import '../../widgets/bluetooth_printer_picker.dart';
import '../../widgets/upload_status.dart';
import '../../core/theme/osp_theme.dart';
import '../../core/utils/time_format.dart';
import '../../widgets/navigation.dart';

class HandoverDetailScreen extends ConsumerWidget {
  final String handoverId;
  const HandoverDetailScreen({super.key, required this.handoverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    // Po pobraniu nowszej wersji z Dysku.
    ref.watch(handoversProvider);
    final handover = db.getHandover(handoverId);
    final firefighters = ref.watch(firefightersProvider);
    final config = ref.watch(unitConfigProvider);

    if (handover == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Przekazanie mienia')),
        body: const Center(child: Text('Nie znaleziono przekazania')),
      );
    }

    Firefighter? findFF(String? id) {
      if (id == null || id.isEmpty) return null;
      return firefighters.where((f) => f.id == id).firstOrNull;
    }

    final handoverFF = findFF(handover.handoverFirefighterId);

    // Cudze przekazania poprawia i usuwa tylko administrator.
    final canEdit =
        ref.watch(syncStateProvider).canEditDocument(handover.createdBy);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Przekazanie mienia'),
        actions: const [HomeButton()],
        bottom: ActionStrip([
          StripAction(
            icon: Icons.print,
            label: 'Drukuj',
            onPressed: () =>
                HandoverPdf.generateAndPrint(handover, config, handoverFF),
          ),
          // Także bez wybranej drukarki — wybór odbywa się wtedy od razu,
          // zamiast odsyłać do Ustawień.
          StripAction(
            icon: Icons.bluetooth,
            label: 'Bluetooth',
            tooltip: bluetoothTooltip(config),
            onPressed: () => printOnBluetoothPrinter(context, ref,
                () => HandoverPdf.bytes(handover, config, handoverFF)),
          ),
          StripAction(
            icon: Icons.share,
            label: 'Wyślij',
            tooltip: 'Udostępnij / wyślij (PDF)',
            onPressed: () =>
                HandoverPdf.generateAndShare(handover, config, handoverFF),
          ),
          if (canEdit) ...[
            StripAction(
              icon: Icons.edit,
              label: 'Edytuj',
              onPressed: () => context.push('/handovers/edit/${handover.id}'),
            ),
            StripAction(
              icon: Icons.delete,
              label: 'Usuń',
              danger: true,
              onPressed: () => _confirmDelete(context, ref, handover),
            ),
          ],
        ]),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + context.bottomInset()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UploadStatusBanner(
              subject: 'Przekazanie',
              pending: ref
                  .watch(handoversAwaitingUploadProvider)
                  .contains(handover.id),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('Miejsce zdarzenia', handover.eventLocation),
                    _Row('Data', TimeFormat.date(handover.eventDate)),
                    _Row('Godzina', TimeFormat.hhmm(handover.eventTime)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Przejmujący',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(),
                    _Row(
                      'Rodzaj',
                      handover.recipientTypeLabel.isEmpty
                          ? 'Nie wybrano'
                          : handover.recipientTypeLabel,
                    ),
                    _Row('Imię i nazwisko', handover.recipientName),
                    if (handover.recipientAddress.isNotEmpty)
                      _Row('Adres', handover.recipientAddress),
                    if (handover.recipientPhone.isNotEmpty)
                      _Row('Telefon', handover.recipientPhone),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Przekazywane mienie',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Divider(),
                    _Row('Kategoria', handover.propertyKind ?? 'Nie wybrano'),
                    const SizedBox(height: 8),
                    Text(handover.propertyDescription),
                    if (handover.notes != null && handover.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _Row('Uwagi', handover.notes!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('Przekazujący', handoverFF?.fullNameWithRank ?? '—'),
                    _Row('Miejscowość, dnia',
                        '${handover.signLocality}, ${TimeFormat.date(handover.signDate)}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.go('/handovers'),
              icon: const Icon(Icons.list),
              label: const Text('Lista przekazań mienia'),
            ),
            TextButton.icon(
              onPressed: () => goHome(context),
              icon: const Icon(Icons.home),
              label: const Text('Wróć do menu głównego'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, PropertyHandover handover) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń przekazanie mienia'),
        content: const Text('Czy na pewno chcesz usunąć to przekazanie mienia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: OspTheme.danger),
            onPressed: () {
              ref.read(handoversProvider.notifier).delete(handover.id);
              Navigator.pop(ctx);
              context.go('/handovers');
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
