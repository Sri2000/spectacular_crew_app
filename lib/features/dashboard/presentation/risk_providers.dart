import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/csv_data_service.dart';
import '../../../core/services/risk_analysis_service.dart';
import '../data/risk_repository.dart';
import '../domain/models/risk_alert.dart';

final csvDataServiceProvider = Provider((ref) => CsvDataService());
final riskAnalysisServiceProvider = Provider((ref) => RiskAnalysisService());

final riskRepositoryProvider = Provider((ref) {
  return RiskRepository(
    csvService: ref.watch(csvDataServiceProvider),
    analysisService: ref.watch(riskAnalysisServiceProvider),
  );
});

final activeAlertsProvider = FutureProvider<List<RiskAlert>>((ref) async {
  final repository = ref.watch(riskRepositoryProvider);
  return repository.getActiveAlerts();
});

final riskDetailProvider = FutureProvider.family<RiskAlert, String>((
  ref,
  id,
) async {
  final repository = ref.watch(riskRepositoryProvider);
  return repository.getRiskDetail(id);
});
