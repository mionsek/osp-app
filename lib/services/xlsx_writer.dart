import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Wyrównanie tekstu w komórce, w poziomie.
enum XlsxAlign { left, center, right }

/// Wygląd komórki arkusza.
///
/// Porównywany po wartościach: te same ustawienia w stu komórkach dają jeden
/// wpis w `styles.xml`, a nie sto.
class XlsxStyle {
  final String font;
  final double size;
  final bool bold;
  final XlsxAlign align;

  /// Tekst przy górnej krawędzi zamiast na środku wysokości.
  final bool top;
  final bool wrap;

  /// Za długi tekst zmniejsza się do szerokości komórki.
  final bool shrink;

  /// Linie krawędzi: 0 — brak, 1 — cienka, 2 — gruba.
  final int left, topLine, right, bottom;

  const XlsxStyle({
    this.font = 'Arial',
    this.size = 10,
    this.bold = false,
    this.align = XlsxAlign.left,
    this.top = false,
    this.wrap = false,
    this.shrink = false,
    this.left = 0,
    this.topLine = 0,
    this.right = 0,
    this.bottom = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is XlsxStyle &&
      other.font == font &&
      other.size == size &&
      other.bold == bold &&
      other.align == align &&
      other.top == top &&
      other.wrap == wrap &&
      other.shrink == shrink &&
      other.left == left &&
      other.topLine == topLine &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(font, size, bold, align, top, wrap, shrink,
      left, topLine, right, bottom);
}

/// Jeden arkusz skoroszytu. Wiersze i kolumny liczone od zera.
///
/// Drukuje się na A4 w poziomie, cały na jednej kartce.
class XlsxSheet {
  final String name;
  XlsxSheet(this.name);

  final Map<int, Map<int, (Object?, XlsxStyle)>> _cells = {};
  final Map<int, double> _widths = {};
  final Map<int, double> _heights = {};
  final List<(int, int, int, int)> _merges = [];
  ({double left, double top, double right, double bottom}) _margins =
      (left: 10, top: 10, right: 10, bottom: 10);

  /// [value]: tekst, liczba albo `null` — pusta komórka z ramką.
  void set(int row, int col, Object? value, XlsxStyle style) =>
      (_cells[row] ??= {})[col] = (value, style);

  /// Scala prostokąt — wartość i styl ustawia się osobno, przez [set].
  void mergeRange(int row, int col, int lastRow, int lastCol) {
    if (lastRow > row || lastCol > col) {
      _merges.add((row, col, lastRow, lastCol));
    }
  }

  /// Szerokość kolumny w znakach — jak w oknie „Szerokość kolumny" Excela.
  void width(int col, double chars) => _widths[col] = chars;

  /// Wysokość wiersza w punktach.
  void height(int row, double points) => _heights[row] = points;

  /// Marginesy wydruku w milimetrach.
  void margins({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) =>
      _margins = (left: left, top: top, right: right, bottom: bottom);

  int get _lastRow {
    final rows = [..._cells.keys, ..._heights.keys];
    return rows.isEmpty ? 0 : rows.reduce((a, b) => a > b ? a : b);
  }

  int get _lastCol {
    var last = 0;
    for (final row in _cells.values) {
      for (final c in row.keys) {
        if (c > last) last = c;
      }
    }
    return last;
  }
}

/// Skoroszyt Excela (.xlsx) składany z ręki z kilku plików XML w archiwum
/// ZIP — bez osobnej biblioteki arkuszy.
///
/// Karty potrzebują tylko tekstu, liczb, ramek, scalonych komórek
/// i ustawień wydruku — to kilkaset linii, nad którymi mamy pełną kontrolę.
/// ZIP robi `archive`, który i tak jest w aplikacji przez bibliotekę PDF.
class XlsxWorkbook {
  final List<XlsxSheet> sheets = [];

  XlsxSheet addSheet(String name) {
    final sheet = XlsxSheet(name);
    sheets.add(sheet);
    return sheet;
  }

  /// Typ pliku do udostępniania.
  static const String mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Adres komórki: (0, 0) → `A1`, (9, 27) → `AB10`.
  static String ref(int row, int col) => '${column(col)}${row + 1}';

  /// Litery kolumny: 0 → `A`, 25 → `Z`, 26 → `AA`.
  static String column(int col) {
    var n = col + 1;
    var s = '';
    while (n > 0) {
      final r = (n - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  Uint8List save() {
    final styles = _Styles();
    final strings = _Strings();
    final sheetXml = [
      for (final s in sheets) _sheetXml(s, styles, strings),
    ];

    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes()))
      ..addFile(ArchiveFile.string('_rels/.rels', _rootRels))
      ..addFile(ArchiveFile.string('xl/workbook.xml', _workbookXml()))
      ..addFile(
          ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRels()))
      ..addFile(ArchiveFile.string('xl/styles.xml', styles.xml()))
      ..addFile(ArchiveFile.string('xl/sharedStrings.xml', strings.xml()));
    for (var i = 0; i < sheets.length; i++) {
      archive.addFile(
          ArchiveFile.string('xl/worksheets/sheet${i + 1}.xml', sheetXml[i]));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static const _main =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _rel =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  static const _xmlHeader =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

  static const _rootRels = '$_xmlHeader'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$_rel/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  String _contentTypes() {
    const ct = 'application/vnd.openxmlformats-officedocument.spreadsheetml';
    final b = StringBuffer(_xmlHeader)
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Override PartName="/xl/workbook.xml" ContentType="$ct.sheet.main+xml"/>')
      ..write('<Override PartName="/xl/styles.xml" ContentType="$ct.styles+xml"/>')
      ..write('<Override PartName="/xl/sharedStrings.xml" ContentType="$ct.sharedStrings+xml"/>');
    for (var i = 0; i < sheets.length; i++) {
      b.write('<Override PartName="/xl/worksheets/sheet${i + 1}.xml" '
          'ContentType="$ct.worksheet+xml"/>');
    }
    b.write('</Types>');
    return b.toString();
  }

  String _workbookXml() {
    final b = StringBuffer(_xmlHeader)
      ..write('<workbook xmlns="$_main" xmlns:r="$_rel">')
      ..write('<bookViews><workbookView/></bookViews><sheets>');
    for (var i = 0; i < sheets.length; i++) {
      b.write('<sheet name="${_escape(sheets[i].name)}" sheetId="${i + 1}" '
          'r:id="rId${i + 1}"/>');
    }
    b.write('</sheets></workbook>');
    return b.toString();
  }

  String _workbookRels() {
    final b = StringBuffer(_xmlHeader)
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (var i = 0; i < sheets.length; i++) {
      b.write('<Relationship Id="rId${i + 1}" Type="$_rel/worksheet" '
          'Target="worksheets/sheet${i + 1}.xml"/>');
    }
    final n = sheets.length;
    b
      ..write('<Relationship Id="rId${n + 1}" Type="$_rel/styles" Target="styles.xml"/>')
      ..write('<Relationship Id="rId${n + 2}" Type="$_rel/sharedStrings" Target="sharedStrings.xml"/>')
      ..write('</Relationships>');
    return b.toString();
  }

  String _sheetXml(XlsxSheet s, _Styles styles, _Strings strings) {
    final b = StringBuffer(_xmlHeader)
      ..write('<worksheet xmlns="$_main" xmlns:r="$_rel">')
      // Cała strona na jednej kartce — jak strona PDF.
      ..write('<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>')
      ..write('<dimension ref="A1:${ref(s._lastRow, s._lastCol)}"/>')
      ..write('<sheetViews><sheetView workbookViewId="0" showGridLines="0"/>'
          '</sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="15"/>');

    if (s._widths.isNotEmpty) {
      b.write('<cols>');
      for (final c in s._widths.keys.toList()..sort()) {
        b.write('<col min="${c + 1}" max="${c + 1}" '
            'width="${_number(s._widths[c]!)}" customWidth="1"/>');
      }
      b.write('</cols>');
    }

    b.write('<sheetData>');
    final rows = {...s._cells.keys, ...s._heights.keys}.toList()..sort();
    for (final r in rows) {
      final h = s._heights[r];
      b.write('<row r="${r + 1}"');
      if (h != null) b.write(' ht="${_number(h)}" customHeight="1"');
      final cells = s._cells[r];
      if (cells == null || cells.isEmpty) {
        b.write('/>');
        continue;
      }
      b.write('>');
      for (final c in cells.keys.toList()..sort()) {
        final (value, style) = cells[c]!;
        b.write(_cellXml(ref(r, c), value, styles.index(style), strings));
      }
      b.write('</row>');
    }
    b.write('</sheetData>');

    if (s._merges.isNotEmpty) {
      b.write('<mergeCells count="${s._merges.length}">');
      for (final (r1, c1, r2, c2) in s._merges) {
        b.write('<mergeCell ref="${ref(r1, c1)}:${ref(r2, c2)}"/>');
      }
      b.write('</mergeCells>');
    }

    String inch(double mm) => _number(mm / 25.4);
    final m = s._margins;
    b
      ..write('<pageMargins left="${inch(m.left)}" right="${inch(m.right)}" '
          'top="${inch(m.top)}" bottom="${inch(m.bottom)}" '
          'header="0" footer="0"/>')
      ..write('<pageSetup paperSize="9" orientation="landscape" '
          'fitToWidth="1" fitToHeight="1"/>')
      ..write('</worksheet>');
    return b.toString();
  }

  String _cellXml(String at, Object? v, int s, _Strings strings) =>
      switch (v) {
        null => '<c r="$at" s="$s"/>',
        final num n => '<c r="$at" s="$s"><v>${_number(n)}</v></c>',
        final String text when text.isEmpty => '<c r="$at" s="$s"/>',
        _ => '<c r="$at" s="$s" t="s"><v>${strings.index('$v')}</v></c>',
      };

  /// Liczba bez wykładnika i bez ogona zmiennoprzecinkowego (0.30000000000000004).
  static String _number(num n) {
    if (n is int || n == n.roundToDouble()) return n.round().toString();
    return double.parse(n.toStringAsFixed(6)).toString();
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Tekst raz, w `sharedStrings.xml` — tak zapisuje go sam Excel i tak
/// czytają go wszystkie przeglądarki arkuszy.
class _Strings {
  final Map<String, int> _index = {};

  int index(String s) => _index.putIfAbsent(s, () => _index.length);

  String xml() {
    final b = StringBuffer(XlsxWorkbook._xmlHeader)
      ..write('<sst xmlns="${XlsxWorkbook._main}" count="${_index.length}" '
          'uniqueCount="${_index.length}">');
    for (final s in _index.keys) {
      b.write('<si><t xml:space="preserve">${XlsxWorkbook._escape(s)}</t></si>');
    }
    b.write('</sst>');
    return b.toString();
  }
}

class _Styles {
  /// Styl 0 to domyślny wygląd Excela; własne style od 1.
  final List<XlsxStyle> _styles = [];
  final List<(String, double, bool)> _fonts = [('Calibri', 11, false)];
  final List<(int, int, int, int)> _borders = [(0, 0, 0, 0)];

  int index(XlsxStyle style) {
    var i = _styles.indexOf(style);
    if (i < 0) {
      _styles.add(style);
      i = _styles.length - 1;
    }
    return i + 1;
  }

  int _id<T>(List<T> list, T item) {
    final i = list.indexOf(item);
    if (i >= 0) return i;
    list.add(item);
    return list.length - 1;
  }

  String xml() {
    // Najpierw wszystkie xf — każde dopisuje swoją czcionkę i ramkę.
    final xfs = [for (final s in _styles) _xf(s)];

    final b = StringBuffer(XlsxWorkbook._xmlHeader)
      ..write('<styleSheet xmlns="${XlsxWorkbook._main}">')
      ..write('<fonts count="${_fonts.length}">');
    for (final (name, size, bold) in _fonts) {
      b.write('<font>${bold ? '<b/>' : ''}'
          '<sz val="${XlsxWorkbook._number(size)}"/>'
          '<name val="${XlsxWorkbook._escape(name)}"/></font>');
    }
    b
      ..write('</fonts>')
      ..write('<fills count="2">'
          '<fill><patternFill patternType="none"/></fill>'
          '<fill><patternFill patternType="gray125"/></fill>'
          '</fills>')
      ..write('<borders count="${_borders.length}">');
    const line = ['', 'thin', 'medium'];
    String side(String tag, int w) => w == 0
        ? '<$tag/>'
        : '<$tag style="${line[w]}"><color auto="1"/></$tag>';
    for (final (l, t, r, bt) in _borders) {
      b.write('<border>${side('left', l)}${side('right', r)}'
          '${side('top', t)}${side('bottom', bt)}<diagonal/></border>');
    }
    b
      ..write('</borders>')
      ..write('<cellStyleXfs count="1">'
          '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
          '</cellStyleXfs>')
      ..write('<cellXfs count="${xfs.length + 1}">'
          '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
          '${xfs.join()}</cellXfs>')
      ..write('<cellStyles count="1">'
          '<cellStyle name="Normal" xfId="0" builtinId="0"/>'
          '</cellStyles>')
      ..write('</styleSheet>');
    return b.toString();
  }

  String _xf(XlsxStyle s) {
    final font = _id(_fonts, (s.font, s.size, s.bold));
    final border = _id(_borders, (s.left, s.topLine, s.right, s.bottom));
    final horizontal = switch (s.align) {
      XlsxAlign.left => 'left',
      XlsxAlign.center => 'center',
      XlsxAlign.right => 'right',
    };
    return '<xf numFmtId="0" fontId="$font" fillId="0" borderId="$border" '
        'xfId="0" applyFont="1" applyBorder="1" applyAlignment="1">'
        '<alignment horizontal="$horizontal" '
        'vertical="${s.top ? 'top' : 'center'}"'
        '${s.wrap ? ' wrapText="1"' : ''}'
        '${s.shrink ? ' shrinkToFit="1"' : ''}/></xf>';
  }
}
