# Plan: z Dysku Google na własną bazę danych

Analiza z 27.11.2026, wersja 1.9.19+42 (test zamknięty w Google Play,
12+ testerów). Zgłoszenie Dawida: testerzy pytają, czemu aplikacja chce
„wyświetlać, edytować, tworzyć i usuwać wszystkie pliki na Dysku Google”,
a niezweryfikowana aplikacja z tym uprawnieniem obsłuży najwyżej 100 kont.
Zakładamy 1–2 jednostki na start i migrację ich danych przyciskiem w aplikacji.

**Stan: plan, nic nie wdrożone. Czeka na decyzje z Etapu 0.**
Wcześniejsze plany: [PLAN_OCHRONA_DANYCH.md](PLAN_OCHRONA_DANYCH.md),
[PLAN_DYSK_WSPOLDZIELONY.md](PLAN_DYSK_WSPOLDZIELONY.md) (ten drugi
przestaje mieć sens, jeśli wybierzemy bazę).

## Po co — co się zgadza, a co poprawić

| Teza | Ocena |
|---|---|
| Najwyżej 100 osób | **Prawda.** Niezweryfikowana aplikacja z uprawnieniem zastrzeżonym (`drive`) ma limit 100 kont; nowe logowania ponad limit Google blokuje |
| Każdy widzi straszny komunikat | **Prawda.** Ekran zgody mówi o pełnym dostępie do Dysku, do tego „aplikacja niezweryfikowana”. Testerzy pytali — obcy nie zainstaluje |
| Weryfikacja wymaga własnej domeny | **W praktyce tak.** Google sprawdza własność domeny w Search Console, a `github.io` to domena współdzielona (Google zaleca wtedy własną). Domena to ok. 50–60 zł/rok — nie jest barierą |
| Weryfikacja może nie przejść | **Realne ryzyko**, ale z innego powodu niż domena: trzeba nagrać film, uzasadnić, czemu węższe `drive.file` nie wystarczy, a Google bywa nieustępliwy. Płatna ocena bezpieczeństwa (CASA, co roku) dotyczy aplikacji, które trzymają te dane na serwerze — nas dziś raczej nie |

Dodatkowe argumenty za bazą, których nie było w zgłoszeniu:
- **Uprawnienia pilnuje serwer.** Dziś każdy członek ma na Dysku prawo edycji
  całego folderu, a role z aplikacji tylko sprawdza telefon (fix/067 to łata).
  W bazie reguły bezpieczeństwa odrzucą zmianę cudzego wpisu u źródła.
- **„Kto dołączył”** (BACKLOG) wychodzi przy okazji — członek to rekord w bazie.
- **Bez Dysku nie trzeba pełnego dostępu do Dysku** — logowanie prosi tylko
  o imię i e-mail. To uprawnienie niewrażliwe: bez weryfikacji, bez limitu
  100 kont, bez ekranu „niezweryfikowana” (do pokazania nazwy i logo na
  ekranie logowania potrzebna jest tylko lekka weryfikacja marki).

## Co się zmienia na gorsze — uczciwie

- **RODO: autor przestaje być „bez dostępu”.** Dane jednostek będą w bazie
  prowadzonej przez autora aplikacji. Jednostka OSP zostaje administratorem
  danych, a autor staje się **podmiotem przetwarzającym** (art. 28): umowa
  powierzenia z każdą jednostką, środki bezpieczeństwa, rejestr czynności,
  obowiązek zgłaszania naruszeń. Przy 1–2 jednostkach to jeden wzór umowy
  i jedna strona dokumentacji, ale trzeba to zrobić przed migracją.
- **Polityka prywatności i deklaracje w Play do przepisania** — dane trafiają
  na serwer dewelopera; Play wymaga usuwania konta **w aplikacji** i przez stronę.
- **Utrzymanie serwera** — kopie zapasowe, kontrola dostępu do konsoli,
  alert kosztów. Przy darmowym planie i 1–2 jednostkach to niewiele, ale nie zero.
- **Termin badań lekarskich** to dana o zdrowiu (szczególna kategoria, art. 9).
  Na Dysku jednostki było to „u jednostki”; na serwerze autora warto ocenić,
  czy trzymać samą datę ważności (jak dziś), czy przenieść ją tylko na telefon.

## Wybór technologii

