# Plan: przejście na dysk współdzielony (feature/047-dysk-wspoldzielony)

Stan na 26.10.2026, wersja 1.7.1+14. Zakłada wcześniejsze wykonanie
[PLAN_OCHRONA_DANYCH.md](PLAN_OCHRONA_DANYCH.md) (fix/046) — patrz
„Kolejność” na końcu.

## Po co

Obecny model to folder w **Moim Dysku** prywatnego konta założyciela,
udostępniony kolegom z rolą `writer`. Trzech jego słabości nie da się
naprawić w kodzie:

- **Własność plików.** W Moim Dysku plik należy do konta, które go utworzyło.
  Raport kolegi leży w folderze założyciela, ale jest własnością prywatnego konta
  kolegi i zajmuje jego miejsce na Dysku. Usunięcie tego konta usuwa jego raporty
  z jednostki. Odejście założyciela to problem z całym folderem.
- **RODO.** Przy prywatnych kontach Gmail nie ma umowy powierzenia
  przetwarzania danych z Google (art. 28). A w danych są też osoby trzecie —
  przejmujący mienie: imię, nazwisko, adres, telefon
  (`lib/models/property_handover.dart:44-52`).
- **Uprawnienia.** Rola `writer` w Moim Dysku pozwala każdemu członkowi
  udostępniać pliki, których jest właścicielem. fix/046 blokuje tylko
  udostępnianie folderów i plików założyciela.

Dysk współdzielony (Google Workspace) odpowiada na wszystkie trzy:

- pliki należą do **organizacji**, nie do osób — zostają po odejściu każdego
  członka, także założyciela;
- rola „Współtwórca” (`writer`) dodaje i edytuje pliki, ale **nie może ich
  usuwać**. Kosz jest tylko dla „Menedżera treści” i „Menedżera”, a trwałe
  usunięcie tylko dla „Menedżera”;
- udostępnianie poza dysk kontrolują Menedżer i ustawienia organizacji;
- Workspace ma umowę powierzenia przetwarzania danych, akceptowaną w konsoli
  administratora;
- historia wersji i dziennik aktywności zostają jak dziś.

## Co się nie zmienia

- Lokalna baza Hive, tryb offline, cała logika scalania: stemple `updatedAt`,
  znaczniki usunięcia, wysyłanie tylko zmian (fix/044).
- Format plików JSON i układ folderów: `config/`, `reports/<rok>/`,
  `handovers/`, `trips/`.
- Koledzy zostają na **swoich prywatnych kontach Gmail**. Konto w domenie
  jednostki potrzebują tylko Menedżerowie (1–2 osoby).
- Jednostki, które zostaną w Moim Dysku, działają jak dotąd. Dysk współdzielony
  jest opcją, nie wymogiem.
- Jeśli pozwoli na to Etap 1 — zakres `drive.file`, który przy publikacji
  w Play nie wymaga oceny bezpieczeństwa.

---

## Etap 0 — decyzje organizacyjne (Dawid + zarząd OSP)

1. **Konto Google Workspace dla jednostki**, jedna z dróg:
   - **Google for Nonprofits** — Workspace for Nonprofits bez opłat. Wymaga
     rejestracji jako organizacja charytatywna według kryteriów danego kraju
     i weryfikacji przez Goodstack (TechSoup nie weryfikuje od 2023). **Czy OSP
     (stowarzyszenie w KRS) się kwalifikuje — do sprawdzenia** w wytycznych dla
     Polski albo bezpośrednio u Google lub Goodstack. Wykluczone są m.in.
     jednostki rządowe; OSP nią nie jest, ale rozstrzyga Google.
   - **Business Starter** — od września 2024 obejmuje dyski współdzielone
     (z okrojonymi ustawieniami administratora). Opłata miesięczna za konto;
     wystarczą konta Menedżerów.
2. **Domena** — Workspace wymaga własnej domeny (np. `ospkielno.pl`). Koszt
   roczny po stronie jednostki.
3. **Menedżerowie dysku** — co najmniej dwie osoby z kontami w domenie, żeby nie
   powtórzyć problemu jednej osoby, od której wszystko zależy.
4. **Konsola administratora Workspace:**
   - zgoda na udostępnianie poza organizację (koledzy na prywatnych Gmailach),
   - na dysku współdzielonym: dostęp dla osób spoza dysku do udostępnionych im
     plików i folderów (koledzy dostają sam folder jednostki, nie cały dysk),
   - akceptacja umowy powierzenia przetwarzania danych w ustawieniach prawnych
     konta.
5. **Polityka prywatności i rejestr czynności przetwarzania** jednostki: gdzie
   leżą dane i kto jest podmiotem przetwarzającym.

