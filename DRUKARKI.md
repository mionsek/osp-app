# Drukarki do raportów OSP — research (stan: 15.07.2026)

Kontekst: raporty drukujemy **2× A5 na jednej kartce A4** (layout z linią cięcia
jest w aplikacji od feature/013). Drukarka musi być osiągalna z telefonu
**bez routera** — czyli Wi-Fi Direct / Access Point Mode + Mopria
(wtedy działa obecny flow `Printing.layoutPdf()` bez żadnych zmian w kodzie)
albo Bluetooth (wtedy druk przez aplikację producenta, poza naszym flow).

## ⚠️ Kartki A4, nie rolki — sprawdzone

Wszystkie modele poniżej drukują na **pojedynczych kartkach A4 (210×297 mm)**:

- **Atramentowe (Canon/HP)** — zwykły papier ksero A4, podajnik na ~50–60 kartek.
- **Termiczne (Phomemo M08F, PeriPage A40)** — obsługują **cięte arkusze
  termiczne A4** (pudełka po 100–200 kartek); rolka to tylko opcjonalna
  alternatywa (uchwyt sprzedawany osobno), nie wymóg.
  Uwaga: to musi być **papier termiczny** (specjalny, ~25–40 zł/200 szt.),
  nie zwykły ksero — i wydruk termiczny **blaknie z czasem**.

## Rekomendacja: Canon PIXMA TS3550i (~267–350 zł)

Stacjonarna atramentowa, **Access Point Mode** (telefon łączy się bezpośrednio
z drukarką bez routera), Mopria/AirPrint, zwykły papier A4 — wydruk nie blaknie,
co ma znaczenie, bo formularz KP PSP trafia do dokumentacji archiwalnej.
Zero zmian w aplikacji.

