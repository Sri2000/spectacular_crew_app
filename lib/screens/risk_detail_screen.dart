import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:retail_failure_simulator/models/failure_risk.dart';
import 'package:provider/provider.dart';
import 'package:retail_failure_simulator/providers/notification_provider.dart';
import 'package:retail_failure_simulator/models/notification_model.dart';

class RiskDetailScreen extends StatelessWidget {
  final FailureRisk risk;
  const RiskDetailScreen({super.key, required this.risk});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF64748B)),
          onPressed: () => Navigator.pop(context),
        ),
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
                      fontSize: 20,
                    ),
                  ),
                  TextSpan(
                    text: 'RISK',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0052FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'EXECUTIVE SUITE',
              style: GoogleFonts.outfit(
                color: const Color(0xFF94A3B8),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDecisionWorkspace(),
            const SizedBox(height: 24),
            _buildIntelReasoningSection(context),
            const SizedBox(height: 32),
            _buildExecutiveImpactSection(),
            const SizedBox(height: 32),
            _buildMitigationSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionWorkspace() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DECISION WORKSPACE',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0052FF),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'ID: ${risk.id}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF475569),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            risk.title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            risk.subTitle,
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildDeepMetricCard(
                  'EXPOSURE',
                  '₹${risk.exposure.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                  Colors.white.withOpacity(0.05),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDeepMetricCard(
                  'FAILURE SCORE',
                  '${risk.propagationScore}',
                  Colors.white.withOpacity(0.05),
                  valueColor: const Color(0xFFE11D48),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF96C83C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF96C83C).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.clock,
                  color: Color(0xFF96C83C),
                  size: 16,
                ),
                const SizedBox(width: 12),
                Text(
                  'CRITICAL WINDOW: ${risk.urgencyWindow.toUpperCase()}',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF96C83C),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeepMetricCard(
    String label,
    String value,
    Color bgColor, {
    Color valueColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: const Color(0xFF475569),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelReasoningSection(BuildContext context) {
    final notifications = context.watch<NotificationProvider>().notifications;
    RetailNotification? riskNotification;

    for (var n in notifications) {
      if (n.title.contains(risk.title)) {
        riskNotification = n;
        break;
      }
    }

    if (riskNotification == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.sparkles,
              color: Color(0xFF96C83C),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'INTEL REASONING',
              style: GoogleFonts.outfit(
                color: const Color(0xFF96C83C),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF0052FF).withOpacity(0.1)),
          ),
          child: Text(
            riskNotification.intelReport,
            style: GoogleFonts.inter(
              color: const Color(0xFF1E293B),
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveImpactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.cloud, color: Color(0xFF818CF8), size: 16),
            const SizedBox(width: 8),
            Text(
              'EXECUTIVE 3-POINT IMPACT',
              style: GoogleFonts.outfit(
                color: const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: risk.impactPoints.asMap().entries.map((entry) {
              return _buildImpactPointItem(
                entry.value,
                entry.key + 1,
                entry.key == risk.impactPoints.length - 1,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildImpactPointItem(ImpactPoint point, int index, bool isLast) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: GoogleFonts.outfit(
                color: const Color(0xFF0052FF),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  point.description,
                  style: GoogleFonts.inter(
                    color: point.isCritical
                        ? const Color(0xFFF97316)
                        : const Color(0xFF64748B),
                    fontSize: 11,
                    height: 1.5,
                    fontWeight: point.isCritical
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMitigationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MITIGATION ACTIONS',
          style: GoogleFonts.outfit(
            color: const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        ...risk.mitigationActions
            .map((action) => _buildMitigationActionCard(action))
            ,
      ],
    );
  }

  Widget _buildMitigationActionCard(MitigationAction action) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action.description,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'RECOVERY',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF10B981),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.recoveryLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF059669),
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
    );
  }
}
