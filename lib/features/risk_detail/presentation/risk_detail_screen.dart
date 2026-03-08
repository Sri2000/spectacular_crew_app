import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/domain/models/risk_alert.dart';
import '../../dashboard/presentation/risk_providers.dart';
import '../../../services/aws_service.dart';

class RiskDetailScreen extends ConsumerStatefulWidget {
  final String riskId;
  const RiskDetailScreen({super.key, required this.riskId});

  @override
  ConsumerState<RiskDetailScreen> createState() => _RiskDetailScreenState();
}

class _RiskDetailScreenState extends ConsumerState<RiskDetailScreen> {
  String? _aiExplanation;
  bool _isAnalyzing = false;

  Future<void> _runAIDeepDive(RiskAlert risk) async {
    setState(() {
      _isAnalyzing = true;
      _aiExplanation = null;
    });

    final prompt =
        """
Analyze this retail risk for an executive:
Type: ${risk.riskType}
Category: ${risk.productCategory}
Summary: ${risk.executiveSummary}
Market Reason: ${risk.marketReason}
Inventory Impact: ${risk.propagationScore.inventory}
Pricing Impact: ${risk.propagationScore.pricing}

Please provide:
1. A deep dive into why this is happening.
2. Strategic recommendations for the next 48 hours.
3. Long-term structural changes to prevent this.
""";

    final response = await AWSClient.invokeBedrock(prompt);
    if (mounted) {
      setState(() {
        _aiExplanation = response;
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskAsync = ref.watch(riskDetailProvider(widget.riskId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive Briefing'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.share2), onPressed: () {}),
          const SizedBox(width: 16),
        ],
      ),
      body: riskAsync.when(
        data: (risk) => _buildContent(context, risk),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, RiskAlert risk) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(risk),
          const SizedBox(height: 32),
          _buildRevenueRisk(risk),
          const SizedBox(height: 32),
          _buildMarketReason(risk),
          const SizedBox(height: 32),
          _buildPropagationImpact(risk),
          const SizedBox(height: 32),
          _buildAIAnalysisSection(risk),
          const SizedBox(height: 32),
          _buildMitigationStrategies(context, risk),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeader(RiskAlert risk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            risk.productCategory.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          risk.riskType,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueRisk(RiskAlert risk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REVENUE RISK',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.critical.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.critical.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.trendingDown,
                color: AppColors.critical,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  risk.executiveSummary,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarketReason(RiskAlert risk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MARKET REASON',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          risk.marketReason,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPropagationImpact(RiskAlert risk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPAGATION IMPACT',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        _buildImpactSlider('Inventory Impact', risk.propagationScore.inventory),
        _buildImpactSlider('Pricing Impact', risk.propagationScore.pricing),
        _buildImpactSlider(
          'Fulfillment Impact',
          risk.propagationScore.fulfillment,
        ),
        _buildImpactSlider('Revenue Impact', risk.propagationScore.revenue),
      ],
    );
  }

  Widget _buildImpactSlider(String label, double score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                score.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 10,
              minHeight: 8,
              backgroundColor: AppColors.accent.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                score > 7
                    ? AppColors.critical
                    : score > 4
                    ? AppColors.high
                    : AppColors.low,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAnalysisSection(RiskAlert risk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EXECUTIVE AI ANALYSIS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            if (_aiExplanation == null && !_isAnalyzing)
              TextButton.icon(
                onPressed: () => _runAIDeepDive(risk),
                icon: const Icon(LucideIcons.sparkles, size: 14),
                label: const Text(
                  'Run Deep Dive',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _isAnalyzing
              ? const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 12),
                      Text(
                        'AI is analyzing structural patterns...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _aiExplanation != null
              ? Text(
                  _aiExplanation!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.6,
                    color: const Color(0xFF1E293B),
                  ),
                )
              : Center(
                  child: Text(
                    'Click "Run Deep Dive" for AI-powered insights.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMitigationStrategies(BuildContext context, RiskAlert risk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MITIGATION OPTIONS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        ...risk.mitigationOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MitigationCard(index: index + 1, option: option),
          );
        }).toList(),
      ],
    );
  }
}

class _MitigationCard extends StatelessWidget {
  final int index;
  final MitigationOption option;

  const _MitigationCard({required this.index, required this.option});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary,
                child: Text(
                  '$index',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.strategyName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            option.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDetailChip(LucideIcons.clock, option.timeline),
              const SizedBox(width: 12),
              _buildDetailChip(LucideIcons.dollarSign, option.cost),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.info,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trade-off: ${option.tradeOffs}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {},
              child: const Text('ACTIVATE STRATEGY'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
