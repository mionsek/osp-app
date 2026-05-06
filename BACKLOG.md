# OSP App — Backlog

## Zrobione (feature/002)
- [x] Google Sign-In + OAuth
- [x] Tworzenie jednostki z kodem zaproszenia
- [x] Dołączanie do jednostki kodem
- [x] Auto-sync co 5 minut + przy zmianie połączenia
- [x] Naprawiono: crew assignment — automatyczne tworzenie ratowników przy wpisaniu ręcznym
- [x] Naprawiono: adres — limity znaków (miejscowość 50, ulica 100)
- [x] Naprawiono: report detail — brak nawigacji do menu głównego
- [x] Naprawiono: ustawienia — potencjalne zawieszanie się

## Zrobione (feature/003-ux-polish)
- [x] Liczba ratowników na ekranie głównym: `Ratownicy (n)`
- [x] Walidacja składu zastępu: ostrzeżenie + pop-up gdy brak kierowcy/dowódcy lub <3 osoby
- [x] Ikona fałszywego alarmu: `Icons.block` na szarym tle
- [x] Ikona miejscowego zagrożenia: żółte tło (`#F9A825`)
- [x] Potwierdzenie zapisu raportu: SnackBar z info o sync
- [x] Naprawiono: case matching ikon zagrożeń (wielkie/małe litery)
- [x] Naprawiono: getNextReportNumber — szuka max numeru zamiast count+1
- [x] Naprawiono: ustawienia — layout crash (RenderFlex overflow)
- [x] Drive: unit_config.json w config/, threat_types.json zamiast threats.json

## Zrobione (feature/004-multi-account)
- [x] Nowy onboarding: wybór ścieżki (Utwórz/Dołącz) na ekranie powitalnym — bez logowania
- [x] Wybór konta Google: jednostki [zalecane] / prywatne / tryb offline
- [x] Ścieżka dołączania: logowanie Google przed kodem zaproszenia
- [x] Badge "zalecane" na karcie wyboru konta

## Zrobione (feature/005-info-and-feedback)
- [x] Ekran "O aplikacji" (`/info`): opis, instrukcja użytkowania, wersja (dynamiczna), autor
- [x] Kontakt: zgłoszenie problemu / propozycja usprawnienia (mailto:)
- [x] Kafelek "O aplikacji" na ekranie głównym
- [x] Ustawienia: dynamiczna wersja (package_info_plus) + link "Więcej o aplikacji"

## Zrobione (feature/006-badania-lekarskie)
- [x] **Ważność badań lekarskich strażaka**: Opcjonalne pole daty ważności badań lekarskich przy dodawaniu/edycji strażaka (DatePicker, placeholder daty, kolor statusu)
- [x] **Ostrzeżenie przy tworzeniu wyjazdu**: Status badań lekarskich widoczny dla każdego pola w kroku Zastępy
- [x] **Wizualna informacja na liście strażaków**: Ikony funkcji (kierowca, dowódca, KPP) + status badań pod nazwiskiem, klikalne z wyjaśnieniem
- [x] **Doprecyzowanie etykiet uprawnień w zastępach**: `✓`/`✗` tylko dla danej roli pola, `✓ KPP` opcjonalnie, status badań dla każdego
- [x] **Naprawiono: overflow na ekranie głównym** (RenderFlex — Spacer → SingleChildScrollView)

## Do zrobienia — Kolejne branche

### Branch: feature/007-monetization
- [ ] **AdMob reklamy**: Banner na ekranie głównym, interstitial przy generowaniu PDF
- [ ] **In-app purchases**: Premium (10-20 PLN) — brak reklam, dodatkowe funkcje

### Branch: feature/008-deduplikacja
- [ ] **Deduplikacja numerów wyjazdów przy sync**: Automatyczna korekta zdublowanych numerów (np. raz dziennie przy synchronizacji z Google Drive). Obecnie `getNextReportNumber` szuka najwyższego istniejącego numeru, ale przy usunięciu i re-sync mogą powstać duplikaty.

### Branch: feature/009-printing
- [ ] **Bluetooth printing**: Drukowanie na drukarce Bluetooth bez podłączania USB

