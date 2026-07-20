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

## Zrobione (feature/007-monetization)
- [x] Integracja AdMob (`google_mobile_ads`)
- [x] Baner reklamowy na ekranie głównym, liście wyjazdów, ratowników i pojazdów
- [x] **NIE** wyświetlać reklam w: kroku dodawania wyjazdu, ekranie szczegółów raportu
- [x] Hardcoded wyłączenie reklam dla konta `ospkielno@gmail.com` — sprawdzanie `ownerEmail` zapisanego z Drive (`unit_config.json`)
- [x] In-app purchase „Wyłącz reklamy" (`remove_ads`) — jednorazowy zakup, sekcja Premium w Ustawieniach, możliwość przywrócenia zakupów
- [ ] **TODO przed publikacją**: zastąpić testowe ID AdMob prawdziwymi w `ad_service.dart` i `AndroidManifest.xml`
- [ ] **TODO przed publikacją**: zarejestrować produkt `remove_ads` w Google Play Console

## Zrobione (feature/008-logo)
- [x] Logo aplikacji — ikony launchera we wszystkich rozdzielczościach Android (mdpi/hdpi/xhdpi/xxhdpi/xI fouatnik+płomień)

## Zrobione (feature/009-app-name)
- [x] Zmiana nazwy wyświetlanej aplikacji z `osp_app` na **„Wyjazdy OSP"** (`android:label` w AndroidManifest.xml)

## Zrobione (feature/010-deduplikacja)
- [x] Pull raportów z Drive przed otwarciem kreatora nowego wyjazdu — numer `max+1` oparty na aktualnych danych z Drive
- [x] Wykrywanie duplikatów numerów wyjazdów po każdym sync — pomarańczowy SnackBar z listą kolizji
- [x] Brak auto-renumeracji — użytkownik decyduje co zrobić z duplikatem

## Zrobione (feature/011-printing)
- [x] Generowanie PDF A5 (148×210 mm) z polskimi znakami (OpenSans via PdfGoogleFonts)
- [x] Layout zgodny z formularzem KP PSP „Potwierdzenie udziału sił i środków podmiotu ratowniczego w działaniu ratowniczym"
  - Nagłówek: nazwa jednostki + pole `nr ewidencyjny zdarzenia` w ramce
  - Wiersz daty z podkreślonymi polami + godziny od/do
  - Wiersz adresu z pełną podkreśloną linią + zagrożenie/podkategoria
  - Tabela 5 kolumn: Lp. / Podmiot / Osoby / Czas udziału / Uwagi
  - Liczba pojazdów i strażaków w ramkach, podpis, przypisy `*` i `**`
  - Dwa egzemplarze (2 strony A5) w jednym dokumencie
- [x] Drukowanie przez Android PrintManager (Mopria/WiFi) + udostępnianie/wysyłanie PDF
- [x] Zmiana kolejności pól w kreatorze raportu: Zagrożenie → Rodzaj zagrożenia → Opis miejsca zdarzenia

## Zrobione (feature/012-statystyki-wyjazdow)
- [x] Osobny kafelek „Statystyki" na ekranie głównym (fioletowy, `/statistics`)
- [x] Filtr roku (domyślnie bieżący rok), dropdown z dostępnymi latami
- [x] Statystyki strażaków: lista posortowana malejąco wg liczby wyjazdów, strażacy z 0 ukryci, medale dla Top 3
- [x] Statystyki kategorii zagrożeń: Pożar / Miejscowe zagrożenie / Fałszywy alarm + łącznie
- [x] Łączny czas działań ratowniczych (suma returnTime − departureTime)
- [x] Ostrzeżenie o raportach bez uzupełnionego czasu zakończenia (czas = 0, lista numerów)
- [x] Drukowanie i udostępnianie PDF statystyk A4 — spójne przyciski z ekranem szczegółów raportu
- [x] Refaktor `PdfService`: wydzielono `_layoutPdf` / `_sharePdf` — zero duplikacji logiki druku
- [x] 9 nowych testów jednostkowych `computeYearStats` (łącznie 44 testy, wszystkie zielone)

## Zrobione (feature/013-druk-a4-podwojny)
- [x] **Druk 2× A5 na jednej kartce A4 (poziomo)** — dwa egzemplarze formularza KP PSP obok siebie + przerywana linia cięcia pośrodku; kartkę przecina się po wydruku
- [x] Refaktor `_buildPdf`: wydzielony `buildCopy()`, jedna strona A4 landscape zamiast dwóch stron A5
- [x] Usunięto `assets/references/` z pubspec — skan wzoru formularza nie był używany w runtime, niepotrzebnie powiększał APK
- [x] Usunięto martwy kod: nieużywana funkcja `buildDb` w `test/deduplication_test.dart`
- **Decyzja sprzętowa**: zamiast drukarki termicznej (Xprinter XP-P442B, ESC/POS) — zwykła drukarka atramentowa z Wi-Fi Direct/Mopria (np. Canon PIXMA TS3550i, ~300 zł). Zero zmian w flow druku (Mopria), zwykły papier, wydruk nie blaknie (dokumentacja archiwalna). Plan integracji ESC/POS porzucony.

