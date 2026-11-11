import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/core/theme/osp_icons.dart';
import 'package:osp_app/core/theme/osp_theme.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/screens/home/home_screen.dart';
import 'package:osp_app/screens/info/info_screen.dart';
import 'package:osp_app/screens/trips/trips_list_screen.dart';
import 'package:osp_app/services/database_service.dart';

import '../helpers/test_app.dart';

/// Ikony, kolory i nazwy wybrane przez Dawida 11.11.2026.
///
/// Zasada: „Dodaj …" i lista pod nim to jedna sekcja — ten sam kolor
/// (wyjazdy czerwone, przekazania mienia niebieskie) i ta sama forma nazwy
/// co reszta menu („Wyjazdy", jak „Pojazdy", a nie „Lista wyjazdów").
/// Cztery ikony spoza wbudowanych `Icons` są w czcionce `OspIcons`.
void main() {
  group('czcionka OspIcons', () {
    test('każda ikona ma swój znak w czcionce, a czcionka jest w paczce', () {
      final glyphs = _cmap(File('assets/fonts/OspIcons.otf').readAsBytesSync());
      for (final icon in const [
        OspIcons.alarmLight,
        OspIcons.humanMaleBoard,
        OspIcons.carWrench,
        OspIcons.circularSaw,
      ]) {
        expect(icon.fontFamily, 'OspIcons');
        expect(glyphs[icon.codePoint], isNot(anyOf(isNull, 0)),
            reason: 'brak znaku 0x${icon.codePoint.toRadixString(16)} — '
                'przebuduj tool/osp_icons/build_font.py');
      }

      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: OspIcons'));
      expect(pubspec, contains('asset: assets/fonts/OspIcons.otf'));
      expect(pubspec, contains('assets/fonts/MDI-LICENSE.txt'),
          reason: 'licencja Apache 2.0 jedzie razem z rysunkami');
    });
  });

  test('ikona aplikacji: logo A na czerwieni OSP z warstwą jednobarwną', () {
    const res = 'android/app/src/main/res';
    final adaptive =
        File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(adaptive, contains('@drawable/ic_launcher_monochrome'),
        reason: 'ikony tematyczne Androida 13+');
    expect(adaptive, isNot(contains('android:inset="16%"')),
        reason: 'pierwszy plan to już całe płótno 108 × 108');

    final red = (OspTheme.primaryRed.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    expect(File('$res/values/colors.xml').readAsStringSync(), contains('#$red'));

    for (final dpi in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(File('$res/drawable-$dpi/ic_launcher_monochrome.png').existsSync(),
          isTrue,
          reason: dpi);
    }
  });

  group('ekrany', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await setUpTestHive();
      final DatabaseService db = seededDb(
        vehicles: [Vehicle(id: 'v1', name: 'GBA 2.5/16', seats: 6)],
        firefighters: [firefighter('f1', 'Jan', 'Kowalski')],
        config: UnitConfig(
          unitFullName: 'Ochotnicza Straż Pożarna w Kielnie',
          onboardingCompleted: true,
        ),
      );
      // Po jednym przejeździe każdego celu, w bieżącym miesiącu.
      final now = DateTime.now();
      for (final (i, purpose) in TripPurposes.all.indexed) {
        final day = DateTime(now.year, now.month, i + 1);
        await db.addTrip(VehicleTrip(
          id: 'trip_$i',
          vehicleId: 'v1',
          date: day,
          departureTime: DateTime(day.year, day.month, day.day, 10),
          returnTime: DateTime(day.year, day.month, day.day, 11),
          odometerStart: 1000 + 10 * i,
          odometerEnd: 1010 + 10 * i,
          odometerStartManual: true,
          purpose: purpose,
          createdAt: day,
          updatedAt: day,
        ));
      }
    });

    tearDown(() => disposeTestHive(tempDir));

    void tallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> pumpHome(WidgetTester tester) async {
      tallScreen(tester);
      const state = SyncState(status: SyncStatus.idle);
      final auth = FakeAuthService();
      when(() => auth.displayName).thenReturn(null);
      when(() => auth.userEmail).thenReturn(null);
      final sync = fakeSync();
      when(() => sync.authService).thenReturn(auth);
      await tester.pumpWidget(testRouterApp(
        GoRouter(routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
        ]),
        sync: sync,
        overrides: [
          syncStateProvider.overrideWith(
              (ref) => FixedSyncState(ref.watch(syncServiceProvider), state)),
        ],
      ));
      await tester.pumpAndSettle();
    }

    /// Ikona kafelka menu z danym napisem.
    Icon menuIcon(WidgetTester tester, String label) {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_MenuButton'),
      );
      return tester.widget<Icon>(
          find.descendant(of: tile, matching: find.byType(Icon)).first);
    }

    testWidgets('menu: „Dodaj …" i lista pod nim mają ten sam kolor',
        (tester) async {
      await pumpHome(tester);

      expect(menuIcon(tester, 'Dodaj wyjazd').color, OspTheme.sectionReports);
      expect(menuIcon(tester, 'Wyjazdy (0)').color, OspTheme.sectionReports);

      expect(menuIcon(tester, 'Dodaj przekazanie mienia').color,
          OspTheme.sectionHandovers);
      expect(menuIcon(tester, 'Przekazania mienia (0)').color,
          OspTheme.sectionHandovers);

      // Niebieski przekazań nie powtarza się w innej sekcji menu.
      for (final other in [
        OspTheme.sectionReports,
        OspTheme.sectionTrips,
        OspTheme.sectionVehicles,
        OspTheme.sectionFirefighters,
        OspTheme.sectionStatistics,
        OspTheme.coffee,
      ]) {
        expect(OspTheme.sectionHandovers, isNot(other));
      }
    });

    testWidgets('menu: „Wyjazdy" jak „Pojazdy" i „Ratownicy", bez „Lista"',
        (tester) async {
      await pumpHome(tester);

      expect(find.text('Wyjazdy (0)'), findsOneWidget);
      expect(find.text('Przekazania mienia (0)'), findsOneWidget);
      expect(find.textContaining('Lista'), findsNothing);
    });

    testWidgets('menu i „O aplikacji": te same ikony ewidencji i sprzętu',
        (tester) async {
      await pumpHome(tester);
      expect(menuIcon(tester, 'Ewidencja przejazdów').icon, Icons.edit_road);
      expect(menuIcon(tester, 'Sprzęt (0)').icon, OspIcons.circularSaw);

      // Nowy ProviderScope z innymi podmianami — najpierw zdjąć stary.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(testApp(const InfoScreen()));
      await tester.pumpAndSettle();
      Finder icon(IconData i) => find.byIcon(i, skipOffstage: false);
      expect(icon(Icons.edit_road), findsOneWidget);
      expect(icon(OspIcons.circularSaw), findsOneWidget);
      expect(icon(Icons.route), findsNothing);
      expect(icon(Icons.handyman), findsNothing);
    });

    testWidgets('ewidencja: każdy cel przejazdu ma swoją ikonę',
        (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(testApp(const TripsListScreen()));
      await tester.pumpAndSettle();

      Finder avatar(IconData icon) => find.descendant(
          of: find.byType(CircleAvatar), matching: find.byIcon(icon));

      expect(avatar(OspIcons.alarmLight), findsOneWidget,
          reason: 'wyjazd alarmowy — kogut');
      expect(avatar(Icons.fire_truck), findsOneWidget,
          reason: 'wyjazd gospodarczy — wóz strażacki');
      expect(avatar(Icons.local_gas_station), findsOneWidget,
          reason: 'tankowanie — bez zmian');
      expect(avatar(OspIcons.humanMaleBoard), findsOneWidget,
          reason: 'ćwiczenia — osoba przy tablicy');
      expect(avatar(OspIcons.carWrench), findsOneWidget,
          reason: 'przegląd / naprawa — samochód z kluczem');
      expect(avatar(Icons.directions_car), findsOneWidget,
          reason: 'inny — bez zmian');
    });
  });
}

