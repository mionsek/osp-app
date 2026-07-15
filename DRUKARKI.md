# Drukarki do raportów OSP — research (stan: 15.07.2026)

Kontekst: raporty drukujemy **2× A5 na jednej kartce A4** (layout z linią cięcia
jest w aplikacji od feature/013). Drukarka musi być osiągalna z telefonu
**bez routera** — czyli Wi-Fi Direct / Access Point Mode + Mopria
(wtedy działa obecny flow `Printing.layoutPdf()` bez żadnych zmian w kodzie)
albo Bluetooth (wtedy druk przez aplikację producenta, poza naszym flow).

## Rekomendacja: Canon PIXMA TS3550i (~250–350 zł)

Stacjonarna atramentowa, **Access Point Mode** (telefon łączy się bezpośrednio
z drukarką), Mopria/AirPrint, zwykły papier — wydruk nie blaknie, co ma znaczenie,
bo formularz KP PSP trafia do dokumentacji archiwalnej.

- Opis funkcji (Access Point Mode): https://techdirect.ng/products/canon-pixma-ts3550i-all-in-one-wireless-wifi-printer
- Szukaj w PL: https://www.ceneo.pl/;szukaj-canon+pixma+ts3550i
- Alternatywa w tej samej klasie: HP DeskJet 4220e (Wi-Fi Direct) — https://www.ceneo.pl/;szukaj-hp+deskjet+4220e

## Przenośne termiczne A4 (Bluetooth + bateria)

Uwaga: papier termiczny **blaknie po kilku miesiącach** — słabe do dokumentów
archiwizowanych. Druk przez aplikację producenta (share PDF), nie przez Mopria.

| Model | Cena | Łączność | Link |
|---|---|---|---|
| Phomemo M08F | ~430–470 zł | BT, USB-C, bateria 1200 mAh | https://allegro.pl/produkt/przenosna-drukarka-termiczna-a4-bluetooth-m08f-c3f94e2c-d77f-43ea-848b-44863d45d464 |
| AIMO M08F (203 dpi, 210 mm) | ~430 zł | BT, USB | https://strefadrukarek.pl/pl/products/przenosna-drukarka-a4-aimo-m08f-203dpi-do-210mm-pc-mac-smartfon-bt-usb-5411.html |
| PeriPage A40 (304 dpi) | ~390–450 zł | BT, bateria 2600 mAh | https://www.ceneo.pl/87317371 · https://allegro.pl/listing?string=drukarka+peripage |
| Zenwire TP-810T (300 dpi) | ~400–500 zł | BT, USB-C | https://zenwire.eu/pl/p/Mini-Drukarka-Termiczna-A4-Przenosna-Mobilna-Zenwire-TP-810T/393 |

## Przenośne atramentowe A4 — odrzucone (cena)

| Model | Cena | Status | Link |
|---|---|---|---|
| Canon PIXMA TR150 | ~1430 zł | wycofany ze sprzedaży | https://www.komputronik.pl/product/701346/canon-pixma-tr150.html |
| Brother PJ-763 / PJ-773 | ~2900 zł | dostępny | https://shop.itcom.com.pl/category/extra-drukarki-przenosne-a4 |
| HP OfficeJet 200 | ~1100–1400 zł | dostępny | https://www.ceneo.pl/;szukaj-hp+officejet+200 |

## Katalogi / przeglądy

- Przenośne drukarki A4: https://strefadrukarek.pl/przenosne-drukarki-a4
- Ceneo — przenośna drukarka A4: https://www.ceneo.pl/oferty/przenosna-drukarka-a4
- Komputronik — drukarki przenośne: https://www.komputronik.pl/search-filter/7789/drukarki-przenosne
- Ranking tanich drukarek do 300 zł: https://www.videotesty.pl/ranking/3791/jaka-tania-drukarka-do-300-zl/

## Wnioski

1. Budżetowe drukarki natywnie A5 praktycznie nie istnieją (tylko termiczne) —
   decyzja o druku 2× A5 na A4 i cięciu jest słuszna.
2. Do remizy: **Canon TS3550i** (lub HP DeskJet 4220e) — zero zmian w aplikacji,
   trwały wydruk, najtańsza opcja.
3. Jeśli kiedyś potrzebny będzie druk „w terenie": termiczna Phomemo/PeriPage
   (~400 zł), ale z zastrzeżeniem blaknięcia i druku poza flow Mopria.
