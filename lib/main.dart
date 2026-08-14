import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/theme/osp_theme.dart';
import 'core/router/app_router.dart';
import 'services/database_service.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.initialize();
  final db = DatabaseService();
  // Migracja słownika zagrożeń do aktualnych stałych list
  await db.ensureDefaultThreats();
  // Wyjazdy zapisane zanim istniała ewidencja przejazdów nie mają swojego
  // wiersza w karcie drogowej — dopisujemy je raz, przy starcie.
  await db.backfillTripsFromReports(
    stationAddress: db.getConfig().stationAddress,
  );
  // Naprawia dane, które rozjechały się zanim istniała synchronizacja
  // raport → ewidencja (np. godzina powrotu dopisana w starszej wersji).
  await db.reconcileTripsWithReports();
  await db.fillMissingRouteFrom(db.getConfig().stationAddress);
  await MobileAds.instance.initialize();
  runApp(const ProviderScope(child: OspApp()));
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
    // Try silent sign-in and restore sync state
    Future.microtask(() async {
      final authService = ref.read(googleAuthServiceProvider);
      await authService.trySilentSignIn();
      final syncNotifier = ref.read(syncStateProvider.notifier);
      await syncNotifier.initialize();
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
