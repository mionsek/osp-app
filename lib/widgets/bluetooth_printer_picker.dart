import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/unit_config.dart';
import '../providers/providers.dart';
import '../services/bluetooth_pairing_service.dart';
import '../core/theme/osp_theme.dart';
import '../services/bluetooth_print_service.dart';
import 'bluetooth_pair_sheet.dart';

/// Pozycja „Wyszukaj i sparuj nową drukarkę" na liście sparowanych.
final _pairNew = BluetoothInfo(name: '', macAdress: '');

/// Wynik próby wyboru drukarki — komunikat jest gotowy do pokazania
/// użytkownikowi, bo powody niepowodzenia są tu bardzo konkretne
/// (wyłączony Bluetooth, brak zgody, brak sparowanych urządzeń).
class PrinterPickResult {
  final bool selected;
  final String? errorMessage;

  const PrinterPickResult.ok() : selected = true, errorMessage = null;
  const PrinterPickResult.failed(String this.errorMessage) : selected = false;
  const PrinterPickResult.cancelled()
      : selected = false,
        errorMessage = null;
}

/// Wspólny wybór sparowanej drukarki termicznej Bluetooth i zapisanie jej
/// w konfiguracji jednostki.
///
/// Używany zarówno z Ustawień, jak i bezpośrednio z ekranu drukowania —
/// dzięki temu użytkownik nie musi szukać opcji w Ustawieniach, gdy chce
/// po prostu wydrukować.
Future<PrinterPickResult> pickBluetoothPrinter(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!await BluetoothPrintService.ensurePermission()) {
    return const PrinterPickResult.failed(
      'Brak zgody na dostęp do Bluetooth. Zezwól aplikacji na urządzenia '
      'w pobliżu w ustawieniach telefonu (Aplikacje → OSP → Uprawnienia).',
    );
  }
  if (!await BluetoothPrintService.isBluetoothEnabled()) {
    return const PrinterPickResult.failed(
      'Włącz Bluetooth w telefonie i spróbuj ponownie.',
    );
  }

  // Drukarki na górze — na liście sparowanych są też słuchawki, samochód
  // i zegarek, a szuka się zawsze drukarki.
  final paired = [...await BluetoothPrintService.pairedPrinters()]
    ..sort((a, b) {
      final pa = isLikelyPrinter(a.name, false);
      final pb = isLikelyPrinter(b.name, false);
      if (pa != pb) return pa ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  if (!context.mounted) return const PrinterPickResult.cancelled();
  final current = ref.read(unitConfigProvider).btPrinterMac;

  // Bez sparowanych urządzeń od razu wyszukiwanie — wcześniej był tu tylko
  // komunikat odsyłający do ustawień Bluetooth telefonu.
  var selected = paired.isEmpty
      ? _pairNew
      : await showModalBottomSheet<BluetoothInfo>(
          context: context,
          // Bez tego okno ma sztywną wysokość i przy dłuższej liście urządzeń
          // treść się nie mieści — ostatnia pozycja znikała pod paskiem
          // ostrzeżenia o przepełnieniu układu.
          isScrollControlled: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Wybierz sparowane urządzenie',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final info in paired)
                        ListTile(
                          leading: Icon(isLikelyPrinter(info.name, false)
                              ? Icons.print
                              : Icons.bluetooth),
                          title: Text(info.name),
                          subtitle: Text(info.macAdress == current
                              ? '${info.macAdress} · obecna drukarka'
                              : info.macAdress),
                          trailing: info.macAdress == current
                              ? const Icon(Icons.check,
                                  color: OspTheme.success)
                              : null,
                          onTap: () => Navigator.pop(ctx, info),
                        ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.bluetooth_searching),
                        title: const Text('Wyszukaj i sparuj nową drukarkę'),
                        onTap: () => Navigator.pop(ctx, _pairNew),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
  if (selected == null || !context.mounted) {
    return const PrinterPickResult.cancelled();
  }
  if (identical(selected, _pairNew)) {
    selected = await showPairPrinterSheet(context);
    if (selected == null || !context.mounted) {
      return const PrinterPickResult.cancelled();
    }
  }

  final config = ref.read(unitConfigProvider);
  await ref.read(unitConfigProvider.notifier).save(config.copyWith(
        btPrinterMac: selected.macAdress,
        btPrinterName: selected.name,
      ));
  return const PrinterPickResult.ok();
}

/// Podpis przycisku „Bluetooth" po przytrzymaniu: nazwa wybranej drukarki
/// albo zapowiedź, że najpierw będzie wybór.
String bluetoothTooltip(UnitConfig config) {
  final mac = config.btPrinterMac;
  if (mac == null || mac.isEmpty) return 'Drukuj na drukarce Bluetooth…';
  return 'Drukuj na ${config.btPrinterName ?? 'drukarce Bluetooth'}';
}

/// Druk dokumentu na sparowanej drukarce termicznej Bluetooth, z wyborem
/// drukarki na miejscu, gdy żadnej jeszcze nie wybrano.
///
/// [choosePrinter] — najpierw lista drukarek, także gdy jakaś jest już
/// zapamiętana (przytrzymanie „Bluetooth" albo „Wybierz inną" po nieudanym
/// połączeniu). Wybrana zostaje zapamiętana na następne wydruki. Prośba
/// Dawida z 15.11.2026: przy dwóch drukarkach (np. w dwóch wozach) albo
/// wyłączonej zapamiętanej trzeba było iść do Ustawień.
///
/// Wspólne dla raportu, przekazania mienia i obu kart — wcześniej każdy
/// ekran miał własną kopię tych samych kroków i komunikatów.
///
/// [rotate90] — dokument w poziomie (A4 landscape) trzeba obrócić, bo
/// drukarka podaje papier pionowo; karta pracy sprzętu jest w pionie.
Future<void> printOnBluetoothPrinter(
  BuildContext context,
  WidgetRef ref,
  Future<Uint8List> Function() pdfBytes, {
  bool rotate90 = true,
  bool choosePrinter = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void show(String text, {bool ok = false, SnackBarAction? action}) {
    messenger.showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: ok ? OspTheme.success : OspTheme.danger,
      action: action,
      // Z przyciskiem — czas, żeby go nacisnąć.
      duration: Duration(seconds: action != null ? 8 : 4),
    ));
  }

  var mac = ref.read(unitConfigProvider).btPrinterMac;
  if (choosePrinter || mac == null || mac.isEmpty) {
    final result = await pickBluetoothPrinter(context, ref);
    if (result.errorMessage != null) {
      show(result.errorMessage!);
      return;
    }
    if (!result.selected) return; // użytkownik zrezygnował
    mac = ref.read(unitConfigProvider).btPrinterMac;
    if (mac == null || mac.isEmpty) return;
  }
  try {
    if (!await BluetoothPrintService.ensurePermission()) {
      show('Brak zgody na dostęp do Bluetooth.');
      return;
    }
    if (!await BluetoothPrintService.connectIfNeeded(mac)) {
      final name = ref.read(unitConfigProvider).btPrinterName ?? '';
      show(
        'Nie udało się połączyć z drukarką${name.isEmpty ? '' : ' $name'}. '
        'Sprawdź, czy jest włączona, albo wybierz inną.',
        action: SnackBarAction(
          label: 'Wybierz inną',
          textColor: Colors.white,
          onPressed: () {
            if (!context.mounted) return;
            printOnBluetoothPrinter(context, ref, pdfBytes,
                rotate90: rotate90, choosePrinter: true);
          },
        ),
      );
      return;
    }
    messenger.showSnackBar(const SnackBar(
      content: Text('Wysyłanie do drukarki...'),
      duration: Duration(seconds: 2),
    ));
    final ok = await BluetoothPrintService.printPdf(await pdfBytes(),
        rotate90: rotate90);
    show(ok ? 'Wysłano do drukarki.' : 'Drukarka odrzuciła zadanie.', ok: ok);
  } catch (e) {
    show('Błąd druku: $e');
  }
}