/// Kod znaku → numer rysunku z tabeli `cmap` czcionki (podtabela formatu 4).
Map<int, int> _cmap(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  var cmap = -1;
  for (var i = 0; i < d.getUint16(4); i++) {
    final record = 12 + 16 * i;
    if (String.fromCharCodes(bytes.sublist(record, record + 4)) == 'cmap') {
      cmap = d.getUint32(record + 8);
    }
  }
  expect(cmap, isNot(-1), reason: 'czcionka bez tabeli cmap');

  final glyphs = <int, int>{};
  for (var t = 0; t < d.getUint16(cmap + 2); t++) {
    final sub = cmap + d.getUint32(cmap + 4 + 8 * t + 4);
    if (d.getUint16(sub) != 4) continue;
    final segX2 = d.getUint16(sub + 6);
    final ends = sub + 14;
    final starts = ends + segX2 + 2;
    final deltas = starts + segX2;
    final ranges = deltas + segX2;
    for (var s = 0; s < segX2 ~/ 2; s++) {
      final start = d.getUint16(starts + 2 * s);
      final end = d.getUint16(ends + 2 * s);
      final delta = d.getInt16(deltas + 2 * s);
      final range = d.getUint16(ranges + 2 * s);
      if (start == 0xFFFF) continue;
      for (var c = start; c <= end; c++) {
        if (range == 0) {
          glyphs[c] = (c + delta) & 0xFFFF;
        } else {
          final g = d.getUint16(ranges + 2 * s + range + 2 * (c - start));
          glyphs[c] = g == 0 ? 0 : (g + delta) & 0xFFFF;
        }
      }
    }
  }
  return glyphs;
}
