import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:isdr/core/services/fcm_service.dart';

/// Service to handle all app permissions
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request all permissions required by the app
  /// Returns a map with permission status for each type
  Future<Map<PermissionType, PermissionStatus>> requestAllPermissions() async {
    final results = <PermissionType, PermissionStatus>{};

    // Request notifications permission
    results[PermissionType.notification] = await requestNotificationPermission();

    // Request camera permission
    results[PermissionType.camera] = await requestCameraPermission();

    // Request storage/gallery permission
    results[PermissionType.storage] = await requestStoragePermission();

    // Check internet permission (usually auto-granted)
    results[PermissionType.internet] = await checkInternetPermission();

    return results;
  }

  /// Request notification permission
  Future<PermissionStatus> requestNotificationPermission() async {
    try {
      if (Platform.isAndroid) {
        // For Android 13+, use permission_handler
        if (await _isAndroid13OrHigher()) {
          final status = await ph.Permission.notification.request();
          debugPrint('Android notification permission: $status');
          return _convertPermissionStatus(status);
        } else {
          // For Android < 13, notifications are granted by default
          return PermissionStatus.granted;
        }
      } else if (Platform.isIOS) {
        // One prompt only. FCMService asks after the app is active and then
        // waits for the APNs token. A second requestPermission here races
        // that prompt and iOS drops it.
        await FCMService().ensureInitialized();
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        debugPrint(
          'iOS notification permission: ${settings.authorizationStatus}',
        );
        return _convertIOSNotificationStatus(settings.authorizationStatus);
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
    return PermissionStatus.denied;
  }

  /// Request camera permission
  Future<PermissionStatus> requestCameraPermission() async {
    try {
      final status = await ph.Permission.camera.request();
      debugPrint('Camera permission: $status');
      return _convertPermissionStatus(status);
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request storage/gallery permission
  Future<PermissionStatus> requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        if (await _isAndroid13OrHigher()) {
          // Android 13+: image_picker/file_picker use the system photo picker;
          // READ_MEDIA_* must not be declared (Google Play photo policy).
          debugPrint(
            'Android 13+ gallery: using system picker, no storage permission needed',
          );
          return PermissionStatus.granted;
        } else {
          // Android < 13 uses external storage
          final status = await ph.Permission.storage.request();
          debugPrint('Android storage permission: $status');
          return _convertPermissionStatus(status);
        }
      } else if (Platform.isIOS) {
        // iOS uses photos permission
        final status = await ph.Permission.photos.request();
        debugPrint('iOS photos permission: $status');
        return _convertPermissionStatus(status);
      }
    } catch (e) {
      debugPrint('Error requesting storage permission: $e');
    }
    return PermissionStatus.denied;
  }

  /// Check internet permission (usually auto-granted on both platforms)
  Future<PermissionStatus> checkInternetPermission() async {
    try {
      // Internet permission is typically auto-granted
      // We'll check if we can make a network request by checking the permission status
      // Note: permission_handler doesn't have a direct internet permission
      // This is usually handled at the OS level
      return PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error checking internet permission: $e');
      return PermissionStatus.denied;
    }
  }

  /// Check if a specific permission is granted
  Future<bool> isPermissionGranted(PermissionType type) async {
    switch (type) {
      case PermissionType.notification:
        if (Platform.isAndroid && await _isAndroid13OrHigher()) {
          final status = await ph.Permission.notification.status;
          return status.isGranted;
        } else if (Platform.isIOS) {
          final messaging = FirebaseMessaging.instance;
          final settings = await messaging.getNotificationSettings();
          return settings.authorizationStatus == AuthorizationStatus.authorized ||
                 settings.authorizationStatus == AuthorizationStatus.provisional;
        }
        return true; // Android < 13 grants by default
      case PermissionType.camera:
        final status = await ph.Permission.camera.status;
        return status.isGranted;
      case PermissionType.storage:
        if (Platform.isAndroid && await _isAndroid13OrHigher()) {
          return true;
        } else if (Platform.isAndroid) {
          final status = await ph.Permission.storage.status;
          return status.isGranted;
        } else {
          final status = await ph.Permission.photos.status;
          return status.isGranted;
        }
      case PermissionType.internet:
        return true; // Usually auto-granted
    }
  }

  /// Open app settings if permission is permanently denied
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  /// Check if Android version is 13 or higher
  /// Android 13 (API 33) introduced granular media permissions
  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33;
    } catch (e) {
      debugPrint('Error checking Android version: $e');
      return false;
    }
  }

  /// Convert permission_handler PermissionStatus to our PermissionStatus enum
  PermissionStatus _convertPermissionStatus(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
      case ph.PermissionStatus.limited:
      case ph.PermissionStatus.provisional:
        return PermissionStatus.granted;
      case ph.PermissionStatus.denied:
        return PermissionStatus.denied;
      case ph.PermissionStatus.restricted:
      case ph.PermissionStatus.permanentlyDenied:
        return PermissionStatus.permanentlyDenied;
    }
  }

  /// Convert iOS notification authorization status to PermissionStatus
  PermissionStatus _convertIOSNotificationStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PermissionStatus.granted;
      case AuthorizationStatus.denied:
        return PermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return PermissionStatus.denied;
    }
  }
}

/// Enum for permission types
enum PermissionType {
  notification,
  camera,
  storage,
  internet,
}

/// Enum for permission status
enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}
