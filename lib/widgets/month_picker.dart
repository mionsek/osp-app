import 'package:flutter/material.dart';

import '../core/utils/polish_text.dart';

/// Rok i miesiąc karty — drogowej albo pracy sprzętu.
typedef CardMonth = ({int year, int month});

/// Wybór miesiąca karty z listy miesięcy, w których coś jest wpisane.
///
/// Bieżący miesiąc jest na liście zawsze, nawet gdy jeszcze pusty — bez
/// tego nie dałoby się wrócić do „teraz" po zajrzeniu do archiwum.
Future<CardMonth?> pickCardMonth(
  BuildContext context, {
  required List<CardMonth> months,
  required CardMonth selected,
}) {
  final now = DateTime.now();
  final options = <CardMonth>[
    if (!months.any((m) => m.year == now.year && m.month == now.month))
      (year: now.year, month: now.month),
    ...months,
  ];

  return showModalBottomSheet<CardMonth>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Wybierz miesiąc',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          for (final m in options)
            ListTile(
              title: Text(PolishText.monthLabel(m.month, m.year)),
              selected: m == selected,
              onTap: () => Navigator.pop(ctx, m),
            ),
        ],
      ),
    ),
  );
}
