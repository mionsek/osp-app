import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../providers/providers.dart';
import '../services/bluetooth_print_service.dart';

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

  final paired = await BluetoothPrintService.pairedPrinters();
  if (!context.mounted) return const PrinterPickResult.cancelled();
  if (paired.isEmpty) {
    return const PrinterPickResult.failed(
      'Brak sparowanych urządzeń Bluetooth. Najpierw sparuj drukarkę '
      'w ustawieniach Bluetooth telefonu, a potem wróć tutaj.',
    );
  }

  final selected = await showModalBottomSheet<BluetoothInfo>(
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
                    leading: const Icon(Icons.print),
                    title: Text(info.name),
                    subtitle: Text(info.macAdress),
                    onTap: () => Navigator.pop(ctx, info),
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

  final config = ref.read(unitConfigProvider);
  await ref.read(unitConfigProvider.notifier).save(config.copyWith(
        btPrinterMac: selected.macAdress,
        btPrinterName: selected.name,
      ));
  return const PrinterPickResult.ok();
}
