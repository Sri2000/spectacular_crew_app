import '../../../core/services/csv_data_service.dart';
import '../../../core/services/risk_analysis_service.dart';
import '../domain/models/risk_alert.dart';
import '../../../services/storage_service.dart';

class RiskRepository {
  final CsvDataService _csvService;
  final RiskAnalysisService _analysisService;
  List<RiskAlert>? _cachedAlerts;

  RiskRepository({
    required CsvDataService csvService,
    required RiskAnalysisService analysisService,
  }) : _csvService = csvService,
       _analysisService = analysisService;

  /// Load data from default CSV or user-uploaded file, then analyze
  Future<List<RiskAlert>> getActiveAlerts() async {
    if (_cachedAlerts != null) return _cachedAlerts!;
    if (!_csvService.isLoaded) {
      final s3Url = StorageService.getUserS3Url();
      if (s3Url != null && s3Url != "N/A" && s3Url.isNotEmpty) {
        final success = await _csvService.loadFromUrl(s3Url);
        if (!success && !StorageService.isLoggedIn) {
          await _csvService.loadDefaultCsv();
        }
      } else if (!StorageService.isLoggedIn) {
        await _csvService.loadDefaultCsv();
      }
    }
    final alerts = await _analysisService.analyzeData(_csvService.records);
    _cachedAlerts = alerts;

    // Auto-save metrics to Cloud if logged in
    if (StorageService.isLoggedIn && alerts.isNotEmpty) {
      final criticalCount = alerts
          .where((a) => a.urgencyLevel == 'CRITICAL')
          .length;
      final highCount = alerts.where((a) => a.urgencyLevel == 'HIGH').length;
      final totalRisk = alerts.fold(
        0.0,
        (sum, a) => sum + (a.rawRevenueEstimate ?? 0.0),
      );

      final metrics = {
        'critical_alerts': criticalCount.toString(),
        'high_alerts': highCount.toString(),
        'total_revenue_risk': '₹${totalRisk.toStringAsFixed(2)}M',
        'last_excel_processed':
            _csvService.loadedFilePath?.split('/').last ?? 'S3_SYNC',
        'sagemaker_inference': 'active',
        'bedrock_reasoning': 'enabled',
      };

      await StorageService.saveProfile(
        StorageService.getUserName() ?? "",
        StorageService.getUserEmail() ?? "",
        StorageService.getUserRiskCategory() ?? "General",
        phone: StorageService.getUserPhone(),
        role: StorageService.getUserRole(),
        department: StorageService.getUserDepartment(),
        s3Url: StorageService.getUserS3Url(),
        metrics: metrics,
      );
    }

    return alerts;
  }

  /// Just let user pick a file
  Future<bool> pickUserFile() async {
    return await _csvService.pickFile();
  }

  /// Process the already picked file
  Future<bool> processUserFile() async {
    final success = await _csvService.processPendingFile();
    if (success) {
      _cachedAlerts = await _analysisService.analyzeData(_csvService.records);
      return true;
    }
    return false;
  }

  /// Reload data from a user-picked file (Legacy support)
  Future<bool> loadFromUserFile() async {
    final loaded = await pickUserFile();
    if (loaded) return await processUserFile();
    return false;
  }

  /// Load data from a remote URL (S3)
  Future<bool> loadFromUrl(String url) async {
    final loaded = await _csvService.loadFromUrl(url);
    if (loaded) {
      _cachedAlerts = await _analysisService.analyzeData(_csvService.records);
      return true;
    }
    return false;
  }

  /// Get a specific risk detail by ID
  Future<RiskAlert> getRiskDetail(String id) async {
    final alerts = await getActiveAlerts();
    return alerts.firstWhere((a) => a.id == id, orElse: () => alerts.first);
  }

  bool get isLoaded => _csvService.isLoaded;
  String? get loadedFilePath => _csvService.loadedFilePath;
  int get recordCount => _csvService.records.length;
  String? get pendingFileName => _csvService.pendingFileName;
  List<int>? get pendingBytes => _csvService.pendingBytes;
}
