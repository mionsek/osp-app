import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/constants.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  Future<void> _launchEmail(BuildContext context, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'mionskowski.dawid@gmail.com',
      queryParameters: {'subject': subject},
    );
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się otworzyć klienta email')),
        );
      }
    }
  }

  /// Adres zbiórki „na kawę" — wystarczy wpisać tu link i przycisk zaczyna
  /// działać, bez zmian w pozostałym kodzie.
  ///
  /// Link zewnętrzny, **nie** płatność w aplikacji — płatność wewnątrz
  /// aplikacji wchodzi w regulamin rozliczeń Google, czyli dokładnie tę
  /// komplikację, dla której uniknięcia zrezygnowaliśmy z reklam.
  static const String _coffeeUrl = kCoffeeUrl;

  Future<void> _launchCoffee(BuildContext context) async {
    // Dopóki adres nie jest ustawiony, przycisk jest widoczny, ale mówi wprost,
    // że zbiórki jeszcze nie ma — zamiast prowadzić donikąd albo udawać błąd.
    if (_coffeeUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(kCoffeeNotReadyMessage),
        ),
      );
      return;
    }
    if (!await launchUrl(
      Uri.parse(_coffeeUrl),
      mode: LaunchMode.externalApplication,
    )) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się otworzyć strony')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('O aplikacji'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(
                Icons.local_fire_department,
                size: 64,
                color: Color(0xFFB71C1C),
              ),
              const SizedBox(height: 12),
              Text(
                'Raporty OSP',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '...';
                  final build = snapshot.data?.buildNumber ?? '';
                  return Text(
                    'Wersja $version${build.isNotEmpty ? ' ($build)' : ''}',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // --- Do czego służy ---
              Text(
                'Do czego służy',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aplikacja dla Ochotniczych Straży Pożarnych — do wypełniania '
                'na miejscu zdarzenia dokumentów wymaganych po działaniach '
                'ratowniczych oraz do prowadzenia ewidencji przejazdów '
                'pojazdów:',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              const _DocumentItem(
                title: 'Potwierdzenie udziału w działaniu ratowniczym',
                description:
                    'Kto brał udział, jakimi pojazdami, w jakich godzinach '
                    'i przy jakim zagrożeniu.',
              ),
              const _DocumentItem(
                title: 'Potwierdzenie przekazania terenu, obiektu lub mienia',
                description:
                    'Komu przekazano nadzór nad miejscem zdarzenia po '
                    'zakończeniu działań (§ 21 ust. 2 pkt 2 rozporządzenia '
                    'MSWiA z 17 września 2021 r.).',
              ),
              const _DocumentItem(
                title: 'Miesięczna karta drogowa pojazdu',
                description:
                    'Ewidencja wszystkich przejazdów — alarmowych, '
                    'gospodarczych i tankowania — z licznikiem, trasą '
                    'i czasem pracy urządzeń specjalnych. Jedna karta '
                    'na pojazd i miesiąc, do wydruku dla gminy.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Dokumenty powstają w układzie zgodnym z papierowymi '
                'formularzami. Potwierdzenia drukują się po dwa identyczne '
                'egzemplarze A5 obok siebie na kartce A4, do rozcięcia wzdłuż '
                'przerywanej linii: jeden zostaje w jednostce, drugi trafia '
                'do drugiej strony. Karta drogowa drukuje się na A4 poziomo.\n\n'
                'Aplikacja prowadzi też ewidencję ratowników (z terminami '
                'badań lekarskich) i pojazdów, liczy roczne statystyki '
                'i potrafi synchronizować dane między telefonami całej '
                'jednostki przez Dysk Google.\n\n'
                'Jest darmowa, nie wyświetla reklam i nie zbiera danych — '
                'wszystko, co wpiszesz, zostaje na Twoim telefonie i na '
                'Dysku Google Twojej jednostki.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // --- Jak korzystać ---
              Text(
                'Jak korzystać',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const _HowToItem(
                icon: Icons.settings,
                title: 'Na początek: nazwa jednostki',
                description:
                    'W Ustawieniach wpisz pełną nazwę tak, jak ma widnieć '
                    'na dokumentach, np. „Ochotnicza Straż Pożarna '
                    'w Kielnie".',
              ),
              const _HowToItem(
                icon: Icons.fire_truck,
                title: 'Dodaj pojazdy',
                description:
                    'Wprowadź pojazdy swojej jednostki '
                    '(numer operacyjny, typ, rejestracja).',
              ),
              const _HowToItem(
                icon: Icons.people,
                title: 'Dodaj ratowników',
                description:
                    'Wprowadź strażaków z jednostki (imię, nazwisko, '
                    'funkcja). Możesz zapisać termin ważności badań '
                    'lekarskich — aplikacja ostrzeże przy układaniu '
                    'zastępu.',
              ),
              const _HowToItem(
                icon: Icons.add_circle,
                title: 'Dodaj wyjazd',
                description:
                    'Wypełnij datę, godziny, adres, rodzaj zagrożenia '
                    'i skład zastępu. Adres podpowie przycisk „Wstaw adres '
                    'z GPS" — zawsze możesz go poprawić.',
              ),
              const _HowToItem(
                icon: Icons.inventory_2,
                title: 'Dodaj przekazanie mienia',
                description:
                    'Gdy przekazujesz teren, obiekt lub mienie pod nadzór '
                    'właścicielowi, policji czy innej służbie. Możesz '
                    'powiązać je z wyjazdem — dane zdarzenia uzupełnią się '
                    'same.',
              ),
              const _HowToItem(
                icon: Icons.route,
                title: 'Ewidencja przejazdów',
                description:
                    'Wyjazd alarmowy dopisuje się tu sam po zapisaniu '
                    'raportu — zostaje uzupełnić stan licznika po powrocie. '
                    'Gospodarcze i tankowanie dodajesz ręcznie. Stan licznika '
                    'przed wyjazdem podstawia się z poprzedniego przejazdu, '
                    'więc wpisujesz tylko jedną liczbę. Kartę za dany miesiąc '
                    'wydrukujesz przyciskiem na górze ekranu.',
              ),
              const _HowToItem(
                icon: Icons.print,
                title: 'Drukuj lub wyślij',
                description:
                    'Z każdego dokumentu: „Drukuj" (drukarki widoczne '
                    'w systemie Android), druk przez Bluetooth albo '
                    '„Udostępnij / Wyślij" — PDF-em mailem lub '
                    'komunikatorem.',
              ),
              const _HowToItem(
                icon: Icons.bar_chart,
                title: 'Statystyki',
                description:
                    'Przeglądaj roczne statystyki wyjazdów — '
                    'udział strażaków, kategorie zagrożeń i łączny czas '
                    'działań. Zestawienie wydrukujesz jako PDF.',
              ),
              const _HowToItem(
                icon: Icons.cloud_sync,
                title: 'Synchronizacja',
                description:
                    'Zaloguj się kontem Google, aby synchronizować '
                    'dane między urządzeniami przez Google Drive.',
              ),
              const _HowToItem(
                icon: Icons.bluetooth,
                title: 'Druk na drukarce Bluetooth',
                description:
                    'Dokument możesz wysłać wprost na przenośną drukarkę '
                    'termiczną — przycisk znajdziesz przy każdym raporcie '
                    'i przekazaniu mienia. Drukarkę wybiera się raz.',
              ),
              const SizedBox(height: 16),

              // Uczciwe ostrzeżenie: obsługa druku Bluetooth powstała przez
              // odtworzenie zamkniętego protokołu jednego modelu drukarki,
              // więc nie ma podstaw zakładać, że zadziała z innymi.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange[800], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Druk przez Bluetooth przetestowano wyłącznie '
                        'z drukarką NETUM XL-P801. Inne modele najpewniej '
                        'nie zadziałają — każdy producent stosuje własny '
                        'sposób komunikacji. Przed zakupem innej drukarki '
                        'najlepiej dopytaj autora aplikacji.\n\n'
                        'Niezależnie od tego zawsze działa zwykły przycisk '
                        '„Drukuj" (drukarki widoczne w systemie Android) '
                        'oraz „Udostępnij / Wyślij".',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // --- Kontakt ---
              Text(
                'Kontakt',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _ContactButton(
                icon: Icons.bug_report,
                label: 'Zgłoś problem',
                subtitle: 'Wyślij email z opisem błędu',
                onTap: () =>
                    _launchEmail(context, 'Raporty OSP — Zgłoszenie problemu'),
              ),
              const SizedBox(height: 8),
              _ContactButton(
                icon: Icons.lightbulb_outline,
                label: 'Zaproponuj usprawnienie',
                subtitle: 'Podziel się pomysłem na nową funkcję',
                onTap: () => _launchEmail(
                  context,
                  'Raporty OSP — Propozycja usprawnienia',
                ),
              ),
              const SizedBox(height: 8),
              _ContactButton(
                icon: Icons.coffee,
                label: 'Postaw mi kawę',
                subtitle: 'Aplikacja jest darmowa i bez reklam',
                onTap: () => _launchCoffee(context),
              ),
              const SizedBox(height: 32),

              // --- Autor ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Autor',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'mionsek',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'github.com/mionsek/osp-app',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pozycja na liście dokumentów, które aplikacja wystawia.
class _DocumentItem extends StatelessWidget {
  final String title;
  final String description;

  const _DocumentItem({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.description, size: 18, color: Color(0xFFB71C1C)),
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
                  description,
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

class _HowToItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HowToItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: const Color(0xFFB71C1C)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28, color: const Color(0xFFB71C1C)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
