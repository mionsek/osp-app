import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/core/theme/osp_theme.dart';

/// Strażnik palety kolorów.
///
/// `OspTheme` istniał od pierwszej gałęzi, a mimo to kod wpisywał wartości
/// z ręki: samo `0xFFB71C1C` pojawiło się **31 razy** w dwudziestu plikach,
/// więc zmiana odcienia wiodącego wymagała przejścia po całym projekcie
/// zamiast poprawienia jednej linijki. Sama podmiana tego nie zatrzyma —
/// następna gałąź dopisze kolejny literał dokładnie tak samo, jak dopisała
/// poprzednie.
///
/// Dlatego reguła jest tutaj, a nie w dobrych chęciach. Ta sama myśl, co
/// przy strażniku listy kluczy JSON w [sync_json_test.dart]: jeśli czegoś
/// nie pilnuje test, to się rozjedzie.
void main() {
  group('paleta kolorów', () {
    test('poza osp_theme.dart nie ma surowych wartości kolorów', () {
      final literal = RegExp(r'0x[Ff][Ff][0-9A-Fa-f]{6}');
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('osp_theme.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (literal.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Kolor zapisany wprost zamiast przez OspTheme. Dodaj stałą '
            'w lib/core/theme/osp_theme.dart i użyj jej tutaj:\n'
            '${offenders.join('\n')}',
      );
    });

    test('nazwy dzielące wartość wskazują na tę samą barwę', () {
      // Aliasy są celowe i opisane w OspTheme: czerwień wyjazdu jest czerwienią
      // błędu, zieleń ratowników zielenią potwierdzenia, pomarańcz pojazdów
      // pomarańczem wpisu do uzupełnienia. Test pilnuje, żeby rozdzielenie
      // ich kiedyś było **świadomą** zmianą, a nie skutkiem ubocznym.
      expect(OspTheme.danger, OspTheme.primaryRed);
      expect(OspTheme.success, OspTheme.sectionFirefighters);
      expect(OspTheme.info, OspTheme.sectionReportsList);
      expect(OspTheme.attention, OspTheme.sectionVehicles);
    });
  });
}
