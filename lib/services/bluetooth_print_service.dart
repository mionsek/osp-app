import 'dart:io';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';

/// Eksperymentalna obsługa drukarek termicznych Bluetooth (np. NETUM
/// XL-P801) po protokole ESC/POS — z pominięciem systemowego okna
/// drukowania Androida, które tych drukarek nie widzi (brak usługi druku).
///
/// To jest ścieżka poboczna względem [PdfService] — nie zastępuje zwykłego
/// drukowania, tylko daje dodatkową opcję dla urządzeń bez usługi druku.
///
/// UWAGA: pakiet `print_bluetooth_thermal` na Androidzie 12+ sam nigdy nie
/// prosi o uprawnienie BLUETOOTH_CONNECT — jeśli go nie ma, każde jego
/// wywołanie po cichu zawiesza się na zawsze (natywny kod po prostu nie
/// wywołuje wtedy callbacku z wynikiem). Dlatego zawsze najpierw jawnie
/// prosimy o uprawnienie przez `permission_handler`, zanim cokolwiek
/// wywołamy z tego pakietu.
class BluetoothPrintService {
  BluetoothPrintService._();

  /// Prosi o uprawnienie Bluetooth (na Androidzie <12 nie jest wymagane —
  /// zwraca true od razu). Musi zostać wywołane i zwrócić true przed
  /// jakimkolwiek innym wywołaniem w tej klasie, inaczej te wywołania mogą
  /// zawiesić się w nieskończoność (patrz uwaga wyżej).
  static Future<bool> ensurePermission() async {
    final connectStatus = await Permission.bluetoothConnect.request();
    final scanStatus = await Permission.bluetoothScan.request();
    return connectStatus.isGranted && scanStatus.isGranted;
  }

  static Future<bool> isBluetoothEnabled() =>
      PrintBluetoothThermal.bluetoothEnabled;

  static Future<bool> isPermissionGranted() =>
      PrintBluetoothThermal.isPermissionBluetoothGranted;

  static Future<List<BluetoothInfo>> pairedPrinters() =>
      PrintBluetoothThermal.pairedBluetooths;

  static Future<bool> connect(String mac) =>
      PrintBluetoothThermal.connect(macPrinterAddress: mac);

  static Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  static Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  /// Łączy się tylko, jeśli jeszcze nie jesteśmy połączeni.
  ///
  /// Wtyczka `print_bluetooth_thermal` ma błąd: gdy `connect` jest wywołane
  /// po raz drugi w tej samej sesji aplikacji, a poprzednie połączenie
  /// wciąż jest otwarte, jej kod po stronie Androida zwraca `false` (nie
  /// próbując nawet nawiązać połączenia), mimo że drukarka fizycznie jest
  /// podłączona. Obchodzimy to, sprawdzając [isConnected] najpierw.
  static Future<bool> connectIfNeeded(String mac) async {
    if (await isConnected) return true;
    return connect(mac);
  }

  // Uwaga: polskie znaki nie wymagają już żadnej podmiany — drukujemy
  // stronę jako bitmapę wyrenderowaną z PDF-a, więc diakrytyki wychodzą
  // dokładnie tak, jak na wydruku systemowym.

  // ---------------------------------------------------------------------
  // Protokół drukarki NETUM XL-P801 (odtworzony z logu HCI)
  // ---------------------------------------------------------------------
  //
  // Ta drukarka NIE rozumie ESC/POS mimo deklaracji sprzedawcy — w
  // przechwyconej transmisji z aplikacji producenta nie ma ani jednej
  // komendy ESC/POS. Zamiast tego używa własnego formatu:
  //
  //   [0..18]  stały nagłówek zadania
  //   [19]     liczba bajtów na wiersz bitmapy (208 = 1664 punkty ≈ 208 mm)
  //   [20..21] liczba wierszy, big-endian (2354 ≈ 294 mm)
  //   [22..23] 0x00 0x00
  //   [24..25] długość bloku danych, big-endian
  //   [26..]   bitmapa 1-bitowa spakowana algorytmem raw deflate
  //            (bit 1 = punkt czarny, bity od najstarszego w bajcie)
  //   koniec   ESC J 100 (wysuw papieru) + 10 FF FE 45 (koniec zadania)
  //
  // Zgodność potwierdzona rachunkiem: 208 × 2354 = 489 632 bajtów, czyli
  // dokładnie tyle, ile miała rozpakowana bitmapa z przechwyconego wydruku.

