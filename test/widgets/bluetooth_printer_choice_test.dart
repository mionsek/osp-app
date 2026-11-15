import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/unit_config.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/services/bluetooth_print_service.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/widgets/bluetooth_printer_picker.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../helpers/test_app.dart';

/// Ustawienia jednostki w pamięci — zapis do Hive w czasie testu widoku
/// (z udawanym zegarem) nigdy by się nie skończył.
class _MemoryConfig extends UnitConfigNotifier {
  _MemoryConfig() : super(DatabaseService());

  @override
  Future<void> save(UnitConfig config) async => state = config;
}

/// Wybór drukarki Bluetooth przy samym druku (feature/060).
///
/// Prośba Dawida z 15.11.2026: zapamiętana drukarka drukowała zawsze, bez
/// wyboru — przy dwóch drukarkach (np. w dwóch wozach) albo wyłączonej
/// trzeba było iść do Ustawień. Wybrany wariant A: „Wybierz inną" przy
/// nieudanym połączeniu i przytrzymanie „Bluetooth".
void main() {
  late Directory tempDir;
  final connects = <String>[];
  var jobs = 0;
  const raster = MethodChannel('pl.osp.osp_app/pdf_raster');

  setUp(() async {
    tempDir = await setUpTestHive();
    seededDb(
        config: UnitConfig(btPrinterMac: 'AA', btPrinterName: 'NETUM w GBA'));
    connects.clear();
    jobs = 0;
    BluetoothPrintService.resetConnection();
    BluetoothPrintService.requestPermission = () async => true;
    BluetoothPrintService.bluetoothEnabled = () async => true;
    BluetoothPrintService.pairedDevices = () async => [
          BluetoothInfo(name: 'NETUM w GBA', macAdress: 'AA'),
          BluetoothInfo(name: 'NETUM w SLRt', macAdress: 'BB'),
        ];
    BluetoothPrintService.isConnected = () async => false;
    BluetoothPrintService.disconnect = () async => true;
    // Drukarka w GBA jest wyłączona, w SLRt — włączona.
    BluetoothPrintService.connect = (mac) async {
      connects.add(mac);
      return mac == 'BB';
    };
    BluetoothPrintService.nativeRaster = true;
    BluetoothPrintService.writeBytes = (bytes) async {
      jobs++;
      return true;
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(raster, (call) async {
      if (call.method == 'pageCount') return 1;
      return {
        'width': 8,
        'height': 4,
        'gray': Uint8List(32)..fillRange(0, 32, 255),
      };
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(raster, null);
    await disposeTestHive(tempDir);
  });

  Future<void> pump(WidgetTester tester, {bool choosePrinter = false}) async {
    await tester.pumpWidget(testApp(
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => printOnBluetoothPrinter(
                  context, ref, () async => Uint8List.fromList([1]),
                  choosePrinter: choosePrinter),
              child: const Text('Drukuj dokument'),
            ),
          ),
        ),
      ),
      overrides: [unitConfigProvider.overrideWith((ref) => _MemoryConfig())],
    ));
    await tester.pumpAndSettle();
  }

  UnitConfig config(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)))
          .read(unitConfigProvider);

  testWidgets('wyłączona drukarka: komunikat z „Wybierz inną", a wybrana '
      'drukuje i zostaje domyślna', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Drukuj dokument'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Nie udało się połączyć z drukarką NETUM w GBA'),
        findsOneWidget);
    expect(connects, ['AA']);

    await tester.tap(find.text('Wybierz inną'));
    await tester.pumpAndSettle();
    expect(find.text('Wybierz sparowane urządzenie'), findsOneWidget);
    expect(find.text('AA · obecna drukarka'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('NETUM w SLRt'));
    await tester.pumpAndSettle();

    expect(connects, ['AA', 'BB']);
    expect(jobs, 1);
    // Po dwusekundowym „Wysyłanie do drukarki…".
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Wysłano do drukarki.'), findsOneWidget);
    expect(config(tester).btPrinterMac, 'BB');
    expect(config(tester).btPrinterName, 'NETUM w SLRt');
  });

  testWidgets('przytrzymanie „Bluetooth": najpierw lista drukarek, mimo '
      'zapamiętanej — bez łączenia przed wyborem', (tester) async {
    await pump(tester, choosePrinter: true);

    await tester.tap(find.text('Drukuj dokument'));
    await tester.pumpAndSettle();
    expect(find.text('Wybierz sparowane urządzenie'), findsOneWidget);
    expect(connects, isEmpty);

    // Rezygnacja — nic nie drukuje i nie zmienia drukarki.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Wybierz sparowane urządzenie'), findsNothing);
    expect(connects, isEmpty);
    expect(jobs, 0);
    expect(config(tester).btPrinterMac, 'AA');
  });

  testWidgets('zwykłe dotknięcie z działającą drukarką drukuje od razu, '
      'bez listy', (tester) async {
    await tester.runAsync(() => DatabaseService().configBox.put(
        'main', UnitConfig(btPrinterMac: 'BB', btPrinterName: 'NETUM w SLRt')));
    await pump(tester);

    await tester.tap(find.text('Drukuj dokument'));
    await tester.pumpAndSettle();

    expect(find.text('Wybierz sparowane urządzenie'), findsNothing);
    expect(connects, ['BB']);
    expect(jobs, 1);
  });
}
