import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:retail_failure_simulator/models/failure_risk.dart';
import 'package:retail_failure_simulator/screens/risk_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:retail_failure_simulator/providers/notification_provider.dart';
import 'package:retail_failure_simulator/providers/tab_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late List<FailureRisk> _currentRisks;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentRisks = List.from(FailureRisk.mockData);
    _timer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (mounted) _syncLiveRisks(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncLiveRisks({bool silent = false}) {
    setState(() {
      _currentRisks.insert(0, FailureRisk.generateRandom());
      if (_currentRisks.length > 5) _currentRisks.removeLast();
    });
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Intel Sync successful.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'RETAIL',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  TextSpan(
                    text: 'RISK',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0052FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'EXECUTIVE SUITE',
              style: GoogleFonts.outfit(
                color: const Color(0xFF94A3B8),
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => context.read<TabProvider>().setTab(1),
              borderRadius: BorderRadius.circular(30),
              child: Consumer<NotificationProvider>(
                builder: (context, provider, child) {
                  final unread = provider.unreadCount;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.bell,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: 8,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVE RISKS',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 14,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: _syncLiveRisks,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.refreshCcw,
                          size: 12,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE SYNC',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF4F46E5),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ..._currentRisks
                .map((risk) => _buildRiskCard(context, risk))
                ,
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard(BuildContext context, FailureRisk risk) {
    Color indicatorColor = _getIndicatorColor(risk.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCategoryIcon(risk.category, indicatorColor),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'PROPAGATION SCORE',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${risk.propagationScore}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFE11D48),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      risk.title,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E293B),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      risk.subTitle,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.clock,
                          color: Color(0xFF94A3B8),
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'WINDOW: ${risk.urgencyWindow.toUpperCase()}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            // Trigger real-time intelligence analysis
                            context
                                .read<NotificationProvider>()
                                .generateRiskAlert(risk);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RiskDetailScreen(risk: risk),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0052FF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'SIMULATE IMPACT',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF0052FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                LucideIcons.arrowRight,
                                size: 14,
                                color: Color(0xFF0052FF),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Updated ${risk.updatedTime}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFCBD5E1),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(RiskCategory category, Color color) {
    IconData iconData;
    switch (category) {
      case RiskCategory.overstock:
        iconData = LucideIcons.package;
        break;
      case RiskCategory.stockout:
        iconData = LucideIcons.alertCircle;
        break;
      case RiskCategory.demandMismatch:
        iconData = LucideIcons.alertTriangle;
        break;
      case RiskCategory.logisticDelay:
        iconData = LucideIcons.truck;
        break;
      case RiskCategory.pricingWar:
        iconData = LucideIcons.trendingDown;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  Color _getIndicatorColor(RiskCategory category) {
    switch (category) {
      case RiskCategory.overstock:
        return const Color(0xFFF97316);
      case RiskCategory.stockout:
        return const Color(0xFFEF4444);
      case RiskCategory.demandMismatch:
        return const Color(0xFFEF4444);
      case RiskCategory.logisticDelay:
        return const Color(0xFF8B5CF6);
      case RiskCategory.pricingWar:
        return const Color(0xFF10B981);
    }
  }
}
