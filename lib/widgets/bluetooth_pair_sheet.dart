import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../services/bluetooth_pairing_service.dart';

/// Wyszukanie drukarki w pobliżu i sparowanie jej bez wychodzenia
/// z aplikacji. Zwraca sparowane urządzenie albo `null`.
///
/// Dotąd trzeba było sparować drukarkę w ustawieniach Bluetooth telefonu
/// i dopiero wtedy wrócić do aplikacji, żeby ją wybrać.
Future<BluetoothInfo?> showPairPrinterSheet(BuildContext context) =>
    showModalBottomSheet<BluetoothInfo>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PairPrinterSheet(),
    );

class _PairPrinterSheet extends StatefulWidget {
  const _PairPrinterSheet();

  @override
  State<_PairPrinterSheet> createState() => _PairPrinterSheetState();
}

class _PairPrinterSheetState extends State<_PairPrinterSheet> {
  final _found = <String, NearbyBluetoothDevice>{};
  StreamSubscription<Map<Object?, Object?>>? _events;
  bool _searching = false;
  String? _pairingMac;
  String? _message;

  @override
  void initState() {
    super.initState();
    // Nasłuch przed wyszukiwaniem — inaczej pierwsze znalezione urządzenia
    // mogłyby przyjść, zanim ktokolwiek ich słucha.
    _events = BluetoothPairingService.events().listen(_onEvent);
    _search();
  }

  @override
  void dispose() {
    // Zamknięcie nasłuchu kończy też wyszukiwanie po stronie Androida.
    _events?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _message = null;
    });
    final status = await BluetoothPairingService.startDiscovery();
    if (!mounted) return;
    setState(() {
      _searching = status == DiscoveryStart.ok;
      _message = switch (status) {
        DiscoveryStart.ok => null,
        DiscoveryStart.unavailable => 'Ten telefon nie ma Bluetooth.',
        DiscoveryStart.off =>
          'Włącz Bluetooth w telefonie i spróbuj ponownie.',
        DiscoveryStart.noPermission =>
          'Brak zgody na urządzenia w pobliżu. Zezwól na nią w ustawieniach '
              'telefonu (Aplikacje → Raporty OSP → Uprawnienia).',
        DiscoveryStart.needsLocation =>
          'Na tej wersji Androida wyszukiwanie urządzeń wymaga zgody na '
              'lokalizację. Zezwól na nią i spróbuj ponownie.',
        DiscoveryStart.failed =>
          'Nie udało się rozpocząć wyszukiwania. Spróbuj ponownie.',
      };
    });
  }

  void _onEvent(Map<Object?, Object?> event) {
    if (!mounted) return;
    switch (event['type']) {
      case 'finished':
        setState(() => _searching = false);
      case 'found':
        final device = NearbyBluetoothDevice.fromEvent(event);
        if (device.mac.isEmpty) return;
        setState(() => _found[device.mac] = device);
      case 'bond':
        final device = NearbyBluetoothDevice.fromEvent(event);
        if (device.mac != _pairingMac) return;
        if (device.isBonded) {
          _finish(device);
        } else if (device.bondState == 'none') {
          setState(() {
            _pairingMac = null;
            _message = 'Nie udało się sparować z ${_label(device)}. Jeśli '
                'telefon pytał o PIN, spróbuj 0000 albo 1234.';
          });
        }
    }
  }

  /// Nazwa ze zdarzenia parowania bywa pusta — bierzemy ją wtedy z listy.
  String _label(NearbyBluetoothDevice d) {
    if (d.name.isNotEmpty) return d.name;
    final known = _found[d.mac]?.name ?? '';
    return known.isNotEmpty ? known : d.mac;
  }

  void _finish(NearbyBluetoothDevice d) {
    Navigator.of(context).pop(BluetoothInfo(name: _label(d), macAdress: d.mac));
  }

  Future<void> _pair(NearbyBluetoothDevice d) async {
    if (d.isBonded) {
      _finish(d);
      return;
    }
    setState(() {
      _pairingMac = d.mac;
      _message = null;
    });
    final start = await BluetoothPairingService.bond(d.mac);
    if (!mounted) return;
    switch (start) {
      case BondStart.alreadyBonded:
        _finish(d);
      case BondStart.started:
        break; // Wynik przyjdzie zdarzeniem `bond`.
      case BondStart.failed:
        setState(() {
          _pairingMac = null;
          _message = 'Telefon odmówił parowania z ${_label(d)}. Spróbuj '
              'ponownie albo sparuj drukarkę w ustawieniach Bluetooth.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Urządzenia bez nazwy to zwykle słuchawki i zegarki sąsiadów —
    // drukarkę zostawiamy, jeśli Android rozpoznał ją po klasie.
    final devices = _found.values
        .where((d) => d.name.isNotEmpty || d.printerClass)
        .toList()
      ..sort((a, b) {
        if (a.looksLikePrinter != b.looksLikePrinter) {
          return a.looksLikePrinter ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sparuj nową drukarkę',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_searching)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Włącz drukarkę i trzymaj ją blisko telefonu. Jeśli telefon '
              'zapyta o PIN, wpisz 0000 albo 1234.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                _message!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final d in devices)
                  ListTile(
                    leading:
                        Icon(d.looksLikePrinter ? Icons.print : Icons.bluetooth),
                    title: Text(d.name.isEmpty ? 'Urządzenie bez nazwy' : d.name),
                    subtitle: Text(d.isBonded ? '${d.mac} · sparowane' : d.mac),
                    trailing: _pairingMac == d.mac
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    enabled: _pairingMac == null,
                    onTap: () => _pair(d),
                  ),
                if (devices.isEmpty && _searching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Szukam urządzeń w pobliżu…',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (devices.isEmpty && !_searching && _message == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nie znaleziono urządzeń. Sprawdź, czy drukarka jest '
                      'włączona, i szukaj ponownie.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed:
                      _searching || _pairingMac != null ? null : _search,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Szukaj ponownie'),
                ),
                TextButton.icon(
                  onPressed: BluetoothPairingService.openBluetoothSettings,
                  icon: const Icon(Icons.settings_bluetooth),
                  label: const Text('Ustawienia Bluetooth'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
