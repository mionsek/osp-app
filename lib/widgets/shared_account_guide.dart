import 'package:flutter/material.dart';

import '../core/theme/osp_theme.dart';

/// Samouczek: tablet w samochodzie na wspólnym koncie jednostki
/// ([SyncState.isSharedDevice]).
///
/// Jeden tekst dla wszystkich miejsc, z których się go otwiera — Członkowie
/// jednostki, wspólne konto w Ustawieniach i „O aplikacji" — żeby kroki nie
/// rozjechały się między ekranami.
Future<void> showSharedAccountGuide(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tablet w samochodzie'),
        content: const SingleChildScrollView(child: SharedAccountGuide()),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Rozumiem'),
          ),
        ],
      ),
    );

class SharedAccountGuide extends StatelessWidget {
  const SharedAccountGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Na wspólnym urządzeniu, np. tablecie w wozie, loguje się konto '
          'jednostki (np. ospkielno@gmail.com). Każdy doda z niego wyjazd, '
          'a aplikacja zapyta, kto wpisuje.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 16),
        // Bez „Przełącz na swoje konto" (Dawid, 27.11.2026): tablet loguje
        // się kontem jednostki, telefon swoim — kto założył jednostkę, nie
        // ma znaczenia.
        const _Step(
          number: 1,
          title: 'Zaproś konto jednostki',
          text: 'Administrator na swoim telefonie: Ustawienia → Członkowie '
              'jednostki → Zaproś do jednostki. Wpisz adres konta jednostki '
              'i zaznacz „Wspólne urządzenie jednostki". Konto, które już '
              'jest w jednostce, oznaczysz w menu ⋮ przy nim.',
        ),
        const _Step(
          number: 2,
          title: 'Zaloguj tablet',
          text: 'Na tablecie zainstaluj aplikację, wybierz „Dołącz do '
              'jednostki", zaloguj się kontem jednostki i wpisz kod '
              'zaproszenia z Ustawień.',
        ),
        const _Step(
          number: 3,
          title: 'Wpisuj z tabletu',
          text: 'Przy zapisie wyjazdu i przekazania mienia wybierz siebie '
              'w polu „Kto wpisuje?". W szczegółach dokumentu widać potem, '
              'kto wpisał, a pod spodem konto jednostki.',
        ),
        const SizedBox(height: 4),
        Text(
          'Dobrze wiedzieć',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const _Bullet(
          'Tablet działa jak konto zwykłego członka: dodaje wyjazdy, '
          'przejazdy i przekazania mienia i poprawia to, co dodano z konta '
          'jednostki. Nie zmieni ustawień, list ratowników, pojazdów ani '
          'sprzętu i nikomu nie nada uprawnień.',
        ),
        const _Bullet(
          'Wspólne urządzenie wyłączy tylko administrator na własnym koncie.',
        ),
        const _Bullet(
          'Jednostkę założono na koncie jednostki? Je też można oznaczyć, ale '
          'najpierw ktoś musi być administratorem na swoim koncie — wspólne '
          'urządzenie jednostką nie zarządza.',
        ),
        const _Bullet(
          'Zgubiony tablet: zmień hasło do konta jednostki i wyloguj tablet '
          'na myaccount.google.com (Bezpieczeństwo → Twoje urządzenia). '
          'Dane jednostki zostają w jednostce.',
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String text;

  const _Step({required this.number, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: OspTheme.primaryRed,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[700], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
