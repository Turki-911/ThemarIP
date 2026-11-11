import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'notification_stub.dart'
    if (dart.library.js) 'notification_web.dart';

class IntelligenceAlert {
  final String id;
  final String ruleId;
  final String ruleName;
  final String ruleType;
  final String userId;
  final String userName;
  final String message;
  final String channel;
  final String deliveryStatus;
  final bool isRead;
  final DateTime triggeredAt;

  IntelligenceAlert({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.ruleType,
    required this.userId,
    required this.userName,
    required this.message,
    required this.channel,
    required this.deliveryStatus,
    required this.isRead,
    required this.triggeredAt,
  });

  factory IntelligenceAlert.fromJson(Map<String, dynamic> json) {
    return IntelligenceAlert(
      id: json['id']?.toString() ?? '',
      ruleId: json['ruleId']?.toString() ?? '',
      ruleName: json['ruleName']?.toString() ?? 'Budget Alert',
      ruleType: json['ruleType']?.toString() ?? 'BudgetThreshold',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      channel: json['channel']?.toString() ?? 'Push Notification',
      deliveryStatus: json['deliveryStatus']?.toString() ?? 'Delivered',
      isRead: json['isRead'] == true || json['isRead'] == 1,
      triggeredAt: json['triggeredAt'] != null
          ? DateTime.tryParse(json['triggeredAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(triggeredAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${triggeredAt.day}/${triggeredAt.month}';
  }
}

class AlertService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// Fetch alerts for the user
  static Future<List<IntelligenceAlert>> fetchAlerts(String userId) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.intelligenceAlerts}?userId=$userId';
      final res = await _dio.get(url);
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((item) => IntelligenceAlert.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('AlertService.fetchAlerts error: $e');
    }
    return [];
  }

  /// Mark single alert as read
  static Future<bool> markAsRead(String alertId) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.intelligenceAlerts}/$alertId/read';
      final res = await _dio.post(url);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('AlertService.markAsRead error: $e');
      return false;
    }
  }

  /// Mark all alerts as read for user
  static Future<bool> markAllAsRead(String userId) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.intelligenceAlerts}/mark-all-read?userId=$userId';
      final res = await _dio.post(url);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('AlertService.markAllAsRead error: $e');
      return false;
    }
  }

  /// Trigger rule evaluation for user (e.g. on budget change or app launch)
  static Future<void> triggerEvaluation(String userId) async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.evaluateIntelligenceRules}?userId=$userId';
      await _dio.post(url, data: {'userId': userId, 'force': false});
    } catch (e) {
      debugPrint('AlertService.triggerEvaluation notice: $e');
    }
  }

  /// Dispatches browser notification if supported
  static void notifyPlatform(String title, String body) {
    if (kIsWeb) {
      triggerWebNotification(title, body);
    }
  }
}
