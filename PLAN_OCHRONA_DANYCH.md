# Plan: ochrona danych — szybkie poprawki (fix/046-ochrona-danych)

Stan na 26.10.2026, wersja 1.7.1+14.

Dane jednostki leżą w folderze `OSP_App_<nazwa>` na Dysku założyciela.
Koledzy mają do niego rolę `writer` (`lib/services/google_drive_service.dart:165`),
a aplikacja używa zakresu `drive.file`, więc widzi wyłącznie pliki, które sama
utworzyła. Analiza znalazła cztery rzeczy do poprawienia **bez zmiany
architektury**. Problemy, których nie da się naprawić w obecnym modelu
(własność plików, umowa powierzenia danych), opisuje
[PLAN_DYSK_WSPOLDZIELONY.md](PLAN_DYSK_WSPOLDZIELONY.md).

| Etap | Co | Wielkość | Zmienia format danych? |
|---|---|---|---|
| 1 | Blokada dalszego udostępniania folderu | mała | nie |
| 2 | Kopia zapasowa Androida wyłączona | bardzo mała | nie |
| 3 | Usuwanie danych jednostki z telefonu | średnia | nie |
| 4 | Szyfrowanie bazy (opcjonalne) | średnia, ryzykowna | nie |

Żaden etap nie zmienia modeli Hive ani `syncFormat`. Wersje 1.7.1 i nowa
synchronizują się ze sobą, więc koledzy nie muszą aktualizować się wszyscy
naraz — inaczej niż przy fix/044.

---

## Etap 1 — blokada dalszego udostępniania folderu

### Problem
Folder tworzony przez `createUnitFolder` (`google_drive_service.dart:42`)
ma domyślne ustawienie Dysku „Edytujący mogą zmieniać uprawnienia
i udostępniać”. Każdy członek może więc udostępnić **cały folder jednostki**
dowolnej osobie — z pominięciem administratora. Lista osób w Ustawieniach
pokaże ją dopiero po fakcie.

### Zmiany
1. **Nowe foldery i pliki** — `writersCanShare = false` w `drive.File()`
   tworzonym przez `createUnitFolder`, `_createSubfolder` (`:72`)
   i `createJsonFile` (`:253`). Dotyczy wszystkiego, co aplikacja zakłada:
   folderu jednostki, `config/`, `reports/`, `reports/<rok>/`, `handovers/`,
   `trips/` i plików JSON.
2. **Istniejące jednostki** — nowa metoda `GoogleDriveService.restrictSharing(fileId)`:
   `files.get(fields: 'ownedByMe, writersCanShare')`, a gdy `ownedByMe`
   i `writersCanShare != false` → `files.update(writersCanShare: false)`.
   Wołana raz, po udanej synchronizacji, dla folderu jednostki i jego
   podfolderów. Wynik zapamiętany w `settingsBox` (np. `sharingRestricted: 1`),
   żeby kolejne synchronizacje nie robiły ani jednego zapytania więcej.
   Ustawienie zmienia tylko właściciel pliku, więc w praktyce zadziała na
   telefonie założyciela. Na pozostałych metoda nic nie robi (`ownedByMe == false`).
   Istniejących **plików** nie poprawiamy: to setki zapytań, a udostępnienie
   pojedynczego raportu jest dużo mniejszym ryzykiem niż udostępnienie folderu.
3. **Kto może zapraszać** — po blokadzie zapraszać i odbierać dostęp może tylko
   właściciel folderu. Administrator z `admins.json`, który nie jest
   właścicielem, dostałby od Dysku 403 w `inviteMember` / `revokeMember`
   (`sync_service.dart:156`, `:172`). W `UnitMembersSection` (`lib/screens/settings/unit_members_section.dart`):
   - `files.get(fields: 'capabilities(canShare)')` decyduje, czy pokazać
     „Zaproś” i „Odbierz dostęp”;
   - bez tego prawa — informacja „Zaprasza właściciel folderu: <e-mail
     założyciela>” zamiast przycisku.

   To zmiana zachowania, ale zgodna z intencją: o tym, kto widzi dane jednostki,
   decyduje jedna osoba, a nie każdy członek.

