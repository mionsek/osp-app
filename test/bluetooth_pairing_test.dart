import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/services/bluetooth_pairing_service.dart';

/// Rozpoznawanie drukarki na liście urządzeń Bluetooth.
///
/// W pobliżu remizy lista bywa długa (słuchawki, zegarki, samochody), a tanie
/// drukarki termiczne często podają się jako urządzenie „nieznane" — stąd
/// rozpoznawanie także po nazwie.
void main() {
  group('isLikelyPrinter', () {
    test('drukarki NETUM i podobne po nazwie', () {
      expect(isLikelyPrinter('NETUM XL-P801', false), isTrue);
      expect(isLikelyPrinter('XL-P801', false), isTrue);
      expect(isLikelyPrinter('BlueTooth Printer', false), isTrue);
      expect(isLikelyPrinter('POS-58', false), isTrue);
      expect(isLikelyPrinter('MPT-II', false), isTrue);
    });

    test('drukarka rozpoznana przez Androida po klasie, nawet bez nazwy', () {
      expect(isLikelyPrinter('', true), isTrue);
    });

    test('inne urządzenia nie wyglądają na drukarkę', () {
      expect(isLikelyPrinter('JBL Flip 5', false), isFalse);
      expect(isLikelyPrinter('Galaxy Watch4', false), isFalse);
      expect(isLikelyPrinter('Opel Astra', false), isFalse);
      expect(isLikelyPrinter('', false), isFalse);
    });
  });

  test('zdarzenie z Androida zamienia się na urządzenie', () {
    final device = NearbyBluetoothDevice.fromEvent({
      'type': 'found',
      'name': 'NETUM XL-P801',
      'mac': '00:11:22:33:44:55',
      'bondState': 'bonded',
      'printerClass': false,
    });
    expect(device.name, 'NETUM XL-P801');
    expect(device.mac, '00:11:22:33:44:55');
    expect(device.isBonded, isTrue);
    expect(device.looksLikePrinter, isTrue);
  });
}
