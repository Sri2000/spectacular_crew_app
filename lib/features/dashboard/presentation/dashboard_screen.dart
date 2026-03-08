import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/models/risk_alert.dart';
import 'risk_providers.dart';
import '../../../services/aws_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final selectedTab = _selectedTab;

    // Realtime notification listener
    ref.listen(activeAlertsProvider, (previous, next) {
      if (next is AsyncData<List<RiskAlert>>) {
        final prevAlerts = previous?.value ?? [];
        final nextAlerts = next.value;
        final newCritical = nextAlerts
            .where(
              (a) =>
                  a.urgencyLevel == 'CRITICAL' &&
                  !prevAlerts.any((pa) => pa.id == a.id),
            )
            .toList();

        if (newCritical.isNotEmpty) {
          for (final alert in newCritical) {
            _showTopAlert(alert);
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                children: const [
                  TextSpan(
                    text: 'R',
                    style: TextStyle(color: Color(0xFF3B82F6)), // Blue
                  ),
                  TextSpan(
                    text: 'iskPulse',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            Text(
              'Critical insights and decision support',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.bell, color: Colors.white),
                onPressed: () => setState(() => _selectedTab = 3),
              ),
              if (ref
                  .watch(activeAlertsProvider)
                  .maybeWhen(
                    data: (d) => d.any((a) => a.urgencyLevel == 'CRITICAL'),
                    orElse: () => false,
                  ))
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(selectedTab),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: Colors.grey.shade500,
        backgroundColor: Colors.white,
        elevation: 10,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(LucideIcons.layoutDashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(LucideIcons.alertTriangle),
            label: 'Risks',
          ),
          const BottomNavigationBarItem(
            icon: Icon(LucideIcons.activity),
            label: 'Scenarios',
          ),
          const BottomNavigationBarItem(
            icon: Icon(LucideIcons.bell),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(LucideIcons.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(int tabIndex) {
    if (tabIndex == 4) {
      return const ProfileTab();
    }

    final alertsAsync = ref.watch(activeAlertsProvider);
    final repo = ref.read(riskRepositoryProvider);

    return alertsAsync.when(
      data: (alerts) {
        if (tabIndex == 0) return DashboardTab(alerts: alerts, repo: repo);
        if (tabIndex == 1) return RiskAssessmentsTab(alerts: alerts);
        if (tabIndex == 2) return ScenariosTab(alerts: alerts);
        if (tabIndex == 3) return NotificationsTab(alerts: alerts);
        return const SizedBox.shrink();
      },
      loading: () => _buildLoadingState(),
      error: (err, stack) => _buildErrorState(err),
    );
  }

  Widget _buildLoadingState([
    String message = 'Analyzing retail risk data...',
  ]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.alertCircle,
            size: 48,
            color: AppColors.critical,
          ),
          const SizedBox(height: 16),
          Text('Error: $err'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(activeAlertsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showTopAlert(RiskAlert alert) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
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
            child: InkWell(
              onTap: () {
                if (entry.mounted) entry.remove();
                context.push('/risk-detail?id=${alert.id}');
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.alertTriangle,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CRITICAL RISK DETECTED',
                            style: GoogleFonts.inter(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${alert.riskType} in ${alert.productCategory}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      color: Colors.grey,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    // Disappear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}

// -----------------------------------------------------
// TABS
// -----------------------------------------------------

class NotificationsTab extends StatelessWidget {
  final List<RiskAlert> alerts;
  const NotificationsTab({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.bellOff, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No new notifications',
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final isCritical = alert.urgencyLevel == 'CRITICAL';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCritical
                  ? Colors.red.withOpacity(0.3)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => context.push('/risk-detail?id=${alert.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isCritical ? Colors.red : Colors.blue).withOpacity(
                      0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCritical ? LucideIcons.alertTriangle : LucideIcons.info,
                    color: isCritical ? Colors.red : Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.riskType,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isCritical ? Colors.red : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Detected in ${alert.productCategory}. Reliability score: ${alert.propagationScore.inventory.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Impact: ${alert.revenueRisk}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF97316),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DashboardTab extends StatelessWidget {
  final List<RiskAlert> alerts;
  final dynamic repo;

  const DashboardTab({super.key, required this.alerts, required this.repo});

  @override
  Widget build(BuildContext context) {
    final criticalRisks = alerts
        .where((a) => a.urgencyLevel == 'CRITICAL')
        .length;
    final highRisks = alerts.where((a) => a.urgencyLevel == 'HIGH').length;
    final totalRevenueRisk = alerts.isEmpty
        ? 0.0
        : alerts.fold(0.0, (sum, a) => sum + a.rawRevenueEstimate);

    final avgRiskScore = alerts.isEmpty
        ? 0.0
        : alerts.fold(0.0, (sum, a) {
                return sum +
                    (a.propagationScore.inventory +
                            a.propagationScore.pricing +
                            a.propagationScore.fulfillment +
                            a.propagationScore.revenue) /
                        4;
              }) /
              alerts.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Data source indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF22C55E).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    repo.isLoaded
                        ? 'Analyzed Data: ${repo.recordCount} records'
                        : 'Sample Data (Upload your file in Profile)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cards
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  label: 'Active Risks',
                  value: '${alerts.length}',
                  sublabel: 'Live',
                  icon: LucideIcons.alertCircle,
                  iconColor: AppColors.critical,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  label: 'Revenue Risk',
                  value: totalRevenueRisk > 1000
                      ? '₹${(totalRevenueRisk / 1000).toStringAsFixed(2)}B'
                      : '₹${totalRevenueRisk.toStringAsFixed(2)}M',
                  sublabel: 'Total',
                  icon: LucideIcons.trendingDown,
                  iconColor: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  label: 'High Risk',
                  value: '${criticalRisks + highRisks}',
                  sublabel: criticalRisks > 0
                      ? '↑ $criticalRisks critical'
                      : 'Monitored',
                  icon: LucideIcons.flame,
                  iconColor: criticalRisks > 0
                      ? AppColors.critical
                      : AppColors.high,
                  sublabelColor: criticalRisks > 0 ? AppColors.critical : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  label: 'Risk Score',
                  value: '${(avgRiskScore * 10).toStringAsFixed(0)}%',
                  sublabel: 'Avg',
                  icon: LucideIcons.activity,
                  iconColor: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          Text(
            'Revenue Risk Overview',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Graph
          Container(
            height: 420,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: alerts.isEmpty
                ? const Center(child: Text("No records to chart"))
                : LineChart(
                    LineChartData(
                      lineTouchData: const LineTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value.toInt() >= alerts.length)
                                return const SizedBox.shrink();
                              return Transform.rotate(
                                angle: -0.5,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text(
                                    alerts[value.toInt()].productCategory
                                        .split(' ')
                                        .first,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            },
                            reservedSize: 50,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              return Text(
                                '₹${value.toInt()}M',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: alerts.take(6).toList().asMap().entries.map((
                            entry,
                          ) {
                            final riskStr = entry.value.revenueRisk
                                .replaceAll('₹', '')
                                .replaceAll('\$', '');
                            double val = 0.0;
                            if (riskStr.endsWith('B')) {
                              val =
                                  (double.tryParse(
                                        riskStr.replaceAll('B', ''),
                                      ) ??
                                      0.0) *
                                  1000;
                            } else {
                              val =
                                  double.tryParse(
                                    riskStr.replaceAll('M', ''),
                                  ) ??
                                  0.0;
                            }
                            return FlSpot(entry.key.toDouble(), val);
                          }).toList(),
                          isCurved: true,
                          color: const Color(0xFF3B82F6),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class RiskAssessmentsTab extends StatelessWidget {
  final List<RiskAlert> alerts;
  const RiskAssessmentsTab({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    // Sort and take top 10 risks by total propagation score
    final topRisks = List<RiskAlert>.from(alerts);
    topRisks.sort((a, b) {
      final aScore =
          a.propagationScore.inventory +
          a.propagationScore.pricing +
          a.propagationScore.fulfillment +
          a.propagationScore.revenue;
      final bScore =
          b.propagationScore.inventory +
          b.propagationScore.pricing +
          b.propagationScore.fulfillment +
          b.propagationScore.revenue;
      return bScore.compareTo(aScore);
    });
    final top10 = topRisks.take(10).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Risk Assessments',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Top 10 risks detected',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '10 highest scored',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'CATEGORY',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'RISK TYPE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SCORE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: top10.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                return RiskRow(alert: top10[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ScenariosTab extends StatelessWidget {
  final List<RiskAlert> alerts;
  const ScenariosTab({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Scenarios',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Latest simulation runs',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${alerts.length} total',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ScenarioCard(alert: alerts[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfileTab> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();
  final _deptController = TextEditingController();
  String? _selectedCategory;
  String? _aiAnalysis;
  bool _isAnalyzing = false;
  bool _isSubmitting = false;

  bool _isLoginMode = true; // Default to login mode if no profile
  List<String> _uploadedFiles = [];

  @override
  void initState() {
    super.initState();
    final name = StorageService.getUserName() ?? "";
    _nameController.text = name;
    _emailController.text = StorageService.getUserEmail() ?? "";
    _phoneController.text = StorageService.getUserPhone() ?? "";
    _roleController.text = StorageService.getUserRole() ?? "";
    _deptController.text = StorageService.getUserDepartment() ?? "";

    if (StorageService.isLoggedIn) {
      _isLoginMode = false;
      _uploadedFiles = StorageService.getUserFileHistory()
          .where((f) => f != "INITIAL")
          .toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  Future<void> _handleFileUpload() async {
    final repo = ref.read(riskRepositoryProvider);
    final picked = await repo.pickUserFile();
    if (picked && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File "${repo.pendingFileName}" selected. Click SUBMIT to process.',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _handleFileSubmit() async {
    setState(() => _isSubmitting = true);
    final repo = ref.read(riskRepositoryProvider);
    final success = await repo.processUserFile();
    if (success && mounted) {
      ref.invalidate(activeAlertsProvider);
      setState(() {
        _uploadedFiles = StorageService.getUserFileHistory()
            .where((f) => f != "INITIAL")
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File processed and analysis updated.'),
          backgroundColor: Colors.green,
        ),
      );
    }
    setState(() => _isSubmitting = false);
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || (!_isLoginMode && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter required details.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final hasProfile = StorageService.isLoggedIn;

      if (hasProfile) {
        // UPDATE FLOW
        await StorageService.saveProfile(
          name,
          email,
          'General',
          phone: _phoneController.text,
          role: _roleController.text,
          department: _deptController.text,
          s3Url: StorageService.getUserS3Url(),
        );
      } else if (_isLoginMode) {
        // LOGIN FLOW
        bool synced = await StorageService.syncProfileFromDB(email);

        if (!synced) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account not found. Please create a new profile.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        // CREATE FLOW - Duplicate Check
        bool exists = await StorageService.syncProfileFromDB(email);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'An account already exists with this email. Please Login instead.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isLoginMode = true);
          }
          return;
        }

        await StorageService.saveProfile(
          name,
          email,
          'General',
          phone: _phoneController.text,
          role: _roleController.text,
          department: _deptController.text,
        );
      }

      // Sync successful or Profile created - update UI
      if (mounted) {
        setState(() {
          _nameController.text = StorageService.getUserName() ?? "";
          _phoneController.text = StorageService.getUserPhone() ?? "";
          _roleController.text = StorageService.getUserRole() ?? "";
          _deptController.text = StorageService.getUserDepartment() ?? "";
          _uploadedFiles = StorageService.getUserFileHistory()
              .where((f) => f != "INITIAL")
              .toList();
        });

        // Auto-load S3 data if it exists
        final s3Url = StorageService.getUserS3Url();
        if (s3Url != null && s3Url != "N/A" && s3Url.isNotEmpty) {
          await ref.read(riskRepositoryProvider).loadFromUrl(s3Url);
          ref.invalidate(activeAlertsProvider);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasProfile
                  ? 'Profile updated and synced to Cloud.'
                  : (_isLoginMode
                        ? 'Welcome back! Sync complete.'
                        : 'Welcome! Your profile is set up.'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Submit Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(riskAnalysisServiceProvider);
    final repo = ref.read(riskRepositoryProvider);
    final categories = analytics.lastAnalyses
        .map((a) => a.category)
        .toSet()
        .toList();
    if (categories.isEmpty) categories.add('Electronics');

    final hasProfile = StorageService.isLoggedIn;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (hasProfile)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.logOut, color: Colors.red),
                  onPressed: () async {
                    await StorageService.clearProfile();
                    await ref.read(csvDataServiceProvider).loadDefaultCsv();
                    ref.invalidate(activeAlertsProvider);
                    ref.invalidate(riskRepositoryProvider);
                    if (!mounted) return;
                    context.go('/splash');
                  },
                ),
              ],
            ),
          const SizedBox(height: 10),
          _buildProfileHeader(),
          const SizedBox(height: 32),

          // CREATE/LOGIN USER SECTION
          _buildSectionCard(
            title: hasProfile
                ? 'EDIT PROFILE'
                : (_isLoginMode ? 'LOGIN TO ACCOUNT' : 'CREATE NEW PROFILE'),
            icon: LucideIcons.userPlus,
            child: Column(
              children: [
                if (!_isLoginMode || hasProfile) ...[
                  _buildTextField(
                    'Full Name',
                    LucideIcons.user,
                    _nameController,
                    enabled: true,
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTextField(
                  'Work Email',
                  LucideIcons.mail,
                  _emailController,
                  enabled: !hasProfile,
                ),
                if (!_isLoginMode || hasProfile) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Phone',
                          LucideIcons.phone,
                          _phoneController,
                          enabled: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          'Role',
                          LucideIcons.briefcase,
                          _roleController,
                          enabled: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Department',
                    LucideIcons.building,
                    _deptController,
                    enabled: true,
                  ),
                ],
                if (hasProfile) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('UPDATE PROFILE & CLOUD SYNC'),
                    ),
                  ),
                ],
                if (!hasProfile) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isLoginMode ? 'LOGIN & SYNC' : 'GET STARTED'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        setState(() => _isLoginMode = !_isLoginMode),
                    child: Text(
                      _isLoginMode
                          ? "Switch to Create New Account"
                          : "Already have an account? Login",
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (hasProfile) ...[
            const SizedBox(height: 24),

            // UPLOAD SECTION
            _buildSectionCard(
              title: 'UPLOAD RISK DATA',
              icon: LucideIcons.uploadCloud,
              child: Column(
                children: [
                  InkWell(
                    onTap: _handleFileUpload,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.2),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.fileSpreadsheet,
                            color: Color(0xFF3B82F6),
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            repo.isLoaded
                                ? 'NEW DATA LOADED'
                                : 'Select Data Source (Excel/CSV)',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: repo.isLoaded
                                  ? const Color(0xFF10B981)
                                  : null,
                            ),
                          ),
                          Text(
                            repo.isLoaded
                                ? 'File ready for analysis'
                                : 'Click to select file',
                            style: GoogleFonts.inter(
                              color: repo.isLoaded
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (repo.pendingFileName != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleFileSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'SUBMIT & PROCESS: ${repo.pendingFileName}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                  if (_uploadedFiles.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'FILE UPLOAD HISTORY',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade400,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _uploadedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _uploadedFiles[index];
                        if (file == "INITIAL") return const SizedBox();
                        final fileName = file.split('/').last;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.fileText,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  fileName,
                                  style: GoogleFonts.inter(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.download,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                onPressed: () async {
                                  final url = AWSClient.getS3Url(fileName);
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(
                                      Uri.parse(url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              const Icon(
                                LucideIcons.checkCircle2,
                                size: 14,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            const SizedBox(height: 48),

            // REAL-TIME AI RISK ASSESSMENT (EXISTING FEATURE)
            Text(
              'ADVANCED RISK INTELLIGENCE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade400,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Select Category for Deep Dive',
                      labelStyle: GoogleFonts.inter(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: (_selectedCategory == null || _isAnalyzing)
                          ? null
                          : () async {
                              setState(() {
                                _isAnalyzing = true;
                                _aiAnalysis = null;
                              });
                              final result = await analytics.geminiService
                                  .analyzeSpecificRisk(
                                    _selectedCategory!,
                                    analytics.lastAnalyses,
                                  );
                              if (mounted) {
                                setState(() {
                                  _aiAnalysis = result;
                                  _isAnalyzing = false;
                                });
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isAnalyzing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Generate AI Breakdown'),
                    ),
                  ),
                  if (_aiAnalysis != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _aiAnalysis!,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ProfileItem(
              icon: LucideIcons.logOut,
              title: 'Logout Account',
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () async {
                await StorageService.clearProfile();
                await ref.read(csvDataServiceProvider).loadDefaultCsv();
                ref.invalidate(activeAlertsProvider);
                ref.invalidate(riskRepositoryProvider);
                if (!context.mounted) return;
                context.go('/splash');
              },
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              child: const Icon(
                LucideIcons.user,
                size: 40,
                color: Color(0xFF3B82F6),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.camera,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _nameController.text.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        Text(
          _emailController.text,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: enabled ? null : Colors.grey,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Color? textColor;
  final VoidCallback onTap;

  const _ProfileItem({
    required this.icon,
    required this.title,
    this.iconColor,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.grey.shade700, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------
// WIDGETS
// -----------------------------------------------------

class SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final Color iconColor;
  final Color? sublabelColor;

  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.iconColor,
    this.sublabelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 22),
              Text(
                sublabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: sublabelColor ?? AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class RiskRow extends StatelessWidget {
  final RiskAlert alert;
  const RiskRow({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    switch (alert.riskType) {
      case 'STOCKOUT RISK':
        badgeColor = AppColors.critical;
        break;
      case 'INVENTORY OVERFLOW':
        badgeColor = AppColors.high;
        break;
      default:
        badgeColor = AppColors.medium;
    }

    final avgScore =
        (alert.propagationScore.inventory +
            alert.propagationScore.pricing +
            alert.propagationScore.fulfillment +
            alert.propagationScore.revenue) /
        4;

    return InkWell(
      onTap: () => context.push('/risk-detail?id=${alert.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                alert.productCategory,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  alert.riskType,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Text(
                    '${(avgScore * 10).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: avgScore / 10,
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(badgeColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScenarioCard extends StatelessWidget {
  final RiskAlert alert;
  const ScenarioCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    switch (alert.urgencyLevel) {
      case 'CRITICAL':
        accentColor = AppColors.critical;
        break;
      case 'HIGH':
        accentColor = AppColors.high;
        break;
      case 'MEDIUM':
        accentColor = AppColors.medium;
        break;
      default:
        accentColor = AppColors.low;
    }

    return InkWell(
      onTap: () => context.push('/risk-detail?id=${alert.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.riskType,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${alert.productCategory} · ${alert.revenueRisk} revenue risk',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