## Zrobione (feature/014-kategorie-i-layout)
- [x] **Zamknięta lista kategorii zagrożeń** w stałej kolejności: Miejscowe Zagrożenie → Pożar → Fałszywy Alarm; usunięto możliwość dodawania własnych kategorii
- [x] **Nowe podkategorie**: MZ — Kolizja, Wypadek, Plama ropopochodna, Powalone drzewo, Zalana posesja; Pożar — Pożar budynku, Pożar samochodu, Pożar sadzy w kominie, Pożar lasu; obie listy z opcją „Inne — dodaj własne"
- [x] **Migracja słownika** (`ensureDefaultThreats`): przy starcie aplikacji i po sync pull — nowe listy domyślne, podtypy własne użytkownika zachowane, wycofane domyślne i kategorie spoza trójki usuwane
- [x] **Layout PDF wg szkicu** (`assets/references/potwierdzenie_udzial_w_dzialaniu.png`): kratki na znaki numeru ewidencyjnego, kropkowane linie pól, tytuł „udziału w działaniu ratowniczym w dniu…", tabela dopełniana pustymi wierszami (min 10), wysunięte przypisy `*`/`**`
- [x] **Zmiana nazwy aplikacji na „Raporty OSP"** (AndroidManifest, MaterialApp, ekran „O aplikacji", pubspec, web)
- [x] Ekran „O aplikacji": dodano sekcję „Statystyki" w instrukcji, tematy maili kontaktowych zmienione na „Raporty OSP — …"

## Zrobione (feature/015-przekazanie-mienia)
- [x] **Nowa funkcja „Przekazanie mienia"**: osobny dokument od wyjazdu — „Potwierdzenie przekazania terenu, obiektu lub mienia objętego działaniem ratowniczym" (§ 21 ust. 2 pkt 2 rozp. MSWiA z 17.09.2021 r.)
- [x] Model `PropertyHandover` (Hive) + box `property_handovers`, CRUD w `DatabaseService`, provider `handoversProvider`
- [x] Ekran formularza: opcjonalne powiązanie z istniejącym wyjazdem (auto-uzupełnia miejsce/datę/godzinę zdarzenia), zamknięta lista rodzaju podmiotu przejmującego (`HandoverRecipientTypes`, z opcją „Inne" + pole opisowe), dropdown „Przekazujący" z listy ratowników, pola przejmującego (imię i nazwisko, adres, telefon), opis mienia i uwagi
- [x] **Miejscowość i data w stopce wypełniane automatycznie** — miejscowość z `UnitConfig.locality`, data z bieżącej daty urządzenia (obie edytowalne)
- [x] Ekran listy (`/handovers`) i szczegółów (`/handovers/view/:id`) z drukiem/udostępnianiem, kafelek „Przekazania mienia (n)" na ekranie głównym
- [x] **Druk PDF A4 w 2 egzemplarzach** (osobne strony, nie A5 jak wyjazd) — layout wzorowany na dostarczonym wzorze PDF, w tym „niepotrzebne skreślić": niewybrane rodzaje podmiotu przekreślone, wybrany pogrubiony/podkreślony
- [x] Synchronizacja z Google Drive: folder `handovers/` w jednostce, push/pull analogiczne do raportów (merge po `updatedAt`)
- [x] 4 nowe testy jednostkowe modelu i stałej listy rodzajów podmiotu
- [x] Zweryfikowane end-to-end na emulatorze OSP_Test: dodanie ratownika, utworzenie przekazania (w tym wybór „Inne" z dodatkowym polem), zapis, podgląd szczegółów, podgląd wydruku (potwierdzone: ISO A4, 2 strony, poprawny layout)

### Analiza (bez zmian kodu) — tworzenie/dołączanie do jednostki
- **Brak zabezpieczenia przed utworzeniem drugiej jednostki na koncie, które już ma jednostkę**: `SyncService.createUnit()` zawsze tworzy nowy folder Drive niezależnie od tego, czy zalogowane konto już jest właścicielem/uczestnikiem innej jednostki — do rozważenia w przyszłości (np. sprawdzenie istniejącego `unit_config.json`/`driveSync` przed „Utwórz jednostkę" i zaproponowanie dołączenia/przełączenia zamiast cichego utworzenia drugiej, rozłącznej jednostki)

## Do zrobienia — Kolejne branche

### Przed publikacją w Play Store
- [ ] Zastąpić testowe ID AdMob prawdziwymi w `ad_service.dart` i `AndroidManifest.xml` (patrz feature/007)
- [ ] Zarejestrować produkt `remove_ads` w Google Play Console (patrz feature/007)
- [ ] Grafiki do sklepu: ikona 512×512, feature graphic 1024×500, min. 2 screenshoty
- [ ] Podbić wersję w `pubspec.yaml` (obecnie `1.0.0+1`)
- [ ] (opcjonalnie) Ikona monochromatyczna `<monochrome>` w adaptive icon — motywy Android 13+

### Pomysły do rozważenia
- [ ] **e-Remiza integration**: Ręczne wpisywanie z przyciskami kopiowania do schowka. Na razie nierealne — do rozważenia w przyszłości.
