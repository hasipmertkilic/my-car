import '../features/expertise/expertise_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/app_shell.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/records/screens/records_screen.dart';
import '../features/records/screens/activity_form_screen.dart';
import '../features/statistics/screens/statistics_screen.dart';
import '../features/vehicles/screens/garage_screen.dart';
import '../features/vehicles/screens/vehicle_form_screen.dart';
import '../features/vehicles/screens/vehicle_edit_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/screens/auth_screen.dart';
import '../features/auth/screens/session_screen.dart';
import '../features/inspection/screens/inspection_screen.dart';
import '../features/parking/screens/parking_screen.dart';
import '../features/parking/screens/parking_tab_screen.dart';
import '../features/parking/screens/parking_history_screen.dart';
import '../features/insurance/screens/policies_screen.dart';
import '../features/insurance/screens/policy_form_screen.dart';
import '../features/stations/stations_screen.dart';
import '../features/maintenance/maintenance_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionProvider);
  final router = GoRouter(
    initialLocation: '/summary',
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.uri.path;
      if (session.loading || session.error != null) {
        return path == '/session' ? null : '/session';
      }
      final isAuth = ['/login', '/register', '/forgot-password'].contains(path);
      if (session.user == null) return isAuth ? null : '/login';
      return isAuth || path == '/session' ? '/summary' : null;
    },
    routes: [
      GoRoute(
        path: '/vehicles/:id/expertise',
        builder: (context, state) =>
            ExpertiseScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicles/:id/maintenance',
        builder: (context, state) => MaintenanceScreen(
          vehicleId: state.pathParameters['id']!,
          latestOnly: state.uri.queryParameters['latest'] == '1',
        ),
      ),
      GoRoute(
        path: '/stations',
        builder: (context, state) => const StationsScreen(),
      ),
      GoRoute(
        path: '/vehicles/:id/policies',
        builder: (context, state) =>
            PoliciesScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicles/:id/policies/new',
        builder: (context, state) =>
            PolicyEditorScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicles/:id/policies/:policyId/edit',
        builder: (context, state) => PolicyEditorScreen(
          vehicleId: state.pathParameters['id']!,
          policyId: state.pathParameters['policyId']!,
        ),
      ),
      GoRoute(
        path: '/vehicles/:id/parking/history',
        builder: (context, state) =>
            ParkingHistoryScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicles/:id/parking',
        builder: (context, state) =>
            ParkingScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicles/:id/inspection',
        builder: (context, state) =>
            InspectionScreen(vehicleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vehicles/:id/fuel/new',
        builder: (context, state) => ActivityFormRoute(
          vehicleId: state.pathParameters['id']!,
          kind: 'fuel',
        ),
      ),
      GoRoute(
        path: '/vehicles/:id/expense/new',
        builder: (context, state) => ActivityFormRoute(
          vehicleId: state.pathParameters['id']!,
          kind: 'expense',
        ),
      ),
      GoRoute(
        path: '/vehicles/:id/records/:recordId/edit',
        builder: (context, state) => ActivityFormRoute(
          vehicleId: state.pathParameters['id']!,
          kind: '',
          recordId: state.pathParameters['recordId'],
        ),
      ),
      GoRoute(
        path: '/vehicles/new',
        builder: (context, state) => const VehicleFormScreen(),
      ),
      GoRoute(
        path: '/vehicles/:id/edit',
        builder: (context, state) =>
            VehicleEditScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/session',
        builder: (context, state) => const SessionScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const AuthScreen(key: ValueKey('login'), page: AuthPage.login),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const AuthScreen(
          key: ValueKey('register'),
          page: AuthPage.register,
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) =>
            const AuthScreen(key: ValueKey('reset'), page: AuthPage.reset),
      ),
      GoRoute(path: '/', redirect: (context, state) => '/summary'),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/vehicles/:id/expertise',
            builder: (context, state) =>
                ExpertiseScreen(vehicleId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/summary',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/records',
            builder: (context, state) => const RecordsScreen(),
          ),
          GoRoute(
            path: '/statistics',
            builder: (context, state) => const StatisticsScreen(),
          ),
          GoRoute(
            path: '/garage',
            builder: (context, state) => const GarageScreen(),
          ),
          GoRoute(
            path: '/parking',
            builder: (context, state) => const ParkingTabScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/summary'),
          child: const Text('Sayfa bulunamadı. Özete dön'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