  /// Bajtów na wiersz w bitmapie drukarki (208 B = 1664 punkty ≈ 208 mm).
  static const int printerBytesPerRow = 208;

  /// Rozdzielczość, przy której strona A4 wypełnia szerokość wydruku.
  /// 1664 punkty / (210 mm / 25.4) ≈ 201 dpi.
  static const double printerDpi = 201.3;

  static const List<int> _jobHeaderPrefix = [
    0x10, 0xFF, 0x40, //
    0x10, 0xFF, 0x10, 0x00, 0x01, //
    0x10, 0xFF, 0xFE, 0x01, //
    0x1F, 0x80, 0x01, 0x10, 0x1F, 0x00, 0x00,
  ];

  static const List<int> _jobFooter = [
    0x1B, 0x4A, 0x64, // ESC J 100 — wysuw papieru
    0x10, 0xFF, 0xFE, 0x45, // koniec zadania
  ];

  /// Ile razy gęściej renderujemy stronę, zanim zredukujemy ją do bitmapy
  /// czarno-białej. Drukarka drukuje tylko "jest punkt / nie ma punktu",
  /// więc renderowanie od razu w jej rozdzielczości gubi cienkie kreski i
  /// drobny tekst. Renderujemy dwukrotnie gęściej i uśredniamy — kreska
  /// pokrywająca choćby część punktu nadal zostanie wydrukowana.
  static const int _supersample = 2;

  /// Próg jasności decydujący o zaczernieniu punktu (0–255). Wyższy niż
  /// połowa skali celowo: po uśrednieniu częściowo pokryty punkt ma jasność
  /// pośrednią, a na papierze termicznym lepiej wypada tekst nieco
  /// pogrubiony niż poszarpany i miejscami zanikający.
  static const int _inkThreshold = 176;

  /// Renderuje pierwszą stronę dokumentu PDF do bitmapy 1-bitowej w
  /// formacie oczekiwanym przez drukarkę i wysyła ją przez Bluetooth.
  ///
  /// [rotate90] — nasze potwierdzenie przekazania mienia jest w poziomie
  /// (A4 landscape z dwoma egzemplarzami A5 obok siebie), a drukarka
  /// podaje papier pionowo, więc stronę trzeba obrócić.
  static Future<bool> printPdf(Uint8List pdfBytes, {bool rotate90 = true}) async {
    final page = await Printing.raster(
      pdfBytes,
      dpi: printerDpi * _supersample,
    ).first;
    final bitmap = _toPrinterBitmap(
      pixels: page.pixels,
      srcWidth: page.width,
      srcHeight: page.height,
      rotate90: rotate90,
    );
    return _sendBitmap(bitmap.data, bitmap.rows);
  }