### Czego to nie załatwia
Pliki utworzone przez kolegów są **ich własnością** (tak działa Mój Dysk),
a właściciel zawsze może udostępnić swój plik. Tego w Moim Dysku nie da się
zablokować — rozwiązuje to dopiero dysk współdzielony.

### Testy
- `test/helpers/fake_drive.dart`: `FakeFile` dostaje `owner` i `writersCanShare`;
  `FakeDrive` — bieżące konto (przełączane w `phone()` w teście „dwa telefony”).
  Nowe metody trzeba w `FakeDrive` zaimplementować, bo `noSuchMethod` wywróci test.
- Nowa jednostka: folder, podfoldery i pliki mają `writersCanShare == false`.
- Istniejąca jednostka: synchronizacja na telefonie właściciela ustawia blokadę
  **raz**. Test „synchronizacja bez zmian niczego nie wysyła ani nie czyta”
  musi dalej przechodzić, także po pierwszym przebiegu z blokadą.
- Telefon nie-właściciela nie próbuje zmieniać ustawienia.
- Administrator bez prawa udostępniania widzi informację zamiast przycisku
  „Zaproś” (test widgetu).

### Sprawdzenie ręczne
drive.google.com → folder jednostki → Udostępnij → koło zębate: „Edytujący
mogą zmieniać uprawnienia i udostępniać” odznaczone. Z konta kolegi —
próba udostępnienia folderu się nie udaje.

---

## Etap 2 — kopia zapasowa Androida

### Problem
`android/app/src/main/AndroidManifest.xml` nie ustawia `android:allowBackup`,
więc domyślnie jest `true`. Android Auto Backup wysyła katalog aplikacji —
razem z całą bazą Hive (ratownicy, daty badań, dane osób przejmujących mienie) —
na **prywatne konto Google właściciela telefonu**, poza kontrolą jednostki.
W backlogu: „Drobne → `allowBackup` domyślnie włączony… Decyzja do podjęcia”.

### Decyzja
- **Kopia w chmurze i przez adb — wyłączona.**
- **Przeniesienie telefon → telefon** (przy konfiguracji nowego telefonu,
  kablem albo przez Wi-Fi) — **zostaje**. To kopia na własne nowe urządzenie,
  nie do chmury. Chroni użytkowników trybu offline, którzy nie mają danych
  nigdzie indziej.

### Zmiana
Jeden atrybut w `<application>`:

```xml
android:allowBackup="false"
```

z komentarzem w manifeście, co to wyłącza, a czego nie. Na Androidzie 12+
`allowBackup="false"` wyłącza kopię w chmurze i przez adb, ale **nie**
przeniesienie między telefonami — dokładnie tego chcemy, więc pliku
`data_extraction_rules.xml` nie trzeba. Na Androidzie ≤ 11 ten sam atrybut
wyłącza też przeniesienie między telefonami. Tego się nie da rozdzielić,
a takich telefonów jest coraz mniej.

Gdyby kiedyś wszedł Etap 4 (szyfrowanie), przeniesienie trzeba będzie wyłączyć
osobnym `android:dataExtractionRules`. Klucz z Keystore nie przechodzi na nowy
telefon, więc przeniesiona baza byłaby nieczytelna.

### Sprawdzenie
- Build release na emulatorze OSP_PlayStore, instalacja jako aktualizacja
  (`adb install -r`) — dane zostają, jak przy poprzednich wydaniach.
- `adb shell bmgr backupnow pl.osp.osp_app` — kopia powinna zostać odrzucona
  (pakiet nie kwalifikuje się do kopii).
