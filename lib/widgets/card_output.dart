import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../core/utils/file_names.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/card_sheet.dart';
import '../services/equipment_card.dart';
import '../services/equipment_card_sheet.dart';
import '../services/file_share.dart';
import '../services/trip_card.dart';
import '../services/xlsx_writer.dart';
import 'bluetooth_printer_picker.dart';

/// Sposób wyprowadzenia kart: drukarka w systemie (Mopria), przenośna
/// drukarka Bluetooth, PDF do wysłania i Excel — do poprawienia na
/// komputerze.
enum CardOutput {
  system,
  bluetooth,
  share,
  excel;

  /// Plik idzie dalej (poczta, Dysk), a nie na papier.
  bool get sends => this == share || this == excel;
}

/// Karta drogowa jednego pojazdu za miesiąc.
List<CardPage> vehicleCard(WidgetRef ref, Vehicle vehicle, int year, int month) =>
    TripCard.pages(
      trips: ref.read(tripsForCardProvider(
          (vehicleId: vehicle.id, year: year, month: month))),
      vehicle: vehicle,
      config: ref.read(unitConfigProvider),
      year: year,
      month: month,
      equipment: ref.read(equipmentProvider),
      reportOf: ref.read(databaseServiceProvider).getReport,
    );

/// Karty pracy urządzeń za miesiąc — po dwie na kartce.
List<CardPage> equipmentCards(
    WidgetRef ref, List<Equipment> devices, int year, int month) {
  final config = ref.read(unitConfigProvider);
  return EquipmentCardSheet.pages(
    cards: [
      for (final d in devices)
        (
          d,
          EquipmentCard.rows(
            device: d,
            year: year,
            month: month,
            trips: ref.read(vehicleTripsProvider),
            work: ref.read(equipmentWorkProvider),
            equipment: ref.read(equipmentProvider),
            reportOf: ref.read(databaseServiceProvider).getReport,
            stationAddress: config.stationAddress,
          ),
        ),
    ],
    config: config,
    year: year,
    month: month,
  );
}

/// Wszystkie karty jednostki za miesiąc: każdy pojazd i każde urządzenie
/// z własnym silnikiem — także nieużywane w tym miesiącu (Dawid,
/// 9.11.2026: „jak w jednostce są 2 wozy i 6 urządzeń, to eksport ma
/// zawierać 8 kart" — gmina rozlicza wszystkie).
List<CardPage> allCards(WidgetRef ref, int year, int month) => [
      for (final v in ref.read(vehiclesProvider))
        ...vehicleCard(ref, v, year, month),
      ...equipmentCards(
          ref,
          ref.read(equipmentProvider).where((e) => e.hasWorkCard).toList(),
          year,
          month),
    ];

/// Nazwa pliku bez rozszerzenia: „karty_OSP_Kielno_2026-11".
String cardFileName(String what, int year, int month) =>
    '${FileNames.sanitize(what)}_${FileNames.yearMonth(year, month)}';

/// Drukuje, wysyła albo zapisuje do Excela strony kart.
Future<void> outputCards(
  BuildContext context,
  WidgetRef ref,
  List<CardPage> pages,
  CardOutput output, {
  required String fileName,
  required String title,
}) async {
  final author = ref.read(unitConfigProvider).fullName;
  Future<Uint8List> pdf() => CardSheet.pdf(pages, title: title, author: author);
  try {
    switch (output) {
      case CardOutput.system:
        await Printing.layoutPdf(
          onLayout: (_) => pdf(),
          name: '$fileName.pdf',
          format: PdfPageFormat.a4.landscape,
        );
      case CardOutput.share:
        await Printing.sharePdf(bytes: await pdf(), filename: '$fileName.pdf');
      case CardOutput.bluetooth:
        // Karty są w poziomie — obrócone wypełniają całą kartkę drukarki.
        await printOnBluetoothPrinter(context, ref, pdf);
      case CardOutput.excel:
        await FileShare.share(
          CardSheet.xlsx(pages),
          fileName: '$fileName.xlsx',
          mimeType: XlsxWorkbook.mimeType,
        );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się przygotować kart: $e')),
      );
    }
  }
}
