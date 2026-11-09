import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'xlsx_writer.dart';

/// Krój pisma druku: bezszeryfowy jak Arial (strony tytułowe kart) albo
/// szeryfowy jak Times New Roman (tabela przejazdów karty drogowej).
enum CardFont { sans, serif }

enum CardAlign { left, center, right }

/// Wygląd tekstu w ramce.
class CardText {
  final double size;
  final bool bold;
  final CardFont font;
  final CardAlign align;

  /// Tekst przy górnej krawędzi ramki zamiast na środku wysokości.
  final bool top;

  const CardText({
    this.size = 9,
    this.bold = false,
    this.font = CardFont.sans,
    this.align = CardAlign.left,
    this.top = false,
  });

  CardText copyWith({
    double? size,
    bool? bold,
    CardFont? font,
    CardAlign? align,
    bool? top,
  }) =>
      CardText(
        size: size ?? this.size,
        bold: bold ?? this.bold,
        font: font ?? this.font,
        align: align ?? this.align,
        top: top ?? this.top,
      );
}

/// Prostokąt na stronie — w milimetrach od lewego górnego rogu kartki.
///
/// Krawędzie to grubości linii w punktach; 0 — bez linii.
class CardBox {
  final double x, y, w, h;
  final String text;
  final CardText style;
  final double left, top, right, bottom;

  /// Dane wpisane przez aplikację, a nie nadruk formularza: za długi tekst
  /// zmniejsza się do szerokości rubryki, zamiast wychodzić poza nią.
  final bool fit;

  const CardBox(
    this.x,
    this.y,
    this.w,
    this.h, {
    this.text = '',
    this.style = const CardText(),
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.fit = false,
  });

  bool get hasBorder => left > 0 || top > 0 || right > 0 || bottom > 0;
}

/// Komórka tabeli [CardPage.table]: wiersz, kolumna, ile wierszy i kolumn
/// zajmuje (scalenie), treść i krawędzie bez linii.
class Cell {
  final int r, c, rs, cs;
  final String text;
  final CardText? style;
  final bool fit;

  /// Krawędzie bez linii: 'l', 't', 'r', 'b' — np. numer pozycji i jej
  /// nazwa w jednej rubryce rozliczenia.
  final String open;

  const Cell(
    this.r,
    this.c,
    this.text, {
    this.rs = 1,
    this.cs = 1,
    this.style,
    this.fit = false,
    this.open = '',
  });
}

/// Jedna strona karty (A4 poziomo) jako zbiór ramek z tekstem.
///
/// Ten sam opis rysuje PDF ([CardSheet.pdf]) i arkusz Excela
/// ([CardSheet.xlsx]), więc oba pliki wyglądają tak samo — prośba Dawida
/// z 9.11.2026: karty mają być „DOKŁADNIE TAKIE SAME" jak papierowe,
/// także po wydruku z Excela.
class CardPage {
  static const double width = 297;
  static const double height = 210;

  /// Linie tabel w punktach: wewnętrzne i obwódka.
  static const double thin = 0.6;
  static const double thick = 1.3;

  /// Nazwa strony — arkusz w Excelu.
  final String title;
  final List<CardBox> boxes = [];

  CardPage(this.title);

  /// Tekst bez ramki.
  void text(double x, double y, double w, double h, String text,
      [CardText style = const CardText(), bool fit = false]) {
    boxes.add(CardBox(x, y, w, h, text: text, style: style, fit: fit));
  }

  /// Tabela: kolumny i wiersze w milimetrach, komórki z treścią i scaleniami.
  /// Miejsca niezajęte przez [cells] stają się pustymi kratkami.
  void table(
    double x,
    double y,
    List<double> cols,
    List<double> rows,
    List<Cell> cells, {
    CardText style = const CardText(),
  }) {
    final taken = List.generate(rows.length, (_) => List.filled(cols.length, false));
    final all = [...cells];
    for (final c in cells) {
      for (var r = c.r; r < c.r + c.rs; r++) {
        for (var k = c.c; k < c.c + c.cs; k++) {
          taken[r][k] = true;
        }
      }
    }
    for (var r = 0; r < rows.length; r++) {
      for (var k = 0; k < cols.length; k++) {
        if (!taken[r][k]) all.add(Cell(r, k, ''));
      }
    }

    double sum(List<double> v, int from, int to) =>
        v.sublist(from, to).fold(0.0, (a, b) => a + b);
    for (final c in all) {
      final lastRow = c.r + c.rs == rows.length;
      final lastCol = c.c + c.cs == cols.length;
      double edge(String side, bool outer) =>
          c.open.contains(side) ? 0 : (outer ? thick : thin);
      boxes.add(CardBox(
        x + sum(cols, 0, c.c),
        y + sum(rows, 0, c.r),
        sum(cols, c.c, c.c + c.cs),
        sum(rows, c.r, c.r + c.rs),
        text: c.text,
        style: c.style ?? style,
        fit: c.fit,
        left: edge('l', c.c == 0),
        top: edge('t', c.r == 0),
        right: edge('r', lastCol),
        bottom: edge('b', lastRow),
      ));
    }
  }
}

