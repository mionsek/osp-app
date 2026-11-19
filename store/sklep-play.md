# Raporty OSP w Google Play — teksty i odpowiedzi do formularzy

Przygotowane w chore/064 (18.11.2026) dla konta osobistego w Play Console.
Kontakt publiczny wyłącznie `raporty.osp@gmail.com` (patrz chore/063).
Grafiki w `store/grafiki/`, zrzuty ekranu w `store/zrzuty/`.

## 1. Utworzenie aplikacji

| Pole | Wartość |
|---|---|
| Nazwa aplikacji | Raporty OSP |
| Język domyślny | polski – pl-PL |
| Aplikacja czy gra | Aplikacja |
| Bezpłatna czy płatna | Bezpłatna (**nie da się później zmienić na płatną**) |

## 2. Wpis w sklepie (Rozwój → Główna strona aplikacji w sklepie)

**Nazwa** (do 30 znaków): `Raporty OSP`

**Krótki opis** (do 80 znaków):

```
Dokumenty po akcji, karta drogowa i karta pracy sprzętu dla OSP — w telefonie
```

**Pełny opis** (do 4000 znaków):

```
Raporty OSP to darmowa aplikacja dla Ochotniczych Straży Pożarnych. Na miejscu zdarzenia wypełnisz w niej dokumenty wymagane po działaniach ratowniczych, a w jednostce poprowadzisz ewidencję przejazdów i pracy sprzętu.

CZTERY DOKUMENTY W UKŁADZIE PAPIEROWYCH FORMULARZY
• Potwierdzenie udziału w działaniu ratowniczym — kto brał udział, jakimi pojazdami, w jakich godzinach i przy jakim zagrożeniu.
• Potwierdzenie przekazania terenu, obiektu lub mienia — według wzoru z rozporządzenia MSWiA z 17 września 2021 r.
• Karta drogowa — miesięczna ewidencja przejazdów pojazdu z licznikiem, trasą i rozliczeniem paliwa. Wyjazd alarmowy dopisuje się do karty sam.
• Karta pracy sprzętu — pilarki, agregaty, motopompy: praca przy akcjach i ćwiczeniach oraz rozruchy kontrolne.

DRUK I WYSYŁKA
• Druk na zwykłej drukarce albo na przenośnej drukarce Bluetooth, np. w samochodzie.
• Wysyłka jako PDF, karty także jako plik Excel.

CAŁA JEDNOSTKA NA KILKU TELEFONACH
• Wspólne dane jednostki przez folder na Dysku Google — druhowie dołączają kodem zaproszenia.
• Administrator decyduje, kto ma dostęp i kto może poprawiać dane.
• Tablet w samochodzie może działać na wspólnym koncie jednostki.

A TAKŻE
• Ewidencja ratowników (z terminami badań lekarskich), pojazdów i sprzętu.
• Roczne statystyki wyjazdów.
• Działa bez logowania i bez internetu — wtedy dane są tylko na telefonie.

PRYWATNOŚĆ
Bez reklam i bez serwera. Dane zostają na telefonie, a jeśli jednostka korzysta z synchronizacji — także w folderze jednostki na jej Dysku Google. Autor aplikacji nie ma do nich dostępu.

Raporty OSP to niezależny, społeczny projekt. Nie jest oficjalną aplikacją Państwowej Straży Pożarnej ani Związku Ochotniczych Straży Pożarnych RP.

Pytania, błędy i pomysły: raporty.osp@gmail.com
```

**Grafiki:**

| Pole | Plik |
|---|---|
| Ikona aplikacji (512 × 512) | `store/grafiki/ikona-512.png` |
| Grafika (1024 × 500) | `store/grafiki/grafika-1024x500.png` (źródło: `store/grafika-1024x500.html`) |
| Zrzuty ekranu telefonu (2–8) | `store/zrzuty/*.png`, 1080 × 1920, w kolejności nazw |

Zrzuty robi `integration_test/store_screenshots_test.dart` na zmyślonych
danych (instrukcja w pliku). Zrzutów tabletu Play nie wymaga.

**Kategoria i kontakt** (Rozwój → Ustawienia sklepu):

| Pole | Wartość |
|---|---|
| Kategoria | Produktywność |
| E-mail | raporty.osp@gmail.com |
| Witryna | https://mionsek.github.io/osp-app/ |
| Telefon | puste |

## 3. Zawartość aplikacji (Zasady → Zawartość aplikacji)

### Polityka prywatności
`https://mionsek.github.io/osp-app/polityka-prywatnosci.html`

### Dostęp do aplikacji
„Wszystkie funkcje lub ich część są ograniczone” → dodaj instrukcję
(bez loginu i hasła, recenzenci czytają po angielsku):

```
No credentials are needed. On the welcome screen tap "Utwórz nową jednostkę" (Create a new unit), then "Kontynuuj bez logowania (tryb offline)" (Continue without signing in). Enter any unit name and locality - every feature works offline, with data kept only on the phone.
Signing in with Google is optional and only syncs the unit's data through a folder on the user's own Google Drive. Any Google account can be used; the app has no server and no accounts of its own.
```

**Przed wysłaniem do recenzji:** ekran zgody OAuth w Google Cloud musi być
„W produkcji”. W trybie „Testowanie” logują się tylko konta z listy testerów,
a recenzent z innym kontem dostałby błąd (plan publikacji, pkt 5).

### Reklamy
„Nie, moja aplikacja nie zawiera reklam”.

