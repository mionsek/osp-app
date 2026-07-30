import 'package:flutter/material.dart';

import '../core/utils/firefighter_search.dart';
import '../models/firefighter.dart';

/// Wynik wyboru ratownika z panelu.
class FirefighterPickResult {
  /// Wybrany ratownik — `null`, gdy użytkownik wybrał „Nie wybrano".
  final Firefighter? firefighter;

  const FirefighterPickResult(this.firefighter);
}

/// Panel wyboru ratownika z wyszukiwarką.
///
/// Zwykła lista rozwijana przestaje się nadawać już przy kilkudziesięciu
/// osobach — trzeba przewijać zamiast wpisać trzy litery nazwiska.
///
/// Zwraca `null`, gdy panel zamknięto bez wyboru (np. gestem wstecz);
/// [FirefighterPickResult] z `firefighter == null` oznacza świadomy wybór
/// pozycji „Nie wybrano".
Future<FirefighterPickResult?> showFirefighterPicker({
  required BuildContext context,
  required List<Firefighter> firefighters,
  String title = 'Wybierz ratownika',
  bool allowEmpty = true,
}) {
  return showModalBottomSheet<FirefighterPickResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _FirefighterPickerSheet(
      firefighters: firefighters,
      title: title,
      allowEmpty: allowEmpty,
    ),
  );
}

class _FirefighterPickerSheet extends StatefulWidget {
  final List<Firefighter> firefighters;
  final String title;
  final bool allowEmpty;

  const _FirefighterPickerSheet({
    required this.firefighters,
    required this.title,
    required this.allowEmpty,
  });

  @override
  State<_FirefighterPickerSheet> createState() =>
      _FirefighterPickerSheetState();
}

class _FirefighterPickerSheetState extends State<_FirefighterPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = FirefighterSearch.filter(widget.firefighters, _query);

    return Padding(
      // Podnosimy panel nad klawiaturę, żeby lista nie chowała się pod nią.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Szukaj — nazwisko lub imię',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.allowEmpty)
                    ListTile(
                      leading: const Icon(Icons.person_off_outlined),
                      title: const Text('Nie wybrano'),
                      onTap: () => Navigator.pop(
                          context, const FirefighterPickResult(null)),
                    ),
                  if (results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nie znaleziono ratownika o takim nazwisku ani imieniu.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final ff in results)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2E7D32),
                          child: Text(
                            ff.lastName.isNotEmpty
                                ? ff.lastName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(ff.lastNameFirst),
                        subtitle: Text(ff.functionsLabel),
                        onTap: () =>
                            Navigator.pop(context, FirefighterPickResult(ff)),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
