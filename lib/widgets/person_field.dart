import 'package:flutter/material.dart';

import '../models/firefighter.dart';

/// Pole na nazwisko z podpowiedziami z kartoteki ratowników — osoba
/// obsługująca sprzęt na karcie pracy.
///
/// Wybór z listy daje nazwisko i identyfikator ratownika; nazwisko wpisane
/// z ręki (ktoś spoza kartoteki) — samo nazwisko, bo druk i tak go wymaga.
class PersonField extends StatelessWidget {
  final String label;
  final String initialName;
  final List<Firefighter> people;
  final void Function(String name, String? id) onChanged;
  final String? helperText;
  final bool dense;

  const PersonField({
    super.key,
    required this.label,
    required this.initialName,
    required this.people,
    required this.onChanged,
    this.helperText,
    this.dense = false,
  });

  bool _matches(Firefighter f, String text) =>
      f.lastNameFirst == text || f.fullName == text;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Firefighter>(
      initialValue: TextEditingValue(text: initialName),
      displayStringForOption: (f) => f.lastNameFirst,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return people;
        return people.where((f) =>
            f.lastNameFirst.toLowerCase().contains(q) ||
            f.fullName.toLowerCase().contains(q));
      },
      onSelected: (f) => onChanged(f.lastNameFirst, f.id),
      // Przez `onChanged`, a nie nasłuch kontrolera — patrz pole kierowcy
      // w formularzu przejazdu: builder działa przy każdym przebudowaniu.
      fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
          TextFormField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        onChanged: (value) {
          final text = value.trim();
          final match = people.where((f) => _matches(f, text)).firstOrNull;
          onChanged(text, match?.id);
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: dense,
          prefixIcon: const Icon(Icons.person_outline),
          helperText: helperText,
          helperMaxLines: 2,
        ),
      ),
    );
  }
}
