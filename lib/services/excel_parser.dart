import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:retail_failure_simulator/services/aws_service.dart';

class ExcelParser {
  static Future<Map<String, dynamic>?> pickAndParse() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.first;
        List<int>? bytes = platformFile.bytes;

        if (bytes == null && platformFile.path != null) {
          final file = File(platformFile.path!);
          bytes = await file.readAsBytes();
        }

        if (bytes != null) {
          String s3Url = 'N/A';
          // Upload to S3 (Audit Log)
          try {
            final success = await AWSClient.uploadToS3(
              platformFile.name,
              bytes,
            );
            if (success) {
              s3Url = AWSClient.getS3Url(platformFile.name);
            }
          } catch (e) {
            print('S3 Upload Error: $e');
          }

          final text = _extractText(bytes);
          return {
            'fileName': platformFile.name,
            'content': text,
            's3Url': s3Url,
          };
        }
      }
    } catch (e) {
      print('Excel Error: $e');
    }
    return null;
  }

  static String _extractText(List<int> bytes) {
    try {
      var excel = Excel.decodeBytes(bytes);
      String text = '';
      int rowCount = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        for (var row in sheet.rows) {
          if (rowCount > 15) break;
          final rowData = row
              .map((e) => e?.value?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .join(', ');
          if (rowData.isNotEmpty) {
            text += '$rowData\n';
            rowCount++;
          }
        }
        if (rowCount > 15) break;
      }
      return text.isEmpty ? 'Empty file or unreadable tabular data.' : text;
    } catch (e) {
      return 'Unreadable Excel data formatting.';
    }
  }
}