- Kopie wysłane wcześniej sama aktualizacja nie usuwa. W razie potrzeby każdy
  może je usunąć w swoim koncie Google (drive.google.com → Kopie zapasowe).
- Decyzję wpisać do polityki prywatności („Przed publikacją” w BACKLOG.md).

---

## Etap 3 — usuwanie danych jednostki z telefonu

### Problem
- „Wyloguj” w Ustawieniach (dialog „Dane lokalne zostaną zachowane”,
  `lib/screens/settings/settings_screen.dart:363`) woła `signOut()` →
  `disconnectUnit()` (`sync_service.dart:219`). Na telefonie zostaje pełna kopia
  danych jednostki, a jedyny sposób, żeby ją usunąć, to odinstalowanie aplikacji.
- Gdy administrator odbierze komuś dostęp (`revokeMember`), telefon tej osoby
  nie dowiaduje się o tym wprost. Synchronizacja kończy się ogólnym błędem,
  a dane zostają.

W backlogu: „RODO: »Usuń dane z tego telefonu« po odejściu z jednostki”.

### Zmiany
1. **`DatabaseService.wipeUnitData()`** — czyści:
   - boksy `vehicles`, `firefighters`, `reports`, `property_handovers`,
     `vehicle_trips`, `threats` (potem `ensureDefaultThreats()`),
   - w `settings` klucze jednostki: `syncTombstones`, `adminEmails`,
     `unitConfigEditedAt`, `tripsBackfilledReportIds`, `driveFileCache`,
   - w `config`: `driveSync` oraz `main`, zresetowane do `UnitConfig()`.

   Zostają ustawienia telefonu, nie jednostki: sparowana drukarka Bluetooth
   (`btPrinterMac`, `btPrinterName`) i `gettingStartedDismissed`. Lista kluczy
   w jednym miejscu, z testem, który wywróci się, gdy ktoś doda nowy boks lub
   klucz z danymi jednostki i zapomni go tu dopisać.
2. **Dialog „Wyloguj”** — trzy wyjścia: „Anuluj” / „Wyloguj, zachowaj dane” /
   „Wyloguj i usuń dane z telefonu”. Przed usunięciem pełna synchronizacja
   (`syncAll`). Pole `syncStatus` rekordów nie jest dziś prowadzone (zawsze
   `'local'`), więc „wszystko wysłane” da się stwierdzić tylko udaną
   synchronizacją. Gdy się nie uda (brak zasięgu, błąd) — drugie ostrzeżenie:
   „Nie udało się wysłać zmian z tego telefonu. Usunięcie skasuje je
   bezpowrotnie.” z osobnym potwierdzeniem. Po usunięciu:
   `onboardingCompleted = false`, przejście do `/onboarding`, odświeżenie
   providerów.
3. **Odebrany dostęp** — na początku `syncAll` sprawdzenie folderu jednostki.
   Dziś `isFolderAccessible` (`google_drive_service.dart:348`, nigdzie nie
   wołana) zwraca `false` przy każdym wyjątku, także przy braku sieci. Trzeba
   rozróżnić:
   - `DetailedApiRequestError` 404 / 403 → **brak dostępu**,
   - wszystko inne → zwykły błąd synchronizacji, jak dziś.

   Przy braku dostępu: nowy stan w `SyncState` (np. `accessRevoked`),
   zatrzymanie automatycznej synchronizacji, komunikat w Ustawieniach i na
   ekranie głównym: „Nie masz już dostępu do jednostki. Jej dane są nadal na
   tym telefonie.” Do tego przyciski „Usuń dane z telefonu” (bez synchronizacji,
   bo nie ma dokąd wysłać) i „Zostaw”. Po pomyłce administratora i ponownym
   udostępnieniu synchronizacja wraca sama.
   **Nigdy nie kasujemy automatycznie** — tylko po kliknięciu.
4. (Może poczekać) Tryb offline: „Usuń wszystkie dane z telefonu”
   w Ustawieniach, z mocnym ostrzeżeniem, bo to jedyna kopia.

