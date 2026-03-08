import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:retail_failure_simulator/models/failure_risk.dart';
import 'package:retail_failure_simulator/services/aws_service.dart';

class IntelService {
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

  Future<String> getIntelInsight(FailureRisk risk) async {
    final prompt =
        '''
    As a Retail Risk Analyst, analyze this failure scenario:
    Title: ${risk.title}
    Category: ${risk.subTitle}
    Propagation Score: ${risk.propagationScore}
    
    Provide a concise (2-3 sentence) executive summary explaining why this specific live risk is critical and one innovative mitigation strategy. Focus on data-driven terminology.
    ''';

    // Try Bedrock first
    try {
      final bedrockResult = await AWSClient.invokeBedrock(prompt);
      if (bedrockResult != null && bedrockResult.isNotEmpty) {
        return bedrockResult;
      }
    } catch (e) {
      print('Bedrock Intel Error: $e');
    }

    // Try each API key until one works (Gemini Fallback)
    for (int i = 0; i < _apiKeys.length; i++) {
      final index = (_currentKeyIndex + i) % _apiKeys.length;
      final apiKey = _apiKeys[index];

      try {
        final model = GenerativeModel(
          model: 'gemini-3.1-flash-lite-preview',
          apiKey: apiKey,
        );

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);

        // Update current index for future calls
        _currentKeyIndex = index;

        if (response.text != null) {
          return response.text!;
        }
      } catch (e) {
        print('Intel Sync Error with key $index: $e');
        // Continue to next key
      }
    }

    return 'INTEL REPORT: Market conditions for ${risk.title} indicate significant volatility. Immediate regional inventory reallocation is advised to mitigate margin erosion.';
  }
}
