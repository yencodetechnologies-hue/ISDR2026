import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationHandler {
  static void handleNotificationTap(RemoteMessage message, BuildContext context) {
    final data = message.data;
    final type = data['type'] as String?;

    debugPrint('Notification tapped: $type');

    // Navigate based on notification type
    switch (type) {
      case 'maintenance':
        // Navigate to maintenance page
        // Navigator.pushNamed(context, '/maintenance');
        break;
      case 'payment':
        // Navigate to payments page
        // Navigator.pushNamed(context, '/payments');
        break;
      case 'complaint':
        // Navigate to complaints page
        // Navigator.pushNamed(context, '/complaints');
        break;
      case 'visitor':
        // Navigate to visitors page
        // Navigator.pushNamed(context, '/visitors');
        break;
      case 'notice':
        // Navigate to notices page
        // Navigator.pushNamed(context, '/notices');
        break;
      case 'message':
        // Navigate to messages page
        // Navigator.pushNamed(context, '/messages');
        break;
      default:
        // Navigate to notifications page
        // Navigator.pushNamed(context, '/notifications');
        break;
    }
  }

  static void handleDataPayload(Map<String, dynamic> data, BuildContext context) {
    final type = data['type'] as String?;
    debugPrint('Handling data payload: $type');
    // Handle deep linking based on data payload
    handleNotificationTap(
      RemoteMessage(data: data),
      context,
    );
  }
}
