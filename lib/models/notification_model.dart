
enum UrgencyLevel { critical, high, moderate, low }

class RetailNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String intelReport;
  final UrgencyLevel urgency;

  RetailNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.intelReport,
    this.urgency = UrgencyLevel.moderate,
  });
}
