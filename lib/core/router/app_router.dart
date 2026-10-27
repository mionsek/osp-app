import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/vehicles/vehicles_screen.dart';
import '../../screens/vehicles/vehicle_form_screen.dart';
import '../../screens/firefighters/firefighters_screen.dart';
import '../../screens/firefighters/firefighter_form_screen.dart';
import '../../screens/reports/report_wizard_screen.dart';
import '../../screens/reports/reports_list_screen.dart';
import '../../screens/reports/report_detail_screen.dart';
import '../../screens/handovers/handovers_list_screen.dart';
import '../../screens/handovers/handover_form_screen.dart';
import '../../screens/handovers/handover_detail_screen.dart';
import '../../screens/trips/trips_list_screen.dart';
import '../../screens/trips/trip_form_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/info/info_screen.dart';
import '../../screens/statistics/statistics_screen.dart';
import '../../widgets/navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final config = ref.read(unitConfigProvider);

  return GoRouter(
    initialLocation: config.onboardingCompleted ? homeLocation : '/onboarding',
    routes: appRoutes,
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Nie znaleziono strony: ${state.uri}'),
      ),
    ),
  );
});

/// Trasy jako drzewo pod ekranem głównym: lista jest rodzicem swojego
/// formularza i podglądu.
///
/// Wcześniej każda trasa leżała osobno, więc `context.go` (po zapisie
/// wyjazdu i przekazania, „Lista wyjazdów", usunięcie) zostawiał na stosie
/// jeden ekran — bez strzałki wstecz, a systemowe „wstecz" zamykało
/// aplikację (zgłoszenie z testu 1.7.6). Z drzewem `go('/handovers/view/x')`
/// buduje stos: ekran główny → lista przekazań → przekazanie.
final List<RouteBase> appRoutes = [
  GoRoute(
    path: '/onboarding',
    builder: (context, state) => const OnboardingScreen(),
  ),
  // Dawny adres ekranu głównego.
  GoRoute(path: '/home', redirect: (context, state) => homeLocation),
  GoRoute(
    path: homeLocation,
    builder: (context, state) => const HomeScreen(),
    routes: [
      GoRoute(
        path: 'vehicles',
        builder: (context, state) => const VehiclesScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const VehicleFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) =>
                VehicleFormScreen(vehicleId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: 'firefighters',
        builder: (context, state) => const FirefightersScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) => const FirefighterFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) => FirefighterFormScreen(
                firefighterId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: 'reports',
        builder: (context, state) => const ReportsListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const ReportWizardScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) =>
                ReportWizardScreen(reportId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'view/:id',
            builder: (context, state) =>
                ReportDetailScreen(reportId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: 'handovers',
        builder: (context, state) => const HandoversListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const HandoverFormScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) =>
                HandoverFormScreen(handoverId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'view/:id',
            builder: (context, state) =>
                HandoverDetailScreen(handoverId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: 'trips',
        builder: (context, state) => const TripsListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => TripFormScreen(
              initialVehicleId: state.uri.queryParameters['vehicleId'],
            ),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (context, state) =>
                TripFormScreen(tripId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: 'statistics',
        builder: (context, state) => const StatisticsScreen(),
      ),
      GoRoute(
        path: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: 'info',
        builder: (context, state) => const InfoScreen(),
      ),
    ],
  ),
];
