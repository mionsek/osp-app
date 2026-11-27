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
    'usuwanie': read('docs/usuwanie-danych.html'),
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
    // Prywatny adres to e-mail z nazwiskiem — samo imię i nazwisko w podpisie
    // jest w porządku (fix/079).
    final privateEmail =
        RegExp(r'[\w.]*mionskowski[\w.]*@', caseSensitive: false);
    for (final MapEntry(:key, :value) in pages.entries) {
      expect(value, contains('mailto:$kContactEmail'), reason: key);
      expect(privateEmail.hasMatch(value), isFalse, reason: key);
    }
    final lib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync());
    expect(lib.where(privateEmail.hasMatch), isEmpty);
  });

  test('podpis autora wszędzie ten sam — imię i nazwisko (fix/079)', () {
    expect(kAuthorName, 'Dawid Mionskowski');
    expect(pages['index'], contains('autor: $kAuthorName'));
    expect(pages['pl'], contains('($kAuthorName)'));
    expect(pages['en'], contains('($kAuthorName)'));
    expect(pages['usuwanie'], contains('autor: $kAuthorName'));
    for (final MapEntry(:key, :value) in pages.entries) {
      // „mionsek" tylko w adresach (GitHub), nie jako podpis.
      expect(value.replaceAll('github.com/mionsek', '')
          .replaceAll('mionsek.github.io', ''),
          isNot(contains('mionsek')),
          reason: key);
    }
    for (final path in [
      'lib/screens/home/home_screen.dart',
      'lib/screens/info/info_screen.dart',
    ]) {
      final code = read(path);
      expect(code, contains('kAuthorName'), reason: path);
      expect(code, isNot(contains("'mionsek'")), reason: path);
    }
  });

  test('usuwanie konta i danych: link dla Play, kroki zgodne z aplikacją '
      '(chore/064)', () {
    final page = pages['usuwanie']!;
    expect(pages['index'], contains('href="usuwanie-danych.html"'));
    expect(pages['pl'], contains('href="usuwanie-danych.html"'));
    expect(pages['en'], contains('href="usuwanie-danych.html#english"'));
    expect(page, contains('id="english"'));
    // Play wymaga nazwy aplikacji i kroków na stronie.
    expect(page, contains('Raporty OSP'));
    expect(page, contains('myaccount.google.com/permissions'));
    expect(page, contains('OSP_App_'));

    // Strona prowadzi do przycisków, które muszą istnieć w aplikacji.
    final settings = read('lib/screens/settings/settings_screen.dart');
    expect(settings, contains("Text('Wyloguj')"));
    expect(settings, contains("Text('Wyloguj i usuń dane')"));
    final lib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join();
    for (final label in ['Członkowie jednostki', 'Odbierz dostęp']) {
      expect(page, contains(label), reason: label);
      expect(lib, contains("'$label'"), reason: label);
    }
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
    expect(find.text('Dawid Mionskowski'), findsOneWidget,
        reason: 'podpis autora jak na ekranie głównym i stronie (fix/079)');
  });
}