#### Badanie drukarek przenośnych (A5/A4, Bluetooth, do wozu strażackiego)

**Wymagania**: Bluetooth, kompaktowa, zasilanie (akumulator / USB-C / 12V zapalniczka / 230V), format min. A5 (raport OSP), trwałość w trudnych warunkach.

**WAŻNE**: Wszystkie drukarki poniżej to **drukarki termiczne** — drukują czarno-biało na specjalnym papierze termicznym (nie na zwykłym papierze!). Wydruk może blaknąć po kilku latach. Dla raportów interwencyjnych to akceptowalne.

| Model | Cena (PLN) | Ocena | Rozdzielczość | Bateria | Formaty | Waga | Uwagi |
|-------|-----------|-------|---------------|---------|---------|------|-------|
| **Phomemo M08F** | ~537 zł | 4.4/5 (1524) | 203 DPI | 1200 mAh (~120 stron) | A4, A5 | 964g | Bluetooth + USB. Kompaktowa (35×6.5×4 cm). Najpopularniejszy model. |
| **Phomemo M834** | ~448 zł | 4.0/5 (696) | 300 DPI | wbudowana | A4, A5, 80mm, 53mm | 695g | Bluetooth + USB-C. Lżejsza, lepsza rozdzielczość. Nowszy model. |
| **Phomemo M832** | ~352 zł | 4.6/5 (1732) | 203 DPI | wbudowana | A4, A5 | ~700g | Tańsza alternatywa. Najlepsze opinie. |
| **Phomemo M832D** | ~504 zł | - | 300 DPI | wbudowana | A4, A5 | ~750g | Wersja z ekranem dotykowym. |
| **Phomemo Q302** | ~837 zł | - | 300 DPI | duża | A4, A5 | - | Premium z Wi-Fi. Droga. |
| **iDPRT MT610 Pro** | ~400-500 zł | 4.5+ | 300 DPI | wbudowana | A4, A5 | ~700g | Konkurent Phomemo. Bluetooth. Dobre opinie. |
| **VEVOR przenośna** | ~300-400 zł | 3.5-4.0 | 203 DPI | 2600 mAh | A4, A5 | ~800g | Budżetowa opcja. Tańsza, ale gorsza jakość. |
| **vretti PB821** | ~350-450 zł | 4.0 | 203 DPI | wbudowana | A4, A5 | ~800g | Alternatywa budżetowa. |

**Rekomendacja dla OSP**:
1. **Najlepsza jakość/cena**: **Phomemo M832** (~352 zł) — najlepsze opinie (4.6★), wystarczająca rozdzielczość 203 DPI, lekka
2. **Lepsza rozdzielczość**: **Phomemo M834** (~448 zł) — 300 DPI, lżejsza (695g), USB-C
3. **Budżetowa**: **VEVOR** (~300 zł) — większa bateria 2600 mAh, ale gorsza jakość

**Zasilanie w wozie strażackim**:
- Wszystkie modele ładują się przez USB-C lub micro-USB
- Do wozu wystarczy **ładowarka samochodowa USB 12V→USB** (10-30 zł) — standardowa ładowarka do telefonu
- Baterie wbudowane wystarczają na 50-120 wydruków — przy 2-3 raportach/dzień to tygodnie bez ładowania
- Brak modeli z bezpośrednim zasilaniem 12V z zapalniczki — nie jest potrzebne przy USB

**Koszt eksploatacji**: Papier termiczny A4 — ok. 1 zł/arkusz (100 szt. ~100 zł). Brak tuszu = zero kosztów eksploatacyjnych poza papierem.

**Integracja z Flutter**: Pakiet `printing` (już w projekcie) obsługuje drukowanie przez Bluetooth. Wymaga sparowania drukarki z telefonem i wysłania PDF. Phomemo ma własną aplikację, ale drukowanie przez system Android (Bluetooth) powinno działać.

### Pomysły do rozważenia
- [ ] **e-Remiza integration**: Ręczne wpisywanie z przyciskami kopiowania do schowka. Na razie nierealne — do rozważenia w przyszłości.
