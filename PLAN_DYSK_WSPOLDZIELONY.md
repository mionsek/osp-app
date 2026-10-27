# Plan: przejście na dysk współdzielony (feature/048-dysk-wspoldzielony)

Analiza z 26.10.2026 (wersja 1.7.1, gałąź `claude/raporty-osp-analysis-1wbpj3`),
poprawiona 27.10.2026, wersja 1.7.4+17. Pierwotnie jako feature/047 — ten numer
zajęły poprawki synchronizacji. Ochronę danych na telefonie opisuje
[PLAN_OCHRONA_DANYCH.md](PLAN_OCHRONA_DANYCH.md).

**Stan: czeka na decyzję zarządu (Etap 0).** Technicznie nic nie blokuje.

## Po co

Dziś folder jednostki leży w **Moim Dysku** konta, które ją założyło (od
fix/046 zalecane: wspólne konto jednostki, np. ospkielno@gmail.com), a koledzy
mają do niego rolę `writer`. Słabości tego modelu, po sprawdzeniu w kodzie:

- **RODO — jedyny argument, którego nie załatwi kod.** Przy prywatnych kontach
  Gmail nie ma umowy powierzenia przetwarzania danych z Google (art. 28).
  W danych są też osoby trzecie — przejmujący mienie: imię, nazwisko, adres,
  telefon. Workspace ma taką umowę, akceptowaną w konsoli administratora.
- **Własność plików — mniejszy problem, niż zakładała analiza.** W Moim Dysku
  raport kolegi jest własnością jego konta; usunięcie konta usuwa plik
  z jednostki. Ale każdy telefon trzyma całą jednostkę, a synchronizacja
  wysyła ponownie rekord, którego pliku na Dysku brak (`_pushDoc`) — zniknięty
  plik wraca przy najbliższej synchronizacji dowolnego telefonu. Ryzyko zostaje
  dla samego folderu, a ten leży na koncie jednostki, nie osoby.
- **Uprawnienia.** Rola `writer` pozwala każdemu członkowi udostępniać folder
  i edytować `config/` (listy, `admins.json`) z pominięciem aplikacji. Na
  dysku współdzielonym udostępnianiem rządzą Menedżerowie i ustawienia
  organizacji. „Współtwórca" nie usuwa plików — ale aplikacja i tak ich nie
  usuwa (usunięcie to znacznik nadpisujący treść), więc tu zysk jest niewielki.

Co **nie** zmienia się przez dysk współdzielony:
- **Zakres `drive` zostaje.** Zgoda `drive.file` dotyczy konta, nie miejsca na
  Dysku — koledzy nie widzieliby swoich plików tak samo jak w Moim Dysku.
  Publikacja w Play wymaga więc weryfikacji Google w obu modelach.
- Lokalna baza Hive, tryb offline, scalanie po stemplach, znaczniki
  usunięcia, wysyłanie tylko zmian, format plików i układ folderów
  (`config/`, `reports/<rok>/`, `handovers/`, `trips/`).
- Koledzy zostają na **prywatnych kontach Gmail**. Konto w domenie jednostki
  potrzebują tylko Menedżerowie (1–2 osoby).
- Jednostki w Moim Dysku działają jak dotąd — dysk współdzielony jest opcją.

---

## Etap 0 — decyzje organizacyjne (Dawid + zarząd OSP)

1. **Konto Google Workspace dla jednostki**, jedna z dróg:
   - **Google for Nonprofits** — Workspace bez opłat. Wymaga rejestracji jako
     organizacja charytatywna według kryteriów danego kraju i weryfikacji przez
     Goodstack. **Czy OSP (stowarzyszenie w KRS) się kwalifikuje — do
     sprawdzenia** w wytycznych dla Polski albo u Google lub Goodstack.
   - **Business Starter** — od września 2024 z dyskami współdzielonymi
     (okrojone ustawienia administratora). Opłata miesięczna za konto;
     wystarczą konta Menedżerów.
2. **Domena** (np. `ospkielno.pl`) — Workspace jej wymaga. Koszt roczny.
3. **Co najmniej dwóch Menedżerów** z kontami w domenie.
4. **Konsola administratora:** zgoda na udostępnianie poza organizację
   (koledzy na Gmailach), dostęp osób spoza dysku do udostępnionych im
   folderów, akceptacja umowy powierzenia przetwarzania danych.
