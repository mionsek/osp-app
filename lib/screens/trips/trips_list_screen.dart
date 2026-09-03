import '../../core/utils/bottom_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../core/utils/polish_text.dart';
import '../../services/trip_odometer.dart';
import '../../services/bluetooth_print_service.dart';
import '../../widgets/bluetooth_printer_picker.dart';
import '../../services/trip_card_pdf.dart';
import '../../core/theme/osp_theme.dart';

/// Ewidencja przejazdów pojazdu — odpowiednik miesięcznej karty drogowej.
///
/// Karta to nie osobny byt, tylko widok: para *pojazd + miesiąc*. Dlatego
/// ekran zaczyna się od wyboru pojazdu, a nie od listy „kart" do założenia.
class TripsListScreen extends ConsumerStatefulWidget {
  const TripsListScreen({super.key});

  @override
  ConsumerState<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends ConsumerState<TripsListScreen> {
  String? _vehicleId;
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);

    // Pierwszy pojazd jako domyślny — w większości jednostek i tak jest jeden
    // używany na co dzień, a pusty ekran wyboru niczego nie wnosi.
    if (_vehicleId == null && vehicles.isNotEmpty) {
      _vehicleId = vehicles.first.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ewidencja przejazdów'),
        actions: [
          if (vehicles.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Drukuj kartę drogową',
              onPressed: () => _printCard(vehicles, _CardOutput.system),
            ),
            IconButton(
              icon: const Icon(Icons.bluetooth),
              tooltip: 'Drukuj na drukarce Bluetooth',
              onPressed: () => _printCard(vehicles, _CardOutput.bluetooth),
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Udostępnij / wyślij kartę',
              onPressed: () => _printCard(vehicles, _CardOutput.share),
            ),
          ],
        ],
      ),
      floatingActionButton: vehicles.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/trips/new?vehicleId=$_vehicleId'),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj przejazd'),
            ),
      body: vehicles.isEmpty ? _noVehicles(context) : _card(context, vehicles),
    );
  }

  /// Drukuje, wysyła na drukarkę Bluetooth albo udostępnia kartę drogową
  /// wybranego pojazdu za wybrany miesiąc.
  ///
  /// Karta powstaje z tego, co widać na ekranie — ta sama para pojazd + miesiąc,
  /// więc nie ma osobnego okna wyboru zakresu.
  Future<void> _printCard(List<Vehicle> vehicles, _CardOutput output) async {
    final vehicle = vehicles.where((v) => v.id == _vehicleId).firstOrNull;
    if (vehicle == null) return;

    final trips = ref.read(tripsForCardProvider(
      (vehicleId: _vehicleId!, year: _year, month: _month),
    ));

    // Miesiąc bez przejazdów nie blokuje druku. Papierową kartę zakłada się
    // **na początku miesiąca** i wypełnia długopisem w trakcie, więc czysty
    // formularz z nagłówkiem pojazdu jest osobną, sensowną potrzebą. Pytamy
    // jednak wprost, żeby nikt nie oddał gminy pustej kartki przez pomyłkę.
    if (trips.isEmpty && !await _confirmEmptyCard()) return;

    final config = ref.read(unitConfigProvider);
    try {
      switch (output) {
        case _CardOutput.system:
          await TripCardPdf.generateAndPrint(
            trips: trips,
            vehicle: vehicle,
            config: config,
            year: _year,
            month: _month,
          );
        case _CardOutput.share:
          await TripCardPdf.generateAndShare(
            trips: trips,
            vehicle: vehicle,
            config: config,
            year: _year,
            month: _month,
          );
        case _CardOutput.bluetooth:
          await _printViaBluetooth(vehicle, config, trips);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się przygotować wydruku: $e')),
        );
      }
    }
  }

  /// Pyta, czy naprawdę wydrukować kartę za miesiąc bez ani jednego przejazdu.
  Future<bool> _confirmEmptyCard() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Miesiąc bez przejazdów'),
        // Nazwa miesiąca w nawiasie, a nie po przyimku: `monthLabel` zwraca
        // mianownik („wrzesień 2026"), więc „W wrzesień 2026" byłoby błędem.
        // Nawias omija odmianę zamiast dokładać tablicę przypadków dla jednego
        // komunikatu.
        content: Text(
          'W tym miesiącu (${PolishText.monthLabel(_month, _year)}) nie ma '
          'jeszcze żadnego przejazdu. Karta wyjdzie z nagłówkiem pojazdu '
          'i pustymi wierszami — do wypełnienia długopisem.',
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

  /// Druk karty na sparowanej drukarce termicznej Bluetooth.
  ///
  /// Karta jest w A4 poziomo, ale drukarka ma szerokość A4, więc obrót o 90°
  /// przy renderowaniu układa ją wzdłuż taśmy — dokładnie tak, jak działa to
  /// od feature/016 dla raportu i przekazania mienia.
  Future<void> _printViaBluetooth(
    Vehicle vehicle,
    UnitConfig config,
    List<VehicleTrip> trips,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    void show(String text, {bool ok = false}) {
      messenger.showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: ok ? OspTheme.success : OspTheme.danger,
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
    final bytes = await TripCardPdf.bytes(
      trips: trips,
      vehicle: vehicle,
      config: ref.read(unitConfigProvider),
      year: _year,
      month: _month,
    );
    final ok = await BluetoothPrintService.printPdf(bytes);
    show(ok ? 'Wysłano do drukarki.' : 'Drukarka odrzuciła zadanie.', ok: ok);
  }

  Widget _noVehicles(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fire_truck, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Najpierw dodaj pojazd',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ewidencję przejazdów prowadzi się osobno dla każdego pojazdu, '
              'więc bez pojazdu nie ma czego zapisywać.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, List<Vehicle> vehicles) {
    final trips = ref.watch(tripsForCardProvider(
      (vehicleId: _vehicleId!, year: _year, month: _month),
    ));
    final km = TripOdometer.distanceInMonth(
      ref.watch(vehicleTripsProvider),
      vehicleId: _vehicleId!,
      year: _year,
      month: _month,
    );

    final vehicle = vehicles.where((v) => v.id == _vehicleId).firstOrNull;
    final normsNotice =
        vehicle == null ? null : _missingNormsNotice(context, vehicle);

    return Column(
      children: [
        _selectors(vehicles),
        _summary(context, trips, km),
        ?normsNotice,
        const Divider(height: 1),
        Expanded(
          child: trips.isEmpty
              ? _emptyMonth(context)
              : ListView.builder(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: 88 + context.bottomInset(),
                  ),
                  itemCount: trips.length,
                  itemBuilder: (context, i) => _tripTile(context, trips[i], i + 1),
                ),
        ),
      ],
    );
  }

  Widget _selectors(List<Vehicle> vehicles) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: _vehicleId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pojazd',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: vehicles
                  .map((v) => DropdownMenuItem(
                        value: v.id,
                        child: Text(v.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _vehicleId = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _pickMonth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Miesiąc',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(
                  PolishText.monthLabel(_month, _year),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Podsumowanie miesiąca — to samo, co wchodzi do rozliczenia na wydruku.
  ///
  /// Minuty urządzeń i postoju są tu dlatego, że to **one** trafiają do pozycji
  /// 5 i 7 rozliczenia materiałów pędnych. Bez nich nie dało się sprawdzić przed
  /// drukiem, czy karta wyjdzie kompletna — liczby widać było dopiero na kartce.
  ///
  /// `Wrap` zamiast `Row`, bo pięć znaczników nie mieści się w jednej linii
  /// na węższym telefonie.
  Widget _summary(BuildContext context, List<VehicleTrip> trips, int km) {
    final open = trips.where((t) => !t.isClosed).length;
    final equipment =
        trips.fold(0, (sum, t) => sum + t.totalEquipmentMinutes);
    final idle = trips.fold(0, (sum, t) => sum + (t.idleMinutes ?? 0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _chip(Icons.route, '${trips.length} ${PolishText.trips(trips.length)}'),
          _chip(Icons.speed, '$km km'),
          if (equipment > 0)
            _chip(Icons.settings_input_component, 'urządzenia $equipment min'),
          if (idle > 0) _chip(Icons.motion_photos_pause, 'postój $idle min'),
          if (open > 0)
            _chip(Icons.pending_outlined, '$open bez powrotu',
                color: OspTheme.attention),
        ],
      ),
    );
  }

  /// Ostrzeżenie, że pojazd nie ma norm zużycia paliwa.
  ///
  /// Bez nich rozliczenie na drugiej stronie karty drukuje się **puste** —
  /// pozycje 4, 5, 7, 8 i 9 wychodzą bez liczb. Zachowanie jest celowe (lepiej
  /// puste niż zmyślone), ale dotąd nic o tym nie mówiło: sekcja „Dane do karty
  /// drogowej" w formularzu pojazdu jest zwijana i domyślnie zamknięta, więc
  /// łatwo ją pominąć, a skutek widać dopiero na wydrukowanej kartce dla gminy.
  Widget? _missingNormsNotice(BuildContext context, Vehicle vehicle) {
    final missing = <String>[
      if (vehicle.fuelPer100Km == null) 'na 100 km',
      if (vehicle.pumpFuelPerHour == null) 'autopompy',
      if (vehicle.idleFuelPerMinute == null) 'pracy na postoju',
      if (vehicle.startupFuelPerMonth == null) 'rozruchu',
    ];
    if (missing.isEmpty) return null;

    final all = missing.length == 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: OspTheme.vehiclesSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/vehicles/edit/${vehicle.id}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_gas_station,
                    size: 19, color: OspTheme.attention),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    all
                        ? 'Pojazd nie ma wpisanych norm zużycia paliwa — '
                            'rozliczenie na karcie wydrukuje się puste. '
                            'Dotknij, żeby je uzupełnić.'
                        : 'Brakuje norm zużycia: ${missing.join(', ')}. '
                            'Te pozycje rozliczenia zostaną na karcie puste. '
                            'Dotknij, żeby je uzupełnić.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[850]),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) {
    final c = color ?? Colors.grey[700]!;
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

  Widget _emptyMonth(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 14),
            Text(
              'Brak przejazdów w tym miesiącu',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wyjazdy alarmowe dopisują się tu same po zapisaniu raportu. '
              'Gospodarcze i tankowanie dodaj przyciskiem poniżej.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripTile(BuildContext context, VehicleTrip trip, int rowNumber) {
    final time = trip.departureTime;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final day = trip.date.day.toString().padLeft(2, '0');
    final mon = trip.date.month.toString().padLeft(2, '0');

    final distance = trip.distance;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        onTap: () => context.push('/trips/edit/${trip.id}'),
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: _purposeColor(trip.purpose).withValues(alpha: 0.15),
          child: Icon(_purposeIcon(trip.purpose),
              size: 18, color: _purposeColor(trip.purpose)),
        ),
        title: Text(
          trip.routeLabel.isEmpty ? trip.purpose : trip.routeLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('$day.$mon, $hh:$mm · ${trip.purpose}'),
            if (trip.driverName.trim().isNotEmpty)
              Text('Kierowca: ${trip.driverName}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            // Nazywamy dokładnie to, czego brakuje. Wspólny komunikat
            // „brak licznika" wysyłał szukać liczby, która bywa już wpisana.
            if (_missingLabel(trip) != null)
              Text(_missingLabel(trip)!,
                  style: const TextStyle(
                      color: OspTheme.attention, fontWeight: FontWeight.w600)),
            if (trip.hasOdometerConflict)
              const Text('Licznik po powrocie mniejszy niż przed wyjazdem',
                  style: TextStyle(
                      color: OspTheme.danger, fontWeight: FontWeight.w600)),
          ],
        ),
        isThreeLine: true,
        trailing: distance == null
            ? Text('#$rowNumber', style: TextStyle(color: Colors.grey[500]))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$distance km',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('#$rowNumber',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
      ),
    );
  }

  /// Czego brakuje, żeby wiersz karty był kompletny — albo `null`, gdy nic.
  String? _missingLabel(VehicleTrip trip) {
    final noTime = trip.returnTime == null;
    final noOdometer = trip.odometerEnd == null;
    if (noTime && noOdometer) return 'Brak godziny przyjazdu i licznika';
    if (noOdometer) return 'Brak stanu licznika po powrocie';
    if (noTime) return 'Brak godziny przyjazdu';
    return null;
  }

  IconData _purposeIcon(String purpose) {
    switch (purpose) {
      case TripPurposes.alarm:
        return Icons.local_fire_department;
      case TripPurposes.refuelling:
        return Icons.local_gas_station;
      case TripPurposes.training:
        return Icons.school;
      case TripPurposes.service:
        return Icons.build;
      default:
        return Icons.directions_car;
    }
  }

  Color _purposeColor(String purpose) {
    switch (purpose) {
      case TripPurposes.alarm:
        return OspTheme.sectionReports;
      case TripPurposes.refuelling:
        return OspTheme.info;
      default:
        return OspTheme.neutral;
    }
  }

  Future<void> _pickMonth() async {
    final months = ref.read(tripMonthsProvider(_vehicleId!));
    final now = DateTime.now();

    // Zawsze bieżący miesiąc na liście, nawet gdy jeszcze pusty — bez tego
    // nie dałoby się wrócić do „teraz" po zajrzeniu do archiwum.
    final options = <({int year, int month})>[
      if (!months.any((m) => m.year == now.year && m.month == now.month))
        (year: now.year, month: now.month),
      ...months,
    ];

    final picked = await showModalBottomSheet<({int year, int month})>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Wybierz miesiąc',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            for (final m in options)
              ListTile(
                title: Text(PolishText.monthLabel(m.month, m.year)),
                selected: m.year == _year && m.month == _month,
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _year = picked.year;
        _month = picked.month;
      });
    }
  }
}

/// Sposób wyprowadzenia karty drogowej z ekranu ewidencji.
///
/// Trzy drogi, bo trzy różne sytuacje: drukarka w sieci (Mopria), przenośna
/// drukarka termiczna sparowana przez Bluetooth i wysyłka pliku, gdy karta
/// ma trafić do gminy mailem.
enum _CardOutput { system, bluetooth, share }
