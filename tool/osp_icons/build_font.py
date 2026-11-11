"""Składa czcionkę z ikonami spoza Material: assets/fonts/OspIcons.otf.

Rysunki w svg/ to niezmienione pliki z Material Design Icons (Pictogrammers,
@mdi/svg 7.4.47, Apache 2.0 — licencja w assets/fonts/MDI-LICENSE.txt).
Do aplikacji trafiają tylko te, których używamy, zamiast całego pakietu
z kilkoma tysiącami ikon.

Nowa ikona: plik SVG z MDI do svg/, wpis w ICONS poniżej (kolejny kod
z obszaru prywatnego Unicode) i stała w lib/core/theme/osp_icons.dart
z tym samym kodem. Potem z katalogu głównego projektu:

    pip install fonttools
    python tool/osp_icons/build_font.py
"""
import re
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path

HERE = Path(__file__).parent
OUT = HERE.parent.parent / 'assets' / 'fonts' / 'OspIcons.otf'

# nazwa pliku w svg/ → kod znaku (ten sam w OspIcons w Darcie)
ICONS = {
    'alarm-light': 0xE000,
    'human-male-board': 0xE001,
    'car-wrench': 0xE002,
    'circular-saw': 0xE003,
}

# Siatka 24 × 24 jak w Material Icons; oś y w czcionce rośnie w górę.
EM = 960
SCALE = EM / 24
FLIP = (SCALE, 0, 0, -SCALE, 0, EM)


def draw(d, pen):
    parse_path(d, TransformPen(pen, FLIP))


def main():
    names = list(ICONS)
    charstrings, metrics = {}, {}
    for name in names:
        svg = (HERE / 'svg' / f'{name}.svg').read_text(encoding='utf-8')
        assert 'viewBox="0 0 24 24"' in svg, name
        paths = re.findall(r'<path d="([^"]+)"', svg)
        assert len(paths) == 1, name
        pen = T2CharStringPen(EM, None)
        draw(paths[0], pen)
        charstrings[name] = pen.getCharString()
        bounds = BoundsPen(None)
        draw(paths[0], bounds)
        metrics[name] = (EM, round(bounds.bounds[0]))

    charstrings['.notdef'] = T2CharStringPen(EM, None).getCharString()
    metrics['.notdef'] = (EM, 0)

    fb = FontBuilder(EM, isTTF=False)
    fb.setupGlyphOrder(['.notdef'] + names)
    fb.setupCharacterMap({cp: name for name, cp in ICONS.items()})
    fb.setupCFF('OspIcons-Regular', {'FullName': 'OspIcons'}, charstrings, {})
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=EM, descent=0)
    fb.setupNameTable({'familyName': 'OspIcons', 'styleName': 'Regular'})
    fb.setupOS2(sTypoAscender=EM, sTypoDescender=0, sTypoLineGap=0,
                usWinAscent=EM, usWinDescent=0)
    fb.setupPost()
    # Stała data w nagłówku — ten sam plik przy każdym przebudowaniu.
    fb.updateHead(created=0, modified=0)
    fb.font.recalcTimestamp = False
    fb.save(str(OUT))
    print(f'{OUT}: {len(names)} ikon')


if __name__ == '__main__':
    main()
