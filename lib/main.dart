import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/osp_theme.dart';
import 'core/router/app_router.dart';
import 'services/database_service.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.initialize();
  runApp(const ProviderScope(child: OspApp()));
}

/// Migracje danych, których wynik nie jest potrzebny do narysowania
/// pierwszego ekranu.
///
/// Świadomie **po** `runApp`, a nie przed: to trzy pełne przebiegi po
/// raportach i przejazdach z zapisem do Hive, wykonywane przy każdym
/// uruchomieniu. Wykonane przed `runApp` opóźniały pierwszą klatkę tym
/// bardziej, im więcej jednostka ma danych — czyli najmocniej u tych,
/// którzy używają aplikacji najdłużej.
///
/// Ekran główny czyta dane przez providery, więc gdy migracja coś zmieni,
/// odświeżamy je i widok sam się przerysuje.
Future<void> _runMigrations(WidgetRef ref) async {
  final db = ref.read(databaseServiceProvider);

  // Słownik zagrożeń do aktualnych stałych list.
  await db.ensureDefaultThreats();
  ref.read(threatsProvider.notifier).refresh();

  final stationAddress = db.getConfig().stationAddress;

  // Wyjazdy zapisane, zanim istniała ewidencja przejazdów, nie mają swojego
  // wiersza w karcie drogowej.
  final added = await db.backfillTripsFromReports(
    stationAddress: stationAddress,
  );
  // Dane rozjechane, zanim istniała synchronizacja raport → ewidencja
  // (np. godzina powrotu dopisana w starszej wersji aplikacji).
  final reconciled = await db.reconcileTripsWithReports();
  // „Skąd" w przejazdach sprzed wpisania adresu remizy.
  final filled = await db.fillMissingRouteFrom(stationAddress);

  if (added + reconciled + filled > 0) {
    ref.read(vehicleTripsProvider.notifier).refresh();
  }
}

class OspApp extends ConsumerStatefulWidget {
  const OspApp({super.key});

  @override
  ConsumerState<OspApp> createState() => _OspAppState();
}

class _OspAppState extends ConsumerState<OspApp> {
  @override
  void initState() {
    super.initState();
    // Migracje i logowanie po pierwszej klatce — ekran główny nie potrzebuje
    // ich wyniku, żeby się narysować.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _runMigrations(ref);

      if (!mounted) return;
      final authService = ref.read(googleAuthServiceProvider);
      await authService.trySilentSignIn();
      if (!mounted) return;
      await ref.read(syncStateProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Raporty OSP',
      theme: OspTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pl')],
      locale: const Locale('pl'),
    );
  }
}
