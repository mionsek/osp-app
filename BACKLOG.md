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

## Zrobione (feature/021-wybor-ratownika)
- [x] **Naprawiono: lista podpowiedzi w kreatorze zastępów pokazywała „Imię Nazwisko"** — przeoczenie z feature/020: zmieniona była kolejność w polu tekstowym i po wyborze, ale nie w samej liście
- [x] **Lista podpowiedzi bez uprawnień i badań** (wariant C) — wcześniej były drobnym, szarym drukiem pod nazwiskiem i zlewały się z nim. Odznaki uprawnień/badań pokazują się nadal, ale dopiero **po** wybraniu osoby
- [x] **Wyszukiwanie ratowników wyciągnięte do `FirefighterSearch`** — wspólne dla kreatora zastępów i formularza przekazania. Ranking trzypoziomowy: początek nazwiska → początek imienia → dopasowanie w środku. Szuka po obu członach, wyświetla zawsze „Nazwisko Imię"
- [x] **Wybór przekazującego z wyszukiwarką** (`showFirefighterPicker`) zamiast listy rozwijanej — przy kilkudziesięciu osobach przewijanie było uciążliwe
- [x] W oknie „Dodaj ratownika" nazwisko przed imieniem, spójnie z resztą aplikacji
- [x] **Wielkie litery w polach tekstowych** — 8 miejsc: przekazanie mienia (miejsce zdarzenia, rodzaj podmiotu, adres, opis, uwagi), nazwa jednostki w Ustawieniach i onboardingu, pole wyszukiwania/tworzenia ratownika w zastępach. Celowo pominięte: wyszukiwarki, numer ewidencyjny i numer telefonu

### Do przetestowania z użytkownikami
- Czy na liście podpowiedzi w zastępach brakuje informacji o uprawnieniach i badaniach? Usunięto je (wariant C), bo zlewały się z nazwiskiem. Alternatywy, gdyby okazały się potrzebne: **(A)** nazwisko pogrubione + uprawnienia mniejszym, szarym drukiem, **(B)** nazwisko pogrubione + uprawnienia kolorem (zielony ✓ / pomarańczowy ✗), spójnie z odznakami pokazywanymi po wyborze

## Zrobione (feature/020-poprawki-raportu)

### Błędy
- [x] **Uwagi wpisywały się od tyłu i nie dało się kasować znaków** — `StepSummary` tworzył `TextEditingController` wewnątrz `build()`, więc każde naciśnięcie klawisza budowało nowy kontroler z kursorem na pozycji 0. Stąd odwrócona kolejność liter i backspace „działający raz". Pole uwag przeniesione do kroku 1, gdzie kontroler żyje w `initState()` (jedyne takie miejsce w aplikacji)
- [x] **Wyszukiwanie ratownika łapało też imię** — wpisanie „Wi" zwracało zarówno Wiktorię, jak i osoby o nazwisku na „Wi". Teraz dopasowanie priorytetowo po początku nazwiska, reszta dopasowań niżej

### Zmiany w kreatorze wyjazdu
- [x] **Uwagi przeniesione do kroku 1** — ostatni krok jest wyłącznie podsumowaniem, bez edycji: albo powrót do edycji, albo zapis
- [x] **Pole KDR usunięte z kreatora** — linia podpisu na wydruku zostaje, ale **zawsze pusta**, do wpisania odręcznie. PSP i tak wpisuje kierującego po swojemu, a przy raporcie na własny użytek pole nie jest potrzebne
- [x] **Godzina powrotu startuje pusta** (wcześniej podstawiała bieżącą godzinę) — przy tworzeniu raportu zwykle jeszcze jej nie znamy
- [x] Wielkie litery: ulica (`words`), opis miejsca zdarzenia i uwagi (`sentences`)

### Ratownicy
- [x] **„Nazwisko Imię"** — nowy getter `lastNameFirst`, użyty w wyszukiwarce zastępu, na liście ratowników i przy sortowaniu (tak zgłaszamy skład telefonicznie do PSP). Automatyczne tworzenie ratownika z wpisanego tekstu też rozbija nazwę w tej kolejności, ale rozpoznaje nadal obie
- [x] **„Ratownik" jako funkcja** — wyliczana, gdy nie ma kierowcy/dowódcy/KPP (`functionLabels`), bez zmian w danych i bez migracji: każdy strażak jest ratownikiem, a pozostałe to dodatkowe uprawnienia. Osoba bez uprawnień nie jest już pokazywana bez żadnej funkcji

### Nazewnictwo
- [x] Ujednolicone na **„pojazd"** (było raz „wóz", raz „pojazd") — ekran główny, lista pojazdów, kreator zastępów, „O aplikacji"

## Zrobione (feature/019-info-i-poprawki-ux)