### Ocena treści (ankieta IARC)
- E-mail: raporty.osp@gmail.com
- Kategoria: „Wszystkie inne typy aplikacji”
- Przemoc, strach, seks, wulgaryzmy, używki, hazard: **nie**
- Interakcja i wymiana treści między użytkownikami: **nie**. Nie ma czatu,
  komentarzy ani publikowania. Synchronizacja dokumentów jednostki między
  telefonami jej członków to wspólna baza, a nie komunikacja.
- Udostępnianie bieżącej lokalizacji innym użytkownikom: **nie** (zapisuje się
  adres zdarzenia, a nie położenie użytkownika na żywo)
- Zakupy produktów cyfrowych: **nie**
- Nieograniczony dostęp do internetu (przeglądarka): **nie**

### Grupa docelowa
Tylko **18 lat i więcej**. Aplikacja nie jest atrakcyjna dla dzieci: „Nie”.

### Pozostałe deklaracje
| Deklaracja | Odpowiedź |
|---|---|
| Aplikacja z wiadomościami | Nie |
| Aplikacja rządowa | Nie (OSP to stowarzyszenie, aplikacja nie powstała na zlecenie urzędu) |
| Funkcje finansowe | Brak funkcji finansowych |
| Aplikacje związane ze zdrowiem | Brak funkcji związanych ze zdrowiem |
| Identyfikator wyświetlania reklam | Nie (brak uprawnienia `AD_ID` w paczce, sprawdzone w chore/064) |

Paczka 1.9.16+39 ma uprawnienia: internet, stan sieci, Bluetooth (połączenie,
wyszukiwanie bez lokalizacji), lokalizacja dokładna i przybliżona (tylko
przycisk „Wstaw adres z GPS”). Brak uprawnień do zdjęć i filmów, usług na
pierwszym planie, SMS-ów i rejestru połączeń — formularze do nich nie dotyczą.

### Bezpieczeństwo danych
Pomoc Google: „zbieranie” to każde wysłanie danych z telefonu. Wyjątek dla
Dysku Google obejmuje tylko kopię zapasową, której aplikacja nigdy nie
odczytuje. Raporty OSP czyta dane jednostki z Dysku przy synchronizacji, więc
deklarujemy je jako **zbierane**. Nie jako **udostępniane**: na Dysk jednostki
i innym członkom dane trafiają z woli użytkownika, a autor ich nie dostaje.

| Pytanie | Odpowiedź |
|---|---|
| Czy aplikacja zbiera lub udostępnia wymagane typy danych? | Tak |
| Czy wszystkie dane są szyfrowane podczas przesyłania? | Tak (HTTPS do interfejsów Google) |
| Metody tworzenia kont | OAuth (logowanie przez Google) |
| Link do usuwania konta | `https://mionsek.github.io/osp-app/usuwanie-danych.html` |
| Usuwanie części danych bez usuwania konta | Tak (usuwanie wpisów w aplikacji) |

Typy danych — przy każdym: **zbierane**, **nieudostępniane**, **nie
przetwarzane tymczasowo**, **opcjonalne** (tryb offline nie wysyła niczego),
cel **Funkcje aplikacji**:

| Kategoria → typ | Skąd w aplikacji |
|---|---|
| Dane osobowe → Imię i nazwisko | ratownicy, osoba przejmująca mienie |
| Dane osobowe → Adres e-mail | konto Google przy wpisie („Dodał”) i na liście członków; cel także **Zarządzanie kontem** |
| Dane osobowe → Adres | adres osoby przejmującej mienie |
| Dane osobowe → Numer telefonu | telefon osoby przejmującej mienie |
| Lokalizacja → Dokładna lokalizacja | adres zdarzenia z przycisku „Wstaw adres z GPS” |
| Zdrowie i aktywność fizyczna → Informacje o zdrowiu | termin ważności badań lekarskich ratownika |
| Aktywność w aplikacji → Inne treści wygenerowane przez użytkownika | wyjazdy, przekazania, przejazdy, uwagi |

Termin badań to dana z pogranicza. Lepiej ją zadeklarować, niż ryzykować
zarzut ukrycia, bo skutkiem jest tylko dodatkowa pozycja w etykiecie.

## 4. Test zamknięty

- Testowanie → Test zamknięty → ścieżka „Closed testing - Alpha” (domyślna).
- Kraje: Polska.
- Testerzy: lista e-mailowa (np. „Jednostka OSP”), co najmniej **12 adresów
  Gmail** — tych samych kont, które są w Sklepie Play na telefonach testerów.
  Adres opinii: raporty.osp@gmail.com.
- Warunek produkcji: 12 osób przez **14 dni z rzędu** po przyjęciu zaproszenia.

**Pierwsza wersja — podpisywanie (decyzja nieodwracalna):**
„Wybierz klucz podpisywania” → **„Użyj innego klucza” → „Eksportuj i prześlij
klucz z magazynu kluczy Java”**, a nie klucz wygenerowany przez Google
(plan publikacji, pkt 3). Play pokaże narzędzie PEPK i klucz szyfrowania —
pobrać oba, eksport zrobimy z naszego keystore'a.

**Paczka:** `build/app/outputs/bundle/release/app-release.aab`
(`flutter build appbundle --release`).

**Informacje o wersji** (pl-PL, do 500 znaków):

```
<pl-PL>
Pierwsza wersja w Sklepie Google Play. Jeśli masz aplikację z pliku APK, aktualizacja ze sklepu zachowa wszystkie dane.
</pl-PL>
```
