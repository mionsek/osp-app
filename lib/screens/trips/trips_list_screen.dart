import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/trip_odometer.dart';
import '../../widgets/banner_ad_widget.dart';

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

  static const List<String> _monthNames = [
    'styczeń', 'luty', 'marzec', 'kwiecień', 'maj', 'czerwiec',
    'lipiec', 'sierpień', 'wrzesień', 'październik', 'listopad', 'grudzień',
  ];

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);

    // Pierwszy pojazd jako domyślny — w większości jednostek i tak jest jeden
    // używany na co dzień, a pusty ekran wyboru niczego nie wnosi.
    if (_vehicleId == null && vehicles.isNotEmpty) {
      _vehicleId = vehicles.first.id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ewidencja przejazdów')),
      bottomNavigationBar: const BannerAdWidget(),
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

    return Column(
      children: [
        _selectors(vehicles),
        _summary(context, trips, km),
        const Divider(height: 1),
        Expanded(
          child: trips.isEmpty
              ? _emptyMonth(context)
              : ListView.builder(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: 88 + MediaQuery.viewPaddingOf(context).bottom,
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
                  '${_monthNames[_month - 1]} $_year',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, List<VehicleTrip> trips, int km) {
    final open = trips.where((t) => !t.isClosed).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          _chip(Icons.route, '${trips.length} ${_tripsLabel(trips.length)}'),
          const SizedBox(width: 8),
          _chip(Icons.speed, '$km km'),
          if (open > 0) ...[
            const SizedBox(width: 8),
            _chip(Icons.pending_outlined, '$open bez powrotu',
                color: const Color(0xFFE65100)),
          ],
        ],
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

  String _tripsLabel(int n) {
    if (n == 1) return 'przejazd';
    final lastTwo = n % 100;
    if (lastTwo >= 12 && lastTwo <= 14) return 'przejazdów';
    final last = n % 10;
    if (last >= 2 && last <= 4) return 'przejazdy';
    return 'przejazdów';
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
                      color: Color(0xFFE65100), fontWeight: FontWeight.w600)),
            if (trip.hasOdometerConflict)
              const Text('Licznik po powrocie mniejszy niż przed wyjazdem',
                  style: TextStyle(
                      color: Color(0xFFB71C1C), fontWeight: FontWeight.w600)),
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
        return const Color(0xFFB71C1C);
      case TripPurposes.refuelling:
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF546E7A);
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
                title: Text('${_monthNames[m.month - 1]} ${m.year}'),
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
