import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../providers/providers.dart';
import '../services/bluetooth_pairing_service.dart';
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
                          subtitle: Text(info.macAdress),
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
