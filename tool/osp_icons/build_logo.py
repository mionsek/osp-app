"""Obrazki logo dla Androida z assets/icon/osp_icon.svg.

Zapisuje w assets/icon/ trzy PNG 1024 × 1024:
- osp_icon.png — pełna ikona z czerwonym tłem, przycięta do tego, co pokazuje
  launcher (środek 72 × 72 z płótna 108 × 108); mipmapy dla starych Androidów,
- osp_icon_foreground.png — karta z płomieniem na przezroczystym tle, całe
  płótno 108 × 108 (tło ikony adaptacyjnej to kolor w pubspec.yaml),
- osp_icon_monochrome.png — sam kształt karty z wyciętymi liniami
  i płomieniem; Android 13+ koloruje go według tapety (ikony tematyczne).

Potem z katalogu głównego projektu:

    pip install pymupdf
    python tool/osp_icons/build_logo.py
    dart run flutter_launcher_icons
"""
import copy
import xml.etree.ElementTree as ET
from pathlib import Path

import pymupdf

ICON = Path(__file__).parent.parent.parent / 'assets' / 'icon'
NS = 'http://www.w3.org/2000/svg'
SIZE = 1024
ET.register_namespace('', NS)


def layer(keep, view_box='0 0 108 108', fill=None):
    """SVG z samymi grupami `keep`; `fill` zamalowuje je jednym kolorem."""
    root = ET.parse(ICON / 'osp_icon.svg').getroot()
    root.set('viewBox', view_box)
    for g in list(root):
        if g.get('id') not in keep:
            root.remove(g)
        elif fill:
            for el in g.iter():
                if el.get('fill'):
                    el.set('fill', fill)
    return ET.tostring(root, encoding='unicode')


def render(svg):
    page = pymupdf.open(stream=svg.encode(), filetype='svg')[0]
    zoom = SIZE / page.rect.width
    return page.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), alpha=True)


def main():
    render(layer({'tlo', 'karta', 'wyciecia'}, '18 18 72 72')).save(ICON / 'osp_icon.png')
    render(layer({'karta', 'wyciecia'})).save(ICON / 'osp_icon_foreground.png')

    # Warstwa jednobarwna: karta minus linie i płomień (tylko kanał alfa).
    card = render(layer({'karta'}, fill='#000000')).samples
    cut = render(layer({'wyciecia'}, fill='#000000')).samples
    out = bytearray(SIZE * SIZE * 4)
    for i in range(3, len(out), 4):
        out[i - 3:i] = b'\xff\xff\xff'
        out[i] = card[i] * (255 - cut[i]) // 255
    pymupdf.Pixmap(pymupdf.csRGB, SIZE, SIZE, bytes(out), True).save(
        ICON / 'osp_icon_monochrome.png')
    print('zapisane w', ICON)


if __name__ == '__main__':
    main()
