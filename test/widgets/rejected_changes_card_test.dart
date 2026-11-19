import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/screens/settings/unit_members_section.dart';

/// Ostrzeżenie dla administratora o zmianach na Dysku z pominięciem
/// aplikacji (fix/067).
void main() {
  testWidgets('kto, co i kiedy — oraz czy telefon przywrócił poprzednią '
      'wersję; „Rozumiem, wyczyść" czyści listę', (tester) async {
    var cleared = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RejectedChangesCard(
          changes: [
            RejectedChange(
              what: 'Lista administratorów',
              by: 'm@gmail.com',
              at: DateTime(2026, 11, 19, 21, 5),
              restored: true,
            ),
            RejectedChange(
              what: 'Wyjazd 0007/2026',
              by: 'm@gmail.com',
              at: DateTime(2026, 11, 19, 21, 4),
            ),
          ],
          onClear: () => cleared = true,
        ),
      ),
    ));

    expect(find.text('Zmiany z pominięciem aplikacji'), findsOneWidget);
    expect(
        find.text('• Lista administratorów — m@gmail.com, 19.11.2026 21:05 '
            '· przywrócone'),
        findsOneWidget);
    expect(find.text('• Wyjazd 0007/2026 — m@gmail.com, 19.11.2026 21:04'),
        findsOneWidget);
    expect(find.textContaining('odbierz tej osobie dostęp'), findsOneWidget);

    await tester.tap(find.text('Rozumiem, wyczyść'));
    expect(cleared, isTrue);
  });

  test('zapis i odczyt — uszkodzony wpis pomijany', () {
    final c = RejectedChange(
        what: 'Lista ratowników', by: 'm@gmail.com', at: DateTime(2026, 11, 19));
    final back = RejectedChange.fromJson(c.toJson())!;
    expect(back.what, c.what);
    expect(back.by, c.by);
    expect(back.at, c.at);
    expect(back.restored, isFalse);
    expect(RejectedChange.fromJson({'what': 1}), isNull);
    expect(RejectedChange.fromJson('tekst'), isNull);
  });
}
