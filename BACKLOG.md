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

## Do zrobienia — Kolejne branche

### Branch: feature/004-multi-account
- [ ] **Architektura kont**: Naczelnik tworzy jednostkę z konta jednostki (np. ospkielno@gmail.com), ale potem chce logować się prywatnym kontem (np. jan.kowalski@gmail.com). Rozwiązania:
  - Opcja A: Pozwolić na zmianę konta w ustawieniach bez utraty danych (migrate ownership)
  - Opcja B: Folder na Drive jest dzielony — każdy członek loguje się swoim kontem, host udostępnia folder
  - Opcja C: Konto jednostki jest tylko do założenia — potem logowanie prywatnym kontem i dołączenie kodem
  - **Rekomendacja**: Opcja B/C — host tworzy jednostkę (dowolnym kontem), a członkowie dołączają swoimi kontami. Folder Drive jest współdzielony.

### Branch: feature/005-eremiza
- [ ] **e-Remiza integration**: Ręczne wpisywanie z przyciskami kopiowania do schowka

### Branch: feature/006-monetization
- [ ] **AdMob reklamy**: Banner na ekranie głównym, interstitial przy generowaniu PDF
- [ ] **In-app purchases**: Premium (10-20 PLN) — brak reklam, dodatkowe funkcje

### Branch: feature/007-printing
- [ ] **Bluetooth printing**: Drukowanie na drukarce Bluetooth bez podłączania USB

### Branch: feature/008-info-and-feedback
- [ ] **Informacje o aplikacji**: Ekran "O aplikacji" — do czego służy, instrukcja użytkowania, wersja, autor
- [ ] **Kontakt z developerem**: Formularz/przycisk zgłoszenia buga lub propozycji usprawnienia (email lub Google Form)

### Pomysły do rozważenia
- [ ] **Deduplikacja numerów wyjazdów przy sync**: Automatyczna korekta zdublowanych numerów (np. raz dziennie przy synchronizacji z Google Drive). Obecnie `getNextReportNumber` szuka najwyższego istniejącego numeru, ale przy usunięciu i re-sync mogą powstać duplikaty.
