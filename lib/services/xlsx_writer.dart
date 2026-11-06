import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../core/theme/osp_theme.dart';

/// Wyrównanie tekstu w komórce, w poziomie.
enum XlsxAlign { left, center, right }

/// Wygląd komórki arkusza.
///
/// Porównywany po wartościach: te same ustawienia w stu komórkach dają jeden
/// wpis w `styles.xml`, a nie sto.
class XlsxStyle {
  final bool bold;
  final bool italic;

  /// Wielkość czcionki w punktach.
  final double size;

  /// Cienka ramka dookoła — komórki tabel, jak kratki na druku.
  final bool border;

  /// Szare tło nagłówka tabeli.
  final bool shaded;

  final bool wrap;
  final XlsxAlign align;

  /// Format liczby po angielsku, np. `0.00` — Excel pokaże go po polsku
  /// („1,50"), bo plik przechowuje liczby niezależnie od języka.
  final String? numberFormat;

  const XlsxStyle({
    this.bold = false,
    this.italic = false,
    this.size = 10,
    this.border = false,
    this.shaded = false,
    this.wrap = false,
    this.align = XlsxAlign.left,
    this.numberFormat,
  });

  XlsxStyle copyWith({
    bool? bold,
    bool? italic,
    double? size,
    bool? border,
    bool? shaded,
    bool? wrap,
    XlsxAlign? align,
    String? numberFormat,
  }) =>
      XlsxStyle(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        size: size ?? this.size,
        border: border ?? this.border,
        shaded: shaded ?? this.shaded,
        wrap: wrap ?? this.wrap,
        align: align ?? this.align,
        numberFormat: numberFormat ?? this.numberFormat,
      );

  @override
  bool operator ==(Object other) =>
      other is XlsxStyle &&
      other.bold == bold &&
      other.italic == italic &&
      other.size == size &&
      other.border == border &&
      other.shaded == shaded &&
      other.wrap == wrap &&
      other.align == align &&
      other.numberFormat == numberFormat;

  @override
  int get hashCode => Object.hash(
      bold, italic, size, border, shaded, wrap, align, numberFormat);
}

/// Formuła Excela bez znaku „=", po angielsku i z przecinkami:
/// `IF(A1="","",A1*2)`. Polski Excel pokaże ją jako `JEŻELI(A1="";"";A1*2)`,
/// bo plik zapisuje formuły niezależnie od języka.
///
/// [cached] — wynik policzony w aplikacji. Excel i tak liczy wszystko od
/// nowa przy otwarciu, ale podgląd załącznika w poczcie czy na Dysku
/// niczego nie liczy i bez tej wartości pokazałby puste pola.
class XlsxFormula {
  final String expression;
  final Object? cached;
  const XlsxFormula(this.expression, [this.cached]);
}

class _Cell {
  final Object? value;
  final XlsxStyle style;
  const _Cell(this.value, this.style);
}

/// Jeden arkusz skoroszytu. Wiersze i kolumny liczone od zera.
class XlsxSheet {
  final String name;
  XlsxSheet(this.name);

  final Map<int, Map<int, _Cell>> _cells = {};
  final Map<int, double> _widths = {};
  final Map<int, double> _heights = {};
  final List<(int, int, int, int)> _merges = [];
  final List<int> _breaks = [];

  /// Druk w poziomie (karta drogowa) albo w pionie (karta pracy).
  bool landscape = false;

  /// Drukowane są tylko kolumny `0..printColumns-1` — dalsze to kolumny
  /// pomocnicze, widoczne w Excelu, ale nie na kartce.
  int? printColumns;

  /// [value]: tekst, liczba, [XlsxFormula] albo `null` — pusta komórka,
  /// ale z ramką i stylem.
  void set(int row, int col, Object? value,
      [XlsxStyle style = const XlsxStyle()]) {
    (_cells[row] ??= {})[col] = _Cell(value, style);
  }

  /// Scala prostokąt. Wartość wpisuje się w lewą górną komórkę, ale styl
  /// dostają wszystkie — inaczej Excel rysuje ramkę tylko wokół pierwszej.
  void merge(int row, int col, int lastRow, int lastCol, Object? value,
      [XlsxStyle style = const XlsxStyle()]) {
    for (var r = row; r <= lastRow; r++) {
      for (var c = col; c <= lastCol; c++) {
        set(r, c, r == row && c == col ? value : null, style);
      }
    }
    if (lastRow > row || lastCol > col) {
      _merges.add((row, col, lastRow, lastCol));
    }
  }

  /// Szerokość kolumny w znakach — jak w oknie „Szerokość kolumny" Excela.
  void width(int col, double chars) => _widths[col] = chars;

  /// Wysokość wiersza w punktach.
  void height(int row, double points) => _heights[row] = points;