  /// Zamienia piksele RGBA na bitmapę 1-bitową o szerokości
  /// [printerBytesPerRow] bajtów, opcjonalnie obracając stronę o 90°.
  ///
  /// Źródło jest [_supersample] razy gęstsze od wyniku — każdy punkt
  /// wydruku powstaje z uśrednienia bloku pikseli źródłowych.
  static ({Uint8List data, int rows}) _toPrinterBitmap({
    required Uint8List pixels,
    required int srcWidth,
    required int srcHeight,
    required bool rotate90,
  }) {
    const s = _supersample;
    // Po obrocie zamieniamy szerokość z wysokością.
    final outWidth = (rotate90 ? srcHeight : srcWidth) ~/ s;
    final rows = (rotate90 ? srcWidth : srcHeight) ~/ s;
    final data = Uint8List(printerBytesPerRow * rows);
    const maxDots = printerBytesPerRow * 8;

    for (var y = 0; y < rows; y++) {
      final rowOffset = y * printerBytesPerRow;
      final limit = outWidth < maxDots ? outWidth : maxDots;
      for (var x = 0; x < limit; x++) {
        var sum = 0;
        var samples = 0;
        for (var sy = 0; sy < s; sy++) {
          for (var sx = 0; sx < s; sx++) {
            final int srcX, srcY;
            if (rotate90) {
              // Obrót o 90° w prawo w siatce nadpróbkowanej.
              srcX = y * s + sy;
              srcY = srcHeight - 1 - (x * s + sx);
            } else {
              srcX = x * s + sx;
              srcY = y * s + sy;
            }
            if (srcX < 0 || srcX >= srcWidth || srcY < 0 || srcY >= srcHeight) {
              continue;
            }
            final i = (srcY * srcWidth + srcX) * 4;
            if (i + 3 >= pixels.length) continue;
            samples++;
            // Przezroczyste tło traktujemy jak białe.
            if (pixels[i + 3] < 128) {
              sum += 255;
              continue;
            }
            sum += (pixels[i] * 299 + pixels[i + 1] * 587 + pixels[i + 2] * 114) ~/
                1000;
          }
        }
        if (samples == 0) continue;
        if (sum ~/ samples >= _inkThreshold) continue; // za jasne — bez druku

        data[rowOffset + (x >> 3)] |= 0x80 >> (x & 7);
      }
    }
    return (data: data, rows: rows);
  }

  /// Składa pełne zadanie druku i wysyła je do drukarki.
  static Future<bool> _sendBitmap(Uint8List bitmap, int rows) async {
    final compressed = ZLibCodec(raw: true, level: 6).encode(bitmap);
    final payloadLen = compressed.length;

    final packet = BytesBuilder();
    packet.add(_jobHeaderPrefix);
    packet.addByte(printerBytesPerRow);
    packet.addByte((rows >> 8) & 0xFF);
    packet.addByte(rows & 0xFF);
    packet.addByte(0x00);
    packet.addByte(0x00);
    packet.addByte((payloadLen >> 8) & 0xFF);
    packet.addByte(payloadLen & 0xFF);
    packet.add(compressed);
    packet.add(_jobFooter);

    // Uwaga: `writeBytes` musi dostać zwykłą List<int>. Przekazanie
    // Uint8List kończy się po stronie Androida wyjątkiem
    // "byte[] cannot be cast to java.util.List" — wtyczka rzutuje
    // argument na List<Int>, a Uint8List mapuje się na byte[].
    return PrintBluetoothThermal.writeBytes(packet.toBytes().toList());
  }

  /// Wydruk testowy własnym protokołem drukarki — rysuje prosty wzór
  /// (ramka + pasy), żeby sprawdzić, czy drukarka przyjmuje nasze zadania
  /// i czy szerokość wydruku jest dobrana poprawnie.
  ///
  /// Nie używa ESC/POS, bo ta drukarka go nie obsługuje — patrz opis
  /// protokołu wyżej.
  static Future<bool> printTestPage(String unitName) async {
    const rows = 400;
    const widthDots = printerBytesPerRow * 8;
    final data = Uint8List(printerBytesPerRow * rows);

    void setPixel(int x, int y) {
      if (x < 0 || x >= widthDots || y < 0 || y >= rows) return;
      data[y * printerBytesPerRow + (x >> 3)] |= 0x80 >> (x & 7);
    }

    // Ramka po obwodzie — pokaże, czy cała szerokość papieru jest użyta.
    for (var x = 0; x < widthDots; x++) {
      for (var t = 0; t < 4; t++) {
        setPixel(x, t);
        setPixel(x, rows - 1 - t);
      }
    }
    for (var y = 0; y < rows; y++) {
      for (var t = 0; t < 4; t++) {
        setPixel(t, y);
        setPixel(widthDots - 1 - t, y);
      }
    }
    // Pasy ukośne w środku — łatwo zauważyć zniekształcenia.
    for (var y = 40; y < rows - 40; y++) {
      for (var w = 0; w < 60; w++) {
        setPixel((y * 3 + w) % (widthDots - 40) + 20, y);
      }
    }

    return _sendBitmap(data, rows);
  }
}
