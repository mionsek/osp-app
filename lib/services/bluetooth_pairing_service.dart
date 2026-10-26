import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Urządzenie Bluetooth znalezione w pobliżu albo zmieniające stan parowania.
class NearbyBluetoothDevice {
  final String name;
  final String mac;

  /// `bonded`, `bonding` albo `none` — wprost z Androida.
  final String bondState;

  /// Android zgłasza urządzenie jako drukarkę (klasa „Imaging").
  final bool printerClass;

  const NearbyBluetoothDevice({
    required this.name,
    required this.mac,
    required this.bondState,
    required this.printerClass,
  });

  factory NearbyBluetoothDevice.fromEvent(Map<Object?, Object?> e) =>
      NearbyBluetoothDevice(
        name: (e['name'] as String?) ?? '',
        mac: (e['mac'] as String?) ?? '',
        bondState: (e['bondState'] as String?) ?? 'none',
        printerClass: e['printerClass'] == true,
      );

  bool get isBonded => bondState == 'bonded';

  bool get looksLikePrinter => isLikelyPrinter(name, printerClass);
}

/// Czy urządzenie wygląda na drukarkę — do ustawienia jej na górze listy.
///
/// Klasa urządzenia nie wystarcza: tanie drukarki termiczne, w tym NETUM,
/// często podają się jako „nieznane". Nazwa jest wtedy jedyną wskazówką.
bool isLikelyPrinter(String name, bool printerClass) =>
    printerClass || _printerName.hasMatch(name);

final _printerName = RegExp(
  r'netum|print|xl-?p\d|\bp80|\bpt-|\bmpt|\bprt|\bpos',
  caseSensitive: false,
);

/// Wynik próby rozpoczęcia wyszukiwania.
enum DiscoveryStart { ok, unavailable, off, noPermission, needsLocation, failed }

/// Wynik prośby o sparowanie. Przy [alreadyBonded] system nie wyśle już
/// żadnego zdarzenia, więc nie ma na co czekać.
enum BondStart { alreadyBonded, started, failed }

/// Wyszukiwanie i parowanie drukarek z poziomu aplikacji (kod natywny
/// w `MainActivity.kt`).
class BluetoothPairingService {
  BluetoothPairingService._();

  static const _methods = MethodChannel('pl.osp.osp_app/bt_pairing');
  static const _events = EventChannel('pl.osp.osp_app/bt_pairing/events');

  /// Zdarzenia: `found` i `bond` z urządzeniem, `finished` po zakończeniu
  /// wyszukiwania. Nasłuch trzeba otworzyć przed [startDiscovery].
  static Stream<Map<Object?, Object?>> events() => _events
      .receiveBroadcastStream()
      .map((e) => (e as Map).cast<Object?, Object?>());

  /// Rozpoczyna wyszukiwanie; do Androida 11 prosi przy okazji o zgodę na
  /// lokalizację, bez której system nie wyszukuje urządzeń.
  static Future<DiscoveryStart> startDiscovery() async {
    var status = await _start();
    if (status == DiscoveryStart.needsLocation &&
        await Permission.locationWhenInUse.request().isGranted) {
      status = await _start();
    }
    return status;
  }

  static Future<DiscoveryStart> _start() async {
    final result = await _methods.invokeMethod<String>('startDiscovery');
    return switch (result) {
      'ok' => DiscoveryStart.ok,
      'unavailable' => DiscoveryStart.unavailable,
      'off' => DiscoveryStart.off,
      'no_permission' => DiscoveryStart.noPermission,
      'needs_location' => DiscoveryStart.needsLocation,
      _ => DiscoveryStart.failed,
    };
  }

  static Future<void> stopDiscovery() =>
      _methods.invokeMethod<void>('stopDiscovery');

  /// Prosi system o sparowanie; okno (np. z PIN-em) pokazuje Android,
  /// a wynik przychodzi zdarzeniem `bond`.
  static Future<BondStart> bond(String mac) async {
    final result =
        await _methods.invokeMethod<String>('bond', {'mac': mac});
    return switch (result) {
      'bonded' => BondStart.alreadyBonded,
      'started' => BondStart.started,
      _ => BondStart.failed,
    };
  }

  static Future<void> openBluetoothSettings() =>
      _methods.invokeMethod<void>('openBluetoothSettings');
}
