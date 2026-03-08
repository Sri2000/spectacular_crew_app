class AWSConfig {
  static const String region = 'eu-west-1';
  static const String accessKey = '';
  static const String secretKey = '';
  static const String s3Bucket = 'spectacular-crew-retail-data';

  // Bedrock Endpoint
  static const String bedrockHost = 'bedrock-runtime.$region.amazonaws.com';
  // SageMaker Endpoint
  static const String sageMakerHost = 'runtime.sagemaker.$region.amazonaws.com';
  // DynamoDB Endpoint
  static const String dynamoDBHost = 'dynamodb.$region.amazonaws.com';

  // Table Names
  static const String userTable = 'RetailUsers';
  static const String metricsTable = 'RetailExcelMetrics';
  static const String logsTable = 'RetailActivityLogs';
}
