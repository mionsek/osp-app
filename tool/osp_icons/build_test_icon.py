"""Ikona wersji testowej — instaluje się obok wersji ze Sklepu Play.

Dawid jest testerem aplikacji ze Sklepu i nie chce jej odinstalowywać
(27.11.2026), więc wersja testowa ma inny identyfikator, nazwę „Raporty OSP
TEST” i ikonę: granatowe tło zamiast czerwonego i żółty napis TEST.

Czyta gotowe ikony z android/app/src/main/res (tam, gdzie zapisuje je
flutter_launcher_icons) i zapisuje wersje testowe do
android/app/src/testowa/res — ten katalog dołącza do budowania tylko
`-Ptestowa=true` (android/app/build.gradle.kts). Z katalogu głównego:

    python tool/osp_icons/build_test_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent.parent.parent
MAIN = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
TEST = ROOT / 'android' / 'app' / 'src' / 'testowa' / 'res'
FONT = ROOT / 'assets' / 'fonts' / 'OpenSans-Bold.ttf'

RED = (0xB7, 0x1C, 0x1C)
NAVY = (0x1A, 0x23, 0x7E)
YELLOW = (0xFF, 0xD6, 0x00)
INK = (0x1A, 0x23, 0x7E)
DENSITIES = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']


def label(img, center_y, width):
    """Żółta plakietka TEST na środku w poziomie."""
    w, _ = img.size
    height = width * 0.36
    draw = ImageDraw.Draw(img)
    box = [(w - width) / 2, center_y - height / 2,
           (w + width) / 2, center_y + height / 2]
    draw.rounded_rectangle(box, radius=height * 0.3, fill=YELLOW + (255,))
    font = ImageFont.truetype(str(FONT), int(height * 0.72))
    draw.text((w / 2, center_y), 'TEST', font=font, fill=INK + (255,),
              anchor='mm')


def recolor(img):
    """Czerwone tło starej ikony (bez warstw) na granatowe."""
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a and abs(r - RED[0]) < 40 and abs(g - RED[1]) < 40 and \
                    abs(b - RED[2]) < 40:
                px[x, y] = NAVY + (a,)


def main():
    for d in DENSITIES:
        fg = Image.open(MAIN / f'drawable-{d}' / 'ic_launcher_foreground.png')
        fg = fg.convert('RGBA')
        size = fg.size[0]
        # Płótno ikony adaptacyjnej 108 dp, widoczny środek 72 dp — plakietka
        # w dolnej części karty, w bezpiecznym polu.
        label(fg, size * 0.70, size * 0.36)
        out = TEST / f'drawable-{d}'
        out.mkdir(parents=True, exist_ok=True)
        fg.save(out / 'ic_launcher_test_foreground.png', optimize=True)

        legacy = Image.open(MAIN / f'mipmap-{d}' / 'ic_launcher.png')
        legacy = legacy.convert('RGBA')
        recolor(legacy)
        label(legacy, legacy.size[1] * 0.80, legacy.size[0] * 0.56)
        out = TEST / f'mipmap-{d}'
        out.mkdir(parents=True, exist_ok=True)
        legacy.save(out / 'ic_launcher_test.png', optimize=True)

    (TEST / 'mipmap-anydpi-v26').mkdir(parents=True, exist_ok=True)
    (TEST / 'mipmap-anydpi-v26' / 'ic_launcher_test.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Wersja testowa: tool/osp_icons/build_test_icon.py -->\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '  <background android:drawable="@color/ic_launcher_test_background"/>\n'
        '  <foreground android:drawable="@drawable/ic_launcher_test_foreground"/>\n'
        '  <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>\n'
        '</adaptive-icon>\n', encoding='utf-8')
    (TEST / 'values').mkdir(parents=True, exist_ok=True)
    (TEST / 'values' / 'colors_test.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <color name="ic_launcher_test_background">#1A237E</color>\n'
        '</resources>\n', encoding='utf-8')


if __name__ == '__main__':
    main()