### Czego to nie załatwia
To higiena i zasada minimalizacji danych, nie zabezpieczenie przed nadużyciem.
Zdeterminowana osoba mogła wcześniej zrobić zrzut ekranu, PDF albo pobrać pliki
z Dysku. Zdalnego kasowania nie ma i nie będzie — telefon musi uruchomić aplikację.

### Testy
- `wipeUnitData` czyści wszystkie boksy i klucze jednostki, zostawia drukarkę.
  Po ponownym otwarciu bazy nic nie wraca (wzorzec z testu stempli w
  `sync_two_phones_test.dart`).
- „Wyloguj i usuń” po udanej synchronizacji: zmiany z tego telefonu są na Dysku
  (`FakeDrive`), zanim znikną lokalnie, a drugi telefon je widzi.
- Nieudana synchronizacja → usunięcie wymaga drugiego potwierdzenia.
- `FakeDrive.revoke(email)` → 404 → stan `accessRevoked`. Brak sieci → zwykły
  błąd, **nie** `accessRevoked`. Ponowne udostępnienie → kolejna synchronizacja
  zdejmuje stan.

---

## Etap 4 (opcjonalny) — szyfrowanie bazy na telefonie

**Co:** `HiveAesCipher` z kluczem 256-bitowym trzymanym w Android Keystore
(pakiet `flutter_secure_storage`).

**Co daje:** dane nieczytelne po wyciągnięciu plików z telefonu z rootem albo
z kopii. Po Etapie 2 kopia w chmurze i przez adb jest jednak już wyłączona,
a telefony wydane z Androidem 10 lub nowszym mają obowiązkowe szyfrowanie
danych (oparte na plikach) — pliki aplikacji są nieczytelne, dopóki telefon
jest zablokowany.

**Ryzyka:**
- **Migracja** — Hive nie otworzy niezaszyfrowanego boksu z szyfrem. Każdy boks
  trzeba przepisać do nowego (pod inną nazwą), porównać liczbę rekordów i dopiero
  wtedy usunąć stary. Do tego znacznik postępu, żeby przerwanie w połowie
  (zamknięcie aplikacji, padnięta bateria) nie zostawiło pół bazy.
- **Utrata klucza = utrata bazy.** Klucz z Keystore nie przechodzi przy
  przeniesieniu na nowy telefon, a na części telefonów znika przy resecie
  blokady ekranu. Członkom jednostki dane wrócą z Dysku, w trybie offline
  przepadną.
- Nowa zależność natywna i nowy punkt awarii przy starcie. fix/025 pokazał,
  jak łatwo o release zawieszony na ekranie startowym.

**Rekomendacja: nie robić teraz.** Wrócić, jeśli aplikacja zacznie trzymać dane
wrażliwsze (np. PESEL, dokumentację medyczną) albo gdy wymusi to polityka Play.

---

## Kolejność i wydanie
1. Etap 2 → Etap 1 → Etap 3, każdy osobnym commitem z testami (zasada
   z `.github/copilot-instructions.md`).
2. Wersja `1.7.2+15`. Format danych bez zmian.
3. Przed wydaniem: `flutter test`, build release, instalacja jako aktualizacja
   na emulatorze z zachowaniem danych, sprawdzenie Etapu 1 na prawdziwym koncie
   Google.
4. Po UAT, w BACKLOG.md: zamknąć „Drobne → `allowBackup`” i „RODO → Usuń dane
   z tego telefonu”, opisać decyzje.

## Niezależnie od tego planu
Otwarty od fix/044 **test na dwóch telefonach z różnymi kontami Google** jest
tu ważny podwójnie. Etap 1 zmienia, kto może zapraszać, a Etap 3 opiera się na
tym, co Dysk odpowiada po odebraniu dostępu. Obie rzeczy da się w pełni
sprawdzić tylko na prawdziwych kontach.
