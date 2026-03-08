import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/risk_detail/presentation/risk_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(
      path: '/risk-detail',
      builder: (context, state) {
        final riskId = state.uri.queryParameters['id'] ?? '';
        return RiskDetailScreen(riskId: riskId);
      },
    ),
  ],
);