5. **Polityka prywatności i rejestr czynności przetwarzania** jednostki.

---

## Etap 1 — sprawdzenie na prawdziwych kontach (krótki spike)

Pierwotne pytanie, od którego zależał cały plan — czy `drive.file` działa
między kontami — jest rozstrzygnięte: **nie działa** (test na dwóch telefonach
z 1.7.1 nie przeszedł, fix/046 przeszedł na `drive`). Z pełnym zakresem
aplikacja sama wylistuje dyski współdzielone (`drives.list`) i założy na nich
folder (`files.create` z `parents: [driveId]`), więc odpada też pytanie, jak
dostać się do dysku założonego ręcznie.

Zostaje do sprawdzenia na koncie Workspace i dwóch Gmailach:

| # | Pytanie | Dlaczego ważne |
|---|---|---|
| S1 | Czy kolega spoza dysku, z dostępem tylko do folderu jednostki, widzi go i może w nim tworzyć pliki? Na wybranym planie Workspace (Business Starter ma okrojone ustawienia). | Na tym opiera się model „koledzy na Gmailach". |
| S2 | Czy `files.list` z `corpora: 'allDrives'` znajduje `unit_config.json` w takim folderze? Czy zwraca `incompleteSearch`? | Od tego zależy dołączanie kodem. |

Wynik zapisać w BACKLOG.md. Spike to kod do wyrzucenia (ekran diagnostyczny
w buildzie debug albo skrypt Dart z `googleapis`).

---

## Etap 2 — kod gotowy na dyski współdzielone (bez zmiany zachowania)

Można wydać przed jakąkolwiek migracją — flagi nie zmieniają niczego dla
folderów w Moim Dysku.

`lib/services/google_drive_service.dart`:
- każde `files.list` → `supportsAllDrives: true, includeItemsFromAllDrives:
  true`, w wyszukiwaniu jednostek `corpora: 'allDrives'` (według S2). Przy
  `incompleteSearch` komunikat „spróbuj ponownie" zamiast „nie znaleziono";
- `files.create/update/get/delete` i `permissions.*` → `supportsAllDrives: true`;
- **okno „Dołączyć do tej jednostki?"** (obrona przed podsuniętym folderem
  z fix/046) pokazuje właściciela folderu z `owners`. **Na dysku współdzielonym
  to pole jest puste** — pliki należą do organizacji. Zamiast właściciela:
  nazwa dysku współdzielonego (`driveId` → `drives.get`) i domena organizacji.
  Bez tego obrona przestaje działać, a okno pokazuje „nieznany";
- **jednostki konta** (ostrzeżenie przed drugą jednostką z fix/047) szukają
  folderów z `ownedByMe` — na dysku współdzielonym zawsze `false`. Dla jednostek
  na dyskach współdzielonych: `capabilities.canAddChildren` + `driveId`;
- **`listFolderMembers`** — na dysku współdzielonym nie ma roli `owner`
  (odpowiednik: `organizer`). Członkowie całego dysku to uprawnienia
  dziedziczone (`permissionDetails[].inherited`) — nie da się ich odebrać
  z poziomu folderu, więc lista pokazuje je z dopiskiem „członek dysku —
  zarządzaj w Dysku Google", bez „Odbierz dostęp";
- `unitStorageInfo(folderId)` → `driveId, capabilities(canShare)`: czy folder
  leży na dysku współdzielonym i czy to konto może zapraszać.

Ustawienia: wiersz „Dane jednostki: dysk współdzielony »…«" albo „Mój Dysk
konta …".

Testy: `FakeDrive` z `driveId`, uprawnieniami dziedziczonymi i `canShare`;
scenariusze z `test/sync_two_phones_test.dart` uruchamiane dla obu modeli.

---

## Etap 3 — nowa jednostka od razu na dysku współdzielonym

„Utwórz jednostkę": wybór „Mój Dysk" albo jednego z dysków współdzielonych
konta (`drives.list`). Dalej jak dziś: `unit_config.json`, kod zaproszenia,
wysłanie danych z telefonu.

---