---

## Etap 1 — weryfikacja techniczna (spike, przed właściwym kodem)

Dokumentacja Google nie rozstrzyga kilku rzeczy, od których zależy kształt kodu.
Trzy próby na prawdziwych kontach: konto Workspace + dwa prywatne Gmaile,
aplikacja w trybie testowym ekranu zgody OAuth.

| # | Pytanie | Dlaczego ważne |
|---|---|---|
| T1 | Czy aplikacja z `drive.file` na koncie B widzi pliki, które ta sama aplikacja utworzyła na koncie A, gdy A udostępniło folder B? | Na tym już dziś opiera się dołączanie do jednostki (`findUnitByInviteCode`, `lib/services/google_drive_service.dart:198`). To ten sam otwarty test „dwa telefony, różne konta Google” z fix/044. **Jeśli koledzy już dziś synchronizują się z własnych kont, T1 jest zaliczony** — wystarczy to zapisać. |
| T2 | To samo, gdy folder jednostki leży na dysku współdzielonym, a B dostał dostęp tylko do tego folderu (nie jest członkiem dysku). | Na tym opiera się model „koledzy spoza dysku z dostępem do folderu”. |
| T3 | Jak aplikacja z `drive.file` może umieścić folder na dysku założonym ręcznie: (a) utworzyć folder z `parents: [driveId]`; (b) utworzyć go w Moim Dysku, a Menedżer przenosi go w drive.google.com; (c) `files.update(addParents: driveId)`? | `drives.create` wymaga pełnego zakresu `drive`. To zakres zastrzeżony: przy publikacji wymaga oceny bezpieczeństwa. Aplikacja raczej więc nie założy dysku sama — trzeba wiedzieć, jak dostanie się do dysku założonego ręcznie. |

Przy okazji sprawdzić, czy `files.list` z `corpora: 'allDrives'` znajduje
`unit_config.json` w folderze udostępnionym osobie spoza dysku. Od tego zależy
wyszukiwanie po kodzie zaproszenia w Etapie 2.

**Decyzje po spiku:**
- T1 i T2 działają, a (a) lub (c) z T3 też → zostajemy przy `drive.file`,
  reszta planu bez zmian.
- T1 i T2 działają, z T3 tylko (b) → kreator w Etapie 3 i 4 prowadzi
  Menedżera przez ręczne przeniesienie pustego folderu.
- **T1 lub T2 nie działa** → `drive.file` nie wystarcza do pracy wielu kont
  **w ogóle, także w obecnej wersji**. Zostaje zakres `drive`: aplikacja
  niezweryfikowana obsłuży do 100 użytkowników, z ekranem ostrzeżenia
  „aplikacja niezweryfikowana”; publikacja wymaga oceny bezpieczeństwa. Albo
  powrót do pytania o własny backend (Firebase). **Tę decyzję trzeba podjąć
  przed resztą planu.**

Spike to mały kod do wyrzucenia: ekran diagnostyczny tylko w buildzie debug
albo skrypt Dart z `googleapis`. Wynik zapisać w BACKLOG.md.

---

## Etap 2 — kod gotowy na dyski współdzielone (bez zmiany zachowania)

Etap można wydać przed jakąkolwiek migracją — poniższe flagi nie zmieniają
niczego dla folderów w Moim Dysku.

`lib/services/google_drive_service.dart`:
- każde `files.list` → `supportsAllDrives: true, includeItemsFromAllDrives: true`.
  W `findUnitByInviteCode` dodatkowo `corpora: 'allDrives'` (według wyniku
  spiku). Odpowiedź może mieć `incompleteSearch` — wtedy komunikat „spróbuj
  ponownie” zamiast „nie znaleziono jednostki”;
- `files.create`, `files.update`, `files.get`, `files.delete` →
  `supportsAllDrives: true`;
- `permissions.create`, `permissions.list`, `permissions.delete` →
  `supportsAllDrives: true`;
- **`listFolderMembers`** — na dysku współdzielonym nie ma roli `owner` (jej
  odpowiednik to `organizer`, czyli Menedżer). Członkowie całego dysku
  występują jako uprawnienia **dziedziczone** (`permissionDetails[].inherited`).
  Takich nie da się odebrać z poziomu folderu: na liście w Ustawieniach
  podpisać ich „członek dysku współdzielonego — zarządzaj w Dysku Google”,
  bez przycisku „Odbierz dostęp”;
- nowa metoda **`unitStorageInfo(folderId)`** → `files.get(fields: 'driveId,
  ownedByMe, capabilities(canShare)')`: czy folder leży na dysku współdzielonym
  i czy to konto może zapraszać. `capabilities.canShare` zastępuje sprawdzanie
  właściciela z Etapu 1 fix/046 i działa w obu modelach.