### Poprawki zgłoszone po testach
- [x] **Pasek nawigacji zasłaniał przycisk w kreatorze „Dodaj wyjazd"** — kreator ma trzy własne, osobno przewijane kroki (`step_basic_info`, `step_crew`, `step_summary`), których wcześniejsza poprawka nie objęła
- [x] **Lista drukarek Bluetooth: czarno-żółty pasek przepełnienia** zasłaniał ostatnie urządzenie — okno ma teraz `isScrollControlled` + przewijaną listę
- [x] **Miejscowość jednostki usunięta z Ustawień** — do stopki „Miejscowość ... dnia ..." trafia bieżąca lokalizacja (przycisk GPS) albo wpis ręczny, bo dokument wypełnia się na miejscu zdarzenia, gdzie miejscowość jednostki bywa nieprawdziwa
- [x] **Onboarding ujednolicony z Ustawieniami** — było wciąż osobne „Nazwa jednostki" + „Miejscowość", czyli nowy użytkownik dostawał dokładnie tę gramatycznie błędną sklejkę, którą naprawialiśmy w feature/016. Teraz jedno puste pole z podpowiedzią „np. Ochotnicza Straż Pożarna w Kielnie"
- [x] Pasek tytułu skraca nazwę: „Ochotnicza Straż Pożarna w Kielnie" → „OSP w Kielnie" (nierozpoznany format zostaje w całości)
- [x] Naprawiono: dołączanie do jednostki nadpisywało `UnitConfig` nowym obiektem, gubiąc pełną nazwę pobraną z Dysku (ta sama klasa błędu, co wcześniej w Ustawieniach)

### Informacje o aplikacji
- [x] **Przepisany ekran „O aplikacji"** — wprost nazwane oba dokumenty (z podstawą prawną przy przekazaniu mienia), wyjaśniony układ 2 × A5 na kartce A4 do rozcięcia, instrukcja rozszerzona o przekazania mienia, adres z GPS, badania lekarskie i trzy sposoby wydania dokumentu
- [x] **Wprowadzenie przy pierwszym uruchomieniu** — świadomie bez blokującego samouczka:
  - ramka na ekranie powitalnym wyjaśniająca, czym aplikacja jest, zanim użytkownik wybierze „Utwórz jednostkę" / „Dołącz"
  - karta „Pierwsze kroki" na ekranie głównym: lista kontrolna (wozy → ratownicy) z odhaczaniem, skrótami do właściwych ekranów i linkiem do opisu aplikacji
- [x] Kartę można zamknąć („×" lub „Nie pokazuj ponownie"); flaga trzymana **lokalnie** w `settingsBox`, nie w synchronizowanym `UnitConfig` — inaczej zamknięcie u jednej osoby ukryłoby podpowiedź kolegom, którzy dopiero instalują aplikację

## Zrobione (feature/017-druk-bt-ux)
- [x] **Drobny druk podstawy prawnej powiększony** z 6 do 7 pkt (`_handoverLegalFontSize`) — tyle, co reszta treści formularza; przy 203 DPI drukarki termicznej 6 pkt było na granicy czytelności
- [x] **Wybór drukarki Bluetooth wprost z ekranu drukowania** — przycisk „Drukuj na drukarce Bluetooth..." jest widoczny zawsze; gdy drukarka nie jest jeszcze wybrana, kliknięcie od razu otwiera listę sparowanych urządzeń, bez odsyłania do Ustawień
- [x] Wspólny `pickBluetoothPrinter()` (`lib/widgets/bluetooth_printer_picker.dart`) — jedno źródło logiki dla Ustawień i obu ekranów druku
- [x] **Druk przez Bluetooth również dla raportu wyjazdu** (wcześniej tylko przekazanie mienia) — ten sam format A4 poziomo z 2 egzemplarzami A5, więc bez zmian w protokole
- [x] **Ostrzeżenie o zgodności drukarek** w „O aplikacji" — druk BT przetestowany wyłącznie z NETUM XL-P801, inne modele najpewniej nie zadziałają (protokół odtworzony wstecznie dla jednego modelu); zaznaczono, że zwykły „Drukuj" i „Udostępnij" działają zawsze

## Zrobione (feature/016-poprawki-przekazania-mienia)

### Druk na przenośnej drukarce termicznej Bluetooth (NETUM XL-P801)
- [x] **Druk bezpośrednio z aplikacji na drukarkę Bluetooth** — z pominięciem systemowego okna druku Androida, którego takie drukarki nie obsługują (brak usługi druku)
- [x] **Protokół drukarki odtworzony metodą inżynierii wstecznej** — mimo deklaracji sprzedawcy drukarka NIE obsługuje ESC/POS (0 komend ESC/POS w przechwyconej transmisji z aplikacji producenta). Log HCI Bluetooth → parser strumienia RFCOMM → analiza. Format: 26-bajtowy nagłówek (bajt 19 = bajtów/wiersz, bajty 20–21 = liczba wierszy BE, bajty 24–25 = długość bloku), dalej bitmapa 1-bit spakowana **raw deflate**, na końcu `ESC J 100` + `10 FF FE 45`. Potwierdzenie: 208 × 2354 = 489 632 B = dokładny rozmiar rozpakowanej bitmapy
- [x] Wybór i zapamiętanie sparowanej drukarki w Ustawieniach (`UnitConfig.btPrinterMac/btPrinterName`) — wybiera się raz
- [x] Wydruk testowy (ramka + ukośne pasy) do weryfikacji szerokości i geometrii
- [x] Przycisk „Drukuj na <drukarce>" na ekranie szczegółów przekazania mienia
- [x] Jakość druku: renderowanie w 2× rozdzielczości + uśrednianie do punktów drukarki, próg przesunięty w stronę czerni (176) — cienkie kreski i drobny tekst nie zanikają
- [x] Naprawiono (obejścia błędów pakietu `print_bluetooth_thermal`): brak żądania uprawnienia BLUETOOTH_CONNECT na Androidzie 12+ → wywołania wisiały w nieskończoność; `outputStream == null` zamiast `=` → ponowne łączenie zawsze zwracało false; `writeBytes` wymaga `List<int>`, nie `Uint8List`

