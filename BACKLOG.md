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
- [x] ~~TODO przed publikacją: prawdziwe ID AdMob~~ — nieaktualne, reklamy usunięte w feature/030
- [x] ~~TODO przed publikacją: produkt `remove_ads` w Play Console~~ — nieaktualne, płatności usunięte w feature/030

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

## Zrobione (fix/029-poprawki-ewidencji)
Druga tura poprawek po testach Wojtka — tym razem na wersji 1.1.0, więc były to realne błędy, a nie brak aktualizacji.
- [x] **Miejscowość w stopce przekazania nie nadążała za źródłem adresu** — moje własne zabezpieczenie z fix/027 („aktualizuj tylko gdy pole puste") chroniło ręczny wpis, ale przy okazji blokowało każdą kolejną aktualizację: po pobraniu adresu z GPS albo po zmianie powiązanego wyjazdu w stopce zostawała **poprzednia** miejscowość. Rozwiązane rozróżnieniem, czy wartość wpisał człowiek, czy podstawiła ją aplikacja — ręczny wpis jest chroniony, automatyczny idzie za zmianą źródła. Świadome kliknięcie „Wstaw adres z GPS" nadpisuje nawet wpis ręczny, bo to wyraźna prośba o adres stąd
- [x] **Godzina powrotu dopisana w starszej wersji nigdy nie trafiała do ewidencji** — synchronizacja raport → przejazd z fix/027 działa wyłącznie w momencie **zapisania raportu**, więc dane rozjechane wcześniej zostawały rozjechane na zawsze; sama aktualizacja aplikacji niczego nie leczyła. Dodane uzgadnianie przy starcie aplikacji i po każdym pobraniu z Dysku (`reconcileTripsWithReports`), zmieniające wyłącznie kolumny pochodzące z raportu
- [x] **„Skąd" zostawało puste w przejazdach sprzed wpisania adresu jednostki** — adres remizy jest przepisywany do przejazdu przy jego tworzeniu, więc uzupełnienie go w ustawieniach nie naprawiało wstecz istniejących wpisów. Dodane `fillMissingRouteFrom`, wywoływane przy starcie, po synchronizacji i zaraz po zapisaniu adresu w ustawieniach. Rusza **wyłącznie puste** pola — trasa wpisana ręcznie zostaje
- [x] **Trasa pionowo zamiast poziomo** — „Kielno, Oliwska 12" nie mieści się w połowie szerokości telefonu, oba pola urywały tekst. Teraz jedno pod drugim, na pełną szerokość, ze strzałką w dół między nimi
- [x] **Dysponent wybierany z załogi zastępu** — lista rozwijana z osób z powiązanego wyjazdu alarmowego, **dowódca pierwszy i podpowiadany domyślnie**, bo to on w praktyce dysponuje pojazdem. Pozycja „Inna osoba…" odsłania zwykłe pole, bo dysponować może ktoś spoza zastępu (dyżurny, naczelnik). Przy przejazdach gospodarczych, gdzie nie ma z czego wybierać, pole zostaje zwykłym wpisem

## Zrobione (fix/027-poprawki-po-testach)
Poprawki po testach Wojtka na telefonie.
- [x] **Kierowca i dowódca kopiowali się do drugiego pojazdu** — najgroźniejszy z listy. Dane były poprawne, ale pole pokazywało tekst z poprzedniego zastępu: przełączenie pojazdu nie zmienia struktury drzewa widgetów, więc Flutter zachowywał stan pola razem z wpisanym nazwiskiem. Gorzej, niż zgłoszono: po utracie fokusu `_tryAutoResolve` dopasowywał ten tekst po nazwisku i **realnie przypisywał osobę do drugiego pojazdu** — kto nie skasował pola ręcznie, mógł mieć kogoś w dwóch zastępach. Naprawione kluczami `ValueKey` z identyfikatorem pojazdu i miejsca
- [x] **Adres jednostki** (`locality` + `unitStreet`) — pomysł użytkownika, lepszy niż planowane pole „remiza": to prawdziwa dana, przydatna w kilku miejscach, a nie doklejka pod jedną funkcję. Pytany przy zakładaniu jednostki, edytowalny w ustawieniach (tylko administrator), wysyłany na Dysk, żeby kolega dołączający kodem dostał podpowiedź bez wpisywania jej u siebie. Podpowiadany jako „Skąd" w ewidencji, edytowalny w każdym przejeździe. Pusty adres nie podpowiada nic, zamiast zmyślać
- [x] **Miejscowość w stopce przekazania mienia** wypełniała się przy pobraniu adresu z GPS, ale nie przy powiązaniu z wyjazdem — ten sam druk, dwie ścieżki, dwa różne wyniki. Nie nadpisuje tego, co ktoś już wpisał. Domyślnej miejscowości jednostki świadomie **nie** dodano: druk wypełnia się na miejscu zdarzenia, więc adres remizy bywałby po prostu nieprawdziwy (decyzja z feature/015 zostaje w mocy)
- [x] **Godzina powrotu dopisana w wyjeździe nie trafiała do ewidencji** — przejazd powstawał raz i nigdy się nie aktualizował. Teraz zapis raportu odświeża kolumny, których źródłem jest raport (data, godziny, cel, kierowca). Licznik, dysponent, minuty urządzeń, uwagi i „skąd" zostają nietknięte — to dane wpisywane w ewidencji, o których raport nic nie wie i których nadpisanie kasowałoby pracę kierowcy
- [x] **Ewidencja nie obejmowała wyjazdów sprzed jej wprowadzenia** — przejazd powstaje przy zapisie raportu, więc starsze wyjazdy nie miały swojego wiersza. Jednorazowe uzupełnienie przy starcie aplikacji i po każdym pobraniu danych z Dysku. Zamiast pojedynczej flagi „zrobione" trzymana jest lista przerobionych raportów: flaga nie objęłaby raportów ściągniętych później z Dysku, a przechodzenie po wszystkich przy każdym starcie wskrzeszałoby przejazdy skasowane ręcznie
- [x] Wpisy historyczne dostają znacznik czasu **z raportu, nie z chwili uzupełnienia** — inaczej każde urządzenie wygenerowałoby rekordy o identycznej treści, ale różnych znacznikach, i przy każdej synchronizacji jedno nadpisywałoby wpis drugiego jako „nowszy"
- [x] **„Otwórz" w powiadomieniu o dopisaniu do ewidencji nie działało** — pasek przeżywa nawigację, ale jego przycisk trzymał się `context` zniszczonego już kreatora. Router pobierany teraz przed opuszczeniem ekranu
- [x] **Opis licznika przy pierwszym przejeździe** — „Wpisany ręcznie" brzmiało jak zapowiedź, że tak już będzie zawsze, i wywołało dokładnie takie pytanie. Teraz mówi wprost, że przy kolejnych przejazdach stan podstawi się sam
- [x] Wersja podbita na `1.1.0+2` — `versionCode` stał na 1 od początku, więc nie dało się odróżnić wydań ani zablokować przypadkowego cofnięcia
- [x] 8 nowych testów (łącznie 112): aktualizacja przejazdu z raportu, nienaruszalność danych z ewidencji, deterministyczne znaczniki przy uzupełnianiu historii, składanie adresu jednostki
- [x] Przejechane na emulatorze w wersji release: aktualizacja przez `adb install -r` zachowuje dane (jednostka, pojazdy, przejazdy, łańcuch licznika); adres jednostki podpowiada się jako „Skąd" i jako miejscowość w nowym wyjeździe; **drugi pojazd ma puste pola kierowcy i dowódcy**; „Otwórz" w powiadomieniu przenosi do ewidencji; wyjazd alarmowy dopisuje się z trasą „Kielno, Oliwska 12 – Kielno"; nowe komunikaty rozróżniają „Brak godziny przyjazdu" od „Brak godziny przyjazdu i licznika"

## Zbadane — „memory error" (feature/032)
Pod jedną nazwą kryły się **dwa niezależne zjawiska**. Zmierzone, nie zgadnięte.

**1. `OutOfMemoryError` w aplikacji — dotyczył wersji z reklamami.**
Sterta Javy procesu wyczerpała limit 192 MB (`growth limit 201326592`).
Ślad stosu wskazywał wątek `com.google.android.gms.internal.ads`, przez co
obwiniłem AdMob — **i to był błąd w rozumowaniu**: ślad OOM pokazuje tego, kto
poprosił o ostatni bajt, a nie tego, kto zajął pamięć. Baner był renderowany
w WebView na siedmiu ekranach, więc jako konsument jest wiarygodny, ale sam
ślad tego nie dowodził.

Pomiar aplikacji **po usunięciu reklam** (12 cykli nawigacji + wymuszony trim):
- sterta Javy: 1,3 MB → 4,4 MB → 4,0 MB po odśmiecaniu (limit 192 MB),
- `Views: 8 → 8`, `Activities: 1 → 1`, `AppContexts: 6 → 6` — **płasko**,
- `WebViews: 0` (z reklamami był jeden na ekran).

Niezmienne liczniki widoków i aktywności to sygnatura braku wycieku.
**Aplikacja nie przecieka.**

**2. Znikanie emulatora — to nie była awaria aplikacji ani emulatora.**
- baza crashpad (`%TEMP%\AndroidEmulator\emu-crash-*.db\reports`) **pusta** —
  gdyby emulator się wywalał, byłyby zrzuty,
- host miał 16,6 GB wolnej pamięci z 32 GB — nie było ciśnienia na RAM,
- `emulator.exe` okazał się procesem **osieroconym**: jego rodzic (powłoka,
  w której go uruchamiałem w tle) już nie istniał.

Czyli emulator był **kończony razem z powłoką**, z której go startowałem —
czasem przeżywał jako sierota, czasem szedł z nią na dno. Stąd wrażenie
losowych awarii i brak jakichkolwiek logów.

**Wniosek praktyczny:** emulator trzeba uruchamiać odczepiony od procesu
narzędzia, a nie jako zadanie w tle. Do odczytu ekranów i tak lepszy jest
`uiautomator dump` (tekst) niż zrzuty — szybszy, tańszy i przeżywa restart.

## Zrobione (feature/026-ewidencja-przejazdow)
- [x] **Ewidencja przejazdów pojazdu** — odpowiednik miesięcznej karty drogowej. Karta nie jest osobnym bytem do zakładania, tylko widokiem: para *pojazd + miesiąc* nad zbiorem przejazdów. Nie trzeba niczego otwierać na początku miesiąca ani zamykać na końcu
- [x] Model `VehicleTrip` (Hive `typeId: 7`) pokrywający wszystkie 11 kolumn druku plus to, czego druk nie ma: powiązanie z raportem, autor wpisu, status synchronizacji
- [x] **Łańcuch licznika** — aplikacja pyta o **jedną liczbę na przejazd**: stan po powrocie. Stan przed wyjazdem podstawia ze stanu po poprzednim przejeździe tego pojazdu. Wynika z uwagi użytkownika: kartę oddaje się często w środku akcji, więc licznik notuje się dopiero po powrocie do jednostki, i ten stan staje się stanem przed następnym wyjazdem
- [x] Łańcuch liczony **po godzinie odjazdu, nie po kolejności wpisywania** — ktoś uzupełniający zaległości wpisze wczorajszy przejazd po dzisiejszym, a licznik i tak rósł chronologicznie. Wpis dodany wstecz przelicza stany wszystkich późniejszych
- [x] **Kłódka przy stanie początkowym** — pominięty przejazd rozjeżdżałby licznik do końca miesiąca bez możliwości korekty. Ręcznie wpisana wartość nie jest nadpisywana i staje się punktem odniesienia dla dalszej części łańcucha
- [x] Ostrzeżenie, gdy stan po powrocie jest mniejszy niż przed wyjazdem — **bez blokady**, bo papierowa karta jest dokumentem źródłowym i czasem trzeba odwzorować to, co ktoś już wpisał długopisem
- [x] **Wyjazd alarmowy dopisuje się sam** po zapisaniu raportu — 7 z 11 kolumn wypełnionych z raportu (data, trasa, cel, kierowca, godziny odjazdu i przyjazdu). Jeden raport z dwoma zastępami daje dwa wpisy, bo każdy pojazd ma własną kartę. Identyfikator wyprowadzony z raportu i pojazdu, więc ponowny zapis raportu nie dubluje wiersza
- [x] Ekran listy z wyborem pojazdu i miesiąca, podsumowaniem (liczba przejazdów, suma km, ile bez zapisanego powrotu) i oznaczeniem wpisów niedokończonych
- [x] Uprawnienia wg zasady z feature/022: dodawać może każdy, edytować cudze — autor lub administrator. Użyta istniejąca `canEditDocument`, bez drugiej równoległej reguły
- [x] Synchronizacja przez Dysk w podfolderze `trips/`, nazwy plików z datą i pojazdem, rozstrzyganie „nowszy wygrywa" jak przy raportach
- [x] **22 nowe testy jednostkowe** łańcucha licznika i generowania przejazdów z raportu (łącznie 104). Jeden z nich złapał realny błąd: `rechain` kasował ręcznie wpisany stan początkowy pierwszego przejazdu pojazdu, bo nie miał poprzednika — czyli ginęła jedyna liczba, od której zaczyna się cały łańcuch
- [x] **Dwa błędy znalezione dopiero na emulatorze**, nie do złapania testami jednostkowymi: (1) przy pierwszym przejeździe pojazdu podgląd „Przejechano X km" i ostrzeżenie o sprzecznym liczniku nie działały, bo liczyły stan początkowy z łańcucha (`null`) zamiast z liczby wpisanej ręcznie — flaga „ręcznie" jest wtedy jeszcze `false`; naprawione jednym wspólnym źródłem prawdy dla podglądu i zapisu, (2) wpis z wpisanym licznikiem, ale bez godziny przyjazdu, był opisany „Brak stanu licznika po powrocie" — czyli wysyłał szukać liczby, która już tam była; komunikat nazywa teraz dokładnie to, czego brakuje
- [x] Przepływ przejechany na emulatorze w wersji release: utworzenie jednostki → pojazd → pierwszy przejazd (pyta o obie liczby) → drugi przejazd (podstawia 1042 z poprzedniego, zablokowane kłódką, pyta tylko o stan po powrocie)
- [x] **Wydruk karty drogowej** — świadomie poza zakresem tej gałęzi. Dane zbierają się od teraz, wydruk powstanie na realnych wpisach. Wymaga norm i linii rozliczeniowych **per pojazd**, bo druk jest załącznikiem do zarządzenia wójta i różni się między gminami (porównane Kielno, Osielsko, Świętajno). **Zrobione w feature/032**, przebudowane na pełny druk Kielna w feature/033 — checkbox został niezaznaczony przez przeoczenie i przez trzy gałęzie wyglądał na otwarte zadanie

## Zrobione (fix/025-crash-release-r8)
- [x] **Aplikacja w wersji release zawieszała się na ekranie startowym** — dotyczyło każdego builda release, czyli także APK do rozdania; w debug wszystko działało, więc problem był niewidoczny przy codziennym testowaniu
- [x] Przyczyna ustalona ze śladu stosu z urządzenia, nie z domysłu: `ClassNotFoundException: io/flutter/util/PathUtils` → `path_provider_android` → `Hive.initFlutter()` → `DatabaseService.initialize()` → pierwsza linijka `main()`. Wyjątek leciał przed `runApp()`, dlatego Flutter nigdy nie rysował pierwszej klatki i zostawał systemowy splash Androida z ikoną
- [x] `path_provider_android` sięga po `io.flutter.util.PathUtils` przez JNI, czyli **po nazwie klasy**. R8 takiego odwołania nie widzi, uznaje klasę za nieużywaną, wkleja jej metody w miejsca wywołań i usuwa samą klasę. Potwierdzone w raporcie R8 `build/app/outputs/mapping/release/usage.txt`
- [x] Naprawa: `android/app/proguard-rules.pro` z regułami `-keep` dla `io.flutter.**` i pakietu `jni`, podpięty przez `proguardFiles` w bloku `release`. Reguła obejmuje cały `io.flutter.**`, a nie samą `PathUtils`, żeby ten sam problem nie wrócił przy kolejnej wtyczce sięgającej refleksyjnie
- [x] Zweryfikowane: `PathUtils` zniknęła z `usage.txt` (usunięte) i pojawiła się w `seeds.txt` (zachowane jawnie); build release uruchomiony na emulatorze wstaje do ekranu powitalnego, logcat bez błędów

## Zrobione (feature/024-ratownik-i-podpowiedzi)
- [x] **„Ratownik" w formularzu ratownika** — pozycja zaznaczona na stałe i nieaktywna, na górze listy funkcji. Zgłoszenie Wojtka („nie ma opcji, jak wpisać zwykłego ratownika") zweryfikowane w kodzie: taką osobę **dało się** zapisać (funkcje były opcjonalne) i na liście widniała już jako „Ratownik", ale formularz z trzema pustymi kwadracikami wyglądał na niedokończony. Świadomie **nie** dodano zwykłego, odznaczalnego pola — byłby to czwarty niezależny przełącznik, możliwy do ustawienia sprzecznie i wymagający migracji istniejących wpisów
- [x] Nagłówek sekcji „Funkcje (opcjonalne)" → „Funkcje"
- [x] **Podpowiedzi w zastępach zależne od miejsca** — pod nazwiskiem wyłącznie to, co dotyczy wybieranego miejsca (kierowca / dowódca / KPP) i wyłącznie u osób, które to mają, plus „✓ Badania". Nazwisko wytłuszczone. Znikły „✗ brak uprawnień" przy każdym nazwisku, które zajmowały miejsce i zlewały się z nazwiskiem — dzięki temu na liście mieści się prawie dwa razy więcej osób
- [x] **Ostrzeżenie po wyborze osoby bez wymaganego uprawnienia** — bez blokowania wyboru (ktoś mógł zrobić kurs, którego nie ma jeszcze w aplikacji, a w akcji nie ma czasu na kartoteki). Działa zarówno przy wyborze z listy, jak i przy wpisaniu nazwiska z ręki