/// Zapis stron kart do PDF i do Excela.
class CardSheet {
  CardSheet._();

  static const double _mm = PdfPageFormat.mm;

  /// Odstęp tekstu od pionowej krawędzi ramki (mm).
  static const double _pad = 1;

  static Map<(CardFont, bool), pw.Font>? _fonts;

  /// Liberation Sans i Serif — krojami i szerokościami liter odpowiadają
  /// Arialowi i Times New Roman z papierowych kart. W paczce aplikacji, bo
  /// karty drukuje się też bez internetu.
  static Future<Map<(CardFont, bool), pw.Font>> _loadFonts() async {
    final cached = _fonts;
    if (cached != null) return cached;
    Future<pw.Font> load(String name) async => pw.Font.ttf(
        await rootBundle.load('assets/fonts/Liberation$name.ttf'));
    return _fonts = {
      (CardFont.sans, false): await load('Sans-Regular'),
      (CardFont.sans, true): await load('Sans-Bold'),
      (CardFont.serif, false): await load('Serif-Regular'),
      (CardFont.serif, true): await load('Serif-Bold'),
    };
  }

  static Future<Uint8List> pdf(
    List<CardPage> pages, {
    required String title,
    required String author,
  }) async {
    final fonts = await _loadFonts();
    final doc = pw.Document(title: title, author: author);
    for (final page in pages) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(children: [
          pw.CustomPaint(
            size: const PdfPoint(CardPage.width * _mm, CardPage.height * _mm),
            painter: (canvas, size) => _lines(canvas, size, page.boxes),
          ),
          for (final b in page.boxes)
            if (b.text.isNotEmpty) _text(b, fonts),
        ]),
      ));
    }
    return Uint8List.fromList(await doc.save());
  }

  /// Linie wszystkich ramek. Wspólna krawędź dwóch sąsiednich komórek to
  /// dwie linie w tym samym miejscu — na papierze jedna.
  static void _lines(PdfGraphics canvas, PdfPoint size, List<CardBox> boxes) {
    canvas
      ..setStrokeColor(PdfColors.black)
      ..setLineCap(PdfLineCap.square);
    void line(double w, double x1, double y1, double x2, double y2) {
      if (w <= 0) return;
      canvas
        ..setLineWidth(w)
        ..moveTo(x1 * _mm, size.y - y1 * _mm)
        ..lineTo(x2 * _mm, size.y - y2 * _mm)
        ..strokePath();
    }

    for (final b in boxes) {
      line(b.left, b.x, b.y, b.x, b.y + b.h);
      line(b.top, b.x, b.y, b.x + b.w, b.y);
      line(b.right, b.x + b.w, b.y, b.x + b.w, b.y + b.h);
      line(b.bottom, b.x, b.y + b.h, b.x + b.w, b.y + b.h);
    }
  }

  static pw.Widget _text(CardBox b, Map<(CardFont, bool), pw.Font> fonts) {
    final s = b.style;
    final align = switch (s.align) {
      CardAlign.left => pw.TextAlign.left,
      CardAlign.center => pw.TextAlign.center,
      CardAlign.right => pw.TextAlign.right,
    };
    final x = switch (s.align) {
      CardAlign.left => -1.0,
      CardAlign.center => 0.0,
      CardAlign.right => 1.0,
    };
    pw.Widget text = pw.Text(
      b.text,
      textAlign: align,
      style: pw.TextStyle(font: fonts[(s.font, s.bold)], fontSize: s.size),
    );
    if (b.fit) text = pw.FittedBox(fit: pw.BoxFit.scaleDown, child: text);
    return pw.Positioned(
      left: b.x * _mm,
      top: b.y * _mm,
      child: pw.SizedBox(
        width: b.w * _mm,
        height: b.h * _mm,
        child: pw.Padding(
          padding: pw.EdgeInsets.symmetric(
              horizontal: _pad * _mm, vertical: s.top ? 0.6 * _mm : 0),
          child: pw.Align(
              alignment: pw.Alignment(x, s.top ? 1 : 0), child: text),
        ),
      ),
    );
  }

  /// Arkusz Excela: każda strona to osobny arkusz w siatce z granic
  /// wszystkich ramek — ramka to scalony zakres komórek z tymi samymi
  /// liniami. Wydruk: A4 poziomo, cała strona na jednej kartce.
  static Uint8List xlsx(List<CardPage> pages) {
    final book = XlsxWorkbook();
    final names = <String>{};
    for (var i = 0; i < pages.length; i++) {
      _sheet(book.addSheet(_sheetName(i, pages[i].title, names)), pages[i]);
    }
    return book.save();
  }

  /// Nazwa arkusza: do 31 znaków, bez znaków zakazanych w Excelu
  /// („GBA 3/30" → „GBA 3-30"), niepowtarzalna.
  static String _sheetName(int i, String title, Set<String> used) {
    var name = '${i + 1} ${title.replaceAll(RegExp(r'[\[\]:*?/\\]'), '-')}';
    if (name.length > 31) name = name.substring(0, 31).trim();
    while (!used.add(name)) {
      name = '${name.substring(0, name.length - 1)}_';
    }
    return name;
  }

  static double _round(double v) => (v * 10).roundToDouble() / 10;

  static void _sheet(XlsxSheet sheet, CardPage page) {
    final xs = <double>{}, ys = <double>{};
    for (final b in page.boxes) {
      xs..add(_round(b.x))..add(_round(b.x + b.w));
      ys..add(_round(b.y))..add(_round(b.y + b.h));
    }
    final xl = xs.toList()..sort();
    final yl = ys.toList()..sort();
    int col(double x) => xl.indexOf(_round(x));
    int row(double y) => yl.indexOf(_round(y));

    for (var c = 0; c + 1 < xl.length; c++) {
      // Szerokość Excela: piksele przy 96 dpi minus 5 px marginesu, przez
      // 7 px na znak (Calibri 11 — czcionka domyślna skoroszytu).
      final px = (xl[c + 1] - xl[c]) / 25.4 * 96;
      sheet.width(c, px > 12 ? (px - 5) / 7 : px / 12);
    }
    for (var r = 0; r + 1 < yl.length; r++) {
      sheet.height(r, (yl[r + 1] - yl[r]) / 25.4 * 72);
    }
    sheet.margins(
      left: xl.first,
      top: yl.first,
      right: CardPage.width - xl.last,
      bottom: CardPage.height - yl.last,
    );

    // Linie komórek: [lewa, górna, prawa, dolna].
    final borders = <(int, int), List<double>>{};
    List<double> at(int r, int c) => borders[(r, c)] ??= [0, 0, 0, 0];
    void put(int r, int c, int side, double w) {
      final b = at(r, c);
      if (w > b[side]) b[side] = w;
    }

    final texts = <(int, int), CardBox>{};
    for (final b in page.boxes) {
      final c0 = col(b.x), c1 = col(b.x + b.w) - 1;
      final r0 = row(b.y), r1 = row(b.y + b.h) - 1;
      for (var r = r0; r <= r1; r++) {
        put(r, c0, 0, b.left);
        put(r, c1, 2, b.right);
      }
      for (var c = c0; c <= c1; c++) {
        put(r0, c, 1, b.top);
        put(r1, c, 3, b.bottom);
      }
      if (b.text.isEmpty) continue;
      texts[(r0, c0)] = b;
      sheet.mergeRange(r0, c0, r1, c1);
    }

    int weight(double w) => w <= 0 ? 0 : (w < 1 ? 1 : 2);
    for (final MapEntry(key: (r, c), value: b) in borders.entries) {
      final box = texts[(r, c)];
      final s = box?.style;
      sheet.set(
        r,
        c,
        box == null ? null : _value(box.text),
        XlsxStyle(
          font: s?.font == CardFont.serif ? 'Times New Roman' : 'Arial',
          size: s?.size ?? 9,
          bold: s?.bold ?? false,
          align: switch (s?.align) {
            CardAlign.center => XlsxAlign.center,
            CardAlign.right => XlsxAlign.right,
            _ => XlsxAlign.left,
          },
          top: s?.top ?? false,
          wrap: box != null && !box.fit,
          shrink: box?.fit ?? false,
          left: weight(b[0]),
          topLine: weight(b[1]),
          right: weight(b[2]),
          bottom: weight(b[3]),
        ),
      );
    }
  }

  /// Liczba („4310", „0,26") jako liczba, żeby dało się ją liczyć; reszta
  /// („04.11", „19:07", „26L") jako tekst.
  static Object _value(String text) {
    if (RegExp(r'^-?\d+(,\d+)?$').hasMatch(text)) {
      return num.parse(text.replaceAll(',', '.'));
    }
    return text;
  }
}
