import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/services/card_sheet.dart';
import 'package:osp_app/services/equipment_card.dart';
import 'package:osp_app/services/equipment_card_sheet.dart';
import 'package:osp_app/services/trip_card.dart';
import 'package:osp_app/services/xlsx_writer.dart';

/// Karty drogowe i karty pracy jak papierowe karty OSP Kielno.
///
/// Dawid, 9.11.2026 (pięć zdjęć kart): wydruk i plik mają być „DOKŁADNIE
/// TAKIE SAME jak ta karta — cały układ tabeli, komórki, scalone komórki,
/// pogrubiony tekst, szerokość tabel", także po wydruku z Excela. PDF
/// i Excel rysują się z tego samego opisu strony ([CardPage]), więc test
/// sprawdza opis, a potem, że Excel ma z niego to samo.
void main() {
  final config = UnitConfig(
    unitFullName: 'Ochotnicza Straż Pożarna w Kielnie',
    locality: 'Kielno',
    unitStreet: 'Oliwska 12',
  );
  final man = Vehicle(
    id: 'v1',
    name: 'GBA 3/30',
    seats: 6,
    make: 'MAN',
    model: 'TGM 320',
    kind: 'GBA 3/30',
    plate: 'GWE 8998T',
    fuelPer100Km: 26,
    pumpFuelPerHour: 15.6, // 0,26 l/min — tak jest na karcie
    idleFuelPerMinute: 0.13,
    startupFuelPerMonth: 2.5,
  );
  final pump = Equipment(
      id: 'pump', name: 'Autopompa', vehicleId: 'v1', poweredByVehicle: true);
  final at = DateTime(2026, 11, 4, 20, 17);
  VehicleTrip trip(String id, int start, int end, {int day = 4}) => VehicleTrip(
        id: id,
        vehicleId: 'v1',
        date: DateTime(2026, 11, day),
        routeFrom: 'Kielno, Oliwska 12',
        routeTo: 'Szemud',
        purpose: TripPurposes.training,
        driverName: 'Mielewczyk M.',
        departureTime: at,
        returnTime: at.add(const Duration(hours: 1)),
        odometerStart: start,
        odometerEnd: end,
        idleMinutes: 20,
        equipmentUse: [
          TripEquipmentUse(name: 'Autopompa', minutes: 30, equipmentId: 'pump'),
        ],
        createdAt: at,
        updatedAt: at,
      );

  List<CardPage> card({List<VehicleTrip>? trips, Vehicle? v}) => TripCard.pages(
        trips: trips ?? [trip('t1', 4310, 4330), trip('t2', 4330, 4340, day: 8)],
        vehicle: v ?? man,
        config: config,
        year: 2026,
        month: 11,
        equipment: [pump],
      );

  String part(Uint8List bytes, String name) => utf8.decode(
      ZipDecoder().decodeBytes(bytes).findFile(name)!.readBytes()!);

  Iterable<String> texts(CardPage p) =>
      p.boxes.map((b) => b.text).where((t) => t.isNotEmpty);
  CardBox box(CardPage p, String text) =>
      p.boxes.firstWhere((b) => b.text == text);

  /// Ramka z tekstem na prawo od [label], w tym samym wierszu.
  String rightOf(CardPage p, String label) {
    final l = box(p, label);
    final row = p.boxes.where((b) =>
        b.text.isNotEmpty && b.y == l.y && b.x >= l.x + l.w - 0.01).toList()
      ..sort((a, b) => a.x.compareTo(b.x));
    return row.first.text;
  }

  group('karta drogowa — strona zewnętrzna', () {
    test('okładka: napisy jak na papierze, Typ to model, Rodzaj — GBA', () {
      final p = card().first;
      for (final t in [
        'OSP KIELNO',
        'Jednostka m..p.',
        'NUMER EWIDENCYJNY KARTY PRACY',
        'MIESIĘCZNA KARTA DROGOWA',
        'POŻARNICZEGO POJAZDU SAMOCHODOWEGO',
        'Numer operacyjny',
        'Rodzaj paliwa',
        'ON/ET',
        'Norma zużycia paliwa autopompy',
        'Zużycie -praca na postoju silnika l/min',
        'Rozruch silnika 1/m - c',
        'Stan licznika autopompy',
        'ZAPISY DOTYCZĄCE OBSŁUG TECHNICZNYCH I TP.\n'
            'Remontu , zakupu, wymiany podzespołów',
        '(miejscowość, data i podpis osoby wydającej kartę)',
      ]) {
        expect(texts(p), contains(t), reason: t);
      }
      expect(rightOf(p, 'Marka'), 'MAN');
      expect(rightOf(p, 'Typ'), 'TGM 320');
      expect(rightOf(p, 'Rodzaj'), 'GBA 3/30');
      expect(rightOf(p, 'Nr rej.'), 'GWE 8998T');
      expect(box(p, 'MAN').style.bold, isTrue);
      expect(box(p, 'Listopad 2026 r.'), isNotNull);
    });

    test('normy w zapisie z karty: 26L, 0,26L/MIN, 0,13L/MIN, 2,5/M-C', () {
      final p = card().first;
      expect(texts(p), containsAll(['26L', '0,26L/MIN', '0,13L/MIN', '2,5/M-C']));
    });

    test('rozliczenie: 12 pozycji, km, godziny, minuty i litry z norm', () {
      final p = card().first;
      for (final t in [
        'ROZLICZENIE MATERIAŁÓW PĘDNYCH',
        'Pobrano (w litrach)',
        'Ogółem',
        'Pozostało z ubiegłego miesiąca',
        'Przepracowano\no godz.',
        'Zużyto paliwa w ciągu miesiąca razem:',
        'Oszczędzono- przechowano',
        'Obliczył',
        '(imię i nazwisko, podpis, data)',
      ]) {
        expect(texts(p), contains(t), reason: t);
      }
      for (var n = 1; n <= 12; n++) {
        expect(texts(p), contains('$n'), reason: 'pozycja $n');
      }
      // 30 km × 26 l / 100 = 7,8; 1 godz. autopompy × 15,6; 40 min × 0,13.
      expect(rightOf(p, 'Przebyto km'), '30');
      expect(texts(p), containsAll(['7,8', '15,6', '5,2', '2,5']));
      // Razem: 7,8 + 15,6 + 5,2 + 2,5 = 31,1 — w kolumnie ON.
      expect(texts(p), contains('31,1'));
    });

    test('„Pobrano (w litrach)" scalone nad czterema kolumnami', () {
      final p = card().first;
      final pobrano = box(p, 'Pobrano (w litrach)');
      expect(pobrano.w, closeTo(14 + 27 + 21 + 21, 0.01));
      expect(box(p, 'Podpis\nmagazyniera').h, closeTo(6 + 5.5, 0.01),
          reason: 'na dwa wiersze nagłówka');
    });
  });

  group('karta drogowa — strona wewnętrzna', () {
    test('kolumny jak na papierze, bez „Lp.", krój jak Times', () {
      final p = card()[1];
      expect(texts(p), isNot(contains('Lp.')));
      for (final t in [
        'Data',
        'Nazwisko\ndysponenta',
        'Trasy jazdy Skąd-dokąd',
        'Cel jazdy',
        'Odjazdy',
        'Przyjazdy',
        'Godz.Min.',
        'Stan licznika',
        'Minuty pracy\nurządzeń\nspecjalistycznych',
        'Dodatki*',
        'Praca silnika\nna postoju\nmin.',
        'Podpis\ndysponenta',
        '* np.. P-30 (praca silnika na postoju - 30 min)',
      ]) {
        expect(texts(p), contains(t), reason: t);
      }
      expect(box(p, 'Cel jazdy').style.font, CardFont.serif);
    });

    test('24 wiersze, dwa na przejazd; cel „Ć" na środku', () {
      final p = card()[1];
      final dates = p.boxes
          .where((b) => b.hasBorder && b.x == 12 && b.y >= 14 + 13)
          .toList();
      expect(dates, hasLength(TripCard.rowsPerPage));
      expect(dates.first.text, '04.11');
      final cel = p.boxes.firstWhere((b) => b.text == 'Ć');
      expect(cel.style.align, CardAlign.center);
      expect(texts(p), containsAll(['OSP – Szemud', 'Szemud – OSP', 'Powrót', '4310']));
    });
  });

  group('karta pracy sprzętu', () {
    final niagara = Equipment(
      id: 'e1',
      name: 'MOTOPOMPA PŁYWAJĄCA',
      brand: 'NIAGARA',
      model: 'GKV160KN/5',
      fuelType: EquipmentFuel.petrol,
      fuelPerHour: 2,
    );
    final honda = Equipment(
        id: 'e2', name: 'AGREGAT PRĄDOTWÓRCZY', brand: 'HONDA', model: 'GX160');
    final rows = [
      EquipmentCardRow(
          date: DateTime(2026, 11, 4),
          operatorName: 'Nowak J.',
          minutes: 90,
          purpose: 'MZ, Kielno'),
      EquipmentCardRow(
          date: DateTime(2026, 11, 7),
          operatorName: 'Kowalski A.',
          minutes: 30,
          purpose: 'Rozruch kontrolny',
          isStartup: true),
    ];
    List<CardPage> sheets() => EquipmentCardSheet.pages(
        cards: [(niagara, rows), (honda, const [])],
        config: config,
        year: 2026,
        month: 11);

    test('dwie karty A5 obok siebie, napisy z papieru', () {
      final front = sheets().first;
      for (final t in [
        'Jednostka',
        'OSP Kielno',
        'MIESIĘCZNA KARTA PRACY',
        'SPRZĘTU SILNIKOWEGO',
        'Na miesiąc',
        'Listopad 2026',
        'Norma eksploatacyjna na 1 godz. Pracy',
        'litrów',
        'Nazwisko i imię\nobsługującego',
        'Minut\npracy',
        'Cel użycia',
      ]) {
        expect(texts(front).where((x) => x == t), hasLength(2), reason: t);
      }
      expect(rightOf(front, 'Typ'), 'GKV160KN/5');
      expect(box(front, 'NIAGARA').x, lessThan(CardPage.width / 2));
      expect(box(front, 'HONDA').x, greaterThan(CardPage.width / 2));
      expect(texts(front), containsAll(['04.11', 'Nowak J.', '90', 'MZ, Kielno']));
    });

    test('tył: karty w odwrotnej kolejności, rozliczenie z litrami w ET', () {
      final back = sheets()[1];
      // Druga karta z przodu (Honda) jest z tyłu po lewej.
      final rozliczenia = back.boxes
          .where((b) => b.text == 'ROZLICZANIE MATERIAŁÓW PĘDNYCH')
          .toList();
      expect(rozliczenia, hasLength(2));
      expect(texts(back), containsAll(['1 godz. 30 min', '3', '30 min', '1', '4']));
      // Litry tylko po stronie Niagary (prawa połowa).
      expect(box(back, '3').x, greaterThan(CardPage.width / 2));
    });
  });

  group('układ, który drukuje się tak samo wszędzie', () {
    List<CardPage> all() => [
          ...card(),
          ...card(trips: [for (var i = 0; i < 14; i++) trip('t$i', 10, 20)]),
          ...EquipmentCardSheet.pages(
              cards: [(Equipment(id: 'e', name: 'Pilarka'), const [])],
              config: config,
              year: 2026,
              month: 11),
        ];

    test('wszystko na kartce A4, z marginesem na niedrukowalny brzeg', () {
      for (final p in all()) {
        for (final b in p.boxes) {
          expect(b.x, greaterThanOrEqualTo(8), reason: '${p.title}: ${b.text}');
          expect(b.y, greaterThanOrEqualTo(8), reason: '${p.title}: ${b.text}');
          expect(b.x + b.w, lessThanOrEqualTo(CardPage.width - 8),
              reason: '${p.title}: ${b.text}');
          expect(b.y + b.h, lessThanOrEqualTo(CardPage.height - 8),
              reason: '${p.title}: ${b.text}');
        }
      }
    });

    test('napisy nie nachodzą na siebie — w Excelu każdy to osobny scalony '
        'zakres', () {
      for (final p in all()) {
        final t = p.boxes.where((b) => b.text.isNotEmpty).toList();
        for (var i = 0; i < t.length; i++) {
          for (var j = i + 1; j < t.length; j++) {
            final a = t[i], b = t[j];
            final overlap = a.x < b.x + b.w - 0.01 &&
                b.x < a.x + a.w - 0.01 &&
                a.y < b.y + b.h - 0.01 &&
                b.y < a.y + a.h - 0.01;
            expect(overlap, isFalse,
                reason: '${p.title}: „${a.text}" i „${b.text}"');
          }
        }
      }
    });

    test('14 przejazdów — druga strona przejazdów', () {
      final pages = card(trips: [for (var i = 0; i < 14; i++) trip('t$i', 10, 20)]);
      expect(pages.map((p) => p.title),
          ['Okładka GBA 3/30', 'Przejazdy GBA 3/30', 'Przejazdy GBA 3/30 2']);
    });
  });

  group('Excel z tego samego opisu', () {
    Map<String, ({String value, String? style})> cells(Uint8List bytes,
        {int sheet = 1}) {
      final zip = ZipDecoder().decodeBytes(bytes);
      String part(String name) => utf8.decode(zip.findFile(name)!.readBytes()!);
      final strings = [
        for (final m in RegExp(r'<si><t[^>]*>(.*?)</t></si>', dotAll: true)
            .allMatches(part('xl/sharedStrings.xml')))
          m
              .group(1)!
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .replaceAll('&amp;', '&'),
      ];
      return {
        for (final m in RegExp(
                r'<c r="([A-Z]+\d+)" s="(\d+)"( t="s")?(?:/>|><v>(.*?)</v></c>)')
            .allMatches(part('xl/worksheets/sheet$sheet.xml')))
          m.group(1)!: (
            value: m.group(3) != null
                ? strings[int.parse(m.group(4)!)]
                : (m.group(4) ?? ''),
            style: m.group(2),
          ),
      };
    }

    test('każda strona to arkusz z tymi samymi napisami co PDF', () {
      final pages = card();
      final bytes = CardSheet.xlsx(pages);
      expect(part(bytes, 'xl/workbook.xml'),
          allOf(contains('name="1 Okładka GBA 3-30"'),
              contains('name="2 Przejazdy GBA 3-30"')));
      for (var i = 0; i < pages.length; i++) {
        final values = cells(bytes, sheet: i + 1).values.map((c) => c.value);
        for (final t in texts(pages[i])) {
          final asNumber = RegExp(r'^-?\d+(,\d+)?$').hasMatch(t)
              ? t.replaceAll(',', '.')
              : t;
          expect(values, contains(asNumber), reason: '${pages[i].title}: $t');
        }
      }
    });

    test('scalone komórki, grube obwódki, A4 poziomo na jednej kartce', () {
      final bytes = CardSheet.xlsx(card());
      final sheet = part(bytes, 'xl/worksheets/sheet1.xml');
      expect(RegExp('<mergeCell ').allMatches(sheet).length, greaterThan(20));
      expect(sheet, contains('<pageSetUpPr fitToPage="1"/>'));
      expect(sheet, contains('orientation="landscape"'));
      expect(sheet, contains('fitToWidth="1" fitToHeight="1"'));
      final styles = part(bytes, 'xl/styles.xml');
      expect(styles, contains('style="medium"'));
      expect(styles, contains('<name val="Arial"/>'));
      final inner = part(bytes, 'xl/styles.xml');
      expect(inner, contains('<name val="Times New Roman"/>'));
    });

    test('liczniki jako liczby, daty i godziny jako tekst', () {
      final bytes = CardSheet.xlsx(card());
      final inner = part(bytes, 'xl/worksheets/sheet2.xml');
      expect(RegExp(r'<c r="[A-Z]+\d+" s="\d+"><v>4310</v></c>').hasMatch(inner),
          isTrue);
      expect(cells(bytes, sheet: 2).values.map((c) => c.value),
          containsAll(['04.11', '20:17']));
    });
  });

  group('zapis arkusza', () {
    test('litery kolumn jak w Excelu', () {
      expect(XlsxWorkbook.column(0), 'A');
      expect(XlsxWorkbook.column(25), 'Z');
      expect(XlsxWorkbook.column(26), 'AA');
      expect(XlsxWorkbook.column(701), 'ZZ');
      expect(XlsxWorkbook.ref(9, 27), 'AB10');
    });

    test('plik ma części, bez których Excel go nie otworzy', () {
      final book = XlsxWorkbook();
      book.addSheet('Arkusz').set(0, 0, 'x', const XlsxStyle());
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

    test('polskie znaki i znaki specjalne bez zmian; jeden styl dla wielu '
        'komórek', () {
      final book = XlsxWorkbook();
      const style = XlsxStyle(bold: true, left: 2);
      final sheet = book.addSheet('Arkusz')..set(0, 0, 'Żółć <gęś> & "łódź"', style);
      for (var r = 1; r < 50; r++) {
        sheet.set(r, 0, 'x', style);
      }
      final bytes = book.save();
      expect(part(bytes, 'xl/sharedStrings.xml'),
          contains('Żółć &lt;gęś&gt; &amp; &quot;łódź&quot;'));
      expect(part(bytes, 'xl/styles.xml'), contains('<cellXfs count="2">'));
    });
  });

  test('EquipmentCard.rows i totals bez zmian — tylko nowy wygląd', () {
    final t = EquipmentCard.totals(
        Equipment(id: 'e', name: 'P', fuelPerHour: 2),
        [
          EquipmentCardRow(
              date: DateTime(2026, 11, 1),
              operatorName: '',
              minutes: 90,
              purpose: ''),
        ]);
    expect(t.workFuel, 3);
  });
}
