import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import '../../../services/storage_service.dart';
import '../../../services/aws_service.dart';

class CsvRecord {
  final String date;
  final String region;
  final String storeId;
  final String productId;
  final String productCategory;
  final double price;
  final int demand;
  final int actualSales;
  final int lostSales;
  final double revenue;
  final int stockLevel;
  final int replenishmentQty;
  final double holdingCost;
  final int stockoutFlag;
  final int overstockFlag;
  final double sellerQualityScore;
  final int promotionFlag;

  CsvRecord({
    required this.date,
    required this.region,
    required this.storeId,
    required this.productId,
    required this.productCategory,
    required this.price,
    required this.demand,
    required this.actualSales,
    required this.lostSales,
    required this.revenue,
    required this.stockLevel,
    required this.replenishmentQty,
    required this.holdingCost,
    required this.stockoutFlag,
    required this.overstockFlag,
    required this.sellerQualityScore,
    required this.promotionFlag,
  });
}

class CsvDataService {
  static const String _assetPath =
      'assets/data/enterprise_retail_risk_dataset.csv';

  List<CsvRecord> _records = [];
  bool _isLoaded = false;
  String? _loadedFilePath;

  List<CsvRecord> get records => _records;
  bool get isLoaded => _isLoaded;
  String? get loadedFilePath => _loadedFilePath;

  /// Load CSV from the bundled asset (works on Android / iOS / all platforms)
  Future<bool> loadDefaultCsv() async {
    try {
      final csvString = await rootBundle.loadString(_assetPath);
      final rows = csv.decode(csvString);
      return _processRows(rows, source: _assetPath);
    } catch (e) {
      return false;
    }
  }

  List<int>? _pendingBytes;
  String? _pendingFileName;

  List<int>? get pendingBytes => _pendingBytes;
  String? get pendingFileName => _pendingFileName;

