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

## Do zrobienia — Kolejne branche

### Branch: feature/003-ux-polish
- [ ] **Liczba ratowników na ekranie głównym**: Dodać `(n)` przy "Ratownicy" tak jak "Wozy bojowe (2)"
- [ ] **Walidacja składu zastępu**: Ostrzeżenie gdy brak kierowcy lub dowódcy w składzie
- [ ] **Ikona fałszywego alarmu**: Zmienić `Icons.cancel` → `Icons.warning_amber` z opacity 0.5 (wygaszony znak ostrzegawczy)
- [ ] **Ustawienia — crash investigation**: Jeśli problem z zawieszaniem nadal występuje po poprawkach, zbadać dokładniej z logami
- [ ] **Udostępnij/Wyślij vs auto-zapis Drive**: Synchronizacja na Drive działa automatycznie (co 5 min). Dodać widoczny wskaźnik na ekranie raportu, że dane są zapisane na Drive
- [ ] **Potwierdzenie zapisu na Drive**: Po zapisaniu raportu, wyświetlić info "Raport zapisany lokalnie. Synchronizacja z Google Drive w toku..."

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
