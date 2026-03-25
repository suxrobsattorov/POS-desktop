import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../di/injection.dart';
import '../../data/local/hive_service.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/pos/pos_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/history/history_screen.dart';
import '../../presentation/shift/shift_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const pos = '/pos';
  static const settings = '/settings';
  static const history = '/history';
  static const shift = '/shift';
}

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: AppRoutes.login,
  redirect: (context, state) {
    final hive = sl<HiveService>();
    final isLoggedIn = hive.isLoggedIn;
    final loc = state.matchedLocation;

    // Not logged in → always go to login
    if (!isLoggedIn) {
      if (loc == AppRoutes.login) return null;
      return AppRoutes.login;
    }

    // Logged in and on login page → go directly to home
    if (loc == AppRoutes.login) {
      return AppRoutes.home;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.pos,
      builder: (context, state) => const PosScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.shift,
      builder: (context, state) => const ShiftScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('404: ${state.error}')),
  ),
);
