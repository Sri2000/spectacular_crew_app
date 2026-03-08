import 'dart:math';
import '../../features/dashboard/domain/models/risk_alert.dart';
import 'csv_data_service.dart';
import 'gemini_risk_service.dart';

class CategoryAnalysis {
  final String category;
  final String region;
  final String storeId;
  final String productId;
  int totalDemand = 0;
  int totalActualSales = 0;
  int totalLostSales = 0;
  double totalRevenue = 0;
  double totalHoldingCost = 0;
  int stockoutDays = 0;
  int overstockDays = 0;
  int totalDays = 0;
  double avgPrice = 0;
  double avgStockLevel = 0;
  double avgSellerQuality = 0;
  int promotionDays = 0;
  double minStockLevel = double.infinity;
  double maxStockLevel = 0;
  List<double> dailyRevenues = [];
  List<int> dailyStockLevels = [];

  CategoryAnalysis({
    required this.category,
    required this.region,
    required this.storeId,
    required this.productId,
  });
}

class RiskAnalysisService {
  final GeminiRiskService _geminiService = GeminiRiskService();
  List<CategoryAnalysis> _lastAnalyses = [];

  GeminiRiskService get geminiService => _geminiService;
  List<CategoryAnalysis> get lastAnalyses => _lastAnalyses;

  String _formatRevenue(double valueInMillions) {
    if (valueInMillions >= 1000) {
      return '₹${(valueInMillions / 1000).toStringAsFixed(2)}B';
    } else {
      return '₹${valueInMillions.toStringAsFixed(2)}M';
    }
  }

