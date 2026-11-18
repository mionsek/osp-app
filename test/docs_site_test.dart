import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osp_app/core/constants/constants.dart';
import 'package:osp_app/screens/info/info_screen.dart';

import 'helpers/test_app.dart';

/// Strona aplikacji i polityka prywatności (docs/061, GitHub Pages z `docs/`).
///
/// Polityka opisuje, co aplikacja robi z danymi — test pilnuje, żeby jej
/// twierdzenia nie rozjechały się z kodem, a sama strona nie wysyłała nic
/// do innych firm.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final pages = {
    'index': read('docs/index.html'),
    'pl': read('docs/polityka-prywatnosci.html'),
    'en': read('docs/privacy-policy.html'),
  };

  test('strona główna prowadzi do obu wersji polityki', () {
    expect(pages['index'], contains('href="polityka-prywatnosci.html"'));
    expect(pages['index'], contains('href="privacy-policy.html"'));
  });

  test('bez zewnętrznych skryptów, czcionek i arkuszy stylów', () {
    for (final MapEntry(:key, :value) in pages.entries) {
      expect(value, isNot(contains('<script')), reason: key);
      expect(RegExp(r'<link[^>]+href="https?://').hasMatch(value), isFalse,
          reason: key);
    }
    expect(read('docs/style.css'), isNot(contains('@import')));
    expect(File('docs/.nojekyll').existsSync(), isTrue,
        reason: 'GitHub Pages bez przetwarzania przez Jekylla');
  });

  test('wymagane przez Google: zasady danych z API i ograniczone użycie', () {
    for (final key in ['pl', 'en']) {
      expect(pages[key],
          contains('developers.google.com/terms/api-services-user-data-policy'),
          reason: key);
      expect(pages[key], contains('Limited Use'), reason: key);
      expect(pages[key], contains('myaccount.google.com/permissions'),
          reason: key);
    }
  });

  test('polityka zgadza się z kodem: folder, zakres Dysku, kopia zapasowa', () {
    final drive = read('lib/services/google_drive_service.dart');
    final auth = read('lib/services/google_auth_service.dart');
    final manifest = read('android/app/src/main/AndroidManifest.xml');

    expect(drive, contains("'OSP_App_\$unitName'"));
    expect(auth, contains('drive.DriveApi.driveScope'),
        reason: 'polityka tłumaczy pełny dostęp do Dysku');
    expect(manifest, contains('android:allowBackup="false"'),
        reason: 'polityka obiecuje brak kopii zapasowej Androida');
    for (final key in ['pl', 'en']) {
      expect(pages[key], contains('OSP_App_'), reason: key);
    }
  });

  test('kontakt: adres aplikacji, nie prywatny adres autora (chore/063)', () {
    expect(kContactEmail, 'raporty.osp@gmail.com');
    for (final MapEntry(:key, :value) in pages.entries) {
      expect(value, contains('mailto:$kContactEmail'), reason: key);
      expect(value, isNot(contains('mionskowski')), reason: key);
    }
    expect(read('lib/screens/info/info_screen.dart'),
        isNot(contains('mionskowski')));
  });

  test('adres polityki w aplikacji wskazuje plik z folderu docs', () {
    expect(kPrivacyPolicyUrl, startsWith('https://'));
    expect(kPrivacyPolicyUrl, endsWith('/polityka-prywatnosci.html'));
  });

  testWidgets('„O aplikacji" ma przycisk polityki prywatności',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(const InfoScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Polityka prywatności'));
    expect(find.text('Polityka prywatności'), findsOneWidget);
    expect(find.text('Jakie dane są w aplikacji i gdzie'), findsOneWidget);
  });
}
