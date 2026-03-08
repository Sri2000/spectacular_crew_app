import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/dashboard/domain/models/risk_alert.dart';
import 'risk_analysis_service.dart';

class GeminiRiskService {
  final List<String> _apiKeys = [
    'AIzaSyCPEztRhzyIe_7jrtGll18gNpaAzVz7Olw',
    'AIzaSyD0YTeB9E08412gSIJpOOnyT3Fp4aQdNxU',
    'AIzaSyCtDd9z_h3gDBBunXqenYGmIVjDt8eQeY0',
    'AIzaSyAsDbVk-QlTs-lKSq_AVyP8c_QJ-HLYlE4',
    'AIzaSyAQNt8CmYz0L03om4NJdHCsyhyBNSL4s0E',
    'AIzaSyCQBGv6dywYW03eTpjP8xSR4D6RHVC_rDY',
    'AIzaSyDbNaNRmGqFv3hrEr4p7tVdm9IWQoDdf74',
    'AIzaSyDWIFrteuhm1pbhS_FCO8riBA0Ww_VkMHQ',
    'AIzaSyC0zXKxNIIHk4fJRRk52dNkuJpzqPOURLQ',
    'AIzaSyB9u95YzVvBovAIHF4Y8kz6pRL48NHgMK8',
  ];

  int _currentKeyIndex = 0;

  Future<RiskAlert?> generateGlobalInsightLabel(
    List<CategoryAnalysis> analyses,
  ) async {
    // Only send the top 5 problematic analyses to save tokens
    final problematic = analyses
        .where((a) => (a.overstockDays > 0 || a.stockoutDays > 0))
        .toList();
    problematic.sort(
      (a, b) => (b.stockoutDays + b.overstockDays).compareTo(
        a.stockoutDays + a.overstockDays,
      ),
    );
    final topAnalyses = problematic.take(5);

    if (topAnalyses.isEmpty) return null;

    final summaryText = topAnalyses
        .map((a) {
          final stockoutRate = (a.stockoutDays / a.totalDays * 100)
              .toStringAsFixed(1);
          final overstockRate = (a.overstockDays / a.totalDays * 100)
              .toStringAsFixed(1);
          return "Product: ${a.productId}, Store: ${a.storeId}, Category: ${a.category}, Stockout Rate: $stockoutRate%, Overstock Rate: $overstockRate%, Holding Cost: \$${a.totalHoldingCost.toStringAsFixed(0)}";
        })
        .join('\n');

    final prompt =
        '''
    As an AI Retail Analyst, review the following dataset summary showing our most problematic products:
    $summaryText

    Provide ONE consolidated active risk alert that encapsulates the biggest aggregate threat to the business based on these top issues.
    Respond ONLY in valid JSON format with the following keys exactly:
    {
      "productCategory": "AI Gemini Summary",
      "riskType": "e.g. PORTFOLIO VULNERABILITY",
      "urgencyLevel": "CRITICAL" or "HIGH",
      "revenueRisk": "e.g. \$2.5M",
      "marketReason": "Detail the overarching reason across products",
      "executiveSummary": "1 sentence executive warning",
      "mitigationName": "Name of best strategy",
      "mitigationDesc": "Strategy description"
    }
    Do not output markdown block formatting.
    ''';

    for (int i = 0; i < _apiKeys.length; i++) {
      final index = (_currentKeyIndex + i) % _apiKeys.length;
      final apiKey = _apiKeys[index];

      try {
        final model = GenerativeModel(
          model: 'gemini-3.1-flash-lite-preview',
          apiKey: apiKey,
        );

        final response = await model.generateContent([Content.text(prompt)]);
        _currentKeyIndex = index;

        if (response.text != null) {
          String cleanText = response.text!.trim();
          if (cleanText.startsWith("```json")) {
            cleanText = cleanText.substring(7);
            if (cleanText.endsWith("```")) {
              cleanText = cleanText.substring(0, cleanText.length - 3);
            }
          }
          final map = jsonDecode(cleanText);

          return RiskAlert(
            id: 'GEMINI_0',
            productCategory: map['productCategory'] ?? 'AI Overview',
            riskType: map['riskType'] ?? 'MULTI-VECTOR RISK',
            urgencyLevel: map['urgencyLevel'] ?? 'HIGH',
            revenueRisk: map['revenueRisk'] ?? 'Unknown',
            marketReason: map['marketReason'] ?? '',
            executiveSummary: map['executiveSummary'] ?? '',
            propagationScore: const PropagationScore(
              inventory: 9.0,
              pricing: 8.5,
              fulfillment: 9.5,
              revenue: 9.9,
            ),
            rawRevenueEstimate: 0.0,
            mitigationOptions: [
              MitigationOption(
                strategyName: map['mitigationName'] ?? 'AI Prescribed Strategy',
                timeline: 'Immediate',
                cost: 'Varies',
                description: map['mitigationDesc'] ?? '',
                tradeOffs: 'Holistic intervention required.',
              ),
            ],
          );
        }
      } catch (e) {
        print("Gemini error $e");
      }
    }
    return null;
  }

  Future<String?> analyzeSpecificRisk(
    String target,
    List<CategoryAnalysis> analyses,
  ) async {
    final relevantAnalyses = analyses
        .where((a) => a.category == target || a.productId == target)
        .toList();
    if (relevantAnalyses.isEmpty && analyses.isNotEmpty) {
      relevantAnalyses.addAll(analyses.take(3));
    }

    final context = relevantAnalyses
        .map(
          (a) =>
              "Category: ${a.category}, Product: ${a.productId}, Stockout Days: ${a.stockoutDays}/${a.totalDays}, Overstock Days: ${a.overstockDays}/${a.totalDays}, Revenue: \$${a.totalRevenue.toStringAsFixed(0)}",
        )
        .join("\n");

    final prompt =
        '''
    As a Senior Retail Risk Strategist, provide a real-time executive risk assessment for: $target
    
    Use this data context:
    $context
    
    Provide 3-4 bullet points covering:
    1. Primary Vulnerability
    2. Market Impact
    3. Recommended Immediate Action
    4. Long-term Mitigation
    
    Keep it concise and professional.
    ''';

    for (int i = 0; i < _apiKeys.length; i++) {
      final index = (_currentKeyIndex + i) % _apiKeys.length;
      final apiKey = _apiKeys[index];
      try {
        final model = GenerativeModel(
          model: 'gemini-3.1-flash-lite-preview',
          apiKey: apiKey,
        );
        final response = await model.generateContent([Content.text(prompt)]);
        _currentKeyIndex = index;
        return response.text;
      } catch (e) {
        print("Gemini specific analysis error: $e");
      }
    }
    return "Unable to generate real-time analysis at this time.";
  }
}