`lib/services/sync_service.dart` i Ustawienia:
- `inviteMember` bez zmian w kodzie. Na dysku współdzielonym rola `writer` to
  „Współtwórca”, czyli bez usuwania plików — synchronizacji to nie przeszkadza,
  bo usunięcia jeżdżą jako znaczniki (nadpisanie treści), a `deleteFile` nie
  jest używane przy synchronizacji;
- w Ustawieniach wiersz „Dane jednostki: Dysk współdzielony »…«” albo
  „Mój Dysk konta …”.

Testy:
- `test/helpers/fake_drive.dart`: `driveId` w `FakeFile`, uprawnienia
  dziedziczone, `canShare`;
- **12 scenariuszy** z `test/sync_two_phones_test.dart` uruchamiane dwa razy:
  dla folderu w Moim Dysku i na dysku współdzielonym (ten sam zestaw,
  sparametryzowany).

---

## Etap 3 — nowa jednostka od razu na dysku współdzielonym

Onboarding „Utwórz jednostkę”: wybór „Mój Dysk” (jak dziś) albo „Dysk
współdzielony jednostki”. Z zakresem `drive.file` aplikacja nie może wylistować
dysków (`drives.list` wymaga szerszego zakresu), więc Menedżer **wkleja link
do dysku współdzielonego** — jego identyfikator jest w adresie.

Dalej według wyniku T3:
- (a) / (c) — aplikacja zakłada folder jednostki bezpośrednio na tym dysku;
- (b) — aplikacja zakłada folder w Moim Dysku i pokazuje instrukcję
  „przenieś folder `OSP_App_…` na dysk współdzielony” z linkiem. Po powrocie
  sprawdza `driveId` folderu i dopiero wtedy kontynuuje.

Reszta jak dziś: `unit_config.json`, kod zaproszenia, `_pushAllData`.

---

## Etap 4 — przeniesienie istniejącej jednostki

Najważniejszy i najbardziej ryzykowny etap. Zasada: **stary folder zostaje
nietknięty aż do jednego, ostatniego zapisu** (znacznik przeniesienia).
Przerwanie w dowolnym momencie przed nim niczego nie psuje — wystarczy zacząć
od nowa.

### Nowy format danych: `syncFormat = 3`
Oznacza: „rozumiem znacznik przeniesienia”. Wersje ≤ 1.7.x zobaczą 3 w starym
folderze i zablokują się z komunikatem „zaktualizuj” (mechanizm z fix/044,
`sync_service.dart:413`). Dzięki temu nie będą dalej pisać do starego folderu.

### Przebieg na telefonie Menedżera
Nowy ekran „Przenieś jednostkę na dysk współdzielony”, tylko dla administratora.

1. **Pełna synchronizacja** ze starym folderem. Musi się udać, inaczej stop.
2. **Nowy folder** jednostki na dysku współdzielonym (droga z Etapu 3).
3. **Konfiguracja:**
   - `unit_config.json` z tym samym `unitName`, `createdBy` (dotychczasowy
     założyciel zostaje założycielem), tym samym kodem zaproszenia,
     `syncFormat: 3` i `movedFrom: <stary folderId>`,
   - `admins.json`, listy ratowników i pojazdów, słownik zagrożeń.
4. **Wszystkie dokumenty razem ze znacznikami usunięcia** —
   `_resetUnitState()` + `_pushAllData()` (`sync_service.dart:967`). To ta sama
   ścieżka, którą dziś przechodzi zakładanie jednostki.
5. **Udostępnienie nowego folderu** wszystkim osobom z dostępem do starego
   (`listFolderMembers` → `shareFolderWithUser`). Nikogo nie trzeba zapraszać
   ręcznie.
6. **Punkt bez powrotu** — w starym `unit_config.json`: `movedTo: <nowy
   folderId>`, `syncFormat: 3`, usunięty `inviteCode` (kod ma prowadzić tylko do
   nowego folderu).
7. **Dopełnienie** — jeszcze jedno pobranie ze starego folderu i wysłanie do
   nowego. Łapie zmiany, które koledzy wysłali między krokiem 1 a 6.
8. **Przełączenie własnego telefonu** na nowy folder (`_saveDriveConfig`,
   `sync_service.dart:1027`).

### Telefon kolegi przy najbliższej synchronizacji
1. `_pullConfig` czyta stary `unit_config.json` i widzi `movedTo`.
2. Sprawdza dostęp do nowego folderu. Potrzebne jest tu odróżnianie „brak
   dostępu” od „brak sieci” z Etapu 3 fix/046.
