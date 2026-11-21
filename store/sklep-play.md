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
| Zrzuty ekranu telefonu (2–8) | `store/zrzuty/*.png`, 1044 × 1856 (9:16), w kolejności nazw |
| Zrzuty z 7-calowego tabletu | `store/zrzuty-tablet-7/*.png`, 1044 × 1856 (9:16) |
| Zrzuty z 10-calowego tabletu | `store/zrzuty-tablet-10/*.png`, 1413 × 2512 (9:16) |

Zrzuty robi `integration_test/store_screenshots_test.dart` na zmyślonych
danych (instrukcja w pliku). Play wymaga proporcji dokładnie 16:9 albo 9:16
(20.11.2026: pola tabletów z gwiazdką), więc zrzuty są przycięte do 9:16
(po kilkanaście pikseli z boków). Ekrany: telefon `wm size 1080x1920`,
tablet 7" `1080x1920` przy `wm density 270` (ok. 640 dp szerokości),
tablet 10" `1440x2560` przy `wm density 240` (ok. 960 dp).

Deklaracja zasobów z AI: „Nie oznaczaj zasobów etykietami” — zrzuty to zwykłe
zrzuty aplikacji, ikona i grafika są wektorowe/HTML, nie z generatora obrazów.

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

### Dane logowania (dawniej „Dostęp do aplikacji”)
„Czy jakakolwiek część aplikacji jest objęta ograniczeniami?” → **Tak**
(logowanie Google jest na liście Google wprost). Recenzenci nie mogą
tworzyć kont ani używać własnych, więc dostają **osobne konto Gmail tylko
dla recenzji** (zrobione 19.11.2026; adres i hasło tylko w Play Console,
nie w repozytorium). Tego konta nie zapraszać do prawdziwej jednostki;
nie usuwać — Google sprawdza nim każdą aktualizację.

- Nazwa: `Test Google account (optional sync)`
- Nazwa użytkownika i hasło: konto recenzji
- Inne informacje (limit 500 znaków, ten tekst ma 428):

```
All features work without signing in: on the welcome screen tap "Utwórz nową jednostkę" (Create a new unit), then "Kontynuuj bez logowania (tryb offline)" (Continue without signing in) and enter any unit name and locality. Google sign-in is optional and only syncs data through the user's own Google Drive - to test it, use the account above. Google shows an "unverified app" notice: tap "Advanced", then "Go to Raporty OSP".
```

- Zaznaczone: „Dane logowania… zapewniają pełny dostęp do wszystkich funkcji”.

**Przed wysłaniem do recenzji:** ekran zgody OAuth w Google Cloud musi być
„W produkcji”. W trybie „Testowanie” logują się tylko konta z listy testerów,
a recenzent z innym kontem dostałby błąd (plan publikacji, pkt 5).
**Zrobione 19.11.2026** — „W wersji produkcyjnej”, bez weryfikacji: przy
logowaniu ekran „aplikacja niezweryfikowana” i limit 100 kont. Marka
(nazwa, strona, polityka, domena `mionsek.github.io`) wpisana, ale
niezweryfikowana, więc Google nie pokazuje jej użytkownikom; logo celowo
niewgrane (wymusza weryfikację). W „Dostępie do danych” zakresów nie
wpisujemy — Dysk aplikacja prosi w kodzie.

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

Paczka 1.9.19+42 ma uprawnienia: internet, stan sieci, Bluetooth (połączenie,
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

**Linki** (21.11.2026 — 15 testerów na liście, 14 zmian wysłanych do recenzji):
- zaproszenie do testu zamkniętego (wysłać testerom po zatwierdzeniu):
  `https://play.google.com/apps/testing/pl.osp.osp_app`
- strona aplikacji w Sklepie (dziś tylko dla testerów, po publikacji — dla
  wszystkich; wtedy podmienić „Jak zdobyć aplikację” na stronie):
  `https://play.google.com/store/apps/details?id=pl.osp.osp_app`
- test wewnętrzny (tylko konta z listy testu wewnętrznego):
  `https://play.google.com/apps/internaltest/4701360502948472937`

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
