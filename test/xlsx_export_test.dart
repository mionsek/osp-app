import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/equipment_card.dart';
import 'package:osp_app/services/equipment_card_xlsx.dart';
import 'package:osp_app/services/trip_card_pdf.dart';
import 'package:osp_app/services/trip_card_xlsx.dart';
import 'package:osp_app/services/xlsx_writer.dart';

/// Karty w Excelu — do poprawienia na komputerze przed wysłaniem do gminy.
///
/// Prośba Dawida z 6.11.2026: „może trzeba będzie to wysłać, lub ewentualnie
/// poprawić przed wysłaniem (bo paliwo się nie zgadza czy coś)". Stąd
/// pilnujemy dwóch rzeczy: arkusz ma tę samą treść co wydruk, a rozliczenie
/// paliwa to formuły, które przeliczą się po poprawce.
void main() {
  /// Komórki arkusza: adres → wartość (tekst, liczba jako tekst) i formuła.
  Map<String, ({String value, String? formula})> cells(Uint8List bytes,
      {int sheet = 1}) {
    final zip = ZipDecoder().decodeBytes(bytes);
    String part(String name) =>
        utf8.decode(zip.findFile(name)!.readBytes()!);
    String unescape(String s) => s
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');

    final strings = [
      for (final m in RegExp(r'<si><t[^>]*>(.*?)</t></si>', dotAll: true)
          .allMatches(part('xl/sharedStrings.xml')))
        unescape(m.group(1)!),
    ];
    final out = <String, ({String value, String? formula})>{};
    final cell = RegExp(
        r'<c r="([A-Z]+\d+)"[^>]*?(?: t="(\w+)")?(?:/>|>(.*?)</c>)',
        dotAll: true);
    for (final m in cell.allMatches(part('xl/worksheets/sheet$sheet.xml'))) {
      final body = m.group(3) ?? '';
      final f = RegExp(r'<f>(.*?)</f>').firstMatch(body)?.group(1);
      final v = RegExp(r'<v>(.*?)</v>').firstMatch(body)?.group(1) ?? '';
      out[m.group(1)!] = (
        value: m.group(2) == 's' ? strings[int.parse(v)] : unescape(v),
        formula: f == null ? null : unescape(f),
      );
    }
    return out;
  }

  String part(Uint8List bytes, String name) => utf8.decode(
      ZipDecoder().decodeBytes(bytes).findFile(name)!.readBytes()!);

  /// Wiersz (numer Excela) komórki z tekstem [label] w kolumnie [col].
  int rowOf(Map<String, ({String value, String? formula})> c, String label,
      {String col = 'B'}) {
    final at = c.entries
        .firstWhere((e) => e.key.startsWith(col) && e.value.value == label)
        .key;
    return int.parse(at.substring(col.length));
  }

  group('zapis arkusza', () {
    test('litery kolumn jak w Excelu', () {
      expect(XlsxWorkbook.column(0), 'A');
      expect(XlsxWorkbook.column(25), 'Z');
      expect(XlsxWorkbook.column(26), 'AA');
      expect(XlsxWorkbook.column(701), 'ZZ');
      expect(XlsxWorkbook.column(702), 'AAA');
      expect(XlsxWorkbook.ref(9, 27), 'AB10');
    });

    test('plik ma części, bez których Excel go nie otworzy', () {
      final book = XlsxWorkbook();
      book.addSheet('Arkusz').set(0, 0, 'x');
      final zip = ZipDecoder().decodeBytes(book.save());
      expect(
        zip.files.map((f) => f.name),
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'xl/workbook.xml',
          'xl/_rels/workbook.xml.rels',
          'xl/styles.xml',
          'xl/sharedStrings.xml',
          'xl/worksheets/sheet1.xml',
        ]),
      );
    });

    test('polskie znaki, cudzysłowy i nawiasy ostre przechodzą bez zmian',
        () {
      final book = XlsxWorkbook();
      book.addSheet('Arkusz')
        ..set(0, 0, 'Żółć <gęś> & "łódź"')
        ..set(0, 1, const XlsxFormula('IF(A1<>"","tak","")', 'tak'))
        ..set(0, 2, 1.5)
        ..set(0, 3, 0.1 + 0.2);
      final c = cells(book.save());
      expect(c['A1']!.value, 'Żółć <gęś> & "łódź"');
      expect(c['B1']!.formula, 'IF(A1<>"","tak","")');
      expect(c['B1']!.value, 'tak');
      expect(c['C1']!.value, '1.5');
      expect(c['D1']!.value, '0.3', reason: 'bez ogona 0.30000000000000004');
    });

    test('ten sam wygląd w wielu komórkach to jeden styl', () {
      final book = XlsxWorkbook();
      const style = XlsxStyle(bold: true, border: true);
      final sheet = book.addSheet('Arkusz');
      for (var r = 0; r < 50; r++) {
        sheet.set(r, 0, 'x', style);
      }
      final styles = part(book.save(), 'xl/styles.xml');
      expect(RegExp(r'<cellXfs count="2">').hasMatch(styles), isTrue,
          reason: 'domyślny i jeden pogrubiony z ramką');
    });

    test('scalona komórka ma ramkę na całej szerokości', () {
      final book = XlsxWorkbook();
      book.addSheet('Arkusz').merge(0, 0, 0, 2, 'tytuł',
          const XlsxStyle(border: true));
      final bytes = book.save();
      final c = cells(bytes);
      expect(c.keys, containsAll(['A1', 'B1', 'C1']));
      expect(part(bytes, 'xl/worksheets/sheet1.xml'),
          contains('<mergeCell ref="A1:C1"/>'));
    });
  });

  group('karta drogowa w Excelu', () {
    const station = 'Kielno, Oliwska 12';
    final config = UnitConfig(
      unitFullName: 'Ochotnicza Straż Pożarna w Kielnie',
      locality: 'Kielno',
      unitStreet: 'Oliwska 12',
    );
    final vehicle = Vehicle(
      id: 'v1',
      name: 'GBA 2,5/16',
      seats: 6,
      make: 'MAN',
      model: 'TGM 13.290',
      kind: 'GBA',
      plate: 'GWE 12345',
      fuelPer100Km: 30,
      pumpFuelPerHour: 12,
      idleFuelPerMinute: 0.05,
      startupFuelPerMonth: 1,
    );
    final pump = Equipment(
        id: 'pump', name: 'Autopompa', vehicleId: 'v1', poweredByVehicle: true);

    final at = DateTime(2026, 11, 3, 19, 40);
    final trips = [
      VehicleTrip(
        id: 't1',
        vehicleId: 'v1',
        date: DateTime(2026, 11, 3),
        dispatcherName: 'Kwapisz O.',
        routeFrom: station,
        routeTo: 'Szemud',
        purpose: TripPurposes.training,
        driverName: 'Mielewczyk M.',
        departureTime: at,
        odometerStart: 1000,
        sceneArrivalTime: at.add(const Duration(minutes: 12)),
        sceneOdometer: 1010,
        sceneDepartureTime: at.add(const Duration(minutes: 70)),
        returnTime: at.add(const Duration(minutes: 85)),
        odometerEnd: 1020,
        idleMinutes: 10,
        equipmentUse: [
          TripEquipmentUse(name: 'Autopompa', minutes: 30, equipmentId: 'pump'),
        ],
        createdAt: at,
        updatedAt: at,
      ),
      VehicleTrip(
        id: 't2',
        vehicleId: 'v1',
        date: DateTime(2026, 11, 5),
        routeFrom: station,
        routeTo: 'Żukowo',
        purpose: TripPurposes.refuelling,
        driverName: 'Mielewczyk M.',
        departureTime: DateTime(2026, 11, 5, 9, 0),
        returnTime: DateTime(2026, 11, 5, 9, 50),
        odometerStart: 1020,
        odometerEnd: 1050,
        createdAt: at,
        updatedAt: at,
      ),
    ];

    Uint8List build({Vehicle? v, List<VehicleTrip>? list}) =>
        TripCardXlsx.bytes(
          trips: list ?? trips,
          vehicle: v ?? vehicle,
          config: config,
          year: 2026,
          month: 11,
          equipment: [pump],
        );

    test('wiersze przejazdów mają tę samą treść co wydruk', () {
      final c = cells(build());
      // Tabela zaczyna się w wierszu 17 — dwa wiersze na przejazd.
      var row = 17;
      for (var i = 0; i < trips.length; i++) {
        final pdfRows = TripCardPdf.tripRowTexts(
          trips[i],
          i + 1,
          equipmentMinutes: i == 0 ? 30 : 0,
          stationAddress: config.stationAddress,
        );
        for (final texts in pdfRows) {
          for (var col = 0; col < texts.length; col++) {
            final at = XlsxWorkbook.ref(row - 1, col);
            expect(c[at]?.value ?? '', texts[col], reason: at);
          }
          row++;
        }
      }
      expect(c['D17']!.value, 'OSP – Szemud');
      expect(c['D19']!.value, 'OSP – Żukowo', reason: 'polskie litery');
    });

    test('liczniki, minuty i postój to liczby, nie tekst', () {
      final xml = part(build(), 'xl/worksheets/sheet1.xml');
      for (final at in ['A17', 'H17', 'J17', 'K17', 'M17', 'J18']) {
        expect(RegExp('<c r="$at" s="\\d+"><v>').hasMatch(xml), isTrue,
            reason: '$at bez t="s"');
      }
    });

    test('kilometry przejazdu liczą się z liczników — po poprawce same',
        () {
      final c = cells(build());
      expect(c['O17']!.formula, contains('J18-H17'));
      expect(c['O17']!.value, '20');
      expect(c['O19']!.formula, contains('J20-H19'));
      expect(c['O19']!.value, '30');
    });

    test('normy w osobnych komórkach — formuły biorą je stąd', () {
      final c = cells(build());
      expect(c['D8']!.value, '30', reason: 'na 100 km');
      expect(c['K8']!.value, '12', reason: 'autopompa');
      expect(c['D9']!.value, '0.05', reason: 'postój');
      expect(c['K9']!.value, '1', reason: 'rozruch');
    });

    test('rozliczenie: te same liczby co na wydruku, ale na formułach', () {
      final c = cells(build());
      final km = rowOf(c, 'Przebyto km');
      expect(c['F$km']!.formula, startsWith(r'SUM($O$17:'));
      expect(c['F$km']!.value, '50');
      expect(c['G$km']!.formula, contains(r'$D$8'));
      expect(c['G$km']!.value, '15', reason: '50 km × 30 l / 100');

      final hours = rowOf(c, 'Przepracowano godz. urządzeń');
      expect(c['F$hours']!.value, '0.5');
      expect(c['G$hours']!.value, '6', reason: '0,5 godz. × 12 l');

      final idle = rowOf(c, 'Praca na postoju');
      expect(c['F$idle']!.value, '10');
      expect(c['G$idle']!.value, '0.5');

      final startup = rowOf(c, 'Wyk. rozruch.');
      expect(c['G$startup']!.value, '1');

      final total = rowOf(c, 'Zużyto paliwa w ciągu miesiąca razem');
      expect(c['G$total']!.formula, 'IF(COUNT(\$G\$$km:\$G\$$startup)=0,"",'
          'SUM(\$G\$$km:\$G\$$startup))');
      expect(c['G$total']!.value, '22.5');
    });

    test('pobrane paliwo przechodzi do rozliczenia, a „pozostało" liczy się '
        'samo — puste, dopóki nikt nic nie wpisze', () {
      final c = cells(build());
      final intake = rowOf(c, 'Ogółem', col: 'A');
      expect(c['D$intake']!.formula, startsWith('IF(COUNT('));
      expect(c['D$intake']!.value, '');

      final got = rowOf(c, 'Pobrano w ciągu miesiąca bieżącego');
      expect(c['G$got']!.formula, contains('\$D\$$intake'));
      expect(c['G$got']!.value, '');

      final left = rowOf(c, 'Pozostało na miesiąc następny');
      expect(c['G$left']!.formula, contains('-'));
      expect(c['G$left']!.value, '', reason: 'nie zmyślamy stanu zbiornika');
    });

    test('pojazd bez norm: litry puste, ale formuły czekają na normę', () {
      final c = cells(build(
          v: Vehicle(id: 'v1', name: 'GLM 8', seats: 4)));
      final km = rowOf(c, 'Przebyto km');
      expect(c['G$km']!.value, '');
      expect(c['G$km']!.formula, contains(r'ISNUMBER($D$8)'));
      final total = rowOf(c, 'Zużyto paliwa w ciągu miesiąca razem');
      expect(c['G$total']!.value, '');
    });

    test('pusty miesiąc — sam formularz z pustymi wierszami', () {
      final c = cells(build(list: const []));
      expect(c['A17']!.value, '');
      expect(c.containsKey('N${17 + TripCardPdf.minRows - 1}'), isTrue,
          reason: 'kratki do wypełnienia');
      expect(c['F${rowOf(c, 'Przebyto km')}']!.value, '0');
    });

    test('drukuje się A4 w poziomie, bez kolumny pomocniczej, rozliczenie '
        'od nowej strony', () {
      final bytes = build();
      final sheet = part(bytes, 'xl/worksheets/sheet1.xml');
      expect(sheet, contains('orientation="landscape"'));
      expect(sheet, contains('paperSize="9"'));
      expect(sheet, contains('<rowBreaks count="1"'));
      expect(part(bytes, 'xl/workbook.xml'),
          contains("<definedName name=\"_xlnm.Print_Area\" localSheetId=\"0\">"
              "'Karta drogowa'!\$A\$1:\$N\$"));
    });

    test('nagłówek z danymi pojazdu — Marka, Model, Typ', () {
      final c = cells(build());
      expect(c['A1']!.value, 'Ochotnicza Straż Pożarna w Kielnie');
      expect(c['E1']!.value, 'MIESIĘCZNA KARTA DROGOWA');
      expect(c['E3']!.value, 'na miesiąc  listopad 2026');
      expect(c['A5']!.value, 'Marka');
      expect(c['D5']!.value, 'MAN');
      expect(c['G5']!.value, 'Model');
      expect(c['K5']!.value, 'TGM 13.290');
      expect(c['A6']!.value, 'Typ');
      expect(c['D6']!.value, 'GBA');
    });

    test('nazwa pliku bez polskich znaków, z rozszerzeniem .xlsx', () {
      expect(TripCardXlsx.fileName(vehicle, 2026, 11),
          'karta_drogowa_GBA_2_5_16_2026-11.xlsx');
    });
  });

  group('karta pracy sprzętu w Excelu', () {
    final config = UnitConfig(unitFullName: 'OSP Kielno', locality: 'Kielno');
    final saw = Equipment(
      id: 'e1',
      name: 'Pilarka',
      vehicleId: 'v1',
      fuelType: EquipmentFuel.mix,
      fuelPerHour: 1.2,
      brand: 'Stihl',
      model: 'MS 462',
    );
    final rows = [
      EquipmentCardRow(
        date: DateTime(2026, 11, 3, 19, 40),
        operatorName: 'Nowak J.',
        minutes: 90,
        purpose: 'MZ, Kielno',
        tripId: 't1',
      ),
      EquipmentCardRow(
        date: DateTime(2026, 11, 7, 10, 0),
        operatorName: 'Kowalski A.',
        minutes: 30,
        purpose: 'Rozruch kontrolny',
        isStartup: true,
        workId: 'w1',
      ),
    ];

    Uint8List build({Equipment? device}) => EquipmentCardXlsx.bytes(
          device: device ?? saw,
          rows: rows,
          config: config,
          year: 2026,
          month: 11,
        );

    test('wiersze pracy jak na wydruku, rozruch oznaczony w kolumnie '
        'pomocniczej', () {
      final c = cells(build());
      expect(c['A12']!.value, '03.11');
      expect(c['B12']!.value, 'Nowak J.');
      expect(c['C12']!.value, '90');
      expect(c['D12']!.value, 'MZ, Kielno');
      expect(c['G12']?.value ?? '', '');
      expect(c['G13']!.value, 'tak');
      expect(c['B7']!.value, 'Stihl');
      expect(c['D7']!.value, 'MS 462');
    });

    test('rozliczenie: praca bez rozruchów, rozruchy osobno, litry w ET', () {
      final c = cells(build());
      final work = rowOf(c, '4. Przepracowano godz. i min.', col: 'A');
      expect(c['C$work']!.formula, contains('"<>tak"'));
      expect(double.parse(c['C$work']!.value) * 1440, closeTo(90, 1e-6));

      final used = rowOf(c, '5. zużyto', col: 'A');
      expect(c['E$used']!.value, '1.8', reason: '1,5 godz. × 1,2 l — ET');
      expect(c['F$used']?.value ?? '', '', reason: 'mieszanka to nie ON');
      expect(c['F$used']?.formula, isNull);

      final startup = rowOf(c, '6. zużyto na rozruchy i kontrole', col: 'A');
      expect(double.parse(c['C$startup']!.value) * 1440, closeTo(30, 1e-6));
      expect(c['E$startup']!.value, '0.6');

      final total = rowOf(c, '7. zużyto w ciągu mies. Razem', col: 'A');
      expect(c['E$total']!.value, '2.4');
    });

    test('bez rodzaju paliwa — litry puste w obu kolumnach, jak na wydruku',
        () {
      final c = cells(build(
          device: Equipment(id: 'e1', name: 'Agregat', fuelPerHour: 1)));
      final used = rowOf(c, '5. zużyto', col: 'A');
      expect(c['E$used']?.formula, isNull);
      expect(c['F$used']?.formula, isNull);
    });

    test('A4 w pionie, bez kolumny „Rozruch" na wydruku', () {
      final bytes = build();
      expect(part(bytes, 'xl/worksheets/sheet1.xml'),
          contains('orientation="portrait"'));
      expect(part(bytes, 'xl/workbook.xml'), contains(r"'Karta pracy'!$A$1:$F$"));
      expect(EquipmentCardXlsx.fileName(saw, 2026, 11),
          'karta_pracy_Pilarka_2026-11.xlsx');
    });
  });
}
