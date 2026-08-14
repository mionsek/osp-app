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

## Do obserwacji
- [ ] **`OutOfMemoryError` w wątku AdMob** (`com.google.android.gms.internal.ads`) po ~7 godzinach ciągłej pracy na emulatorze z reklamami testowymi — proces zabity, sterta 192 MB wyczerpana. Nie pochodzi z naszego kodu i nie da się tego przypisać konkretnemu błędowi na podstawie jednego zdarzenia. `BannerAdWidget` ładuje baner raz i zwalnia go w `dispose`, więc na oko jest poprawny. Warto sprawdzić, czy zgłosi to ktoś przy normalnym użyciu — jeśli tak, podejrzany numer jeden to tworzenie osobnego banera na każdym ekranie przy częstej nawigacji

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
- [ ] **Wydruk karty drogowej** — świadomie poza zakresem tej gałęzi. Dane zbierają się od teraz, wydruk powstanie na realnych wpisach. Wymaga norm i linii rozliczeniowych **per pojazd**, bo druk jest załącznikiem do zarządzenia wójta i różni się między gminami (porównane Kielno, Osielsko, Świętajno)

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

## Do zrobienia — Wyjazdy gospodarcze / tankowanie
Zgłoszenie od Sebastiana: osobna ewidencja wyjazdów niealarmowych
(gospodarczy, tankowanie, przewóz sprzętu), oddzielona od wyjazdów
alarmowych — inna lista, inne statystyki.

**Proponowane pola:** data, godzina wyjazdu i powrotu, pojazd, kierowca,
przebieg (licznik przed/po lub sam dystans), miejscowość/trasa, cel wyjazdu
(np. „Gdynia SLRR — wyjazd po pompę na plażę"), uwagi.

**Powiązanie:** ten temat pokrywa się z zapisanym wcześniej pomysłem
„przebieg pojazdów (kilometry)" dla Gospodarza — obie rzeczy powinny
powstać razem, bo to ten sam zestaw danych i ten sam odbiorca.

**Do ustalenia z Deringiem przed implementacją:** dokładny zestaw pól i to,
czy rozliczenie ma być miesięczne per pojazd, czy per wyjazd.

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

### Usunięcie reklam + „postaw mi kawę”
**Decyzja podjęta 12.08.2026: rezygnujemy z reklam.**

Powód nie jest taki, że reklamy przeszkadzają — baner na dole nikomu nie wadził.
Powód jest taki, że przy realnej skali tej aplikacji **nie zarabiają nic
sensownego, a komplikują prostą sytuację prawną**.

Arytmetyka na której oparta jest decyzja (przy założeniu 1000 użytkowników
i ~3000 wypełnionych raportów rocznie):

| Format | Stawka / 1000 wyśw. | Wyświetleń rocznie | Przychód rocznie |
|---|---|---|---|
| Baner na dole | 2–5 zł | 15–30 tys. | 30–150 zł |
| Pełnoekranowa | 15–40 zł | ~3 tys. | 45–120 zł |
| Filmik z nagrodą | 30–80 zł | 150–300 | 10–25 zł |

Kluczowa obserwacja: pełnoekranowa płaci **ośmiokrotnie lepiej za wyświetlenie**,
a daje mniej więcej tyle samo pieniędzy — bo wąskim gardłem jest liczba zdarzeń
(3000 raportów), nie stawka. Zmiana formatu nie rusza rzędu wielkości, rusza
tylko to, jak bardzo aplikacja przeszkadza przy zdarzeniu.

Czego naprawdę kosztują reklamy (opłat **nie ma** — platforma zgód Google jest
darmowa; kosztem jest praca i odpowiedzialność):
- okno zgody RODO przy pierwszym uruchomieniu (wymagane dla użytkowników z UE
  przy każdym formacie, także zwykłym banerze) — **nie jest wdrożone**,
- polityka prywatności opisująca zbieranie identyfikatorów reklamowych,
- deklaracja zbieranych danych w Google Play,
- odpowiedzialność za to przetwarzanie po stronie autora aplikacji.

Bez reklam aplikacja nie zbiera praktycznie nic — dane leżą na Dysku Google
samego użytkownika. Polityka prywatności mieści się w akapicie.

Do zrobienia:
- [ ] Usunąć `google_mobile_ads`, `BannerAdWidget`, `AdService` i `showAdsProvider`
- [ ] Usunąć sekcję „Premium / Wyłącz reklamy" z Ustawień wraz z `PurchaseService`
- [ ] Usunąć `com.google.android.gms.ads.APPLICATION_ID` z `AndroidManifest.xml`
- [ ] Dodać skromny przycisk **„Postaw mi kawę"** w „O aplikacji" (link zewnętrzny,
      bez płatności w aplikacji — inaczej wchodzimy w regulamin płatności Google)
- [ ] Sprawdzić, o ile schudnie APK (dziś 64 MB, spora część to biblioteka reklamowa)
- [ ] Przy okazji odpada podejrzany o `OutOfMemoryError` z sekcji „Do obserwacji”

Model płatny (roczna licencja na jednostkę) **odłożony do czasu, aż powstanie
wydruk karty drogowej** — to jedyna funkcja, która realnie oszczędza komuś czas,
więc dopiero po niej będzie wiadomo, czy ktokolwiek chce za to płacić. Uwaga na
przyszłość: OSP finansuje gmina, a gmina kupuje na fakturę i przelew — subskrypcja
w Google Play jest kupowana przez osobę prywatną kartą, bez faktury dla gminy.

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
