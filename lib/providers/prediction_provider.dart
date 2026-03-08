import 'package:flutter/material.dart';
import 'package:retail_failure_simulator/services/prediction_service.dart';

class PredictionProvider with ChangeNotifier {
  PredictionResult? _latestPrediction;
  bool _isLoading = false;

  PredictionResult? get latestPrediction => _latestPrediction;
  bool get isLoading => _isLoading;

  Future<void> generatePrediction(String excelContent) async {
    _isLoading = true;
    notifyListeners();

    final service = PredictionService();
    _latestPrediction = await service.analyzeExcelData(excelContent);

    _isLoading = false;
    notifyListeners();
  }
}