## Etap 4 — przeniesienie istniejącej jednostki

Najważniejszy i najbardziej ryzykowny etap. Zasada: **stary folder zostaje
nietknięty aż do jednego, ostatniego zapisu** (znacznik przeniesienia).

### Nowy format danych: `syncFormat = 3`
„Rozumiem znacznik przeniesienia". Wersje ze `syncFormat` 2 zobaczą 3
w starym folderze i zablokują się z komunikatem „zaktualizuj" (mechanizm
z fix/044), więc nie będą dalej pisać do starego folderu.

### Przebieg na telefonie Menedżera
1. Pełna synchronizacja ze starym folderem — musi się udać.
2. Nowy folder jednostki na dysku współdzielonym.
3. `unit_config.json` z tym samym `unitName`, `createdBy`, kodem zaproszenia,
   `syncFormat: 3` i `movedFrom`; `admins.json`, listy, słownik.
4. Wszystkie dokumenty razem ze znacznikami usunięcia (`_resetUnitState()` +
   `_pushAllData()` — ścieżka zakładania jednostki).
5. Udostępnienie nowego folderu wszystkim z dostępem do starego.
6. **Punkt bez powrotu** — w starym `unit_config.json`: `movedTo`,
   `syncFormat: 3`, usunięty `inviteCode`.
7. Dopełnienie: jeszcze jedno pobranie ze starego i wysłanie do nowego
   (zmiany kolegów między krokiem 1 a 6).
8. Przełączenie własnego telefonu na nowy folder.

### Telefon kolegi przy najbliższej synchronizacji
`_pullConfig` widzi `movedTo` → sprawdza dostęp do nowego folderu (wymaga
odróżniania „brak dostępu" od „brak sieci" — Etap 3b planu ochrony danych) →
przy dostępie `_resetUnitState()`, zapis nowego folderu i zwykła
synchronizacja; niewysłane zmiany trafią do nowego folderu. Bez dostępu
komunikat „Jednostka została przeniesiona. Poproś administratora (…) o dostęp",
dane lokalne nietknięte.

Uwaga na fix/047: przełączenie **nie może** iść przez `joinFoundUnit`, bo ten
zastępuje listy ratowników i pojazdów listą jednostki — tu listy są te same,
ale niewysłana zmiana administratora by przepadła.

### Po przeniesieniu i wycofanie
- Okres przejściowy 2–4 tygodnie, potem kolegom „Czytelnik" w starym folderze,
  potem archiwum.
- Przed krokiem 6 — porzucić nowy folder. Po kroku 6 — usunąć `movedTo`
  (przycisk „Cofnij przeniesienie" dla Menedżera albo ręcznie).

### Testy (`FakeDrive`)
Nowy folder ma te same raporty, przekazania, przejazdy, listy i znaczniki;
telefon kolegi przełącza się sam bez utraty niewysłanej zmiany; zmiana z okna
między krokiem 1 a 6 dociera dzięki krokowi 7; kolega bez dostępu dostaje
komunikat; format 2 blokowany; usunięty rekord nie wraca; przerwanie przed
krokiem 6 niczego nie psuje; kod zaproszenia prowadzi do nowego folderu.

---

## Etap 5 — wdrożenie w OSP Kielno

1. Etap 0 załatwiony.
2. Wszyscy koledzy na wersji z Etapem 4 — aplikacja nie zbiera informacji
   o wersjach, więc potwierdzić osobiście lub na grupie.
3. Przeniesienie w spokojnym momencie, z telefonu Menedżera z dobrym zasięgiem.
4. Sprawdzenie na drugim telefonie: przełączenie, raporty, druk.

Wersja `1.8.0` — nowy format danych.

## Ryzyka
- **Koszt Workspace albo weryfikacja non-profit** — decyzja zarządu.
- **Business Starter ma okrojone ustawienia** — sprawdzić S1 przed wyborem.
- **Telefon, który przez okres przejściowy nie uruchomi aplikacji** — przełączy
  się później, dopóki stary folder jest czytelny.

## Kolejność
1. Test na dwóch telefonach (otwarty od fix/044) i Etap 3b planu ochrony danych.
2. Decyzja zarządu (Etap 0) — bez niej plan stoi.
3. Etapy 1–5.
