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
import '../../screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final config = ref.read(unitConfigProvider);

  return GoRouter(
    initialLocation: config.onboardingCompleted ? '/home' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: '/vehicles/add',
        builder: (context, state) => const VehicleFormScreen(),
      ),
      GoRoute(
        path: '/vehicles/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VehicleFormScreen(vehicleId: id);
        },
      ),
      GoRoute(
        path: '/firefighters',
        builder: (context, state) => const FirefightersScreen(),
      ),
      GoRoute(
        path: '/firefighters/add',
        builder: (context, state) => const FirefighterFormScreen(),
      ),
      GoRoute(
        path: '/firefighters/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FirefighterFormScreen(firefighterId: id);
        },
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsListScreen(),
      ),
      GoRoute(
        path: '/reports/new',
        builder: (context, state) => const ReportWizardScreen(),
      ),
      GoRoute(
        path: '/reports/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReportWizardScreen(reportId: id);
        },
      ),
      GoRoute(
        path: '/reports/view/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReportDetailScreen(reportId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Nie znaleziono strony: ${state.uri}'),
      ),
    ),
  );
});
