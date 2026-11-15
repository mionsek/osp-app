import 'package:flutter/material.dart';

import '../models/firefighter.dart';
import 'firefighter_picker.dart';

/// „Kto wpisuje?" na wspólnym koncie jednostki, np. tablecie w samochodzie.
///
/// Tam konto nie mówi, kto dodał wpis — `createdBy` to zawsze adres
/// jednostki. Formularz podaje tu od razu podpowiedź z samego wpisu
/// (dowódcę zastępu, przekazującego), więc zwykle wystarczy ją zostawić.
/// To deklaracja, a nie logowanie: uprawnień nie daje.
class EnteredByField extends StatelessWidget {
  final List<Firefighter> firefighters;

  /// Wybrany ratownik albo podpowiedź, gdy nikt jeszcze nie wybierał.
  final String? selectedId;
  final ValueChanged<String> onChanged;

  /// Nikogo nie wybrano, a zapis tego wymaga.
  final bool missing;

  const EnteredByField({
    super.key,
    required this.firefighters,
    required this.selectedId,
    required this.onChanged,
    this.missing = false,
  });

  /// Ratownik o [id] z listy — do podpowiedzi i do wyświetlenia.
  static Firefighter? find(List<Firefighter> firefighters, String? id) =>
      id == null || id.isEmpty
          ? null
          : firefighters.where((f) => f.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final selected = find(firefighters, selectedId);
    return InkWell(
      onTap: () async {
        final result = await showFirefighterPicker(
          context: context,
          firefighters: firefighters,
          title: 'Kto wpisuje?',
          allowEmpty: false,
        );
        final picked = result?.firefighter;
        if (picked != null) onChanged(picked.id);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Kto wpisuje?',
          prefixIcon: const Icon(Icons.edit_note),
          helperText: 'Konto jednostki jest wspólne — wybierz siebie',
          errorText: missing ? 'Wybierz, kto wpisuje' : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.lastNameFirst ?? 'Wybierz z listy ratowników',
                overflow: TextOverflow.ellipsis,
                style: selected == null
                    ? TextStyle(color: Colors.grey[600])
                    : null,
              ),
            ),
            Icon(Icons.search, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
