import '../../core/utils/bottom_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/bluetooth_print_service.dart';
import '../../services/handover_pdf.dart';
import '../../widgets/bluetooth_printer_picker.dart';
import '../../core/theme/osp_theme.dart';

class HandoverDetailScreen extends ConsumerWidget {
  final String handoverId;
  const HandoverDetailScreen({super.key, required this.handoverId});

  /// Druk na sparowanej drukarce termicznej Bluetooth — z pominięciem
  /// systemowego okna drukowania, którego takie drukarki nie obsługują.
  Future<void> _printViaBluetooth(
    BuildContext context,
    WidgetRef ref,
    PropertyHandover handover,
    UnitConfig config,
    Firefighter? handoverFF,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    void show(String text, {bool ok = false}) {
      messenger.showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: ok ? OspTheme.success : Colors.red,
      ));
    }

    var mac = config.btPrinterMac;
    // Gdy drukarka nie jest jeszcze wybrana, pozwalamy wybrać ją od razu
    // tutaj — bez odsyłania użytkownika do Ustawień.
    if (mac == null || mac.isEmpty) {
      final result = await pickBluetoothPrinter(context, ref);
      if (result.errorMessage != null) {
        show(result.errorMessage!);
        return;
      }
      if (!result.selected) return; // użytkownik zrezygnował
      mac = ref.read(unitConfigProvider).btPrinterMac;
      if (mac == null || mac.isEmpty) return;
    }
    try {
      if (!await BluetoothPrintService.ensurePermission()) {
        show('Brak zgody na dostęp do Bluetooth.');
        return;
      }
      if (!await BluetoothPrintService.connectIfNeeded(mac)) {
        show('Nie udało się połączyć z drukarką.');
        return;
      }
      messenger.showSnackBar(const SnackBar(
        content: Text('Wysyłanie do drukarki...'),
        duration: Duration(seconds: 2),
      ));
      final bytes =
          await HandoverPdf.bytes(handover, config, handoverFF);
      final ok = await BluetoothPrintService.printPdf(bytes);
      show(
        ok ? 'Wysłano do drukarki.' : 'Drukarka odrzuciła zadanie.',
        ok: ok,
      );
    } catch (e) {
      show('Błąd druku: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
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
    String formatTime(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/home'),
          tooltip: 'Menu główne',
        ),
        title: const Text('Przekazanie mienia'),
        actions: [
          // Cudze przekazania poprawia i usuwa tylko administrator.
          if (ref
              .watch(syncStateProvider)
              .canEditDocument(handover.createdBy)) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/handovers/edit/${handover.id}'),
              tooltip: 'Edytuj',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context, ref, handover),
              tooltip: 'Usuń',
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + context.bottomInset()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('Miejsce zdarzenia', handover.eventLocation),
                    _Row('Data', DateFormat('dd.MM.yyyy').format(handover.eventDate)),
                    _Row('Godzina', formatTime(handover.eventTime)),
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
                        '${handover.signLocality}, ${DateFormat('dd.MM.yyyy').format(handover.signDate)}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => HandoverPdf.generateAndPrint(
                  handover, config, handoverFF),
              icon: const Icon(Icons.print),
              label: const Text('Drukuj'),
            ),
            const SizedBox(height: 8),
            // Przycisk jest widoczny również wtedy, gdy drukarka nie jest
            // jeszcze wybrana — wybór odbywa się wtedy od razu tutaj,
            // zamiast odsyłać użytkownika do Ustawień.
            Builder(builder: (context) {
              final hasPrinter = config.btPrinterMac != null &&
                  config.btPrinterMac!.isNotEmpty;
              return OutlinedButton.icon(
                onPressed: () => _printViaBluetooth(
                    context, ref, handover, config, handoverFF),
                icon: const Icon(Icons.bluetooth),
                label: Text(hasPrinter
                    ? 'Drukuj na ${config.btPrinterName ?? "drukarce Bluetooth"}'
                    : 'Drukuj na drukarce Bluetooth...'),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => HandoverPdf.generateAndShare(
                  handover, config, handoverFF),
              icon: const Icon(Icons.share),
              label: const Text('Udostępnij / Wyślij'),
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
              onPressed: () => context.go('/home'),
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
