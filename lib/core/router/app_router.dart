import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/presentation/no_access_screen.dart';
import '../../features/onboarding/presentation/setup_business_screen.dart';
import '../../features/session/session.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/splash_screen.dart';
import '../../features/staff/presentation/staff_screen.dart';
import 'app_routes.dart';

const _adminOnly = [AppRoutes.labels, AppRoutes.staff];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionStateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref.read(sessionStateProvider), state),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: AppRoutes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(path: AppRoutes.setup, builder: (_, _) => const SetupBusinessScreen()),
      GoRoute(path: AppRoutes.noAccess, builder: (_, _) => const NoAccessScreen()),
      GoRoute(
        path: AppRoutes.qrLanding,
        redirect: (_, state) => AppRoutes.cylinder(state.pathParameters['serial']!),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
          GoRoute(path: AppRoutes.staff, builder: (_, _) => const StaffScreen()),
          GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

/// Sends people where their session allows, and remembers the page they asked
/// for (`?from=`) so a scanned QR link survives the sign-in detour.
String? _redirect(SessionState session, GoRouterState state) {
  final loc = state.matchedLocation;
  final wanted = state.uri.queryParameters['from'];
  String withFrom(String path) {
    final from = AppRoutes.public.contains(loc) || loc == AppRoutes.setup ? wanted : state.uri.toString();
    return from == null || from == AppRoutes.home
        ? path
        : Uri(path: path, queryParameters: {'from': from}).toString();
  }

  switch (session) {
    case SessionLoading():
      return loc == AppRoutes.splash ? null : withFrom(AppRoutes.splash);
    case SignedOut():
      return loc == AppRoutes.signIn || loc == AppRoutes.signUp ? null : withFrom(AppRoutes.signIn);
    case NeedsBusiness():
      return loc == AppRoutes.setup ? null : AppRoutes.setup;
    case NoAccess():
      return loc == AppRoutes.noAccess ? null : AppRoutes.noAccess;
    case Ready(:final session):
      if (AppRoutes.public.contains(loc) || loc == AppRoutes.setup || loc == AppRoutes.noAccess) {
        return wanted ?? AppRoutes.home;
      }
      if (!session.isAdmin && _adminOnly.any(loc.startsWith)) return AppRoutes.home;
      return null;
  }
}
