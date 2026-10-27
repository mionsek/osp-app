import '../../core/utils/bottom_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../models/sync_state.dart';
import '../../providers/providers.dart';
import '../../services/bluetooth_print_service.dart';
import '../../services/report_numbers.dart';
import '../../services/report_pdf.dart';
import '../../widgets/bluetooth_printer_picker.dart';
import '../../widgets/sync_feedback.dart';
import '../../core/theme/osp_theme.dart';
import '../../core/utils/time_format.dart';

class ReportDetailScreen extends ConsumerWidget {
  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  /// Druk na sparowanej drukarce termicznej Bluetooth. Gdy drukarka nie
  /// jest jeszcze wybrana, pozwalamy wybrać ją od razu tutaj.
  Future<void> _printViaBluetooth(
    BuildContext context,
    WidgetRef ref,
    Report report,
    UnitConfig config,
    List<Firefighter> firefighters,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    void show(String text, {bool ok = false}) {
      messenger.showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: ok ? OspTheme.success : Colors.red,
      ));
    }

    var mac = config.btPrinterMac;
    if (mac == null || mac.isEmpty) {
      final result = await pickBluetoothPrinter(context, ref);
      if (result.errorMessage != null) {
        show(result.errorMessage!);
        return;
      }
      if (!result.selected) return;
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
          await ReportPdf.bytes(report, config, firefighters);
      final ok = await BluetoothPrintService.printPdf(bytes);
      show(ok ? 'Wysłano do drukarki.' : 'Drukarka odrzuciła zadanie.', ok: ok);
    } catch (e) {
      show('Błąd druku: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    // Po zmianie numeru albo po pobraniu nowszej wersji z Dysku.
    ref.watch(reportsProvider);
    final report = db.getReport(reportId);
    final firefighters = ref.watch(firefightersProvider);
    final config = ref.watch(unitConfigProvider);
    final syncState = ref.watch(syncStateProvider);

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


    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/home'),
          tooltip: 'Menu główne',
        ),
        title: Text('Wyjazd ${report.reportNumber}'),
        actions: [
          // Cudze raporty poprawia i usuwa tylko administrator — autor
          // zawsze może zmienić swój własny.
          if (ref.watch(syncStateProvider).canEditDocument(report.createdBy)) ...[
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
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + context.bottomInset()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (syncState.isConnected && syncState.unitFolderId != null)
              _UploadStatus(report: report),
            _DuplicateNumberNotice(report: report),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('Nr ewidencyjny', report.reportNumber),
                    _Row('Data',
                        TimeFormat.date(report.date)),
                    _Row(
                      'Godziny',
                      TimeFormat.range(report.departureTime, report.returnTime),
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
                                color: OspTheme.sectionVehicles),
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
                              findFF(crew.driverId)?.lastNameFirst ?? '—'),
                        if (crew.commanderId != null)
                          _Row('🎖️ Dowódca',
                              findFF(crew.commanderId)?.lastNameFirst ?? '—'),
                        ...crew.crewMemberIds
                            .where((id) => id.isNotEmpty)
                            .map((id) => _Row(
                                '   Ratownik', findFF(id)?.lastNameFirst ?? '—')),
                      ],
                    ),
                  ),
                )),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () =>
                  ReportPdf.generateAndPrint(report, config, firefighters),
              icon: const Icon(Icons.print),
              label: const Text('Drukuj (2 egzemplarze)'),
            ),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final hasPrinter = config.btPrinterMac != null &&
                  config.btPrinterMac!.isNotEmpty;
              return OutlinedButton.icon(
                onPressed: () => _printViaBluetooth(
                    context, ref, report, config, firefighters),
                icon: const Icon(Icons.bluetooth),
                label: Text(hasPrinter
                    ? 'Drukuj na ${config.btPrinterName ?? "drukarce Bluetooth"}'
                    : 'Drukuj na drukarce Bluetooth...'),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  ReportPdf.generateAndShare(report, config, firefighters),
              icon: const Icon(Icons.share),
              label: const Text('Udostępnij / Wyślij'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.go('/reports'),
              icon: const Icon(Icons.list),
              label: const Text('Lista wyjazdów'),
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
                backgroundColor: OspTheme.danger),
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

/// Czy ten wyjazd jest już na Dysku jednostki.
///
/// Wcześniej pasek pisał „Zapisano na Google Drive" po każdej udanej
/// synchronizacji — także przy wyjeździe, który dopiero czekał na wysłanie.
class _UploadStatus extends ConsumerWidget {
  final Report report;
  const _UploadStatus({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncStateProvider);
    final pending =
        ref.watch(reportsAwaitingUploadProvider).contains(report.id);

    final (Color color, Color surface, IconData icon, String text) =
        switch ((pending, sync.isSyncing, sync.status == SyncStatus.error)) {
      (false, _, _) => (
          OspTheme.success,
          OspTheme.successSurface,
          Icons.cloud_done,
          'Zapisano na Dysku jednostki',
        ),
      (true, true, _) => (
          OspTheme.info,
          OspTheme.infoSurface,
          Icons.sync,
          'Wysyłanie na Dysk jednostki…',
        ),
      (true, false, true) => (
          OspTheme.danger,
          OspTheme.dangerSurface,
          Icons.cloud_off,
          'Wyjazd jest na telefonie, ale jeszcze nie na Dysku jednostki. '
              '${syncErrorText(sync)}',
        ),
      (true, false, false) => (
          OspTheme.attention,
          OspTheme.attentionSurface,
          Icons.cloud_upload,
          'Czeka na wysłanie na Dysk jednostki',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)),
          ),
          if (pending && !sync.isSyncing)
            TextButton(
              onPressed: () => runManualSync(context, ref),
              child: const Text('Wyślij teraz'),
            ),
        ],
      ),
    );
  }
}