  /// Wydruk zaczyna nową stronę od wiersza [row] — jak odwrót kartki.
  void pageBreakBefore(int row) => _breaks.add(row);

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

  /// Skala wydruku, przy której kolumny do [printColumns] mieszczą się na
  /// szerokość A4.
  ///
  /// Nie „dopasuj do strony": przy nim Excel pomija ręczne podziały stron,
  /// a rozliczenie ma zaczynać się od nowej kartki.
  int get _printScale {
    final columns = printColumns ?? _lastCol + 1;
    var widthPoints = 0.0;
    for (var c = 0; c < columns; c++) {
      // Szerokość w znakach na punkty: 7 px na znak + 5 px marginesu,
      // 0,75 pt na piksel (Calibri 11, 96 dpi).
      widthPoints += ((_widths[c] ?? 8.43) * 7 + 5) * 0.75;
    }
    final paper = landscape ? 842.0 : 595.0;
    final printable = paper - 2 * _marginInches * 72;
    final scale = (printable / widthPoints * 100).floor();
    return scale.clamp(10, 100);
  }

  static const double _marginInches = 0.4;
}

/// Skoroszyt Excela (.xlsx) składany z ręki z kilku plików XML w archiwum
/// ZIP — bez osobnej biblioteki arkuszy.
///
/// Karty potrzebują tylko tekstu, liczb, formuł, ramek, scalonych komórek
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
    b.write('</sheets>');
    final areas = [
      for (var i = 0; i < sheets.length; i++)
        if (sheets[i].printColumns != null)
          '<definedName name="_xlnm.Print_Area" localSheetId="$i">'
              "'${_escape(sheets[i].name.replaceAll("'", "''"))}'!"
              '\$A\$1:\$${column(sheets[i].printColumns! - 1)}'
              '\$${sheets[i]._lastRow + 1}</definedName>',
    ];
    if (areas.isNotEmpty) b.write('<definedNames>${areas.join()}</definedNames>');
    // Przeliczenie przy otwarciu — wyniki zapisane w pliku są tylko podglądem.
    b.write('<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>');
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
      ..write('<dimension ref="A1:${ref(s._lastRow, s._lastCol)}"/>')
      ..write('<sheetViews><sheetView workbookViewId="0"/></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="15"/>');

    if (s._widths.isNotEmpty) {
      b.write('<cols>');
      for (final c in s._widths.keys.toList()..sort()) {
        b.write('<col min="${c + 1}" max="${c + 1}" '
            'width="${s._widths[c]}" customWidth="1"/>');
      }
      b.write('</cols>');
    }

    b.write('<sheetData>');
    final rows = {...s._cells.keys, ...s._heights.keys}.toList()..sort();
    for (final r in rows) {
      final h = s._heights[r];
      b.write('<row r="${r + 1}"');
      if (h != null) b.write(' ht="$h" customHeight="1"');
      final cells = s._cells[r];
      if (cells == null || cells.isEmpty) {
        b.write('/>');
        continue;
      }
      b.write('>');
      for (final c in cells.keys.toList()..sort()) {
        b.write(_cellXml(ref(r, c), cells[c]!, styles, strings));
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

    const m = XlsxSheet._marginInches;
    b
      ..write('<printOptions horizontalCentered="1"/>')
      ..write('<pageMargins left="$m" right="$m" top="$m" bottom="$m" '
          'header="0.2" footer="0.2"/>')
      ..write('<pageSetup paperSize="9" scale="${s._printScale}" '
          'orientation="${s.landscape ? 'landscape' : 'portrait'}"/>');

    if (s._breaks.isNotEmpty) {
      b.write('<rowBreaks count="${s._breaks.length}" '
          'manualBreakCount="${s._breaks.length}">');
      // Podział „po wierszu id" — czyli przed wierszem o numerze id + 1.
      for (final r in s._breaks) {
        b.write('<brk id="$r" max="16383" man="1"/>');
      }
      b.write('</rowBreaks>');
    }
    b.write('</worksheet>');
    return b.toString();
  }

  String _cellXml(String at, _Cell cell, _Styles styles, _Strings strings) {
    final s = styles.index(cell.style);
    final v = cell.value;
    return switch (v) {
      null => '<c r="$at" s="$s"/>',
      final num n => '<c r="$at" s="$s"><v>${_number(n)}</v></c>',
      final String text when text.isEmpty => '<c r="$at" s="$s"/>',
      final String text =>
        '<c r="$at" s="$s" t="s"><v>${strings.index(text)}</v></c>',
      XlsxFormula(:final expression, :final cached) => switch (cached) {
          final num n => '<c r="$at" s="$s"><f>${_escape(expression)}</f>'
              '<v>${_number(n)}</v></c>',
          final String text => '<c r="$at" s="$s" t="str">'
              '<f>${_escape(expression)}</f><v>${_escape(text)}</v></c>',
          _ => '<c r="$at" s="$s"><f>${_escape(expression)}</f></c>',
        },
      _ => '<c r="$at" s="$s" t="s"><v>${strings.index('$v')}</v></c>',
    };
  }

  /// Liczba bez wykładnika i bez ogona zmiennoprzecinkowego (0.30000000000000004).
  static String _number(num n) {
    if (n is int || n == n.roundToDouble()) return n.round().toString();
    return double.parse(n.toStringAsFixed(10)).toString();
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
  /// Styl 0 to domyślny wygląd Excela — komórki bez stylu.
  final List<XlsxStyle> _styles = [const _DefaultStyle()];
  final List<(bool, bool, double)> _fonts = [(false, false, 11)];
  final List<String> _formats = [];

  int index(XlsxStyle style) {
    final i = _styles.indexOf(style);
    if (i >= 0) return i;
    _styles.add(style);
    return _styles.length - 1;
  }

  int _font(XlsxStyle s) {
    final key = (s.bold, s.italic, s.size);
    final i = _fonts.indexOf(key);
    if (i >= 0) return i;
    _fonts.add(key);
    return _fonts.length - 1;
  }

  /// Własne formaty liczb mają numery od 164 — niższe są wbudowane w Excela.
  int _format(String? code) {
    if (code == null) return 0;
    var i = _formats.indexOf(code);
    if (i < 0) {
      _formats.add(code);
      i = _formats.length - 1;
    }
    return 164 + i;
  }

  String xml() {
    final xfs = [
      for (final s in _styles)
        if (s is _DefaultStyle)
          '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        else
          _xf(s),
    ];
    final fill = OspTheme.spreadsheetHeader
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();

    final b = StringBuffer(XlsxWorkbook._xmlHeader)
      ..write('<styleSheet xmlns="${XlsxWorkbook._main}">');
    if (_formats.isNotEmpty) {
      b.write('<numFmts count="${_formats.length}">');
      for (var i = 0; i < _formats.length; i++) {
        b.write('<numFmt numFmtId="${164 + i}" '
            'formatCode="${XlsxWorkbook._escape(_formats[i])}"/>');
      }
      b.write('</numFmts>');
    }
    b.write('<fonts count="${_fonts.length}">');
    for (final (bold, italic, size) in _fonts) {
      b.write('<font>${bold ? '<b/>' : ''}${italic ? '<i/>' : ''}'
          '<sz val="${XlsxWorkbook._number(size)}"/>'
          '<name val="Calibri"/><family val="2"/></font>');
    }
    b
      ..write('</fonts>')
      ..write('<fills count="3">'
          '<fill><patternFill patternType="none"/></fill>'
          '<fill><patternFill patternType="gray125"/></fill>'
          '<fill><patternFill patternType="solid"><fgColor rgb="$fill"/>'
          '<bgColor indexed="64"/></patternFill></fill>'
          '</fills>')
      ..write('<borders count="2">'
          '<border><left/><right/><top/><bottom/><diagonal/></border>'
          '<border>'
          '<left style="thin"><color auto="1"/></left>'
          '<right style="thin"><color auto="1"/></right>'
          '<top style="thin"><color auto="1"/></top>'
          '<bottom style="thin"><color auto="1"/></bottom>'
          '<diagonal/></border>'
          '</borders>')
      ..write('<cellStyleXfs count="1">'
          '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>'
          '</cellStyleXfs>')
      ..write('<cellXfs count="${xfs.length}">${xfs.join()}</cellXfs>')
      ..write('<cellStyles count="1">'
          '<cellStyle name="Normal" xfId="0" builtinId="0"/>'
          '</cellStyles>')
      ..write('</styleSheet>');
    return b.toString();
  }

  String _xf(XlsxStyle s) {
    final horizontal = switch (s.align) {
      XlsxAlign.left => 'left',
      XlsxAlign.center => 'center',
      XlsxAlign.right => 'right',
    };
    return '<xf numFmtId="${_format(s.numberFormat)}" fontId="${_font(s)}" '
        'fillId="${s.shaded ? 2 : 0}" borderId="${s.border ? 1 : 0}" xfId="0" '
        'applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1" '
        'applyAlignment="1"><alignment horizontal="$horizontal" '
        'vertical="center"${s.wrap ? ' wrapText="1"' : ''}/></xf>';
  }
}

/// Znacznik stylu 0 — różny od każdego [XlsxStyle] z kodu.
class _DefaultStyle extends XlsxStyle {
  const _DefaultStyle() : super(size: -1);
}
