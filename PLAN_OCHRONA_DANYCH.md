# Plan: ochrona danych — poprawki bez zmiany architektury

Analiza z 26.10.2026 (wersja 1.7.1, gałąź `claude/raporty-osp-analysis-1wbpj3`),
poprawiona 27.10.2026, wersja 1.7.4+17.

Dane jednostki leżą w folderze `OSP_App_<nazwa>` na Dysku konta, które ją
założyło (zalecane: wspólne konto jednostki). Koledzy mają do folderu rolę
`writer`. **Od fix/046 aplikacja ma pełny dostęp do Dysku (`drive`)**, a nie
`drive.file`, jak zakładała pierwotna analiza: przy `drive.file` koledzy nie
widzieli nawzajem swoich plików i dołączanie z innego konta nie działało.
Ograniczenie do folderu jednostki istnieje więc tylko w kodzie — patrz
„Przegląd bezpieczeństwa" w sekcji fix/046 w [BACKLOG.md](BACKLOG.md).

Problemy, których nie da się naprawić w tym modelu (umowa powierzenia danych,
własność plików), opisuje [PLAN_DYSK_WSPOLDZIELONY.md](PLAN_DYSK_WSPOLDZIELONY.md).

| Etap | Co | Stan |
|---|---|---|
| 1 | Blokada dalszego udostępniania folderu | **odrzucony** |
| 2 | Kopia zapasowa Androida wyłączona | **zrobione w fix/047** |
| 3a | „Wyloguj i usuń dane" | **zrobione w fix/047** |
| 3b | Wykrywanie odebranego dostępu | czeka na test na dwóch telefonach |
| 4 | Szyfrowanie bazy | odłożony |

Żaden etap nie zmienia modeli Hive ani `syncFormat`.

---

## Etap 1 — blokada dalszego udostępniania folderu (odrzucony)

**Problem.** Folder jednostki ma domyślne ustawienie Dysku „Edytujący mogą
zmieniać uprawnienia i udostępniać". Każdy członek może udostępnić cały folder
dowolnej osobie z pominięciem administratora.

**Proponowana poprawka:** `writersCanShare = false` na folderze i podfolderach.

**Dlaczego odrzucona.** Po blokadzie udostępniać i odbierać dostęp może tylko
**właściciel** folderu. Od fix/046 zalecany przepływ to: jednostka na koncie
jednostki (np. ospkielno@gmail.com), potem „Przełącz na swoje konto" — prywatne
konto jest administratorem w aplikacji, ale nie właścicielem folderu. Po
blokadzie Dysk odrzucałby każde „Zaproś strażaka" i „Odbierz dostęp" z tego
konta; zapraszać dałoby się tylko po przelogowaniu na konto jednostki.

Zysk jest mały: lista „Pokaż, kto ma dostęp" w Ustawieniach pokazuje każdego
z dostępem, także dodanego poza aplikacją, a członek i tak może zrobić zrzut
ekranu albo PDF. Udostępnianiem rządzi dopiero dysk współdzielony. Pliki
utworzone przez kolegów są ich własnością i tak by się nie dało ich zablokować.

---

## Etap 2 — kopia zapasowa Androida (zrobione w fix/047)

Domyślnie `android:allowBackup` jest włączony, więc Android Auto Backup
wysyłał bazę Hive (ratownicy, daty badań, dane osób przejmujących mienie) na
**prywatne konto Google właściciela telefonu**, poza kontrolą jednostki.

- `android:allowBackup="false"` w `<application>`, z komentarzem w manifeście.
- Od Androida 12 to wyłącza kopię w chmurze i przez adb, ale **nie**
  przeniesienie kablem albo przez Wi-Fi na nowy telefon — dokładnie tego
  chcemy, bo chroni to tryb offline. Na Androidzie 11 i starszym wyłącza też
  przeniesienie; tego nie da się rozdzielić.
- Kopii wysłanych wcześniej aktualizacja nie usuwa — każdy może je usunąć
  w swoim koncie Google (drive.google.com → Kopie zapasowe).
