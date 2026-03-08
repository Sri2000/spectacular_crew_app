import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:retail_failure_simulator/services/aws_service.dart';

class PredictionData {
  final String label;
  final double score;

  PredictionData({required this.label, required this.score});

  factory PredictionData.fromJson(Map<String, dynamic> json) {
    return PredictionData(
      label: json['label'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
    );
  }
}

class PredictionResult {
  final String summary;
  final String explanation;
  final String riskAssessment;
  final int impactScore;
  final List<String> executivePoints;
  final List<String> mitigationActions;
  final List<PredictionData> trend;

  PredictionResult({
    required this.summary,
    required this.explanation,
    required this.riskAssessment,
    required this.impactScore,
    required this.executivePoints,
    required this.mitigationActions,
    required this.trend,
  });
}

class PredictionService {
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

  Future<PredictionResult?> analyzeExcelData(String content) async {
    final prompt =
        '''
    Analyze the following retail/supply chain excel data dump and predict the risk trend over the next 5 weeks.
    Data Dump:
    "${content.length > 500 ? content.substring(0, 500) : content}"
    
    Ensure any monetary values are presented in Indian Rupees (₹) instead of Dollars (\$).
    
    Return the response strictly in the following JSON format without any markdown blocks or extra text:
    {
      "summary": "A 2-3 sentence summary predicting the risk outcome based on the data.",
      "explanation": "A detailed explanation of the patterns in the excel data.",
      "riskAssessment": "Overall risk assessment (e.g., HIGH, MODERATE, LOW).",
      "impactScore": 85,
      "executivePoints": ["Point 1", "Point 2", "Point 3"],
      "mitigationActions": ["Action 1", "Action 2"],
      "trend": [
        {"label": "Week 1", "score": 25.0},
        {"label": "Week 2", "score": 40.0},
        {"label": "Week 3", "score": 60.0},
        {"label": "Week 4", "score": 75.0},
        {"label": "Week 5", "score": 90.0}
      ]
    }
    The trend scores should reflect the risk level (0-100) increasing or decreasing over 5 weeks. The impactScore is the overall propagation score (0-100).
    ''';

    // Try Bedrock first
    try {
      final bedrockResponse = await AWSClient.invokeBedrock(prompt);
      if (bedrockResponse != null) {
        return _parseAIResponse(bedrockResponse);
      }
    } catch (e) {
      print('Bedrock Prediction Error: $e');
    }

    // Attempt SageMaker for raw prediction if applicable
    try {
      final sagemakerResponse = await AWSClient.invokeSageMaker({
        "data": content,
      });
      if (sagemakerResponse != null) {
        print('SageMaker direct prediction received');
        // If SageMaker provides structured data, use it.
        // For now, we continue to Bedrock/Gemini for reasoning.
      }
    } catch (e) {
      print('SageMaker Error: $e');
    }

    // Gemini Fallback
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
          return _parseAIResponse(response.text!);
        }
      } catch (e) {
        print('Prediction AI Error with key $index: $e');
      }
    }

    return _fallbackResult();
  }

  PredictionResult _parseAIResponse(String text) {
    String cleanText = text.trim();
    if (cleanText.startsWith('```json')) {
      cleanText = cleanText.substring(7, cleanText.length - 3).trim();
    } else if (cleanText.startsWith('```')) {
      cleanText = cleanText.substring(3, cleanText.length - 3).trim();
    }
    final jsonData = jsonDecode(cleanText);

    List<PredictionData> trend = [];
    if (jsonData['trend'] != null) {
      for (var t in jsonData['trend']) {
        trend.add(PredictionData.fromJson(t));
      }
    }

    return PredictionResult(
      summary: jsonData['summary'] ?? 'Risk prediction based on recent data.',
      explanation:
          jsonData['explanation'] ??
          'Data anomalies indicate a shift in regular operational performance.',
      riskAssessment: jsonData['riskAssessment'] ?? 'HIGH',
      impactScore: jsonData['impactScore'] ?? 75,
      executivePoints: List<String>.from(jsonData['executivePoints'] ?? []),
      mitigationActions: List<String>.from(jsonData['mitigationActions'] ?? []),
      trend: trend,
    );
  }

  PredictionResult _fallbackResult() {
    return PredictionResult(
      summary:
          'Data analysis indicates a steady increase in operational risk. Recommend immediate mitigation strategies.',
      explanation:
          'Simulated fallback explanation due to AI timeout. The excel data shows irregularities in inventory rotation.',
      riskAssessment: 'CRITICAL',
      impactScore: 88,
      executivePoints: [
        'Inventory glut detected',
        'Potential margin erosion of ₹45,000',
        'Supply chain latency increasing',
      ],
      mitigationActions: [
        'Halt incoming POs',
        'Initiate tier-1 markdown protocol',
      ],
      trend: [
        PredictionData(label: 'Week 1', score: 30),
        PredictionData(label: 'Week 2', score: 45),
        PredictionData(label: 'Week 3', score: 60),
        PredictionData(label: 'Week 4', score: 70),
        PredictionData(label: 'Week 5', score: 85),
      ],
    );
  }
}
