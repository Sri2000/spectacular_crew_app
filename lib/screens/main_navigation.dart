import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:retail_failure_simulator/screens/dashboard_screen.dart';
import 'package:retail_failure_simulator/screens/notification_screen.dart';
import 'package:retail_failure_simulator/screens/profile_screen.dart';
import 'package:retail_failure_simulator/screens/simulation_screen.dart';
import 'package:retail_failure_simulator/screens/prediction_screen.dart';
import 'package:retail_failure_simulator/providers/notification_provider.dart';
import 'package:retail_failure_simulator/providers/tab_provider.dart';
import 'package:retail_failure_simulator/models/notification_model.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final List<Widget> _screens = [
    const DashboardScreen(),
    const SimulationScreen(),
    const PredictionScreen(),
    const NotificationScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    final selectedIndex = context.watch<TabProvider>().currentTabIndex;
    final latestNotification = context
        .watch<NotificationProvider>()
        .latestPopup;

    if (latestNotification != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLiveAlert(context, latestNotification);
        context.read<NotificationProvider>().clearPopup();
      });
    }

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => context.read<TabProvider>().setTab(index),
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF0052FF),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.layoutDashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.activity),
              label: 'Simulation',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.trendingUp),
              label: 'Predictions',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(LucideIcons.bell),
                  if (unreadCount > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Notifications',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.user),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _showLiveAlert(BuildContext context, dynamic notification) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            tween: Tween(begin: -100.0, end: 0.0),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Opacity(
                  opacity: ((100 + value) / 100).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: _getUrgencyColor(
                    notification.urgency,
                  ).withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getUrgencyColor(
                        notification.urgency,
                      ).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.sparkles,
                      color: _getUrgencyColor(notification.urgency),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${notification.urgency.toString().split('.').last.toUpperCase()} INTEL READY',
                          style: GoogleFonts.outfit(
                            color: _getUrgencyColor(notification.urgency),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          notification.title,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      color: Colors.black38,
                      size: 16,
                    ),
                    onPressed: () => entry.remove(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  Color _getUrgencyColor(UrgencyLevel urgency) {
    switch (urgency) {
      case UrgencyLevel.critical:
        return const Color(0xFFE11D48);
      case UrgencyLevel.high:
        return const Color(0xFFF97316);
      case UrgencyLevel.moderate:
        return const Color(0xFFEAB308);
      case UrgencyLevel.low:
        return const Color(0xFF96C83C);
    }
  }
}