| | Firebase (Firestore + Auth) | Supabase (Postgres) | Własny serwer (VPS + Postgres / PocketBase) |
|---|---|---|---|
| Praca offline | **wbudowana** (kolejka zmian w SDK) | trzeba samemu (mamy już swoją z Hive) | trzeba samemu |
| Uprawnienia | reguły bezpieczeństwa w bazie | Row Level Security | własny kod API |
| Region danych | **Warszawa** (`europe-central2`) | Frankfurt | do wyboru (np. Polska) |
| Koszt na start | **0 zł** (1 GB, 50 tys. odczytów i 20 tys. zapisów dziennie) | 0 zł, ale **darmowy projekt usypia po tygodniu bez ruchu**; płatny ok. 25 USD/mies. | VPS ok. 20–40 zł/mies. |
| Logowanie | Google (tylko e-mail i imię), link na e-mail, hasło | to samo | samemu |
| Obsługa | prawie żadna | mała | **największa** (aktualizacje, kopie, bezpieczeństwo) |
| Minus | nadal Google — ale jako serwer, bez dostępu do czyjegokolwiek Dysku | firma z USA, hosting w UE | cała odpowiedzialność na autorze |

**Rekomendacja: Firebase w regionie Warszawa.** Najmniej pracy, praca offline
bez pisania jej od nowa, uprawnienia po stronie serwera, darmowo przy naszej
skali. Jeśli zasada brzmi „żadnego Google” — Supabase, a dla pełnej kontroli
własny serwer, w tej kolejności.

## Model danych (Firebase)

```
units/{unitId}                      nazwa, adres remizy, kod zaproszenia, właściciel
units/{unitId}/members/{uid}        e-mail, rola (owner/admin/member/shared),
                                    dołączył, ostatnio, wersja aplikacji
units/{unitId}/invites/{e-mail}     kto zaprosił, kiedy (lista dopuszczonych)
units/{unitId}/reports/{id}         ta sama treść co dziś (SyncJson) +
             /handovers/{id}        createdBy, updatedAt, deleted (znacznik)
             /trips/{id}
             /equipmentWork/{id}
units/{unitId}/firefighters/{id}    listy prowadzone przez administratora
             /vehicles/{id}
             /equipment/{id}
             /threatTypes/{id}
config/app                          minimalna wersja aplikacji (wymuszenie aktualizacji)
```

Reguły (sprawdzane przez serwer, z testami na emulatorze Firebase):
- czytać może tylko członek jednostki;
- dodać wpis może każdy członek, jako autor tylko on sam;
- zmienić lub usunąć — autor albo administrator (jak `canEditDocument` dziś);
- listy ratowników, pojazdów, sprzętu — tylko administrator;
- role nadaje administrator; właściciela nie da się usunąć;
- dołączenie: zalogowany e-mail jest na liście zaproszonych i podał kod —
  wtedy sam zakłada swój rekord członka.

## Aplikacja — co zostaje, co się zmienia

- **Zostaje:** lokalna baza Hive, wszystkie ekrany, druk, karty, scalanie po
  stemplach i znaczniki usunięcia. Wymieniamy tylko „transport”: obok
  dzisiejszego `SyncService` (Dysk) powstaje `ServerSyncService` (baza)
  z tym samym zadaniem — wysłać zmiany, pobrać zmiany.
- **Logowanie:** Firebase Auth — Google tylko z e-mailem i imieniem, do tego
  logowanie linkiem na e-mail (dla osób bez Gmaila). Konto wspólne na tablecie
  działa jak dziś (rola `shared`).
- **Zaproszenie:** administrator dopisuje e-mail (lista zaproszonych) i wysyła
  kod przez „Udostępnij kod”. Bez udostępniania folderu i bez maila od Google.
- **Nowe wymogi:** usuwanie konta w aplikacji (Play), wymuszenie aktualizacji
  (`config/app`), „kto dołączył” na liście członków.
- **Uprawnienie do Dysku tylko na czas migracji** — nowe instalacje nigdy go
  nie widzą; prosi o nie dopiero przycisk migracji (Google pozwala dołożyć
  uprawnienie później), a po migracji aplikacja go nie używa.

## Migracja — przycisk w aplikacji

Warunek wstępny: wszyscy członkowie jednostki mają nową wersję. Pomoże tu
„kto dołączył” wdrożone **jeszcze w wersji z Dyskiem** — administrator zobaczy,
kto ma jaką wersję (patrz Etap 1).