- Do wpisania w polityce prywatności („Przed publikacją" w BACKLOG.md).

Do sprawdzenia przy następnym buildzie na emulatorze:
`adb shell bmgr backupnow pl.osp.osp_app` powinno odrzucić pakiet.

---

## Etap 3 — dane jednostki po odejściu z niej

### 3a. „Wyloguj i usuń dane" (zrobione w fix/047)
- Wylogowanie z jednostki ma trzy wyjścia: „Anuluj" / „Wyloguj i usuń dane"
  / „Wyloguj" (dane zostają, jak dotąd).
- Przed usunięciem pełna synchronizacja. Pole `syncStatus` rekordów nie jest
  prowadzone, więc „wszystko wysłane" da się stwierdzić tylko udaną
  synchronizacją. Gdy się nie uda — drugie ostrzeżenie, że niewysłane zmiany
  przepadną, z osobnym potwierdzeniem.
- `DatabaseService.wipeUnitData()` czyści ratowników, pojazdy, wyjazdy,
  przekazania, przejazdy, słownik zagrożeń, konfigurację jednostki i całą
  pamięć synchronizacji. Zostaje to, co należy do telefonu: sparowana drukarka
  i zamknięta karta „Pierwsze kroki". W `settings` zachowywana jest **lista
  kluczy telefonu**, a nie usuwana lista kluczy jednostki — nowy klucz
  z danymi jednostki zniknie sam, bez dopisywania go do kodu usuwania.
- Po usunięciu aplikacja wraca do ekranu powitalnego.

**Czego to nie załatwia.** To higiena i minimalizacja danych, nie
zabezpieczenie przed nadużyciem — zdeterminowana osoba mogła wcześniej zrobić
zrzut, PDF albo pobrać pliki z Dysku. Zdalnego kasowania nie ma i nie będzie.

### 3b. Wykrywanie odebranego dostępu (do zrobienia)
Gdy administrator odbierze komuś dostęp, telefon tej osoby nie dowiaduje się
o tym wprost: synchronizacja kończy się ogólnym błędem, a dane zostają.

1. Na początku `syncAll` sprawdzenie folderu jednostki. Dziś
   `isFolderAccessible` zwraca `false` przy każdym wyjątku, także przy braku
   sieci — przez to zmiana konta przy chwilowym braku zasięgu mówi „to konto
   nie ma dostępu". Trzeba rozróżnić: `DetailedApiRequestError` 404 / 403 bez
   powodu „limit zapytań" → **brak dostępu**; błędy przejściowe
   (`isTransientDriveError`) → zwykły błąd sieci.
2. Przy braku dostępu: nowy stan w `SyncState` (np. `accessRevoked`),
   zatrzymanie automatycznej synchronizacji, komunikat w Ustawieniach i na
   ekranie głównym: „Nie masz już dostępu do jednostki. Jej dane są nadal na
   tym telefonie." z przyciskami „Usuń dane z telefonu" (bez synchronizacji —
   nie ma dokąd wysłać) i „Zostaw".
3. Po ponownym udostępnieniu synchronizacja wraca sama.
4. **Nigdy nie kasujemy automatycznie** — tylko po kliknięciu.

**Dlaczego czeka.** Co dokładnie Dysk odpowiada po odebraniu dostępu (404 czy
403, z jakim powodem, czy od razu), da się sprawdzić tylko na prawdziwych
kontach. Krok 7 testu na dwóch telefonach: odebrać dostęp z telefonu A i zrobić
zrzut komunikatu na telefonie B.

---

## Etap 4 — szyfrowanie bazy na telefonie (odłożony)

`HiveAesCipher` z kluczem w Android Keystore (`flutter_secure_storage`). Po
Etapie 2 kopia w chmurze i przez adb jest już wyłączona, a telefony z Androidem
10 i nowszym mają obowiązkowe szyfrowanie plików aplikacji.

Ryzyka: migracja każdego boksu z kontrolą liczby rekordów i odpornością na
przerwanie; utrata klucza (nowy telefon, reset blokady ekranu) = utrata bazy,
w trybie offline bez ratunku; nowa zależność natywna przy starcie (fix/025
pokazał, jak łatwo o zawieszony release).

**Wrócić**, gdy aplikacja zacznie trzymać dane wrażliwsze (PESEL,
dokumentacja medyczna) albo wymusi to polityka Play. Wtedy przeniesienie na
nowy telefon trzeba wyłączyć osobnym `android:dataExtractionRules` — klucz
z Keystore nie przechodzi, więc przeniesiona baza byłaby nieczytelna.
