import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/services/bluetooth_print_service.dart';

/// Druk na drukarce termicznej Bluetooth (NETUM XL-P801).
///
/// Zgłoszenie Dawida z 8.11.2026: „jak klikamy drukuj bluetooth, to
/// aplikacja się crashuje". Odtworzone na emulatorze w wersji wydania:
/// `OutOfMemoryError` przy przekazaniu obrazu strony z Androida — strona
/// renderowana dwa razy gęściej niż drukarka miała 63 MB. Poprawka z fix/054
/// (strona od razu w rozdzielczości drukarki) dała za słaby druk — zgłoszenie
/// z 15.11.2026. Od fix/059 nadpróbkowanie wraca, ale w pasach.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Wymiary obrazu strony w punktach drukarki.
  ({int width, int height}) raster(double widthPt, double heightPt) => (
        width: (widthPt / 72 * BluetoothPrintService.printerDpi).toInt(),
        height: (heightPt / 72 * BluetoothPrintService.printerDpi).toInt(),
      );

  group('pamięć', () {
    test('do aplikacji trafia obraz w szarości — kilka MB na stronę A4, '
        'nie kilkadziesiąt', () {
      final a4 = raster(842, 595);
      expect(a4.width * a4.height, lessThan(5 * 1024 * 1024));
    });

    test('nadpróbkowanie tylko w pasie, nie na całej stronie', () {
      final a4 = raster(842, 595);
      const s = BluetoothPrintService.supersample;
      const rows = BluetoothPrintService.rasterBandRows;
      final band = a4.width * s * rows * s * 4; // ARGB pasa + tablica pikseli
      final wholePage = a4.width * s * a4.height * s * 4;
      expect(s, 2, reason: 'tak jak do 1.9.3, kiedy druk był dobry');
      expect(band * 2, lessThan(8 * 1024 * 1024));
      // Cała strona naraz — 63 MB, przez co aplikacja padała do 1.9.3.
      expect(wholePage, greaterThan(60 * 1000 * 1000));
    });
  });

  test('karta w poziomie po obrocie wypełnia całą szerokość papieru', () {
    final a4 = raster(842, 595); // A4 poziomo
    const dots = BluetoothPrintService.printerBytesPerRow * 8;
    // Po obrocie krótszy bok strony idzie w poprzek papieru.
    expect(a4.height, closeTo(dots, 2));
  });

  /// Obraz w szarości w×h, biały, z czarnymi punktami [black] (x, y).
  Uint8List image(int w, int h, List<(int, int)> black) {
    final px = Uint8List(w * h)..fillRange(0, w * h, 255);
    for (final (x, y) in black) {
      px[y * w + x] = 0;
    }
    return px;
  }

  bool dot(({Uint8List data, int rows}) b, int x, int y) =>
      b.data[y * BluetoothPrintService.printerBytesPerRow + (x >> 3)] &
          (0x80 >> (x & 7)) !=
      0;

  test('bez obrotu: punkt obrazu to punkt wydruku', () {
    final b = BluetoothPrintService.toPrinterBitmap(
      gray: image(10, 4, [(3, 2)]),
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
      gray: image(10, 4, [(2, 1)]),
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
    final b = BluetoothPrintService.toPrinterBitmap(
      gray: Uint8List.fromList([200, 120]), // jasnoszare tło, wygładzona kreska
      srcWidth: 2,
      srcHeight: 1,
      rotate90: false,
    );
    expect(dot(b, 0, 0), isFalse);
    expect(dot(b, 1, 0), isTrue);
  });

  test('po uśrednieniu: punkt w połowie pokryty kreską się drukuje, '
      'w ćwierci — nie', () {
    // Blok 2×2 z jednym czarnym pikselem: średnia 191 — za jasno. Z dwoma: 127.
    const oneOfFour = 255 * 3 ~/ 4;
    const twoOfFour = 255 * 2 ~/ 4;
    final b = BluetoothPrintService.toPrinterBitmap(
      gray: Uint8List.fromList([oneOfFour, twoOfFour]),
      srcWidth: 2,
      srcHeight: 1,
      rotate90: false,
    );
    expect(dot(b, 0, 0), isFalse);
    expect(dot(b, 1, 0), isTrue);
  });

  test('RGBA na szarość: jasność jak dotąd, przezroczyste tło białe', () {
    final gray = BluetoothPrintService.grayFromRgba(Uint8List.fromList([
      0, 0, 0, 255, // czarny
      255, 255, 255, 255, // biały
      120, 120, 120, 255, // szary
      0, 0, 0, 0, // przezroczysty
    ]));
    expect(gray, [0, 255, 120, 255]);
  });

  group('druk w pasach przez Androida', () {
    const channel = MethodChannel('pl.osp.osp_app/pdf_raster');
    final calls = <String>[];
    final requests = <Map<Object?, Object?>>[];
    late bool previousNative;

    setUp(() {
      calls.clear();
      requests.clear();
      previousNative = BluetoothPrintService.nativeRaster;
      BluetoothPrintService.nativeRaster = true;
      BluetoothPrintService.writeBytes = (bytes) async {
        calls.add('wyślij');
        return true;
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map<Object?, Object?>;
        requests.add(args);
        if (call.method == 'pageCount') {
          calls.add('strony');
          return 2;
        }
        calls.add('strona ${args['page']}');
        // Mała strona 16×8 punktów z czarnym kwadratem w rogu.
        final gray = Uint8List(16 * 8)..fillRange(0, 16 * 8, 255);
        gray[0] = 0;
        return {'width': 16, 'height': 8, 'gray': gray};
      });
    });

    tearDown(() {
      BluetoothPrintService.nativeRaster = previousNative;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('strona po stronie: następna renderuje się dopiero po wysłaniu '
        'poprzedniej, w nadpróbkowaniu i w pasach', () async {
      final ok = await BluetoothPrintService.printPdf(
          Uint8List.fromList([1, 2, 3]),
          rotate90: false);

      expect(ok, isTrue);
      expect(calls, ['strony', 'strona 0', 'wyślij', 'strona 1', 'wyślij']);
      final page = requests[1];
      expect(page['supersample'], BluetoothPrintService.supersample);
      expect(page['bandRows'], BluetoothPrintService.rasterBandRows);
      expect(page['dpi'], BluetoothPrintService.printerDpi);
    });

    test('błąd renderowania (np. brak pamięci) to wyjątek z komunikatem, '
        'a nie zamknięcie aplikacji', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
            code: 'raster', message: 'OutOfMemoryError: Failed to allocate');
      });
      await expectLater(
        BluetoothPrintService.printPdf(Uint8List.fromList([1])),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, isEmpty, reason: 'nic nie poszło do drukarki');
    });
  });

  test('kod Androida: pas renderowany na osobnym wątku, z białym tłem', () {
    // Pilnuje założeń, których test w Darcie nie sprawdzi.
    final kotlin = File(
            'android/app/src/main/kotlin/pl/osp/osp_app/PdfBandRasterizer.kt')
        .readAsStringSync();
    final activity =
        File('android/app/src/main/kotlin/pl/osp/osp_app/MainActivity.kt')
            .readAsStringSync();
    expect(kotlin, contains('eraseColor(Color.WHITE)'));
    expect(kotlin, contains('postTranslate(0f, -(top * ss).toFloat())'));
    expect(activity, contains('rasterExecutor.execute'));
    expect(activity, contains('"pl.osp.osp_app/pdf_raster"'));
  });
}