  /// Analyze CSV records and generate risk alerts
  Future<List<RiskAlert>> analyzeData(List<CsvRecord> records) async {
    if (records.isEmpty) return _generateFallbackAlerts();

    // Group by product + store
    final Map<String, CategoryAnalysis> analyses = {};

    for (final record in records) {
      final key = '${record.productId}_${record.storeId}';
      final analysis = analyses.putIfAbsent(
        key,
        () => CategoryAnalysis(
          category: record.productCategory,
          region: record.region,
          productId: record.productId,
          storeId: record.storeId,
        ),
      );

      analysis.totalDemand += record.demand;
      analysis.totalActualSales += record.actualSales;
      analysis.totalLostSales += record.lostSales;
      analysis.totalRevenue += record.revenue;
      analysis.totalHoldingCost += record.holdingCost;
      analysis.stockoutDays += record.stockoutFlag;
      analysis.overstockDays += record.overstockFlag;
      analysis.totalDays++;
      analysis.avgPrice += record.price;
      analysis.avgStockLevel += record.stockLevel;
      analysis.avgSellerQuality += record.sellerQualityScore;
      analysis.promotionDays += record.promotionFlag;
      analysis.dailyRevenues.add(record.revenue);
      analysis.dailyStockLevels.add(record.stockLevel);

      if (record.stockLevel < analysis.minStockLevel) {
        analysis.minStockLevel = record.stockLevel.toDouble();
      }
      if (record.stockLevel > analysis.maxStockLevel) {
        analysis.maxStockLevel = record.stockLevel.toDouble();
      }
    }

    // Calculate averages
    _lastAnalyses = analyses.values.toList();
    for (final a in _lastAnalyses) {
      if (a.totalDays > 0) {
        a.avgPrice /= a.totalDays;
        a.avgStockLevel /= a.totalDays;
        a.avgSellerQuality /= a.totalDays;
      }
    }

    // Generate risk alerts from analysis
    final alerts = <RiskAlert>[];
    int id = 1;

    for (final analysis in analyses.values) {
      final stockoutRate = analysis.totalDays > 0
          ? analysis.stockoutDays / analysis.totalDays
          : 0.0;
      final overstockRate = analysis.totalDays > 0
          ? analysis.overstockDays / analysis.totalDays
          : 0.0;
      final fulfillmentRate = analysis.totalDemand > 0
          ? analysis.totalActualSales / analysis.totalDemand
          : 1.0;
      final lostRevenueEstimate = analysis.totalLostSales * analysis.avgPrice;

      // Determine risk type and urgency
      String? riskType;
      String urgencyLevel;
      String revenueRisk;
      String marketReason;
      String executiveSummary;
      double inventoryImpact;
      double pricingImpact;
      double fulfillmentImpact;
      double revenueImpact;
      double rawVal = 0.0;

      if (stockoutRate > 0.05) {
        // Stockout risk
        riskType = 'STOCKOUT RISK';
        revenueRisk = _formatRevenue(lostRevenueEstimate / 1000000);
        inventoryImpact = min(10, stockoutRate * 100);
        pricingImpact = min(10, (1 - analysis.avgSellerQuality) * 12);
        fulfillmentImpact = min(10, (1 - fulfillmentRate) * 15);
        revenueImpact = min(
          10,
          (lostRevenueEstimate /
                  (analysis.totalRevenue + lostRevenueEstimate + 1)) *
              12,
        );

        if (stockoutRate > 0.15) {
          urgencyLevel = 'CRITICAL';
        } else if (stockoutRate > 0.08) {
          urgencyLevel = 'HIGH';
        } else {
          urgencyLevel = 'MEDIUM';
        }

        marketReason =
            'Product ${analysis.productId} (${analysis.category}) at Store ${analysis.storeId} (${analysis.region}) experienced stockouts on ${analysis.stockoutDays} of ${analysis.totalDays} days '
            '(${(stockoutRate * 100).toStringAsFixed(1)}%). '
            'Average demand of ${(analysis.totalDemand / analysis.totalDays).toStringAsFixed(0)} units/day '
            'exceeds replenishment capacity, causing ${analysis.totalLostSales} lost sales.';

        rawVal = lostRevenueEstimate / 1000000;
        executiveSummary =
            'Potential revenue loss of $revenueRisk due to stockout events for ${analysis.productId}. '
            'Fulfillment rate at ${(fulfillmentRate * 100).toStringAsFixed(1)}%.';
      } else if (overstockRate > 0.3) {
        // Overstock risk
        riskType = 'INVENTORY OVERFLOW';
        final holdingCostM = analysis.totalHoldingCost / 1000000;
        revenueRisk = _formatRevenue(holdingCostM);
        inventoryImpact = min(10, overstockRate * 12);
        pricingImpact = min(10, 3 + (overstockRate * 5));
        fulfillmentImpact = min(10, 2.0);
        revenueImpact = min(10, holdingCostM * 2);

        if (overstockRate > 0.7) {
          urgencyLevel = 'HIGH';
        } else if (overstockRate > 0.5) {
          urgencyLevel = 'MEDIUM';
        } else {
          urgencyLevel = 'LOW';
        }

        marketReason =
            'Product ${analysis.productId} at Store ${analysis.storeId} has excess inventory on ${analysis.overstockDays} of ${analysis.totalDays} days '
            '(${(overstockRate * 100).toStringAsFixed(1)}%). '
            'Holding cost of ₹${(analysis.totalHoldingCost / 1000).toStringAsFixed(0)}K is eroding margins. '
            'Average stock level of ${analysis.avgStockLevel.toStringAsFixed(0)} units is above optimal.';

        rawVal = holdingCostM;
        executiveSummary =
            'Excess inventory holding cost of $revenueRisk for ${analysis.productId}. '
            'Stock levels consistently above demand capacity.';
      } else if (fulfillmentRate < 0.95) {
        // Fulfillment risk
        riskType = 'FULFILLMENT DELAY';
        revenueRisk = _formatRevenue(lostRevenueEstimate / 1000000);
        inventoryImpact = min(10, 3.0);
        pricingImpact = min(10, 4.0);
        fulfillmentImpact = min(10, (1 - fulfillmentRate) * 20);
        revenueImpact = min(10, (1 - fulfillmentRate) * 15);

        urgencyLevel = fulfillmentRate < 0.85 ? 'HIGH' : 'MEDIUM';

        marketReason =
            'Product ${analysis.productId} at Store ${analysis.storeId} has a fulfillment rate of only '
            '${(fulfillmentRate * 100).toStringAsFixed(1)}%. '
            'Customer satisfaction at risk due to unmet demand of ${analysis.totalLostSales} units.';

        rawVal = lostRevenueEstimate / 1000000;
        executiveSummary =
            'Fulfillment rate below target at ${(fulfillmentRate * 100).toStringAsFixed(1)}%. '
            'Estimated revenue impact of $revenueRisk.';
      } else {
        continue; // No significant risk
      }

      alerts.add(
        RiskAlert(
          id: '${id++}',
          productCategory: '${analysis.category} (${analysis.productId})',
          riskType: riskType,
          urgencyLevel: urgencyLevel,
          revenueRisk: revenueRisk,
          marketReason: marketReason,
          executiveSummary: executiveSummary,
          propagationScore: PropagationScore(
            inventory: double.parse(inventoryImpact.toStringAsFixed(1)),
            pricing: double.parse(pricingImpact.toStringAsFixed(1)),
            fulfillment: double.parse(fulfillmentImpact.toStringAsFixed(1)),
            revenue: double.parse(revenueImpact.toStringAsFixed(1)),
          ),
          rawRevenueEstimate: rawVal,
          mitigationOptions: _generateMitigations(riskType, analysis),
        ),
      );
    }

    // Sort by urgency
    const urgencyOrder = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3};
    alerts.sort(
      (a, b) => (urgencyOrder[a.urgencyLevel] ?? 3).compareTo(
        urgencyOrder[b.urgencyLevel] ?? 3,
      ),
    );
    // Try to get a high-level summary from Gemini
    final geminiAlert = await _geminiService.generateGlobalInsightLabel(
      analyses.values.toList(),
    );