3. **Dostęp jest** → `_resetUnitState()`, zapis nowego folderu, zwykła
   synchronizacja: pobranie z nowego, wysłanie tego, co lokalnie nowsze.
   Niewysłane zmiany z tego telefonu trafią do nowego folderu — scalanie po
   stemplach już to obsługuje.
4. **Dostępu brak** → komunikat „Jednostka została przeniesiona. Poproś
   administratora (<e-mail>) o dostęp.” Dane lokalne zostają nietknięte.

### Po przeniesieniu
- **Okres przejściowy** (np. 2–4 tygodnie): stary folder zostaje, a aktualne
  wersje przekierowują się same.
- Potem Menedżer zmienia kolegom dostęp do starego folderu na „Czytelnik”.
  Znacznik `movedTo` nadal da się odczytać, więc spóźnieni też się przełączą.
  Po kolejnym okresie folder idzie do archiwum albo do usunięcia. Pliki kolegów
  w starym folderze dalej należą do nich, ale to tylko archiwum — źródłem prawdy
  jest dysk współdzielony.

### Plan wycofania
- **Przed krokiem 6** — porzucić nowy folder, nic się nie stało.
- **Po kroku 6** — usunąć `movedTo` ze starego `unit_config.json`: przyciskiem
  „Cofnij przeniesienie” dostępnym dla Menedżera przez okres przejściowy albo
  ręcznie. Zmiany, które trafiły tylko do nowego folderu, przenosi się z powrotem
  tą samą procedurą w drugą stronę.

### Testy (`test/sync_two_phones_test.dart`, `FakeDrive`)
- Po kroku 8 nowy folder ma te same raporty, przekazania, przejazdy, listy
  i znaczniki usunięcia co stary.
- Telefon kolegi przełącza się sam i nie gubi niewysłanej zmiany.
- Zmiana wysłana do starego folderu w trakcie przeniesienia (między krokiem
  1 a 6) trafia do nowego dzięki krokowi 7.
- Kolega bez dostępu do nowego folderu dostaje komunikat, a dane lokalne zostają.
- Stara wersja (format 2) jest blokowana przez `syncFormat: 3` w starym folderze.
- Usunięty rekord nie wraca po przeniesieniu (znacznik przeszedł).
- Przerwanie przed krokiem 6 zostawia stary folder nietknięty, a ponowna próba
  się udaje.
- Kod zaproszenia po przeniesieniu prowadzi do nowego folderu.

---

## Etap 5 — wdrożenie w OSP Kielno

1. Etap 0 załatwiony: konto, domena, Menedżerowie, ustawienia, umowa powierzenia.
2. **Wszyscy koledzy na wersji z Etapem 4** — potwierdzić osobiście lub na
   grupie jednostki. Aplikacja nie zbiera informacji o wersjach.
3. Przeniesienie w spokojnym momencie (nie w trakcie akcji), z telefonu
   Menedżera z dobrym zasięgiem.
4. Sprawdzenie na drugim telefonie: przełączenie, raporty, druk.
5. Po okresie przejściowym: stary folder tylko do odczytu, potem archiwum.

Wersja: `1.8.0`. Nowy format danych, więc podbicie drugiej cyfry, jak przy
zmianach w fix/044.

---

## Ryzyka
- **Wynik spiku może wymusić zakres `drive`** — wtedy rośnie koszt publikacji
  w Play (ocena bezpieczeństwa), a ekran zgody pokazuje szerszy dostęp.
- **Koszt Workspace albo weryfikacja non-profit** — to decyzja zarządu, nie
  programisty. Bez niej plan stoi na Etapie 0.
- **Telefon, który przez okres przejściowy nie uruchomi aplikacji** — przełączy
  się później, byle stary folder był jeszcze czytelny. Dlatego przed usunięciem
  starego folderu przechodzi się przez etap „tylko do odczytu”.
- **Ustawienia Business Starter są okrojone** — przed wyborem sprawdzić, czy
  da się w nim włączyć dostęp dla osób spoza dysku do pojedynczego folderu.

## Kolejność względem planu ochrony danych
Najpierw fix/046 ([PLAN_OCHRONA_DANYCH.md](PLAN_OCHRONA_DANYCH.md)):
- Etap 3 tamtego planu (rozróżnianie „brak dostępu” od „brak sieci”) jest
  potrzebny przy przełączaniu po `movedTo`;
- Etapy 2 i 3 (kopia zapasowa, usuwanie danych z telefonu) dotyczą telefonów,
  nie Dysku, więc zostają ważne także po przejściu na dysk współdzielony;
- Etap 1 (`writersCanShare`) przestaje mieć znaczenie po przeniesieniu —
  na dysku współdzielonym udostępnianiem rządzą ustawienia dysku.