- [Media Expert](https://www.mediaexpert.pl/komputery-i-tablety/drukarki-i-urzadzenia-biurowe/urzadzenia-wielofunkcyjne/urzadzenie-wielofunkcyjne-canon-pixma-ts3550i-czarny)
- [RTV Euro AGD](https://www.euro.com.pl/urzadzenia-wielofunkcyjne/canon-urzadzenie-wielof-canon-pixma-ts3550i.bhtml)
- [Kozak.pl — najniższa znaleziona cena ~267 zł](https://kozak.pl/drukarka-canon-pixma-ts3550i)
- [Canon Polska — strona produktu](https://www.canon.pl/support/consumer/products/printers/pixma/ts-series/pixma-ts3550i.html)
- Alternatywa: HP DeskJet 4220e (Wi-Fi Direct) — [szukaj na Ceneo](https://www.ceneo.pl/;szukaj-hp+deskjet+4220e)

## Przenośne termiczne A4 (Bluetooth + bateria)

Drukują na ciętych arkuszach termicznych A4. Druk przez aplikację producenta
(udostępnij PDF), nie przez Mopria. Wydruk blaknie po miesiącach — słabe do
dokumentów archiwizowanych.

| Model | Cena | Papier | Link |
|---|---|---|---|
| Phomemo M08F | ~430–470 zł | arkusze A4 (200 szt./pudełko) lub rolka z uchwytem | [Allegro](https://allegro.pl/produkt/przenosna-drukarka-termiczna-a4-bluetooth-m08f-c3f94e2c-d77f-43ea-848b-44863d45d464) · [GOMEDIA](https://gomedia.net.pl/pl/p/Drukarka-Termiczna-do-Dokumentow-Papier-A4-Phomemo-M08F-Bluetooth-Android/2444868) |
| AIMO M08F (203 dpi) | ~430 zł | arkusze A4 (100 szt. w zestawie) | [Strefadrukarek](https://strefadrukarek.pl/pl/products/przenosna-drukarka-a4-aimo-m08f-203dpi-do-210mm-pc-mac-smartfon-bt-usb-5411.html) |
| PeriPage A40 (304 dpi) | ~390–450 zł | arkusze składane A4 (100 szt.) lub rolka | [Ceneo](https://www.ceneo.pl/87317371) · [PeriPage Store](https://www.peripageglobal.com/collections/a4) |
| NETUM LT-A10 (203 dpi) | **209 zł** | pojedyncze arkusze A4/A5/B5 lub rolka (57–210 mm) | [Allegro](https://allegro.pl/oferta/przenosna-termiczna-drukarka-a4-netum-lt-a10-do-dokumentow-zdjec-etykiet-18491947859) · [ERLI](https://erli.pl/produkt/przenosna-termiczna-drukarka-a4-netum-do-dokumentow-zdjec-etykiet-tatuaz,223525837) |

NETUM LT-A10 — szczegóły z oferty Allegro (209 zł, sprawdzone 15.07.2026):
- BT + USB, bateria **1500 mAh** (mniejsza niż w Phomemo/PeriPage), ładowanie 5 V/2 A
- szerokość druku **A4, A5, B5, 57 mm** — jako jedyna z listy obsługuje wprost
  kartki A5 (można by drukować pojedyncze egzemplarze A5 bez cięcia!)
- druk przez apkę **ScanPrint** (Android/iOS) — poza flow Mopria
- sprzedawca **nie wystawia faktury** — problem, jeśli kupuje jednostka
- zdecydowanie najtańsza (209 zł vs Phomemo ~430 zł), ale nadal: tylko papier
  termiczny → wydruk blaknie, słaby do dokumentacji archiwalnej

Papier termiczny A4 (cięte kartki):
[Phomemo 200 szt. — Amazon.pl](https://www.amazon.pl/Phomemo-szybkoschn%C4%85cy-termiczny-przeno%C5%9Bnej-termicznej/dp/B0D6BK35HH) ·
[Phomemo 200 szt. — Empik](https://www.empik.com/papier-termiczny-kartki-bialy-a4-210mm-200-szt-do-phomemo-m832-m833-m08f-q22-dzf2-rmsg10-a4-phomemo,p1550913341,elektronika-p) ·
[uniwersalny 200 szt. — Allegro](https://allegro.pl/oferta/papier-termiczny-a4-200-szt-do-przenosnej-drukarki-m08f-pj-i-inne-arkusze-17776932612) ·
[PeriPage A40 (3 lata trwałości obrazu)](https://www.peripageglobal.com/products/peripage-a40-thermal-paper)

## Przenośne atramentowe A4 (kartki, zwykły papier) — odrzucone (cena)

| Model | Cena | Status | Link |
|---|---|---|---|
| Canon PIXMA TR150 | ~1430 zł | wycofany ze sprzedaży | [Komputronik](https://www.komputronik.pl/product/701346/canon-pixma-tr150.html) |
| Brother PJ-763 / PJ-773 | ~2900 zł | dostępny | [itcom](https://shop.itcom.com.pl/category/extra-drukarki-przenosne-a4) |
| HP OfficeJet 200 | ~1100–1400 zł | dostępny | [Ceneo](https://www.ceneo.pl/;szukaj-hp+officejet+200) |

## Katalogi / przeglądy

- [Strefadrukarek — przenośne drukarki A4](https://strefadrukarek.pl/przenosne-drukarki-a4)
- [Ceneo — przenośna drukarka A4](https://www.ceneo.pl/oferty/przenosna-drukarka-a4)
- [Komputronik — drukarki przenośne](https://www.komputronik.pl/search-filter/7789/drukarki-przenosne)
- [Ranking tanich drukarek do 300 zł](https://www.videotesty.pl/ranking/3791/jaka-tania-drukarka-do-300-zl/)

## Wnioski

1. Budżetowe drukarki natywnie A5 praktycznie nie istnieją (tylko termiczne) —
   decyzja o druku 2× A5 na A4 i cięciu jest słuszna.
2. Do remizy: **Canon TS3550i (~267 zł)** — zwykłe kartki A4, zero zmian
   w aplikacji, trwały wydruk, najtańsza sensowna opcja.
3. Jeśli kiedyś potrzebny będzie druk „w terenie": termiczna Phomemo/PeriPage
   (~400 zł) — też drukują na kartkach A4 (termicznych, ciętych), ale wydruk
   blaknie i druk idzie poza flow Mopria.
