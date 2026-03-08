import 'dart:convert';
import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'package:http/http.dart' as http;
import '../core/aws_config.dart';

class AWSClient {
  static final AWSSigV4Signer _signer = AWSSigV4Signer(
    credentialsProvider: const AWSCredentialsProvider(
      AWSCredentials(AWSConfig.accessKey, AWSConfig.secretKey),
    ),
  );

  static Future<String?> invokeBedrock(String prompt) async {
    final host = AWSConfig.bedrockHost;
    final region = AWSConfig.region;
    const service = 'bedrock';
    final url = Uri.parse(
      'https://$host/model/anthropic.claude-3-haiku-20240307-v1:0/invoke',
    );

    final payload = jsonEncode({
      "anthropic_version": "bedrock-2023-05-31",
      "max_tokens": 1024,
      "messages": [
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
          ],
        },
      ],
    });

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: url,
      headers: {
        'Content-Type': 'application/json',
        'X-Amz-Target': 'InvokeModel',
      },
      body: utf8.encode(payload),
    );

    try {
      final signedRequest = await _signer.sign(
        request,
        credentialScope: AWSCredentialScope.raw(
          region: region,
          service: service,
        ),
      );

      final response = await http.post(
        url,
        headers: {...request.headers, ...await signedRequest.headers},
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['content'][0]['text'];
        print('Bedrock AI Response: $result');
        return result;
      } else {
        print('Bedrock Error: ${response.statusCode}');
        print('Bedrock Response Body: ${response.body}');
      }
    } catch (e) {
      print('Bedrock Exception: $e');
    }
    return null;
  }

  static Future<String?> invokeSageMaker(Map<String, dynamic> data) async {
    final host = AWSConfig.sageMakerHost;
    final region = AWSConfig.region;
    const service = 'sagemaker';
    final url = Uri.parse(
      'https://$host/endpoints/retail-failure-prediction/invocations',
    );

    final payload = jsonEncode(data);

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: url,
      headers: {'Content-Type': 'application/json'},
      body: utf8.encode(payload),
    );

    try {
      final signedRequest = await _signer.sign(
        request,
        credentialScope: AWSCredentialScope.raw(
          region: region,
          service: service,
        ),
      );

      final response = await http.post(
        url,
        headers: {...request.headers, ...await signedRequest.headers},
        body: payload,
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        print('SageMaker Error: ${response.statusCode}');
        print('SageMaker Response Body: ${response.body}');
      }
    } catch (e) {
      print('SageMaker Exception: $e');
    }
    return null;
  }

  static Future<bool> uploadToS3(String fileName, List<int> bytes) async {
    final bucket = AWSConfig.s3Bucket;
    final region = AWSConfig.region;
    final host = '$bucket.s3.$region.amazonaws.com';

    // Sanitize filename to avoid signature mismatches from special characters
    final safeName = fileName.replaceAll(' ', '_');
    final path = safeName.startsWith('/') ? safeName : '/$safeName';
    final url = Uri.https(host, path);

    // Using UNSIGNED-PAYLOAD for S3 simplifies signing with complex binary data
    const contentHash = 'UNSIGNED-PAYLOAD';

    final request = AWSHttpRequest(
      method: AWSHttpMethod.put,
      uri: url,
      headers: {
        'Content-Type': 'application/octet-stream',
        'Host': host,
        'x-amz-content-sha256': contentHash,
      },
      body: bytes,
    );

    try {
      final signedRequest = await _signer.sign(
        request,
        credentialScope: AWSCredentialScope.raw(region: region, service: 's3'),
      );

      final response = await http.put(
        url,
        headers: {...request.headers, ...await signedRequest.headers},
        body: bytes,
      );

      if (response.statusCode == 200) {
        print('S3 File URL: $url');
      } else {
        print('S3 Upload Status: ${response.statusCode}');
        print('S3 Upload Body: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      print('S3 Upload Exception: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getFromDynamoDB(
    String email, {
    String? tableName,
  }) async {
    final host = AWSConfig.dynamoDBHost;
    final region = AWSConfig.region;
    const service = 'dynamodb';
    final url = Uri.parse('https://$host/');
    final table = tableName ?? AWSConfig.userTable;

    final payload = jsonEncode({
      "TableName": table,
      "Key": {
        "userId": {"S": email},
      },
    });

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: url,
      headers: {
        'Content-Type': 'application/x-amz-json-1.0',
        'X-Amz-Target': 'DynamoDB_20120810.GetItem',
      },
      body: utf8.encode(payload),
    );

    try {
      final signedRequest = await _signer.sign(
        request,
        credentialScope: AWSCredentialScope.raw(
          region: region,
          service: service,
        ),
      );

      final response = await http.post(
        url,
        headers: {...request.headers, ...await signedRequest.headers},
        body: payload,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Item'] != null) {
          return data['Item'];
        }
      } else {
        print('DynamoDB Get Status: ${response.statusCode}');
        print('DynamoDB Get Error Body: ${response.body}');
      }
    } catch (e) {
      print('DynamoDB Get Exception: $e');
    }
    return null;
  }

  static String getS3Url(String fileName) {
    return 'https://${AWSConfig.s3Bucket}.s3.${AWSConfig.region}.amazonaws.com/$fileName';
  }

  static Future<bool> saveToDynamoDB(
    Map<String, dynamic> item, {
    String? tableName,
  }) async {
    final host = AWSConfig.dynamoDBHost;
    final region = AWSConfig.region;
    const service = 'dynamodb';
    final url = Uri.parse('https://$host/');
    final table = tableName ?? AWSConfig.userTable;

    final payload = jsonEncode({"TableName": table, "Item": item});

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: url,
      headers: {
        'Content-Type': 'application/x-amz-json-1.0',
        'X-Amz-Target': 'DynamoDB_20120810.PutItem',
      },
      body: utf8.encode(payload),
    );

    try {
      final signedRequest = await _signer.sign(
        request,
        credentialScope: AWSCredentialScope.raw(
          region: region,
          service: service,
        ),
      );

      final response = await http.post(
        url,
        headers: {...request.headers, ...await signedRequest.headers},
        body: payload,
      );

      if (response.statusCode == 200) {
        print('DynamoDB Row Created/Updated: $payload');
      } else {
        final body = response.body;
        print('DynamoDB Put Status: ${response.statusCode}');
        print('DynamoDB Put Error Body: $body');

        if (body.contains('ResourceNotFoundException') ||
            body.contains('Table is being created')) {
          print(
            'DynamoDB: Table $table is missing or being created. Waiting...',
          );
          if (body.contains('ResourceNotFoundException')) {
            await createDynamoDBTable(tableName: table);
          }
          await Future.delayed(const Duration(seconds: 10));
          return saveToDynamoDB(item, tableName: table);
        }
      }
      return response.statusCode == 200;
    } catch (e) {
      print('DynamoDB Exception: $e');
      return false;
    }
  }

  static Future<bool> createDynamoDBTable({String? tableName}) async {
    final host = AWSConfig.dynamoDBHost;
    final region = AWSConfig.region;
    const service = 'dynamodb';
    final url = Uri.parse('https://$host/');
    final table = tableName ?? AWSConfig.userTable;

    final isLogsTable = table == AWSConfig.logsTable;

    final payload = jsonEncode({
      "TableName": table,
      "KeySchema": [
        {"AttributeName": "userId", "KeyType": "HASH"},
        if (isLogsTable) {"AttributeName": "activityId", "KeyType": "RANGE"},
      ],
      "AttributeDefinitions": [
        {"AttributeName": "userId", "AttributeType": "S"},
        if (isLogsTable) {"AttributeName": "activityId", "AttributeType": "S"},
      ],
      "ProvisionedThroughput": {
        "ReadCapacityUnits": 5,
        "WriteCapacityUnits": 5,
      },
    });

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: url,
      headers: {
        'Content-Type': 'application/x-amz-json-1.0',
        'X-Amz-Target': 'DynamoDB_20120810.CreateTable',
      },
      body: utf8.encode(payload),
    );

    try {
      final signedRequest = await _signer.sign(
        request,
        credentialScope: AWSCredentialScope.raw(
          region: region,
          service: service,
        ),
      );

      final response = await http.post(
        url,
        headers: {...request.headers, ...await signedRequest.headers},
        body: payload,
      );

      print('DynamoDB CreateTable Status: ${response.statusCode}');
      print('DynamoDB CreateTable Response: ${response.body}');
      return response.statusCode == 200 ||
          response.body.contains('ResourceInUseException');
    } catch (e) {
      print('DynamoDB CreateTable Exception: $e');
      return false;
    }
  }

  static Future<bool> saveMetrics(
    String email,
    Map<String, dynamic> metrics,
  ) async {
    final host = AWSConfig.dynamoDBHost;
    final region = AWSConfig.region;
    const service = 'dynamodb';
    final url = Uri.parse('https://$host/');

    final payload = jsonEncode({
      "TableName": AWSConfig.metricsTable,
      "Key": {
        "userId": {"S": email},
      },
      "UpdateExpression": "SET metrics = :m, lastUpdate = :t",
      "ExpressionAttributeValues": {
        ":m": {
          "M": metrics.map((k, v) => MapEntry(k, {"S": v.toString()})),
        },
        ":t": {"S": DateTime.now().toIso8601String()},
      },
    });

    final request = AWSHttpRequest(
      method: AWSHttpMethod.post,
      uri: url,
      headers: {
        'Content-Type': 'application/x-amz-json-1.0',
        'X-Amz-Target': 'DynamoDB_20120810.UpdateItem',
      },
      body: utf8.encode(payload),
    );

    try {
      final signedRequest = await _signer.sign(
        request,
        credentialScope: AWSCredentialScope.raw(
          region: region,
          service: service,
        ),
      );

      final response = await http.post(
        url,
        headers: {...request.headers, ...await signedRequest.headers},
        body: payload,
      );

      print('DynamoDB UpdateMetrics Status: ${response.statusCode}');
      if (response.statusCode != 200 &&
          response.body.contains('ResourceNotFoundException')) {
        print('DynamoDB: Metrics table not found. Creating...');
        await createDynamoDBTable(tableName: AWSConfig.metricsTable);
        await Future.delayed(const Duration(seconds: 5));
        return saveMetrics(email, metrics);
      }
      return response.statusCode == 200;
    } catch (e) {
      print('DynamoDB UpdateMetrics Exception: $e');
      return false;
    }
  }

  static Future<List<String>> listS3Files() async {
    final bucket = AWSConfig.s3Bucket;
    final region = AWSConfig.region;
    final host = '$bucket.s3.$region.amazonaws.com';
    final url = Uri.https(host, '/');

    final request = AWSHttpRequest(method: AWSHttpMethod.get, uri: url);

    try {
      final signedRequest = await _signer.sign(
        request,
        credentialScope: AWSCredentialScope.raw(
          region: AWSConfig.region,
          service: 's3',
        ),
      );

      final response = await http.get(
        url,
        headers: {...request.headers, ...await signedRequest.headers},
      );

      if (response.statusCode == 200) {
        final keys = RegExp(
          r'<Key>(.*?)</Key>',
        ).allMatches(response.body).map((m) => m.group(1)!).toList();
        return keys;
      }
    } catch (e) {
      print('S3 List Exception: $e');
    }
    return [];
  }

  static Future<bool> logActivity(String email, String activity) async {
    final item = {
      "userId": {"S": email},
      "activityId": {"S": DateTime.now().millisecondsSinceEpoch.toString()},
      "activity": {"S": activity},
      "timestamp": {"S": DateTime.now().toIso8601String()},
    };

    // For logs we need a slightly different schema if we want to query by something else,
    // but for now we'll use userId as hash and a generated activityId.
    // However, createDynamoDBTable currently only supports HASH key 'userId'.
    // Let's add a special check for the logs table creation.

    return saveToDynamoDB(item, tableName: AWSConfig.logsTable);
  }
}
