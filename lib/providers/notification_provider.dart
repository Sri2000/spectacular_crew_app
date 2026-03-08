import 'package:flutter/material.dart';
import 'package:retail_failure_simulator/models/notification_model.dart';
import 'package:retail_failure_simulator/services/intel_service.dart';
import 'package:retail_failure_simulator/models/failure_risk.dart';
import 'package:retail_failure_simulator/services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final List<RetailNotification> _notifications = [];
  final IntelService _intelService = IntelService();
  bool _isGenerating = false;

  List<RetailNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isGenerating => _isGenerating;
  RetailNotification? _latestPopup;
  RetailNotification? get latestPopup => _latestPopup;

  void addNotification(RetailNotification notification) {
    _notifications.insert(0, notification);
    _latestPopup = notification;
    notifyListeners();
  }

  void clearPopup() {
    _latestPopup = null;
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = RetailNotification(
        id: _notifications[index].id,
        title: _notifications[index].title,
        message: _notifications[index].message,
        timestamp: _notifications[index].timestamp,
        intelReport: _notifications[index].intelReport,
        urgency: _notifications[index].urgency,
        isRead: true,
      );
      notifyListeners();
    }
  }

  Future<void> generateRiskAlert(FailureRisk risk) async {
    _isGenerating = true;
    notifyListeners();

    try {
      final aiInsight = await _intelService.getIntelInsight(risk);

      UrgencyLevel urgency;
      if (risk.propagationScore >= 90) {
        urgency = UrgencyLevel.critical;
      } else if (risk.propagationScore >= 75) {
        urgency = UrgencyLevel.high;
      } else if (risk.propagationScore >= 50) {
        urgency = UrgencyLevel.moderate;
      } else {
        urgency = UrgencyLevel.low;
      }

      final label = urgency.toString().split('.').last.toUpperCase();
      final newNotification = RetailNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '$label ALERT: ${risk.title}',
        message:
            'Detected $label propagation risk in ${risk.subTitle}. Score: ${risk.propagationScore}',
        timestamp: DateTime.now(),
        intelReport: aiInsight,
        urgency: urgency,
      );

      addNotification(newNotification);

      await MobileNotificationService.showNotification(
        id: int.parse(
          newNotification.id.substring(newNotification.id.length - 8),
        ),
        title: newNotification.title,
        body: newNotification.message,
      );
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }
}
