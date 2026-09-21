import 'package:dio/dio.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/services/api_service.dart';
import 'package:flutter/foundation.dart';

class NotificationRepository {
  final ApiService _apiService = ApiService();

  /// Get notifications with pagination and filters
  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? read,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (type != null) queryParams['type'] = type;
      if (read != null) queryParams['read'] = read.toString();

      final response = await _apiService.get(
        ApiConfig.getNotifications,
        queryParameters: queryParams,
      );

      if (response['success'] == true) {
        final notifications = (response['notifications'] as List)
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        return {
          'success': true,
          'notifications': notifications,
          'pagination': response['pagination'],
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to fetch notifications',
        };
      }
    } catch (e) {
      debugPrint('Get notifications error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get(ApiConfig.getUnreadCount);
      if (response['success'] == true) {
        return response['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Get unread count error: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _apiService.put(
        ApiConfig.markAsReadUrl(notificationId),
      );
      return response['success'] == true;
    } catch (e) {
      debugPrint('Mark as read error: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiService.put(ApiConfig.markAllAsRead);
      return response['success'] == true;
    } catch (e) {
      debugPrint('Mark all as read error: $e');
      return false;
    }
  }

  /// Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final response = await _apiService.delete(
        ApiConfig.deleteNotificationUrl(notificationId),
      );
      return response['success'] == true;
    } catch (e) {
      debugPrint('Delete notification error: $e');
      return false;
    }
  }
}