1. **Administrator (najlepiej założyciel)**: Ustawienia → „Przenieś jednostkę
   na nowy serwer”. Aplikacja najpierw robi pełną synchronizację z Dyskiem —
   telefon ma wtedy całą jednostkę.
2. **Kopiowanie:** aplikacja zakłada jednostkę w bazie (on = właściciel)
   i przenosi wszystko z zachowaniem identyfikatorów, stempli i autorów:
   wyjazdy, przekazania, przejazdy, pracę sprzętu, listy, rodzaje zagrożeń,
   dane jednostki. Administratorzy z `admins.json` → role; osoby z dostępem do
   folderu → lista zaproszonych (dołączą bez wpisywania kodu).
3. **Sprawdzenie:** liczba rekordów każdego rodzaju w bazie = na telefonie;
   ekran z podsumowaniem. Coś się nie zgadza → nic nie jest przełączane,
   jednostka w bazie do usunięcia, można spróbować ponownie.
4. **Przełączenie:** w folderze na Dysku pojawia się `migrated.json`
   (identyfikator nowej jednostki, kiedy, kto). Od tej chwili Dysk to archiwum.
5. **Pozostali członkowie:** ich aplikacja przy synchronizacji widzi
   `migrated.json` → „Jednostka przeniesiona na nowy serwer” → logowanie
   (dołączają automatycznie, bo są na liście) → **ich niewysłane zmiany idą do
   bazy** (scalanie po stemplach) → synchronizacja z Dyskiem wyłączona.
6. **Spóźnialscy na starej wersji:** gdyby ktoś po migracji zapisał coś na
   Dysku, nowa wersja przy pierwszym uruchomieniu po aktualizacji jeszcze raz
   przegląda folder i przenosi wpisy nowsze niż migracja. Do tego wymuszenie
   aktualizacji przez `config/app`.
7. **Po migracji:** folder na Dysku zostaje jako kopia przez np. 30 dni, potem
   administrator może go usunąć (przypomnienie w aplikacji).

## Etapy

0. **Decyzje** (pytania niżej) — bez nich nie zaczynamy.
1. **„Kto dołączył” w wersji z Dyskiem** (już w BACKLOG) — przyda się teraz
   i przy migracji. Razem z polityką prywatności i deklaracją w Play.
2. **Serwer:** projekt Firebase (region Warszawa — wyboru nie da się zmienić),
   reguły, testy reguł dla każdej roli na emulatorze, alert kosztów.
3. **Aplikacja z serwerem dla nowych jednostek** — logowanie, zaproszenia,
   synchronizacja, usuwanie konta. Test zamknięty na nowej jednostce.
4. **Migracja** — próba na kopii (zmyślone dane, kopia folderu), potem
   jednostka testowa, na końcu Kielno.
5. **Prawo i dokumenty** — przed migracją Kielna: polityka prywatności,
   wzór umowy powierzenia, strona usuwania danych, „Bezpieczeństwo danych”
   w Play, rejestr czynności (podmiot przetwarzający).
6. **Wersja bez Dysku** dla nowych instalacji; uprawnienie do Dysku tylko
   przy migracji. Potem wniosek o produkcję w Play bez obaw o limit 100.

Test zamknięty, który trwa teraz (wersja z Dyskiem), nie przeszkadza: przy
1–2 jednostkach limit 100 kont nie grozi, a 14 dni i tak trzeba odbyć.

## Pytania do Dawida (Etap 0)

1. **Firebase** (Google jako serwer, bez dostępu do niczyjego Dysku) — tak,
   czy zasada „żadnego Google”, i wtedy Supabase albo własny serwer?
2. **Logowanie:** Google (tylko e-mail i imię) + link na e-mail — wystarczy?
3. **Własna domena** (np. `raportyosp.pl`) — kupić? Przyda się do strony,
   adresu e-mail i weryfikacji marki (nazwa i logo na ekranie logowania).
4. **Rola podmiotu przetwarzającego** — akceptujesz umowę powierzenia
   z jednostkami (wzór przygotujemy)?
5. **Termin badań lekarskich** — zostaje w bazie czy tylko na telefonie?
6. **Kolejność:** najpierw „kto dołączył” na Dysku (Etap 1), czy od razu serwer?
