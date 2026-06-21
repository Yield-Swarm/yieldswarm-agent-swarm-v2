import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/customer/presentation/customer_home_screen.dart';
import '../../features/depin/presentation/depin_dashboard_screen.dart';
import '../../features/driver/presentation/driver_home_screen.dart';
import '../../features/driver/presentation/driver_onboarding_screen.dart';
import '../../shared/providers/session_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  return GoRouter(
    initialLocation: session.isOnboarded ? '/driver' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const DriverOnboardingScreen(),
      ),
      GoRoute(
        path: '/driver',
        builder: (_, __) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: '/customer',
        builder: (_, __) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/depin',
        builder: (_, __) => const DepinDashboardScreen(),
      ),
    ],
  );
});