  /// Just picks a file and stores it in memory
  Future<bool> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      _pendingBytes = result.files.single.bytes!;
      _pendingFileName = result.files.single.name;
      return true;
    }
    return false;
  }

  /// Uploads and processes the pending file
  Future<bool> processPendingFile() async {
    if (_pendingBytes == null || _pendingFileName == null) return false;

    final bytes = _pendingBytes!;
    final name = _pendingFileName!;

    // Auto-upload to S3 if logged in
    if (StorageService.isLoggedIn) {
      print("CSV: User logged in. Auto-uploading $name to S3...");
      final success = await AWSClient.uploadToS3(name, bytes);
      if (success) {
        final url = AWSClient.getS3Url(name);
        print("CSV: Upload successful. S3 URL: $url");

        // Update profile with new S3 URL if it's different from current
        if (StorageService.getUserS3Url() != url) {
          await StorageService.saveProfile(
            StorageService.getUserName() ?? "User",
            StorageService.getUserEmail() ?? "",
            StorageService.getUserRiskCategory() ?? "General",
            phone: StorageService.getUserPhone(),
            role: StorageService.getUserRole(),
            department: StorageService.getUserDepartment(),
            s3Url: url,
          );
        }
      }
    }

    final success = await loadFromBytes(bytes, name);
    if (success) {
      _pendingBytes = null;
      _pendingFileName = null;
    }
    return success;
  }

  /// Let user pick a CSV/Excel file (Legacy support)
  Future<bool> pickAndLoadFile() async {
    final picked = await pickFile();
    if (picked) return processPendingFile();
    return false;
  }

  /// Load from an S3 or other public URL
  Future<bool> loadFromUrl(String url) async {
    try {
      print("CSV: Fetching data from URL: $url");
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return loadFromBytes(response.bodyBytes, url);
      } else {
        print("CSV: Error fetching URL: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("CSV: URL Load Error: $e");
      return false;
    }
  }

  Future<bool> loadFromBytes(List<int> bytes, String sourceName) async {
    try {
      if (sourceName.toLowerCase().endsWith('.xlsx') ||
          sourceName.toLowerCase().endsWith('.xls')) {
        print("CSV: Decoding Excel from bytes...");
        var excel = Excel.decodeBytes(bytes);
        if (excel.tables.isEmpty) return false;

        final rows = <List<dynamic>>[];
        for (var table in excel.tables.keys) {
          final tableRows = excel.tables[table]!.rows;
          if (tableRows.length <= 1) continue;

          for (var row in tableRows) {
            rows.add(
              row.map((e) {
                if (e == null) return '';
                final val = e.value;
                if (val == null) return '';
                if (val is TextCellValue) return val.value;
                if (val is IntCellValue) return val.value.toString();
                if (val is DoubleCellValue) return val.value.toString();
                if (val is DateCellValue) return val.toString();
                if (val is BoolCellValue) return val.value.toString();
                return val.toString();
              }).toList(),
            );
          }
          if (rows.length > 1) break;
          rows.clear();
        }
        return _processRows(rows, source: sourceName);
      } else {
        print("CSV: Decoding CSV from bytes...");
        final csvString = String.fromCharCodes(bytes);
        final rows = csv.decode(csvString);
        return _processRows(rows, source: sourceName);
      }
    } catch (e) {
      print("CSV: Bytes load error: $e");
      return false;
    }
  }

  bool _processRows(List<List<dynamic>> rows, {required String source}) {
    try {
      // Skip header row
      _records = [];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (i < 5) print("CSV: Row $i length: ${row.length}");
        if (row.length < 3) continue;

        try {
          final String cat = row.length > 4
              ? row[4].toString()
              : (row.length > 0 ? row[0].toString() : 'Category');
          final String prod = row.length > 3
              ? row[3].toString()
              : (row.length > 1 ? row[1].toString() : 'Product');
          final String store = row.length > 2 ? row[2].toString() : 'Store-A';
          final String reg = row.length > 1 ? row[1].toString() : 'Global';
          final String dt = row.length > 0 ? row[0].toString() : '2024';

          _records.add(
            CsvRecord(
              date: dt,
              region: reg,
              storeId: store,
              productId: prod,
              productCategory: cat,
              price: row.length > 5 ? _toDouble(row[5]) : 99.0,
              demand: row.length > 6 ? _toInt(row[6]) : 50,
              actualSales: row.length > 7 ? _toInt(row[7]) : 45,
              lostSales: row.length > 8 ? _toInt(row[8]) : 5,
              revenue: row.length > 9
                  ? _toDouble(row[9])
                  : (row.length > 2 ? _toDouble(row[2]) : 1500.0),
              stockLevel: row.length > 10 ? _toInt(row[10]) : 20,
              replenishmentQty: row.length > 11 ? _toInt(row[11]) : 0,
              holdingCost: row.length > 12 ? _toDouble(row[12]) : 5.0,
              stockoutFlag: row.length > 13
                  ? _toInt(row[13])
                  : (i % 8 == 0 ? 1 : 0),
              overstockFlag: row.length > 14
                  ? _toInt(row[14])
                  : (i % 12 == 0 ? 1 : 0),
              sellerQualityScore: row.length > 15 ? _toDouble(row[15]) : 0.88,
              promotionFlag: row.length > 16 ? _toInt(row[16]) : 0,
            ),
          );
        } catch (e) {
          print("CSV: Skip row $i: $e");
        }
      }

      _isLoaded = _records.isNotEmpty;
      _loadedFilePath = source;
      print(
        "CSV: _processRows finished. records count: ${_records.length}, isLoaded: $_isLoaded",
      );
      return _isLoaded;
    } catch (e) {
      print("CSV: _processRows error: $e");
      return false;
    }
  }

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v == null || v == '') return 0.0;

    // In case the value is wrapped in TextCellValue(value: "..."), strip strings
    String s = v.toString();
    if (s.contains('value: "')) {
      s = s.split('value: "')[1].split('")')[0];
    } else if (s.contains('TextCellValue(')) {
      s = s.replaceAll('TextCellValue(', '').replaceAll(')', '');
    } else if (s.contains('IntCellValue(')) {
      s = s.replaceAll('IntCellValue(', '').replaceAll(')', '');
    } else if (s.contains('DoubleCellValue(')) {
      s = s.replaceAll('DoubleCellValue(', '').replaceAll(')', '');
    }
    return double.tryParse(s) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v == null || v == '') return 0;

    String s = v.toString();
    if (s.contains('value: "')) {
      s = s.split('value: "')[1].split('")')[0];
    } else if (s.contains('TextCellValue(')) {
      s = s.replaceAll('TextCellValue(', '').replaceAll(')', '');
    } else if (s.contains('IntCellValue(')) {
      s = s.replaceAll('IntCellValue(', '').replaceAll(')', '');
    } else if (s.contains('DoubleCellValue(')) {
      s = s.replaceAll('DoubleCellValue(', '').replaceAll(')', '');
    }
    return int.tryParse(s) ?? double.tryParse(s)?.toInt() ?? 0;
  }
}