### Poprawki zgłoszone po testach
- [x] **Nazwa jednostki jako jedno pole** — `UnitConfig.unitFullName`, np. „Ochotnicza Straż Pożarna w Kielnie" zamiast gramatycznie błędnej sklejki „... Kielno" (polskiej odmiany miejscowości nie da się sensownie zautomatyzować). Miejscowość została osobno — do stopki „Miejscowość ... dnia ...". Stare konfiguracje działają dalej (fallback na prefiks + miejscowość)
- [x] **Adres z GPS** (`LocationService`) — przycisk podpowiadający miejscowość i ulicę w kreatorze wyjazdu i w formularzu przekazania; pola pozostają w pełni edytowalne, czytelne komunikaty przy braku zasięgu/zgody/GPS
- [x] **Przyciski chowające się za systemowym paskiem nawigacji** — dolny odstęp `MediaQuery.viewPaddingOf(context).bottom` na wszystkich przewijanych ekranach (m.in. „Wróć do menu głównego" było całkowicie niedostępne)
- [x] Stopka „Aplikację stworzył Dawid Mionskowski" na ekranie głównym
- [x] Przekazujący strażak — opcja „Nie wybrano" z ostrzeżeniem (osobny komunikat, gdy nie ma jeszcze żadnych ratowników) zamiast twardej blokady zapisu
- [x] Formularz przekazania: A4 poziomo z 2 egzemplarzami A5 obok siebie (zamiast 2 osobnych stron A4), stopka bezpośrednio pod podpisami
- [x] Naprawiono: `Firefighter.fullNameWithRank` dawał „Jan Kowalski," gdy stopień był pusty
- [x] Naprawiono: zapis Ustawień tworzył nową konfigurację od zera, kasując konto właściciela i zapamiętaną drukarkę

### Do rozważenia w kolejnym branchu
- Podgląd wydruku przed wysłaniem na drukarkę Bluetooth (obecnie druk startuje od razu)
- Powiększyć drobny tekst podstawy prawnej („zgodnie z § 21 ust. 2 pkt 2...") — przy 6 pkt i 203 DPI jest na granicy czytelności

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

### Przebieg pojazdów (kilometry)
Ewidencja przebiegu per pojazd — Gospodarz jednostki rozlicza się miesięcznie
z kilometrów przejechanych przez każdy pojazd. Do przemyślenia: czy wpisywać
stan licznika przy wyjeździe i powrocie (dokładniejsze, ale dwa pola więcej
w kreatorze), czy sam dystans po fakcie; plus ekran historii i podsumowanie
miesięczne/roczne do wydruku.

### Funkcje ratownika — możliwe rozszerzenia
Obecnie „Ratownik" jest **wyliczany**: brak kierowcy/dowódcy/KPP = ratownik.
Rozważane alternatywy, gdyby to przestało wystarczać:
- jawny checkbox „Ratownik" (wymaga pilnowania sprzeczności i uzupełnienia
  istniejących wpisów),
- pełny słownik funkcji zamiast trzech flag (np. mechanik, operator sprzętu,
  ratownik wodny) — pozwoliłby też odróżnić uprawnienia od funkcji na wyjeździe.

### Godziny dla PSP vs OSP
PSP nie potrzebuje godzin, OSP tak. Na razie rozwiązane tak, że godzina powrotu
startuje pusta i wpisuje się ją samodzielnie. Gdyby okazało się to niewygodne,
do rozważenia osobne pola „czas dla PSP" i „czas wewnętrzny OSP".

### Podgląd wydruku przed drukiem Bluetooth
Obecnie druk startuje od razu po kliknięciu.


### Przed publikacją w Play Store
- [ ] Zastąpić testowe ID AdMob prawdziwymi w `ad_service.dart` i `AndroidManifest.xml` (patrz feature/007)
- [ ] Zarejestrować produkt `remove_ads` w Google Play Console (patrz feature/007)
- [ ] Grafiki do sklepu: ikona 512×512, feature graphic 1024×500, min. 2 screenshoty
- [ ] Podbić wersję w `pubspec.yaml` (obecnie `1.0.0+1`)
- [ ] (opcjonalnie) Ikona monochromatyczna `<monochrome>` w adaptive icon — motywy Android 13+

### Pomysły do rozważenia
- [ ] **e-Remiza integration**: Ręczne wpisywanie z przyciskami kopiowania do schowka. Na razie nierealne — do rozważenia w przyszłości.