/// Ten sam numer ma inny wyjazd — zwykle dwa telefony nadały go w tych
/// samych minutach, zanim któryś wysłał swój wyjazd na Dysk.
///
/// Wcześniej było o tym tylko 6 sekund paska na ekranie głównym.
class _DuplicateNumberNotice extends ConsumerWidget {
  final Report report;
  const _DuplicateNumberNotice({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(reportsProvider);
    final db = ref.watch(databaseServiceProvider);
    final others = db.reportsWithNumber(report.reportNumber, exceptId: report.id);
    if (others.isEmpty) return const SizedBox.shrink();

    final canEdit =
        ref.watch(syncStateProvider).canEditDocument(report.createdBy);
    final next = db.nextReportNumberFor(report.reportNumber,
        fallbackYear: report.year);

    // Dwa raporty z tej samej akcji — tu automat numeru nie zmienia.
    final sameIncident =
        others.any((o) => ReportNumbers.looksLikeSameIncident(o, report));

    String describe(Report r) => [
          '${TimeFormat.date(r.date)} ${TimeFormat.hhmm(r.departureTime)}',
          [r.addressLocality, r.threatCategory]
              .where((s) => s.isNotEmpty)
              .join(' — '),
          if (r.createdBy.isNotEmpty) 'z konta ${r.createdBy}',
        ].join(', ');

    return Card(
      color: OspTheme.attentionSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: OspTheme.attention),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sameIncident
                        ? 'Ten sam wyjazd zapisany dwa razy?'
                        : 'Numer ${report.reportNumber} ma też inny wyjazd',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: OspTheme.attention,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (sameIncident)
              Text('Numer ${report.reportNumber} ma też wyjazd z tego samego '
                  'dnia i podobnej godziny:'),
            for (final r in others) Text('• ${describe(r)}'),
            const SizedBox(height: 8),
            Text(
              [
                sameIncident
                    ? 'Jeśli to ta sama akcja, usuń jeden z wyjazdów (kosz '
                        'u góry ekranu). Jeśli to różne wyjazdy, nadaj temu '
                        'nowy numer.'
                    : 'Późniejszy z wyjazdów dostanie nowy numer sam, przy '
                        'synchronizacji telefonu, z którego go dodano.',
                if (!canEdit)
                  'Numer tego wyjazdu może zmienić jego autor albo '
                      'administrator.',
              ].join(' '),
            ),
            if (canEdit) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _renumber(context, ref, next),
                child: Text('Nadaj temu wyjazdowi numer $next'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _renumber(
      BuildContext context, WidgetRef ref, String next) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Zmienić numer na $next?'),
        content: Text(
          'Wyjazd ${report.reportNumber} dostanie numer $next — także na '
          'Dysku jednostki i u kolegów. Jeśli był już wydrukowany, popraw '
          'numer na wydruku.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zmień numer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final number =
        await ref.read(reportsProvider.notifier).assignNextNumber(report);
    messenger.showSnackBar(SnackBar(
      content: Text('Wyjazd ma teraz numer $number.'),
      backgroundColor: OspTheme.success,
    ));
  }
}
