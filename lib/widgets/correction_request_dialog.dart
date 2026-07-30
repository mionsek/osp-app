import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/firefighter.dart';

/// Typowe powody zgłoszenia — gotowa lista zamiast pustego pola, bo
/// szybciej się klika i administrator dostaje jednoznaczny komunikat.
const _reasons = <String>[
  'Błąd w imieniu lub nazwisku',
  'Nieaktualny termin badań lekarskich',
  'Błędne uprawnienia (kierowca / dowódca / KPP)',
  'Osoba nie należy już do jednostki',
  'Inne',
];

/// Pozwala zwykłemu użytkownikowi zgłosić administratorowi poprawkę
/// w danych ratownika.
///
/// Zgłoszenie wychodzi zwykłą wiadomością (e-mail lub dowolny komunikator
/// z listy udostępniania), a nie przez Dysk — administrator dostaje je
/// tam, gdzie i tak zagląda, i nie trzeba budować obiegu zatwierdzania.
Future<void> showCorrectionRequestDialog({
  required BuildContext context,
  required Firefighter firefighter,
  required String? adminEmail,
  required String? reporterEmail,
  required String unitName,
}) async {
  var reason = _reasons.first;
  final noteController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Zgłoś poprawkę'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dotyczy: ${firefighter.lastNameFirst}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Czego dotyczy'),
                isExpanded: true,
                items: _reasons
                    .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => reason = v ?? _reasons.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Jak powinno być?',
                  hintText: 'np. prawidłowe nazwisko to Wiśniewska',
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                maxLength: 300,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Wyślij'),
          ),
        ],
      ),
    ),
  );

  final note = noteController.text.trim();
  noteController.dispose();
  if (confirmed != true || !context.mounted) return;

  final body = StringBuffer()
    ..writeln('Zgłoszenie poprawki danych ratownika')
    ..writeln()
    ..writeln('Jednostka: $unitName')
    ..writeln('Dotyczy: ${firefighter.lastNameFirst}')
    ..writeln('Czego dotyczy: $reason');
  if (note.isNotEmpty) {
    body.writeln('Jak powinno być: $note');
  }
  if (reporterEmail != null && reporterEmail.isNotEmpty) {
    body
      ..writeln()
      ..writeln('Zgłasza: $reporterEmail');
  }
  body
    ..writeln()
    ..writeln('Wiadomość wysłana z aplikacji Raporty OSP.');

  final uri = Uri(
    scheme: 'mailto',
    path: adminEmail ?? '',
    queryParameters: {
      'subject': 'Poprawka danych: ${firefighter.lastNameFirst}',
      'body': body.toString(),
    },
  );

  final messenger = ScaffoldMessenger.of(context);
  try {
    if (!await launchUrl(uri)) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Nie udało się otworzyć programu pocztowego.'),
      ));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('Nie udało się wysłać zgłoszenia: $e'),
    ));
  }
}
