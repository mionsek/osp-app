import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/services/bluetooth_print_service.dart';

/// Druk na drukarce termicznej Bluetooth (NETUM XL-P801).
///
/// Zgłoszenie Dawida z 8.11.2026: „jak klikamy drukuj bluetooth, to
/// aplikacja się crashuje". Odtworzone na emulatorze w wersji wydania:
/// `OutOfMemoryError` przy przekazaniu obrazu strony z Androida — strona
/// renderowana dwa razy gęściej niż drukarka miała 63 MB.
void main() {
  /// Wymiary obrazu strony w punktach drukarki.
  ({int width, int height}) raster(double widthPt, double heightPt) => (
        width: (widthPt / 72 * BluetoothPrintService.printerDpi).round(),
        height: (heightPt / 72 * BluetoothPrintService.printerDpi).round(),
      );

  test('strona A4 renderuje się w rozdzielczości drukarki — kilkanaście MB, '
      'nie kilkadziesiąt', () {
    final a4 = raster(842, 595);
    final bytes = a4.width * a4.height * 4; // RGBA
    expect(bytes, lessThan(20 * 1024 * 1024));
  });

  test('karta w poziomie po obrocie wypełnia całą szerokość papieru', () {
    final a4 = raster(842, 595); // A4 poziomo
    const dots = BluetoothPrintService.printerBytesPerRow * 8;
    // Po obrocie krótszy bok strony idzie w poprzek papieru.
    expect(a4.height, closeTo(dots, 2));
  });

  /// Obraz RGBA w×h, biały, z czarnymi punktami [black] (x, y).
  Uint8List image(int w, int h, List<(int, int)> black) {
    final px = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
    for (final (x, y) in black) {
      final i = (y * w + x) * 4;
      px[i] = px[i + 1] = px[i + 2] = 0;
    }
    return px;
  }

  bool dot(({Uint8List data, int rows}) b, int x, int y) =>
      b.data[y * BluetoothPrintService.printerBytesPerRow + (x >> 3)] &
          (0x80 >> (x & 7)) !=
      0;

  test('bez obrotu: punkt obrazu to punkt wydruku', () {
    final b = BluetoothPrintService.toPrinterBitmap(
      pixels: image(10, 4, [(3, 2)]),
      srcWidth: 10,
      srcHeight: 4,
      rotate90: false,
    );
    expect(b.rows, 4);
    expect(dot(b, 3, 2), isTrue);
    expect(dot(b, 2, 3), isFalse);
  });

  test('obrót o 90° w prawo: wiersze wydruku to kolumny strony', () {
    // Strona 10×4 (pozioma) → wydruk 4 punkty szerokości, 10 wierszy.
    final b = BluetoothPrintService.toPrinterBitmap(
      pixels: image(10, 4, [(2, 1)]),
      srcWidth: 10,
      srcHeight: 4,
      rotate90: true,
    );
    expect(b.rows, 10);
    // (2, 1) → wiersz 2, kolumna 4 - 1 - 1 = 2.
    expect(dot(b, 2, 2), isTrue);
    expect(dot(b, 1, 2), isFalse);
  });

  test('szare tło nie drukuje się, ciemna kreska tak', () {
    final px = image(2, 1, []);
    px.setAll(0, [200, 200, 200, 255]); // jasnoszary
    px.setAll(4, [120, 120, 120, 255]); // wygładzona kreska
    final b = BluetoothPrintService.toPrinterBitmap(
        pixels: px, srcWidth: 2, srcHeight: 1, rotate90: false);
    expect(dot(b, 0, 0), isFalse);
    expect(dot(b, 1, 0), isTrue);
  });
}
