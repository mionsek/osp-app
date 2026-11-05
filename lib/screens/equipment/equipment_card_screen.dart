import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/osp_theme.dart';
import '../../core/utils/bottom_inset.dart';
import '../../core/utils/polish_text.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/equipment_card.dart';
import '../../services/equipment_card_pdf.dart';
import '../../services/pdf_output.dart';
import '../../widgets/bluetooth_printer_picker.dart';
import '../../widgets/month_picker.dart';
import '../../widgets/navigation.dart';

/// Miesięczna karta pracy jednego urządzenia z własnym silnikiem.
///
/// Wiersze zbierają się same: praca przy akcjach i ćwiczeniach z przejazdów,
/// rozruchy kontrolne z wpisów dodanych tutaj. Każde urządzenie ma w gminie
/// osobną kartę (Dering, listopad 2026).
class EquipmentCardScreen extends ConsumerStatefulWidget {
  final String equipmentId;
  const EquipmentCardScreen({super.key, required this.equipmentId});

  @override
  ConsumerState<EquipmentCardScreen> createState() =>
      _EquipmentCardScreenState();
}

enum _CardOutput { system, bluetooth, share }

class _EquipmentCardScreenState extends ConsumerState<EquipmentCardScreen> {
  late CardMonth _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = (year: now.year, month: now.month);
    // Rozruchy i przejazdy kolegów — jak przy ewidencji przejazdów.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(syncStateProvider.notifier).syncIfStale();
    });
  }

  List<EquipmentCardRow> _rows(Equipment device) {
    final db = ref.read(databaseServiceProvider);
    return EquipmentCard.rows(
      device: device,
      year: _month.year,
      month: _month.month,
      trips: ref.watch(vehicleTripsProvider),
      work: ref.watch(equipmentWorkProvider),
      equipment: ref.watch(equipmentProvider),
      reportOf: db.getReport,
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = ref
        .watch(equipmentProvider)
        .where((e) => e.id == widget.equipmentId)
        .firstOrNull;
    if (device == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Karta pracy'),
          actions: const [HomeButton()],
        ),
        body: const Center(child: Text('Nie znaleziono sprzętu')),
      );
    }
    final rows = _rows(device);
    final notice = _missingDataNotice(device);

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Drukuj kartę pracy',
            onPressed: () => _output(device, rows, _CardOutput.system),
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth),
            tooltip: 'Drukuj na drukarce Bluetooth',
            onPressed: () => _output(device, rows, _CardOutput.bluetooth),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Udostępnij / wyślij kartę',
            onPressed: () => _output(device, rows, _CardOutput.share),
          ),
          const HomeButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/equipment/work/new?equipmentId=${device.id}'),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj pracę'),
      ),
      body: Column(
        children: [
          _monthSelector(device),
          _summary(device, rows),
          // Nie `?notice` — patrz ewidencja przejazdów (hive_generator).
          // ignore: use_null_aware_elements
          if (notice != null) notice,
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyMonth()
                : ListView.builder(
                    padding: EdgeInsets.only(
                        top: 8, bottom: 88 + context.bottomInset()),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => _RowTile(rows[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _monthSelector(Equipment device) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: InkWell(
          onTap: () => _pickMonth(device),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Miesiąc',
              border: OutlineInputBorder(),
              isDense: true,
              suffixIcon: Icon(Icons.arrow_drop_down),
            ),
            child: Text(PolishText.monthLabel(_month.month, _month.year)),
          ),
        ),
      );

  /// To samo, co trafia do pozycji 4–7 rozliczenia na odwrocie karty.
  Widget _summary(Equipment device, List<EquipmentCardRow> rows) {
    final totals = EquipmentCard.totals(device, rows);
    final fuel = totals.totalFuel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chip(Icons.timer_outlined,
                'praca ${EquipmentCard.hoursAndMinutes(totals.workMinutes)}'),
            if (totals.startupMinutes > 0)
              _chip(Icons.power_settings_new,
                  'rozruchy ${EquipmentCard.hoursAndMinutes(totals.startupMinutes)}'),
            if (fuel != null && fuel > 0)
              _chip(Icons.local_gas_station,
                  'paliwo ${PdfOutput.number(fuel)} l'),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    final c = Colors.grey[700]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Bez normy i rodzaju paliwa rozliczenie na odwrocie wychodzi puste —
  /// lepiej to powiedzieć przed drukiem niż po.
  Widget? _missingDataNotice(Equipment device) {
    final missing = [
      if (device.fuelPerHour == null) 'normy zużycia paliwa',
      if (device.settlementColumn == null) 'rodzaju paliwa',
    ];
    if (missing.isEmpty) return null;
    final isAdmin = ref.watch(isAdminProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: OspTheme.vehiclesSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isAdmin
              ? () => context.push('/equipment/edit/${device.id}')
              : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Icon(Icons.local_gas_station,
                    size: 19, color: OspTheme.attention),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Brak ${missing.join(' i ')} — rozliczenie paliwa na '
                    'karcie zostanie puste. '
                    '${isAdmin ? 'Dotknij, żeby uzupełnić.' : 'Uzupełnić może administrator.'}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[850]),
                  ),
                ),
                if (isAdmin) const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth(Equipment device) async {
    final picked = await pickCardMonth(
      context,
      months: EquipmentCard.months(
        device: device,
        trips: ref.read(vehicleTripsProvider),
        work: ref.read(equipmentWorkProvider),
        equipment: ref.read(equipmentProvider),
      ),
      selected: _month,
    );
    if (picked != null && mounted) setState(() => _month = picked);
  }

  Future<void> _output(
    Equipment device,
    List<EquipmentCardRow> rows,
    _CardOutput output,
  ) async {
    if (rows.isEmpty && !await _confirmEmptyCard()) return;
    if (!mounted) return;
    final config = ref.read(unitConfigProvider);
    try {
      switch (output) {
        case _CardOutput.system:
          await EquipmentCardPdf.generateAndPrint(
            device: device,
            rows: rows,
            config: config,
            year: _month.year,
            month: _month.month,
          );
        case _CardOutput.share:
          await EquipmentCardPdf.generateAndShare(
            device: device,
            rows: rows,
            config: config,
            year: _month.year,
            month: _month.month,
          );
        case _CardOutput.bluetooth:
          await printOnBluetoothPrinter(
            context,
            ref,
            () => EquipmentCardPdf.bytes(
              device: device,
              rows: rows,
              config: config,
              year: _month.year,
              month: _month.month,
            ),
            rotate90: false,
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się przygotować wydruku: $e')),
        );
      }
    }
  }

  Future<bool> _confirmEmptyCard() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Miesiąc bez pracy'),
        content: Text(
          'W tym miesiącu (${PolishText.monthLabel(_month.month, _month.year)}) '
          'urządzenie nie ma jeszcze żadnego wpisu. Karta wyjdzie z nagłówkiem '
          'urządzenia i pustymi wierszami — do wypełnienia długopisem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Drukuj pustą kartę'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }
}

class _RowTile extends StatelessWidget {
  final EquipmentCardRow row;
  const _RowTile(this.row);

  @override
  Widget build(BuildContext context) {
    final fromTrip = row.tripId != null;
    final operator = row.operatorName.trim().isEmpty
        ? 'obsługujący nie wpisany'
        : row.operatorName;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        onTap: () => context.push(fromTrip
            ? '/trips/edit/${row.tripId}'
            : '/equipment/work/edit/${row.workId}'),
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: OspTheme.neutral.withValues(alpha: 0.15),
          child: Icon(
            row.isStartup
                ? Icons.power_settings_new
                : fromTrip
                    ? Icons.fire_truck
                    : Icons.handyman,
            size: 18,
            color: OspTheme.neutral,
          ),
        ),
        title: Text(
          row.purpose.isEmpty ? '—' : row.purpose,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${DateFormat('dd.MM').format(row.date)} · $operator'
          '${fromTrip ? ' · z przejazdu' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text('${row.minutes} min',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 14),
            Text(
              'Brak pracy w tym miesiącu',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Praca przy akcjach dopisuje się sama z ewidencji przejazdów. '
              'Rozruch kontrolny dodaj przyciskiem poniżej.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