    if (geminiAlert != null) {
      alerts.insert(0, geminiAlert);
    }

    return alerts.isEmpty ? _generateFallbackAlerts() : alerts;
  }

  List<MitigationOption> _generateMitigations(
    String riskType,
    CategoryAnalysis analysis,
  ) {
    switch (riskType) {
      case 'STOCKOUT RISK':
        return [
          MitigationOption(
            strategyName: 'Expedite Supplier Replenishment',
            timeline: '3-5 days',
            cost: 'Medium',
            description:
                'Activate emergency procurement channels and air freight for ${analysis.category} SKUs in ${analysis.region}.',
            tradeOffs:
                'Higher shipping costs (15-25% premium). May reduce margins temporarily.',
          ),
          MitigationOption(
            strategyName: 'Cross-Regional Inventory Transfer',
            timeline: '2-3 days',
            cost: 'Low',
            description:
                'Redistribute ${analysis.category} stock from overstocked regions to ${analysis.region}.',
            tradeOffs:
                'Transfer logistics cost. Risk of creating stockout in source region.',
          ),
          MitigationOption(
            strategyName: 'Demand Dampening Promotion',
            timeline: '1-2 days',
            cost: 'Low',
            description:
                'Redirect ${analysis.region} customers to alternative products via targeted campaigns.',
            tradeOffs:
                'Potential customer dissatisfaction. Brand perception risk.',
          ),
        ];
      case 'INVENTORY OVERFLOW':
        return [
          MitigationOption(
            strategyName: 'Flash Clearance Event',
            timeline: '2-3 days',
            cost: 'High',
            description:
                'Launch targeted discounting (20-40%) on ${analysis.category} in ${analysis.region} to clear excess.',
            tradeOffs:
                'Significant margin impact. Current holding cost is ₹${(analysis.totalHoldingCost / 1000).toStringAsFixed(0)}K.',
          ),
          MitigationOption(
            strategyName: 'Pause Replenishment Orders',
            timeline: '1 day',
            cost: 'Low',
            description:
                'Halt new purchase orders for ${analysis.category} until stock normalizes.',
            tradeOffs: 'Risk of future stockout if demand spikes unexpectedly.',
          ),
          MitigationOption(
            strategyName: 'B2B Liquidation Channel',
            timeline: '5-7 days',
            cost: 'Medium',
            description:
                'Route excess ${analysis.category} inventory to wholesale/B2B partners at reduced rates.',
            tradeOffs:
                'Lower revenue per unit but recovers capital tied up in inventory.',
          ),
        ];
      default:
        return [
          MitigationOption(
            strategyName: '3PL Diversification',
            timeline: '4-5 days',
            cost: 'Medium',
            description:
                'Onboard secondary delivery partners for ${analysis.category} in ${analysis.region}.',
            tradeOffs:
                'Setup time and integration cost. New partner quality risk.',
          ),
          MitigationOption(
            strategyName: 'Customer Proactive Communication',
            timeline: '1 day',
            cost: 'Low',
            description:
                'Send proactive delay notifications with discount vouchers to affected ${analysis.region} customers.',
            tradeOffs: 'Voucher cost of ~2-5% per order. Prevents churn.',
          ),
        ];
    }
  }

  List<RiskAlert> _generateFallbackAlerts() {
    return [
      const RiskAlert(
        id: '1',
        productCategory: 'Electronics',
        riskType: 'STOCKOUT RISK',
        urgencyLevel: 'CRITICAL',
        revenueRisk: '₹1.2M',
        marketReason:
            'Seasonal demand spike combined with delayed supplier replenishment.',
        executiveSummary:
            'Potential revenue loss of ₹1.2M due to forecasted stockout in core electronics category.',
        propagationScore: PropagationScore(
          inventory: 8.2,
          pricing: 6.9,
          fulfillment: 7.5,
          revenue: 8.8,
        ),
        rawRevenueEstimate: 1.2,
        mitigationOptions: [
          MitigationOption(
            strategyName: 'Reduce Procurement Delay',
            timeline: '5 days',
            cost: 'Medium',
            description: 'Expedite air freight for critical SKUs.',
            tradeOffs: 'Higher margin erosion due to shipping costs.',
          ),
          MitigationOption(
            strategyName: 'Launch Targeted Promotion',
            timeline: '2 days',
            cost: 'Low',
            description: 'Redirect demand to available substitutes.',
            tradeOffs: 'Minor impact on customer loyalty.',
          ),
        ],
      ),
    ];
  }
}
