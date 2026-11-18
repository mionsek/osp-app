/// Adres zbiórki „na kawę".
///
/// Jedno miejsce dla obu wejść — stopki ekranu głównego i sekcji „Kontakt"
/// w „O aplikacji". Pusty adres oznacza, że zbiórka nie jest uruchomiona:
/// przyciski wtedy zostają, ale mówią o tym wprost, zamiast prowadzić donikąd.
///
/// Link zewnętrzny, **nie** płatność w aplikacji — płatność wewnątrz aplikacji
/// wchodzi w regulamin rozliczeń Google, czyli dokładnie tę komplikację,
/// dla której uniknięcia zrezygnowaliśmy z reklam.
const String kCoffeeUrl = 'https://buycoffee.to/mionsek';

/// Publiczny adres kontaktowy aplikacji — „Zgłoś problem", „Zaproponuj
/// usprawnienie", strona i polityka prywatności, a także e-mail dewelopera
/// w sklepie Play. Osobne konto, żeby nie pokazywać prywatnego adresu
/// autora (decyzja Dawida z 18.11.2026).
const String kContactEmail = 'raporty.osp@gmail.com';

/// Strona aplikacji i polityka prywatności (GitHub Pages z folderu `docs/`).
///
/// Sklep Play wymaga linku do polityki prywatności także w samej aplikacji,
/// nie tylko w opisie w sklepie. Po przejściu na własną domenę wystarczy
/// zmienić adres tutaj.
const String kWebsiteUrl = 'https://mionsek.github.io/osp-app/';
const String kPrivacyPolicyUrl = '${kWebsiteUrl}polityka-prywatnosci.html';

/// Komunikat pokazywany, gdy zbiórka nie ma jeszcze adresu.
const String kCoffeeNotReadyMessage =
    'Zbiórka nie jest jeszcze uruchomiona — dzięki za chęci!';