## Zrobione (fix/023-adres-z-gps)
- [x] **Naprawiono: podwojony numer domu przy adresie z GPS** („Józefa Sikorskiego 12 12"). Przyczyna potwierdzona w źródłach biblioteki `geocoding`: pole `street` to **gotowa linia adresu, już zawierająca numer** (na Androidzie fragment sformatowanego adresu do pierwszego przecinka), a nie sama nazwa ulicy. Doklejanie do niej `subThoroughfare` dublowało numer. Teraz numer dokładamy wyłącznie do nazwy ulicy (`thoroughfare`), a gotową linię bierzemy bez zmian
- [x] **Adresy wiejskie**: gdy geokoder podaje miejscowość jako ulicę („Kielno 85"), w polu ulicy zostaje sam numer — adres brzmi „Kielno, 85" zamiast „Kielno, Kielno 85"
- [x] 8 testów jednostkowych `buildStreet`, w tym dokładny przypadek ze zgłoszenia i zabezpieczenie, by numer „12" nie był uznany za obecny w „112"

## Zrobione (feature/022-role-administratora)

### Naprawa dołączania do jednostki (fundament)
- [x] **Dołączenie z innego konta Google w ogóle nie działało** — `shareFolderWithUser` istniało, ale nie było nigdzie wywoływane, a `findUnitByInviteCode` przeszukuje wyłącznie pliki widoczne dla konta. Kolega z prawidłowym kodem dostawał „nie znaleziono jednostki". Nie było tego widać w testach, bo drugi telefon logował się tym samym kontem
- [x] Administrator zaprasza podając adres Gmail → aplikacja udostępnia folder → kolega dołącza kodem
- [x] Lista osób z dostępem (z Dysku) + odbieranie dostępu
- [x] **Naprawiono: nazwa jednostki była przy synchronizacji rozbijana po spacjach** („ostatni wyraz to miejscowość") — po zmianie na pełną nazwę dawało to bezsens u każdego, kto dołączy. Teraz nazwa idzie w całości

### Role
- [x] Administratorzy w `config/admins.json` na Dysku jednostki; **założyciel** (`createdBy`) jest stałym administratorem i nie da się mu odebrać uprawnień — inaczej jednostka mogłaby zostać bez nikogo do zarządzania
- [x] Kopia listy administratorów lokalnie (`settingsBox`) — bez niej po restarcie aplikacji lub bez zasięgu nikt nie byłby administratorem
- [x] `isAdminProvider`; praca bez jednostki (offline) = własne dane, więc pełne uprawnienia
- [x] Nadawanie i odbieranie uprawnień administratora w Ustawieniach
- [x] **Zablokowane dla zwykłego użytkownika:** dodawanie/edycja/usuwanie pojazdów i ratowników, zmiana nazwy jednostki, zakładanie ratownika w kreatorze zastępów (pełna spójność — w razie potrzeby raport drukuje się i dopisuje odręcznie)
- [x] **Raporty i przekazania:** każdy edytuje i usuwa własne (`createdBy`), administrator wszystkie. Dokumenty bez autora (starsze/offline) zostają edytowalne
- [x] Zamiast ukrywania — wyjaśnienie „może zmieniać tylko administrator" z adresem administratora

### Zgłaszanie poprawek
- [x] Zwykły użytkownik ma przy każdym ratowniku przycisk „Zgłoś poprawkę" — wybiera powód (błąd w nazwisku, nieaktualne badania, błędne uprawnienia, nie należy do jednostki, inne), dopisuje komentarz i wysyła gotową wiadomość do administratora

### Uwagi
- Model uprawnień jest **miękki**: każdy członek ma prawo zapisu do folderu na Dysku (musi wysyłać raporty), więc technicznie mógłby podmienić `admins.json`. To zabezpieczenie przed pomyłką, nie przed złośliwością — realną granicą jest to, kogo w ogóle wpuszczamy do jednostki
- Kod zaproszenia: 6 znaków z alfabetu 32-znakowego = **32⁶ ≈ 1,07 mld** kombinacji, losowane generatorem kryptograficznym. Sam kod i tak nie wystarcza — potrzebny jest dostęp do folderu na Dysku

### Do rozważenia
- Zgłoszenia poprawek jako obieg w aplikacji (lista u administratora, zatwierdzanie, historia) zamiast wiadomości — jeśli po testach okaże się, że zgłoszenia giną
- Powiadomienie kolegi po zaproszeniu (obecnie trzeba mu przekazać kod osobno)

## Zrobione (feature/021-wybor-ratownika)
- [x] **Naprawiono: lista podpowiedzi w kreatorze zastępów pokazywała „Imię Nazwisko"** — przeoczenie z feature/020: zmieniona była kolejność w polu tekstowym i po wyborze, ale nie w samej liście
- [x] **Lista podpowiedzi bez uprawnień i badań** (wariant C) — wcześniej były drobnym, szarym drukiem pod nazwiskiem i zlewały się z nim. Odznaki uprawnień/badań pokazują się nadal, ale dopiero **po** wybraniu osoby
- [x] **Wyszukiwanie ratowników wyciągnięte do `FirefighterSearch`** — wspólne dla kreatora zastępów i formularza przekazania. Ranking trzypoziomowy: początek nazwiska → początek imienia → dopasowanie w środku. Szuka po obu członach, wyświetla zawsze „Nazwisko Imię"
- [x] **Wybór przekazującego z wyszukiwarką** (`showFirefighterPicker`) zamiast listy rozwijanej — przy kilkudziesięciu osobach przewijanie było uciążliwe
- [x] W oknie „Dodaj ratownika" nazwisko przed imieniem, spójnie z resztą aplikacji
- [x] **Wielkie litery w polach tekstowych** — 8 miejsc: przekazanie mienia (miejsce zdarzenia, rodzaj podmiotu, adres, opis, uwagi), nazwa jednostki w Ustawieniach i onboardingu, pole wyszukiwania/tworzenia ratownika w zastępach. Celowo pominięte: wyszukiwarki, numer ewidencyjny i numer telefonu

### Do przetestowania z użytkownikami
- [x] ~~Czy na liście podpowiedzi w zastępach brakuje informacji o uprawnieniach i badaniach?~~ — **rozstrzygnięte w feature/024**. Okazało się, że brakuje: wybrano wariant zbliżony do (A), czyli nazwisko pogrubione + wyłącznie to uprawnienie, które dotyczy wybieranego miejsca (kierowca / dowódca / KPP) i wyłącznie u osób, które je mają. Bez „✗ brak uprawnień" przy każdym nazwisku — dzięki temu na liście mieści się prawie dwa razy więcej osób

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
- Podgląd wydruku przed wysłaniem na drukarkę Bluetooth (obecnie druk startuje od razu) — **nadal otwarte**, powtórzone niżej w „Kolejne branche"
- [x] ~~Powiększyć drobny tekst podstawy prawnej~~ — **zrobione w feature/017**: 6 → 7 pkt, tyle co reszta treści formularza

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

### Urządzenia specjalne per pojazd + rozbicie minut pracy
Dziś minuty pracy urządzeń specjalnych to **jedna liczba** (`VehicleTrip.specialEquipmentMinutes`)
— tyle, ile ma kolumna 10 papierowej karty. Propozycja: rozbić na pozycje,
np. `Agregat 30 min`, `Autopompa 60 min`, wybierane z listy urządzeń danego pojazdu.

**Argument za jest mocniejszy, niż się wydaje.** Przy analizie druków wyszło,
że gminy mają **osobne normy dla różnych urządzeń** — zarządzenie Świętajna
rozlicza osobno postój, rozruch i autopompę. Jeśli wydruk karty ma sam liczyć
zużycie według norm, jedna zbiorcza liczba minut do tego nie wystarczy.

**Dlaczego nie teraz.** To zmiana modelu danych (pole w Hive), a ewidencja już
zbiera realne wpisy. Zrobiona osobno wymusi migrację teraz i **drugą migrację**
po ustaleniach z Deringiem i po dobraniu norm do wydruku. Lepiej raz, razem
z normami per pojazd, które i tak są warunkiem wydruku karty.

Do rozstrzygnięcia przed implementacją:
- lista urządzeń **stała** (autopompa, agregat, pilarka, wyciągarka…) czy
  definiowana per pojazd? Stała jest prostsza i pewnie wystarczy, ale nie każdy
  pojazd ma autopompę — pokazywanie jej przy GLM byłoby mylące,
- czy wydruk potrzebuje sumy minut, czy rozbicia na urządzenia — zależy od
  wzoru druku obowiązującego w gminie Kielno,
- czy normy zużycia trzymamy przy urządzeniu, czy przy pojeździe.

Do potwierdzenia u Deringa. Do tego czasu jedna liczba zostaje i działa.

### Funkcje ratownika — możliwe rozszerzenia
Obecnie „Ratownik" jest **wyliczany**: brak kierowcy/dowódcy/KPP = ratownik.
W feature/024 doszła stała, zaznaczona i nieaktywna pozycja „Ratownik" na górze
listy funkcji — formularz nie wygląda już na niedokończony, ale mechanizm
pod spodem został wyliczany.

Rozważane alternatywy, gdyby to przestało wystarczać:
- jawny, odznaczalny checkbox „Ratownik" — **świadomie odrzucony w feature/024**:
  byłby czwartym niezależnym przełącznikiem, możliwym do ustawienia sprzecznie
  z pozostałymi i wymagającym migracji istniejących wpisów,
- pełny słownik funkcji zamiast trzech flag (np. mechanik, operator sprzętu,
  ratownik wodny) — pozwoliłby też odróżnić uprawnienia od funkcji na wyjeździe.

### Godziny dla PSP vs OSP
PSP nie potrzebuje godzin, OSP tak. Na razie rozwiązane tak, że godzina powrotu
startuje pusta i wpisuje się ją samodzielnie. Gdyby okazało się to niewygodne,
do rozważenia osobne pola „czas dla PSP" i „czas wewnętrzny OSP".

### Podgląd wydruku przed drukiem Bluetooth
Obecnie druk startuje od razu po kliknięciu.


### Przed publikacją w Play Store
- [ ] **Własny klucz podpisu** — dziś APK jest podpisany kluczem debug. Po zmianie klucza Android potraktuje aplikację jako inną i **każdy będzie musiał odinstalować przed aktualizacją, tracąc dane lokalne**. Im więcej osób dostanie wersję na kluczu debug, tym boleśniejsze. Wymaga dopisania nowego odcisku SHA-1 do klienta OAuth w Google Cloud, inaczej przestanie działać logowanie Google (błąd 10)
- [ ] Grafiki do sklepu: ikona 512×512, feature graphic 1024×500, min. 2 screenshoty
- [ ] Polityka prywatności — po usunięciu reklam aplikacja nie zbiera praktycznie nic (dane leżą na Dysku Google użytkownika), więc mieści się w akapicie
- [ ] (opcjonalnie) Ikona monochromatyczna `<monochrome>` w adaptive icon — motywy Android 13+

**Publikacja w Play daje też odpowiedź na pytanie o statystyki**: konsola pokazuje
liczbę instalacji, odinstalowań, kraje i wersje Androida — bez dokładania
czegokolwiek do aplikacji. Rozdawanie APK z Dysku nie daje żadnych liczb.
Czego Play **nie** poda: nazw jednostek — te leżą na Dyskach użytkowników,
a zbieranie ich wymagałoby zgód i polityki przetwarzania.

### Adresy e-mail jednostek PSP — wysyłka raportu
Raport da się dziś wysłać („Udostępnij / Wyślij"), ale adresata trzeba za każdym
razem wpisać z ręki. Propozycja: **lista adresów do wyboru** przy wysyłce, plus
możliwość wpisania własnego.

Do przemyślenia przed implementacją:
- gdzie trzymać adres domyślny — przy jednostce (jedna komenda powiatowa dla całej
  OSP) czy jako lista wielu odbiorców (KP PSP, gmina, zarząd gminny),
- czy lista ma być wspólna dla jednostki (synchronizowana przez Dysk, edytowalna
  przez administratora), czy lokalna na telefonie,
- czy podpowiadać ostatnio użyty adres — przy jednym stałym odbiorcy to wystarczy
  zamiast całej listy,
- czy dołączać PDF automatycznie, czy zostawić obecny mechanizm udostępniania.

Najprostszy wariant, który pewnie załatwia 90% potrzeby: **jedno pole „domyślny
adres e-mail" w danych jednostki**, podstawiane jako adresat, edytowalne przy
każdej wysyłce. Rozbudowa do listy dopiero, gdy okaże się potrzebna.

### Pomysły do rozważenia
- [ ] **e-Remiza integration**: Ręczne wpisywanie z przyciskami kopiowania do schowka. Na razie nierealne — do rozważenia w przyszłości.

## Zrobione (feature/031-backlog-kawa-psp)
- [x] **Przegląd i uporządkowanie backlogu** — sekcje „do zrobienia", które zostały już zrealizowane, przestały być listą zadań, a stały się mylącym śladem. Usunięte lub oznaczone jako nieaktualne:
  - „Wyjazdy gospodarcze / tankowanie" (zgłoszenie Sebastiana) — zrealizowane w feature/026 jako ewidencja przejazdów; pytania do Deringa o zestaw pól rozstrzygnięte w rozmowie
  - „Usunięcie reklam + postaw mi kawę" — zrealizowane w feature/030
  - dwa `TODO przed publikacją` z feature/007 (prawdziwe ID AdMob, produkt `remove_ads`) — bezprzedmiotowe po usunięciu reklam i płatności
  - „Podbić wersję (obecnie 1.0.0+1)" — wersja idzie już własnym torem, dziś 1.2.0+4
  - „Powiększyć drobny tekst podstawy prawnej" — zrobione w feature/017 (6 → 7 pkt)
  - „Czy na liście podpowiedzi brakuje uprawnień?" — rozstrzygnięte w feature/024 na korzyść wariantu (A)
- [x] **Sprostowana obserwacja o `OutOfMemoryError`** — obwiniałem AdMob, bo awaria wystąpiła w jego wątku. Po usunięciu reklam emulator pada dalej, więc przyczyna jest po stronie maszyny, nie aplikacji. Zapisane wprost, żeby nikt nie szukał drugi raz w złym miejscu
- [x] **Przycisk „Postaw mi kawę"** w „O aplikacji" — widoczny od razu, ale bez odnośnika. Do czasu ustawienia adresu kliknięcie mówi wprost, że zbiórki jeszcze nie ma, zamiast prowadzić donikąd. Uruchomienie sprowadza się do wpisania linku w `_coffeeUrl` w [info_screen.dart](lib/screens/info/info_screen.dart)
- [x] **Nowy punkt w backlogu: adresy e-mail jednostek PSP** przy wysyłce raportu — lista do wyboru plus możliwość wpisania własnego adresu, z rozpisanymi pytaniami do rozstrzygnięcia i propozycją najprostszego wariantu na start
- [x] Do „Przed publikacją w Play Store" dopisany **własny klucz podpisu** (dziś APK idzie na kluczu debug) i polityka prywatności, wraz z notatką, że publikacja w Play jest jedyną czystą drogą do statystyk pobrań

## Zrobione (feature/032-kawa-druk-ewidencji)
- [x] **Odnośnik do zbiórki „na kawę"** — `https://buycoffee.to/mionsek`, wyciągnięty do wspólnej stałej `kCoffeeUrl`, żeby nie żył w dwóch miejscach. Widżety HTML z buycoffee są do stron WWW — w aplikacji otwieramy sam adres w przeglądarce
- [x] **Kawa w stopce ekranu głównego** — dyskretny odnośnik tekstowy pod linijką o autorze, a nie kafelek w menu. Kafelki to czynności (dodaj wyjazd, ewidencja, ustawienia); prośba o wsparcie nie należy do tej samej kategorii i nie powinna stać w jednym rzędzie z „Dodaj wyjazd". Stopka „o autorze" to naturalne miejsce na „możesz mu podziękować"
- [x] **Wydruk miesięcznej karty drogowej** ([trip_card_pdf.dart](lib/services/trip_card_pdf.dart)) — A4 poziomo, 12 kolumn odtworzonych z druku gminnego: Lp., data, dysponent, trasa, cel, kierowca, odjazd (godzina i licznik), przyjazd (godzina i licznik), minuty pracy urządzeń specjalnych, podpis. Przyciski „Drukuj" i „Udostępnij" na ekranie ewidencji — drukują to, co widać, czyli wybraną parę pojazd + miesiąc, bez osobnego okna wyboru zakresu
- [x] Tabela dopełniana do 16 wierszy — karta z trzema przejazdami ma wyglądać jak formularz, a nie jak urwana kartka; reszta zostaje do dopisania długopisem, jak w papierowym druku
- [x] **Rozliczenie zużycia paliwa zostaje puste** — normy i liczba linii różnią się między gminami (porównane Kielno, Osielsko, Świętajno), a aplikacja ich nie zna. Wydrukowanie zmyślonych wartości byłoby gorsze niż zostawienie miejsca na długopis. Ta sama zasada, co przy przekazaniu mienia
- [x] Osobny plik zamiast kolejnych 250 linii w `PdfService` (już 1177 linii) — karta drogowa nie dzieli z formularzami KP PSP niczego poza biblioteką `pdf`
- [x] **„O aplikacji" zaktualizowane** — dopisana karta drogowa jako trzeci dokument, krok „Ewidencja przejazdów" w instrukcji (z wyjaśnieniem łańcucha licznika i automatycznego dopisywania wyjazdów alarmowych) oraz zdanie, że aplikacja jest darmowa, bez reklam i nie zbiera danych
- [x] Zweryfikowane na emulatorze: okno druku otwiera się bez błędów, karta renderuje się w całości, a łańcuch licznika widać na wydruku (przejazd 1 kończy na 1042, przejazd 2 od 1042 startuje)

- [x] **Naprawiona orientacja wszystkich wydruków poziomych** — `Printing.layoutPdf` ma parametr `format`, którego **nigdy nie podawaliśmy**. Domyślny `PdfPageFormat.standard` to US Letter **pionowo**, więc okno druku startowało w pionie i wciskało poziomą stronę na pionową kartkę: wydruk wychodził zmniejszony i nieczytelny zamiast wypełnić arkusz. Dotyczyło to nie tylko nowej karty drogowej, ale **także raportu wyjazdu i przekazania mienia** — obu dokumentów w układzie 2× A5 na A4 poziomo, używanych od feature/013. `_layoutPdf` wymaga teraz formatu jako parametru obowiązkowego, żeby nie dało się tego znów pominąć
- [x] Pierwotnie opisałem to jako „okno druku domyślnie proponuje pion, trzeba przestawić" i zostawiłem jako rzecz do sprawdzenia. To było zrzucanie własnego błędu na użytkownika — zgłoszenie od Dawida („musi być poziomo, bo inaczej jest nieczytelne") słusznie to zakwestionowało
- [x] **Karta „postaw mi kawę" zamiast samego odnośnika** — w stopce ekranu głównego, pod przyciskiem wyjścia: ikona kawy, tekst „Aplikacja jest w pełni darmowa i bez reklam. Podoba Ci się? Postaw mi kawę!" i znak otwarcia w przeglądarce. Klikalna jest cała karta, nie osobny przycisk w środku — większy cel i mniej elementów. Brąz wzięty z istniejącej palety (przekazania mienia), żeby nie wprowadzać nowego koloru dla jednej karty. Tło odróżnia ją od kafelków menu, więc nie czyta się jako kolejna pozycja do kliknięcia. Podpis autora zostaje ostatni, pod kartą

## Zrobione (feature/033-pelna-karta-drogowa)
Wydruk karty z feature/032 odtwarzał tylko środkową część druku. Dawid zapytał, czy nie przysłał więcej zdjęć — przysłał, a ja ich nie otworzyłem.

- [x] **Odczytany druk obowiązujący w OSP Kielno** ze zdjęć (`rozliczenie-materialow-pednych-osp-kielno.jpeg`, `wyjazdy-tabela-osp-kielno.jpeg`). Wcześniej odkodowałem PDF `miesieczna-karta-drogowa.pdf`, ale to załącznik gminy **Osielsko** — inny druk, inna gmina. Struktura obu zapisana w `scratchpad/druk-kielno.txt` i `druk-osielsko.txt`
- [x] **Tabela przejazdów ma 13 kolumn, nie 11** — brakowało „Dodatki*" i „Praca silnika na postoju min.". Obie mają odpowiedniki w rozliczeniu (poz. 6 i 7), więc bez nich rozliczenia nie da się wypełnić. Dodane jako pola `VehicleTrip.extras` i `idleMinutes`
- [x] **Dane pojazdu do nagłówka karty** — `Vehicle` dostał marka, typ, rodzaj, nr rej., numer operacyjny, rodzaj paliwa oraz cztery normy zużycia: na 100 km, autopompy na godzinę, pracy na postoju na minutę i rozruchu na miesiąc. Wszystkie opcjonalne, wszystkie synchronizowane przez Dysk. W formularzu pojazdu zwijana sekcja „Dane do karty drogowej" — domyślnie zamknięta, bo przy zwykłym dodawaniu pojazdu nikt jej nie potrzebuje
- [x] **Wydruk przebudowany na pełny druk Kielna**: nagłówek z danymi pojazdu i normami, ramka „Zapisy dotyczące obsług technicznych", tabela przejazdów, a na drugiej stronie „Pobrano (w litrach)" i 12-pozycyjne rozliczenie materiałów pędnych ze stopką Obliczył/Sprawdził
- [x] **Rozliczenie liczone z norm pojazdu**: przebyte kilometry × norma na 100 km, godziny pracy urządzeń × norma autopompy, minuty postoju × norma na minutę, rozruch raz na miesiąc, plus suma. Zweryfikowane na emulatorze: 42 km × 9,5/100 = 3,99 l, + 1 l rozruchu = 4,99 l razem
- [x] **Pozycje, których aplikacja nie zna, zostają puste** — ilości pobranego paliwa (z kwitów) i dodatek zimowy. Nie znam reguły naliczania dodatku i **nie zgadywałem jej**; puste pole jest uczciwsze niż zmyślona liczba w dokumencie idącym do gminy
- [x] Rozliczenie zawsze od nowej strony — na papierowym druku jest po drugiej stronie kartki, a wcześniej sam nagłówek zostawał na dole poprzedniej

### Poprzednia wersja wydruku — co było źle
- [x] ~~Tabela „Rozliczenie zużycia paliwa" (Wyszczególnienie / Norma / Ilość / Zużycie)~~ — **wymyślona przeze mnie**, nie odpowiadała niczemu w druku. Napisałem wtedy, że „zostawiam miejsce na długopis, bo nie znam norm", ale w praktyce wydrukowałem zmyśloną tabelę wyglądającą na urzędową — gorzej, niż gdybym nie drukował nic
- [x] ~~Podpisy „Sporządził / Sprawdził / Zatwierdził"~~ — w druku są dwa: „Obliczył" i „Sprawdził"

### Do rozstrzygnięcia
- [ ] **Reguła dodatku zimowego** — których miesięcy dotyczy i jaki jest narzut. Po ustaleniu doliczy się automatycznie (poz. 6 rozliczenia)
- [ ] **Ilości pobranego paliwa** — dziś tabela „Pobrano" drukuje się pusta. Do rozważenia osobny ekran wpisywania kwitów (data, stan licznika, ON, ET), który wypełniłby też pozycje 1–3 i 10–12 rozliczenia
- [ ] **Stan autopompy na początek i koniec miesiąca** — pole jest na wydruku, ale aplikacja go nie zbiera

## Zrobione (refactor/034-przeglad-kodu)
Przegląd kodu na prośbę Dawida: wydajność, jakość, magic numbers, komentarze, testy.

### Naprawione błędy
- [x] **Wyciek nasłuchów w polu kierowcy** ([trip_form_screen.dart](lib/screens/trips/trip_form_screen.dart)) — `fieldViewBuilder` w `Autocomplete` uruchamia się przy **każdym** przebudowaniu formularza, a ja dodawałem tam `controller.addListener` bez usuwania poprzedniego. Po kilkunastu `setState` (a formularz przebudowuje się przy każdej zmianie licznika i dysponenta) jedno naciśnięcie klawisza odpalało kilkanaście reakcji, każda z zapisem do kontrolera. Zamienione na `onChanged`, które działa raz na zmianę niezależnie od liczby przebudowań
- [x] **Niezwalniane kontrolery okna „Dodaj ratownika"** ([step_crew.dart](lib/screens/reports/steps/step_crew.dart)) — dwa `TextEditingController` tworzone przy każdym otwarciu okna i nigdy nie zwalniane, bo `showDialog` nie ma własnego `dispose`. Dodane `whenComplete`
- [x] **Trzy różne reguły sanityzacji nazw plików** w czterech miejscach: jedna usuwała tylko znaki zabronione w Windows (zostawiając spacje i polskie znaki), druga wszystko poza znakami słowa, trzecia jeszcze inaczej. Ta sama miejscowość dawała **różne nazwy plików** w PDF-ie i na Dysku. Ujednolicone w `FileNames.sanitize`
- [x] Usunięta pozostałość debugowa `debugPrint('SettingsScreen.build() called')` — logowała przy każdym przebudowaniu ekranu

### Wydajność
- [x] **Trzy migracje danych blokowały pierwszą klatkę** — `backfillTripsFromReports`, `reconcileTripsWithReports` i `fillMissingRouteFrom` szły w `main()` **przed** `runApp`, przy każdym uruchomieniu. To pełne przebiegi po raportach i przejazdach z zapisem do Hive; opóźnienie rosło wraz z ilością danych, czyli najmocniej dotykało tych, którzy używają aplikacji najdłużej. Przeniesione do `addPostFrameCallback` — ekran główny rysuje się od razu, a providery odświeżają się, gdy migracja coś zmieni
- [x] Zmierzone po zmianach: sterta Javy 1,3 MB, `Views: 8`, `Activities: 1`, `AppContexts: 6` — płasko, bez wycieków

### Jakość i duplikaty
- [x] **`PolishText`** ([polish_text.dart](lib/core/utils/polish_text.dart)) — odmiana liczebników i nazwy miesięcy. Odmiana była powielona w trzech ekranach, nazwy miesięcy w dwóch miejscach. Przy okazji obie kopie odmiany „miejsc" używały uproszczonej reguły `2–4`, **błędnej dla 12–14** — nieszkodliwej tylko dlatego, że pojazd ma maksymalnie 6 miejsc. Wspólna wersja obsługuje nastki poprawnie
- [x] **`FileNames`** ([file_names.dart](lib/core/utils/file_names.dart)) — sanityzacja, data i para rok-miesiąc do nazw plików

### Testy — największa luka
Było 104 testy, wszystkie **czysto jednostkowe na modelach i logice bez wejścia-wyjścia**. Warstwa bazy i synchronizacji nie miała ani jednego.
- [x] **`database_service_test.dart`** (14 testów) — Hive na katalogu tymczasowym. Sprawdza to, co dotąd weryfikowałem wyłącznie ręcznie na emulatorze: czy `addTrip` faktycznie przelicza łańcuch licznika, czy wpis dodany wstecz przesuwa późniejsze, czy usunięcie środkowego przejazdu przelicza resztę, czy uzupełnianie historii nie dubluje i **nie wskrzesza przejazdu skasowanego ręcznie**, czy uzgadnianie z raportem nie nadpisuje licznika wpisanego w ewidencji
- [x] **`sync_json_test.dart`** (6 testów) — serializacja na Dysk, przez prawdziwy `jsonEncode`/`jsonDecode`. To najbardziej krucha część synchronizacji: przy każdym dodaniu pola do modelu trzeba pamiętać o dopisaniu go **i** do zapisu, **i** do odczytu, a nic tego nie wymusza. Pominięcie objawia się dopiero u kolegi, któremu dane wrócą niekompletne. Testy obejmują też odczyt plików zapisanych przez **starsze wersje** aplikacji (bez nowych pól) i strażnika listy kluczy JSON
- [x] Mapowania `vehicleToJson` / `tripToJson` i odwrotne zrobione statycznymi i publicznymi (`@visibleForTesting`), żeby dało się je testować bez budowania całego `SyncService`
- [x] Łącznie **124 testy**

### Znalezione, świadomie odłożone
Wszystkie cztery **zrobione w refactor/036** — opis niżej.
- [x] **Paleta kolorów istnieje, ale jest omijana** — `OspTheme.primaryRed` jest zdefiniowany, a kod używa surowego `0xFFB71C1C` **31 razy**; podobnie zieleń (20×), pomarańcz (9×), błękit (7×), brąz (4×). Zmiana mechaniczna, ale dotyka ~20 plików — osobna gałąź, żeby nie mieszać z naprawami
- [x] **Brak testów widoków i integracyjnych** — zero `testWidgets`, brak katalogu `integration_test`. Najbardziej przydałyby się dla kreatora wyjazdu (trzy kroki, walidacje, ostrzeżenia) i formularza przejazdu (łańcuch licznika w interfejsie)
- [x] **`pdf_service.dart` ma 1192 linie** — trzy niezależne dokumenty w jednym pliku. Karta drogowa dostała już własny plik; raport, statystyki i przekazanie mienia mogłyby pójść tą samą drogą
- [x] **Mapowania JSON raportu i przekazania mienia** zostały prywatne i nietestowane — ta sama krucha konstrukcja co przy pojeździe i przejeździe

### Rozstrzygnięte — nie do zrobienia
Nie są to zadania, tylko decyzje. Trzymane osobno, bo jako pozycje `- [ ]` na
liście otwartych wyglądały na zaległość i przy każdym przeglądzie ktoś proponował
je „dokończyć".
- **Stałe układu wydruków** (rozmiary czcionek, szerokości kolumn) **zostają przy swoich wydrukach** — to parametry layoutu, nie konfiguracja aplikacji, i wyniesienie ich do wspólnego pliku pogorszyłoby czytelność: liczba przestałaby sąsiadować z tabelą, na którą wpływa. Potwierdzone ponownie przy refactor/036

## Zrobione (fix/035-nazwiska-urzadzenia-paski)
Trzy zgłoszenia: dwa od Wojtka, jedno od Dawida.

- [x] **Kolejność „Nazwisko Imię" nie obowiązywała na wydrukach i w podglądach** — wybór ratownika działał po nazwisku, ale `Firefighter.fullName` zwraca „Imię Nazwisko" i to jego używały: tabela uczestników w PDF raportu, statystyki, szczegóły wyjazdu, podsumowanie kreatora, kierowca i dysponent w ewidencji. Ujednolicone: `lastNameFirst` to **jedyna** kolejność do pokazania i wydruku, `fullNameWithRank` też z niej korzysta, a `fullName` zostaje wyłącznie do dopasowywania wpisanego tekstu (bo ktoś może wpisać w tej kolejności). Wyszukiwanie akceptuje obie
- [x] **Praca urządzeń specjalnych bez wyboru urządzenia** — było jedno pole na minuty, bez wskazania **czego** dotyczą. Zgłoszenie: „nie ma możliwości wyboru urządzenia, co powoduje że to trzeba pominąć i najlepiej wpisać w komentarzu np. autopompa 2h, agregat 1h". Rubryka była więc w praktyce nie do użycia. Nowy model `TripEquipmentUse` (Hive typeId 8) i lista „urządzenie + minuty" w formularzu, ze stałą listą (autopompa, agregat, piła, wyciągarka, wentylator, inne) i sumą na bieżąco. Na wydruk (kolumna 10) idzie suma, bo druk ma tam jedną liczbę
- [x] Przejazdy zapisane przed tą zmianą mają tylko liczbę minut — pokazują się jako jedna pozycja bez nazwy, do uzupełnienia, zamiast zniknąć. Suma zapisuje się **także** do starego pola, żeby kolega na starszej wersji aplikacji nadal widział poprawną liczbę
- [x] **Przycisk zasłonięty przez pasek nawigacji telefonu** — formularz przejazdu używał `viewInsetsOf` (klawiatura), ale nie `viewPaddingOf` (pasek). Przy schowanej klawiaturze zapas wynosił zero i „Zapisz zmiany" chowało się za przyciskami telefonu. Naprawione **jednolicie**: wspólne `context.bottomInset()` / `context.scrollPadding()` ([bottom_inset.dart](lib/core/utils/bottom_inset.dart)) bierze większą z dwóch wartości i zastąpiło wszystkie 15 miejsc liczących to na własną rękę
- [x] Zweryfikowane na emulatorze: dysponent „Nowak Adam (dowódca)", lista urządzeń z sumą, przycisk zapisu w całości widoczny

### Uwaga do zgłoszenia o dysponencie
Wojtek pytał, czy dysponent nie mógłby zaciągać się z powiązanego wyjazdu tak jak kierowca. **To już działa** od fix/029 — lista rozwijana bierze załogę tego zastępu, a dowódca jest podpowiadany domyślnie. Na zrzucie widać wypełnione oba pola. Prawdopodobnie testował wersję sprzed tej zmiany.

### Nadal otwarte
- [ ] **Lista urządzeń per pojazd** — dziś jest wspólna dla wszystkich, więc przy GLM pokazuje autopompę, której ten wóz nie ma. Wymaga ustaleń z Deringiem (czy definiować urządzenia przy pojeździe, czy zostawić stałą listę)
- [ ] Rozliczenie paliwa liczy wszystkie urządzenia jedną normą autopompy — przy realnym rozbiciu na autopompę i agregat trzeba by norm per urządzenie

## Zrobione (refactor/036-paleta-testy-pdf-wersje)
Cztery pozycje z „Znalezione, świadomie odłożone" (refactor/034) plus podbicie
wersji Androida, które wyszło dopiero przy stawianiu środowiska od zera.

### Wersje Androida — pilniejsze, niż wyglądało
- [x] **Projekt stał dokładnie na progu błędu Fluttera** — narzędzia trzymają dla AGP, Kotlina i Gradle dwa progi, `warn` i `error`. Wszystkie trzy nasze wersje były **równe wartościom `error`**: AGP `8.11.1`, KGP `2.2.20`, Gradle `8.14`. To nie było ostrzeżenie na przyszłość — najbliższe wydanie Fluttera podnoszące progi **wywaliłoby build twardo**, a nie wypisało uwagę. Przechodziło o zero
- [x] Podbite do progów `warn`: **AGP 9.0.1, Kotlin 2.3.20, Gradle 9.1.0**. Wariant minimalny, nie równanie do szablonu Fluttera (9.1 / 2.4 / 9.3.1) — dwie wtyczki z pub.dev (`package_info_plus`, `print_bluetooth_thermal`) używają wycofywanego `kotlinOptions`, a nad ich kodem nie mamy kontroli
- [x] **`kotlinOptions` zastąpione blokiem `kotlin { compilerOptions }`** ([android/app/build.gradle.kts](android/app/build.gradle.kts)) — wycofane w Kotlinie 2.3, zgodnie z aktualnym szablonem Fluttera
- [x] `android.newDsl=false` i `android.builtInKotlin=false` **zostają** — trzymają stare DSL i wyłączają z równania największą zmianę AGP 9. Nowe DSL to osobna gałąź
- [x] Uwaga na przyszłość: dystrybucje Gradle 9 mają **trzyczłonowe** numery. `gradle-9.1-all.zip` nie istnieje (wersja nazywa się `9.1.0`), a wrapper zgłasza to jako „błąd pobierania artefaktów", nie jako złą nazwę pliku

### Paleta kolorów — jedno źródło prawdy
- [x] **`OspTheme` rozszerzony o pełną paletę** ([osp_theme.dart](lib/core/theme/osp_theme.dart)), a wszystkie **86 surowych literałów** `0xFF……` z 21 plików zastąpione nazwami. Sama czerwień wiodąca była wpisana z ręki 31 razy
- [x] Nazwy **od znaczenia, nie od barwy**: `sectionVehicles`, a nie `orange`. Kolory mają w tej aplikacji role — każda sekcja ma swoją, osobno od `danger` / `success` / `info` / `warning` / `neutral` / `attention`
- [x] Cztery pary nazw dzielą wartość (`danger` = `primaryRed`, `success` = `sectionFirefighters`, `info` = `sectionReportsList`, `attention` = `sectionVehicles`) — **celowo**. Czerwień wyjazdu jest od początku czerwienią błędu; osobne nazwy pozwalają je kiedyś rozdzielić przez zmianę jednej linijki zamiast przeglądania całego kodu
- [x] **Strażnik w teście** ([theme_palette_test.dart](test/theme_palette_test.dart)) — przechodzi po plikach w `lib/` i przewraca się na surowym kolorze poza `osp_theme.dart`. Bez tego następna gałąź dopisałaby kolejny literał dokładnie tak, jak dopisały poprzednie: paleta istniała od pierwszej gałęzi i to jej nie powstrzymało
- [x] Zero zmian wizualnych — podmiana wartości na nazwę, piksel w piksel

### Podział pdf_service.dart (1197 linii)
- [x] **Cztery pliki zamiast jednego**: [pdf_output.dart](lib/services/pdf_output.dart) (wspólny druk, udostępnianie i zawijanie tekstu), [report_pdf.dart](lib/services/report_pdf.dart), [stats_pdf.dart](lib/services/stats_pdf.dart), [handover_pdf.dart](lib/services/handover_pdf.dart). Każdy dokument wołany jest przez **inny ekran** i żaden ekran nie sięga po dwa naraz, więc fasada nie miałaby czego skrywać — `PdfService` zniknął
- [x] **Karta drogowa podpięta pod wspólne wyjście** — miała własną kopię obsługi druku razem z powielonym ostrzeżeniem w komentarzu. Dokładnie ta duplikacja, przed którą ma chronić wydzielenie
- [x] Ostrzeżenie o obowiązkowym `format` (feature/032: brak parametru wysyłał **wszystkie trzy** poziome wydruki na pionową kartkę) przeniesione do `pdf_output.dart` i nadal wymuszone sygnaturą
- [x] Usunięty alias `_sanitizeFilename`, którego własny komentarz tłumaczył się z istnienia — wywołania idą wprost do `FileNames.sanitize`
- [x] Publiczne nazwy bez zbędnych sufiksów: `StatsPdf.generateAndPrint` zamiast `PdfService.generateAndPrintStats` — klasa niesie już typ dokumentu

### Mapowania JSON raportu i przekazania mienia
- [x] **`reportToJson`/`reportFromJson`, `handoverToJson`/`handoverFromJson`, `crewToJson`/`crewFromJson`** zrobione statycznymi i `@visibleForTesting`, jak wcześniej pojazd i przejazd. Wszystkie są czystymi funkcjami, więc zmiana nie ruszyła zachowania
- [x] **13 nowych testów serializacji**: komplet danych przez prawdziwy `jsonEncode`/`jsonDecode`, puste pola opcjonalne, **pliki zapisane starszą wersją aplikacji** (realny przypadek — na Dysku jednostki leżą pliki sprzed każdej zmiany modelu) i strażnicy list kluczy
- [x] Osobny test na to, że zapis na Dysk oznacza raport jako `synced` niezależnie od stanu lokalnego — dotąd nieopisane założenie
- [ ] **Mapowania ratownika i słownika zagrożeń** (`_firefighterToJson`, `_threatToJson`) zostają prywatne i nietestowane — poza zakresem tej pozycji, ta sama krucha konstrukcja

### Testy widoków i integracyjne — największa luka zamknięta
Było **124 testy, wszystkie bez dotykania interfejsu**. Jest **158** plus test integracyjny.
- [x] **Wspólny fundament** ([test/helpers/test_app.dart](test/helpers/test_app.dart)) — Hive na katalogu tymczasowym i `ProviderScope` z podmienionym `SyncService`. Ekrany pracują na **prawdziwym** `DatabaseService`, więc testujemy to, co pojedzie na telefon; podmieniona jest tylko synchronizacja, bo kreator pobiera raporty z Dysku przy starcie
- [x] **Kreator wyjazdu, 8 testów** ([report_wizard_test.dart](test/widgets/report_wizard_test.dart)) — blokada „Dalej" przy braku pojazdu i zagrożenia, oba ostrzeżenia o niepełnym składzie (to z kroku zastępów i to z kreatora), „Popraw" zatrzymujące w miejscu, podpowiedź miejscowości z danych jednostki i kolejność „Nazwisko Imię" w podsumowaniu (regresja z fix/035)
- [x] **Formularz przejazdu, 11 testów** ([trip_form_test.dart](test/widgets/trip_form_test.dart)) — łańcuch licznika w interfejsie: podstawienie z poprzedniego przejazdu, kłódka, powrót do wartości z łańcucha, podgląd kilometrów (także przy pierwszym przejeździe pojazdu — to był realny błąd z feature/026), ostrzeżenie o cofniętym liczniku, lista urządzeń z sumą minut
- [x] **Test integracyjny** ([integration_test/app_test.dart](integration_test/app_test.dart)) — pełne przejście na urządzeniu: onboarding offline → jednostka → pojazd → trzej ratownicy → wyjazd → sprawdzenie, że przejazd **dopisał się sam** do ewidencji. Ta ścieżka była dotąd przechodzona ręcznie po każdej zmianie. Wymaga czystych danych (`adb shell pm clear pl.osp.osp_app`) i mówi to wprost, zamiast wywalić się później na „nie znaleziono przycisku"

### Dwie pułapki testów widoków, warte zapamiętania
- [x] **Zapis do Hive w ciele `testWidgets` zawiesza test na głucho** — ciało biegnie w sztucznej pętli zdarzeń, a zapis kolejkuje tam timery, których `pumpAndSettle` nigdy nie wyczerpie. Bez komunikatu, bez stosu: test po prostu wisi do timeoutu. Dane przygotowujemy **wyłącznie w `setUp`**
- [x] **Domyślne okno testowe to 800×600** — dla formularza przejazdu za mało: `ensureVisible` przewijało cel pod pasek tytułu i kliknięcia trafiały w `AppBar`. Testy ustawiają wymiary telefonu (1080×2400), na którym aplikacja realnie chodzi

### Nowe ostrzeżenie, które ujawnił dopiero AGP 9 — Built-in Kotlin
Po podbiciu wersji zniknęły ostrzeżenia o AGP i Kotlinie, ale wyszło następne
w kolejce. Flutter przechodzi na **Built-in Kotlin**: wtyczka Kotlina ma być
stosowana przez AGP, a nie przez projekt. Nas dotyczy podwójnie.
- [ ] **Aplikacja sama stosuje KGP** (`id("kotlin-android")` w [android/app/build.gradle.kts](android/app/build.gradle.kts)) — do zdjęcia razem z `android.builtInKotlin=true`
- [ ] **Dwie wtyczki z pub.dev stosują KGP u siebie**: `package_info_plus` i `print_bluetooth_thermal`. **To one blokują migrację** — nad ich kodem nie mamy kontroli, a Flutter zapowiada, że przyszłe wersje odmówią budowania. Do sprawdzenia w ich changelogach, zanim zacznie boleć; `print_bluetooth_thermal` jest najmniej aktywnie rozwijaną zależnością w projekcie i to najbardziej prawdopodobny kandydat do wymiany
- Póki co trzyma nas `android.builtInKotlin=false` — flaga, nie rozwiązanie
