import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:osp_app/core/theme/osp_theme.dart';
import 'package:osp_app/models/models.dart';
import 'package:osp_app/models/sync_state.dart';
import 'package:osp_app/providers/providers.dart';
import 'package:osp_app/services/database_service.dart';
import 'package:osp_app/services/sync_service.dart';

/// Fundament testów widoków.
///
/// Warstwa widoków nie miała **ani jednego** testu — 124 testy sprawdzały
/// modele, logikę i bazę, a to, czy ostrzeżenie faktycznie się pokazuje
/// i czy przycisk faktycznie przenosi dalej, sprawdzało się wyłącznie ręcznie
/// na emulatorze po każdej zmianie.
///
/// Hive stoi na katalogu tymczasowym, dokładnie jak w `database_service_test`,
/// więc ekrany pracują na **prawdziwym** `DatabaseService` — testujemy to,
/// co pojedzie na telefon, a nie atrapę. Podmieniony jest tylko `SyncService`:
/// kreator wyjazdu pobiera raporty z Dysku przy starcie i bez podmiany każdy
/// test szedłby do sieci.
class FakeSyncService extends Mock implements SyncService {}

/// Otwiera Hive na katalogu tymczasowym i zwraca ten katalog, żeby dało się
/// go posprzątać w `tearDown` przez [disposeTestHive].
Future<Directory> setUpTestHive() async {
  final tempDir = await Directory.systemTemp.createTemp('osp_widget_test');
  Hive.init(tempDir.path);
  DatabaseService.registerAdapters();
  await DatabaseService.openBoxes();
  return tempDir;
}

Future<void> disposeTestHive(Directory tempDir) async {
  await Hive.deleteFromDisk();
  await Hive.close();
  if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
}

/// Atrapa synchronizacji, która nic nie robi i o niczym nie wie.
///
/// Kreator wyjazdu woła `pullReportsOnly()` w `initState`, więc bez tego
/// każdy test próbowałby sięgnąć na Dysk Google.
FakeSyncService fakeSync() {
  registerFallbackValue(<Report>[]);
  final sync = FakeSyncService();
  when(() => sync.pullReportsOnly()).thenAnswer((_) async => true);
  when(() => sync.state).thenReturn(const SyncState());
  // Każdy zapis przez provider zgłasza zmianę do wysłania.
  when(() => sync.notifyLocalChange()).thenReturn(null);
  when(() => sync.reportsAwaitingUpload(any())).thenReturn(const {});
  return sync;
}

/// Stan synchronizacji ustalony z góry — ekran dostaje dokładnie ten
/// przypadek, który badamy, bez logowania i bez Dysku.
class FixedSyncState extends SyncStateNotifier {
  FixedSyncState(super.syncService, SyncState initial) {
    state = initial;
  }
}

/// Opakowuje badany ekran w to samo, co daje mu aplikacja: motyw, polskie
/// tłumaczenia widżetów Material (używane przez wybór daty i godziny)
/// i `ProviderScope` z podmienioną synchronizacją.
Widget testApp(
  Widget child, {
  FakeSyncService? sync,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      syncServiceProvider.overrideWithValue(sync ?? fakeSync()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: OspTheme.lightTheme,
      localizationsDelegates: _localizations,
      supportedLocales: const [Locale('pl')],
      locale: const Locale('pl'),
      home: child,
    ),
  );
}

/// [testApp] z routerem — dla ekranów, które po zapisie przechodzą dalej
/// (`context.go`).
Widget testRouterApp(
  GoRouter router, {
  FakeSyncService? sync,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      syncServiceProvider.overrideWithValue(sync ?? fakeSync()),
      ...overrides,
    ],
    child: MaterialApp.router(
      theme: OspTheme.lightTheme,
      localizationsDelegates: _localizations,
      supportedLocales: const [Locale('pl')],
      locale: const Locale('pl'),
      routerConfig: router,
    ),
  );
}

const _localizations = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Skrót na wypełnienie bazy danymi, od których zaczyna się większość testów.
DatabaseService seededDb({
  List<Vehicle> vehicles = const [],
  List<Firefighter> firefighters = const [],
  UnitConfig? config,
}) {
  final db = DatabaseService();
  for (final v in vehicles) {
    db.vehiclesBox.put(v.id, v);
  }
  for (final f in firefighters) {
    db.firefightersBox.put(f.id, f);
  }
  if (config != null) db.configBox.put('main', config);
  return db;
}

/// Ratownik z domyślnymi uprawnieniami — testy nadpisują tylko to, co badają.
Firefighter firefighter(
  String id,
  String firstName,
  String lastName, {
  String rank = '',
  bool isDriver = false,
  bool isCommander = false,
  bool isKPP = false,
}) =>
    Firefighter(
      id: id,
      firstName: firstName,
      lastName: lastName,
      rank: rank,
      isDriver: isDriver,
      isCommander: isCommander,
      isKPP: isKPP,
    );
