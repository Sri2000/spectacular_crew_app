import 'package:flutter/foundation.dart';

@immutable
class RiskAlert {
  final String id;
  final String productCategory;
  final String riskType;
  final String urgencyLevel;
  final String revenueRisk;
  final String marketReason;
  final String executiveSummary;
  final PropagationScore propagationScore;
  final double rawRevenueEstimate;
  final List<MitigationOption> mitigationOptions;

  const RiskAlert({
    required this.id,
    required this.productCategory,
    required this.riskType,
    required this.urgencyLevel,
    required this.revenueRisk,
    required this.marketReason,
    required this.executiveSummary,
    required this.propagationScore,
    required this.rawRevenueEstimate,
    required this.mitigationOptions,
  });

  factory RiskAlert.fromJson(Map<String, dynamic> json) {
    return RiskAlert(
      id: json['id'] as String,
      productCategory: json['productCategory'] as String,
      riskType: json['riskType'] as String,
      urgencyLevel: json['urgencyLevel'] as String,
      revenueRisk: json['revenueRisk'] as String,
      marketReason: json['marketReason'] as String,
      executiveSummary: json['executiveSummary']?.toString() ?? '',
      propagationScore: json['propagationScore'] != null
          ? PropagationScore.fromJson(
              json['propagationScore'] as Map<String, dynamic>,
            )
          : const PropagationScore(
              inventory: 0,
              pricing: 0,
              fulfillment: 0,
              revenue: 0,
            ),
      rawRevenueEstimate:
          (json['rawRevenueEstimate'] as num?)?.toDouble() ?? 0.0,
      mitigationOptions: (json['mitigationOptions'] as List<dynamic>)
          .map((e) => MitigationOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@immutable
class PropagationScore {
  final double inventory;
  final double pricing;
  final double fulfillment;
  final double revenue;

  const PropagationScore({
    required this.inventory,
    required this.pricing,
    required this.fulfillment,
    required this.revenue,
  });

  factory PropagationScore.fromJson(Map<String, dynamic> json) {
    return PropagationScore(
      inventory: (json['inventory'] as num).toDouble(),
      pricing: (json['pricing'] as num).toDouble(),
      fulfillment: (json['fulfillment'] as num).toDouble(),
      revenue: (json['revenue'] as num).toDouble(),
    );
  }
}

@immutable
class MitigationOption {
  final String strategyName;
  final String timeline;
  final String cost;
  final String description;
  final String tradeOffs;

  const MitigationOption({
    required this.strategyName,
    required this.timeline,
    required this.cost,
    required this.description,
    required this.tradeOffs,
  });

  factory MitigationOption.fromJson(Map<String, dynamic> json) {
    return MitigationOption(
      strategyName: json['strategyName'] as String,
      timeline: json['timeline'] as String,
      cost: json['cost'] as String,
      description: json['description'] as String,
      tradeOffs: json['tradeOffs'] as String,
    );
  }
}
