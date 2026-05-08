# Instrukcje dla GitHub Copilot — OSP App

## Język
- Odpowiadaj zawsze po **polsku**, chyba że użytkownik wyraźnie poprosi po angielsku.

## Podejście do implementacji
- **Nigdy nie implementuj od razu.** Na początku każdego zadania przeanalizuj problem i zaprezentuj w czacie plan działania (co, gdzie i dlaczego zostanie zmienione), zanim zaczniesz pisać kod.
- Poczekaj na akceptację planu przez użytkownika, chyba że zadanie jest trywialne (np. literówka).

## Cykl pracy z BACKLOG.md
- Po przeprowadzeniu UAT przez użytkownika i przed mergem do `master`:
  1. Zaktualizuj sekcję "Zrobione" w [BACKLOG.md](../BACKLOG.md) — zaznacz ukończone zadania (`[x]`).
  2. Zaktualizuj strefę "Do zrobienia" — usuń wykonane pozycje lub dodaj nowe uwagi.
  3. Zadbaj o poprawne numerowanie branchy.

## Testowanie
- Do każdej zmiany w kodzie dodaj odpowiednie testy jednostkowe (lub zaktualizuj istniejące).
- Zawsze uruchom testy przed zgłoszeniem zadania jako ukończonego.
- Testy muszą przechodzić — nie akceptuj stanu „testy napisane, ale nie uruchomione".
- Po pomyślnym przejściu testów uruchom emulator i aplikację, aby sprawdzić działanie wizualne.
  - Emulator: AVD `OSP_PlayStore` (device ID: `emulator-5554`), Android 14 API 34.
  - Jeśli emulator jest już uruchomiony, nie uruchamiaj go ponownie — tylko wystartuj aplikację (`flutter run`).

## Zarządzanie branchami i Git
- Przed rozpoczęciem pracy nad nowym zadaniem **zawsze utwórz nowy branch z `master`**.
- Konwencja nazewnictwa: `feature/NNN-krotki-opis` (np. `feature/009-deduplikacja`), numer zgodny z BACKLOG.md.
- Po UAT przeprowadzonym przez użytkownika i jego akceptacji:
  1. Zaktualizuj BACKLOG.md (patrz sekcja wyżej).
  2. Wypchnij branch na zdalne repozytorium (`git push origin <branch>`).
  3. Zmerguj branch do `master` (`git merge --no-edit`) i wypchnij `master` (`git push origin master`).
  4. Nie wykonuj tych kroków bez wyraźnej akceptacji użytkownika po UAT.

## Kontekst projektu
- Aplikacja Flutter dla Ochotniczych Straży Pożarnych (OSP) w Polsce.
- Pakiet: `pl.osp.osp_app`, branch główny: `master`.
- Stack: Flutter ^3.11.4, Hive ^2.2.3, Riverpod ^2.6.1, go_router ^14.8.1.
- Monetyzacja: AdMob (`google_mobile_ads`), IAP (`in_app_purchase`), konto `ospkielno@gmail.com` bez reklam.
