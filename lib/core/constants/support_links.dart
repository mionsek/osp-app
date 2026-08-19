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

/// Komunikat pokazywany, gdy zbiórka nie ma jeszcze adresu.
const String kCoffeeNotReadyMessage =
    'Zbiórka nie jest jeszcze uruchomiona — dzięki za chęci!';
