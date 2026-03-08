import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retail_failure_simulator/services/aws_service.dart';
import 'package:retail_failure_simulator/core/aws_config.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveProfile(
    String name,
    String email,
    String riskCategory, {
    String? phone,
    String? role,
    String? department,
    String? s3Url,
    Map<String, String>? metrics,
  }) async {
    await _prefs.setString('userName', name);
    await _prefs.setString('userEmail', email);
    await _prefs.setString('userRiskCategory', riskCategory);
    if (phone != null) await _prefs.setString('userPhone', phone);
    if (role != null) await _prefs.setString('userRole', role);
    if (department != null) {
      await _prefs.setString('userDepartment', department);
    }
    if (s3Url != null) await _prefs.setString('userS3Url', s3Url);

    // Backup to DynamoDB
    try {
      // 1. Save User Profile to RetailUsers
      final Map<String, dynamic> userItem = {
        "userId": {"S": email},
        "name": {"S": name},
        "riskCategory": {"S": riskCategory},
        "phone": {"S": phone ?? "N/A"},
        "role": {"S": role ?? "N/A"},
        "department": {"S": department ?? "N/A"},
        "s3Url": {"S": s3Url ?? "N/A"},
        "timestamp": {"S": DateTime.now().toIso8601String()},
      };

      if (metrics != null) {
        userItem["metrics"] = {
          "M": metrics.map((k, v) => MapEntry(k, {"S": v})),
        };
      }

      await AWSClient.saveToDynamoDB(userItem, tableName: AWSConfig.userTable);

      // 2. Save Metrics/Excel info to RetailExcelMetrics
      final existingMetrics = await AWSClient.getFromDynamoDB(
        email,
        tableName: AWSConfig.metricsTable,
      );
      List<String> history = [];
      if (existingMetrics != null && existingMetrics['fileHistory'] != null) {
        history = List<String>.from(
          existingMetrics['fileHistory']?['SS'] ?? [],
        );
      }
      if (s3Url != null && !history.contains(s3Url)) {
        history.add(s3Url);
      }

      final Map<String, dynamic> metricsItem = {
        "userId": {"S": email},
        "s3Url": {"S": s3Url ?? (existingMetrics?['s3Url']?['S'] ?? "N/A")},
        "fileHistory": {
          "SS": history.isEmpty ? ["INITIAL"] : history,
        },
        "timestamp": {"S": DateTime.now().toIso8601String()},
      };

      if (metrics != null) {
        metricsItem["metrics"] = {
          "M": metrics.map((k, v) => MapEntry(k, {"S": v})),
        };
      } else if (existingMetrics != null &&
          existingMetrics['metrics'] != null) {
        metricsItem["metrics"] = existingMetrics['metrics'];
      }

      await AWSClient.saveToDynamoDB(
        metricsItem,
        tableName: AWSConfig.metricsTable,
      );

      // 3. Log Activity
      await AWSClient.logActivity(email, "Profile updated/created");
    } catch (e) {
      print('DynamoDB Split Save Error: $e');
    }
  }

  static List<String> getUserFileHistory() {
    return _prefs.getStringList('userFileHistory') ?? [];
  }

  static Map<String, String> getUserMetrics() {
    final jsonStr = _prefs.getString('userMetrics');
    if (jsonStr == null) return {};
    return Map<String, String>.from(
      Map<String, dynamic>.from(Map<String, dynamic>.from(jsonDecode(jsonStr))),
    );
  }

  static Future<bool> syncProfileFromDB(String email) async {
    try {
      // Fetch from User table
      final userData = await AWSClient.getFromDynamoDB(
        email,
        tableName: AWSConfig.userTable,
      );
      // Fetch from Metrics table
      final metricsData = await AWSClient.getFromDynamoDB(
        email,
        tableName: AWSConfig.metricsTable,
      );

      if (userData != null) {
        await _prefs.setString('userName', userData['name']?['S'] ?? '');
        await _prefs.setString('userEmail', email);
        await _prefs.setString(
          'userRiskCategory',
          userData['riskCategory']?['S'] ?? '',
        );
        await _prefs.setString('userPhone', userData['phone']?['S'] ?? '');
        await _prefs.setString('userRole', userData['role']?['S'] ?? '');
        await _prefs.setString(
          'userDepartment',
          userData['department']?['S'] ?? '',
        );

        if (metricsData != null) {
          await _prefs.setString('userS3Url', metricsData['s3Url']?['S'] ?? '');
          final history = metricsData['fileHistory']?['SS'] ?? [];
          await _prefs.setStringList(
            'userFileHistory',
            List<String>.from(history),
          );

          if (metricsData['metrics'] != null) {
            final m = metricsData['metrics']['M'] as Map<String, dynamic>;
            final metricsMap = m.map((k, v) => MapEntry(k, v['S'].toString()));
            await _prefs.setString('userMetrics', jsonEncode(metricsMap));
          }
        }

        await AWSClient.logActivity(email, "Profile synced from Cloud");
        return true;
      }
    } catch (e) {
      print('Profile Split Sync Error: $e');
    }
    return false;
  }

  static String? getUserName() => _prefs.getString('userName');
  static String? getUserEmail() => _prefs.getString('userEmail');
  static String? getUserRiskCategory() => _prefs.getString('userRiskCategory');
  static String? getUserPhone() => _prefs.getString('userPhone');
  static String? getUserRole() => _prefs.getString('userRole');
  static String? getUserDepartment() => _prefs.getString('userDepartment');
  static String? getUserS3Url() => _prefs.getString('userS3Url');

  static bool get isLoggedIn => _prefs.getString('userEmail') != null;

  static Future<void> clearProfile() async {
    await _prefs.remove('userName');
    await _prefs.remove('userEmail');
    await _prefs.remove('userRiskCategory');
    await _prefs.remove('userPhone');
    await _prefs.remove('userRole');
    await _prefs.remove('userDepartment');
    await _prefs.remove('userS3Url');
  }
}
