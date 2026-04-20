import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  Future<void> _launchEmail(BuildContext context, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'mionsek@gmail.com',
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
                'Aplikacja OSP',
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
              Text('Do czego służy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 8),
              const Text(
                'Aplikacja do tworzenia raportów z wyjazdów ratowniczych '
                'dla Ochotniczych Straży Pożarnych. Pozwala szybko '
                'dokumentować interwencje, zarządzać składem osobowym '
                'i pojazdami, a następnie generować raporty w formacie PDF.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // --- Jak korzystać ---
              Text('Jak korzystać',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 12),
              const _HowToItem(
                icon: Icons.fire_truck,
                title: 'Dodaj pojazdy',
                description: 'Wprowadź wozy bojowe swojej jednostki '
                    '(numer operacyjny, typ, rejestracja).',
              ),
              const _HowToItem(
                icon: Icons.people,
                title: 'Dodaj ratowników',
                description: 'Wprowadź strażaków z jednostki '
                    '(imię, nazwisko, funkcja).',
              ),
              const _HowToItem(
                icon: Icons.add_circle,
                title: 'Twórz raporty',
                description: 'Dodaj wyjazd — wypełnij datę, godziny, adres, '
                    'rodzaj zagrożenia i skład zastępu.',
              ),
              const _HowToItem(
                icon: Icons.picture_as_pdf,
                title: 'Generuj PDF',
                description: 'Z każdego raportu wygeneruj dokument PDF — '
                    'wydrukuj, udostępnij lub zapisz.',
              ),
              const _HowToItem(
                icon: Icons.cloud_sync,
                title: 'Synchronizacja',
                description: 'Zaloguj się kontem Google, aby synchronizować '
                    'dane między urządzeniami przez Google Drive.',
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // --- Kontakt ---
              Text('Kontakt',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 12),
              _ContactButton(
                icon: Icons.bug_report,
                label: 'Zgłoś problem',
                subtitle: 'Wyślij email z opisem błędu',
                onTap: () => _launchEmail(
                    context, 'OSP App — Zgłoszenie problemu'),
              ),
              const SizedBox(height: 8),
              _ContactButton(
                icon: Icons.lightbulb_outline,
                label: 'Zaproponuj usprawnienie',
                subtitle: 'Podziel się pomysłem na nową funkcję',
                onTap: () => _launchEmail(
                    context, 'OSP App — Propozycja usprawnienia'),
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
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12),
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
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
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
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 13, height: 1.4),
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
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12)),
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
