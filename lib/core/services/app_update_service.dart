import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart' hide AppUpdateInfo;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_update_config.dart';
import '../models/app_update_info.dart';

class AppUpdateService {
  String? _iosStoreUrl;

  /// Returns update info when a store update is required, otherwise null.
  Future<AppUpdateInfo?> checkForStoreUpdate() async {
    if (kIsWeb) return null;
    if (kDebugMode) {
      debugPrint('Store update check skipped in debug mode');
      return null;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (Platform.isAndroid) {
        return _checkAndroidStoreUpdate(currentVersion);
      }
      if (Platform.isIOS) {
        return _checkIosStoreUpdate(currentVersion);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Store update check skipped: $e');
      }
    }

    return null;
  }

  /// Triggers platform-specific store update flow.
  Future<StoreUpdateOutcome> performStoreUpdate(AppUpdateInfo info) async {
    if (info.isAndroid) {
      return _performAndroidImmediateUpdate();
    }
    if (info.isIos) {
      return _openIosAppStore(info.storeUrl ?? _iosStoreUrl);
    }
    return StoreUpdateOutcome.failed;
  }

  Future<AppUpdateInfo?> _checkAndroidStoreUpdate(String currentVersion) async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      final availability = updateInfo.updateAvailability;

      if (availability == UpdateAvailability.updateAvailable ||
          availability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        return AppUpdateInfo.android(currentVersion: currentVersion);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Android update check skipped: $e');
      }
    }
    return null;
  }

  Future<AppUpdateInfo?> _checkIosStoreUpdate(String currentVersion) async {
    try {
      final response = await http
          .get(Uri.parse(AppUpdateConfig.appStoreLookupUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final appData = results.first as Map<String, dynamic>;
      final storeVersion = appData['version'] as String?;
      final trackViewUrl = appData['trackViewUrl'] as String?;

      if (storeVersion == null || trackViewUrl == null) return null;
      if (!_isVersionBehind(currentVersion, storeVersion)) return null;

      _iosStoreUrl = trackViewUrl;
      return AppUpdateInfo.ios(
        currentVersion: currentVersion,
        latestVersion: storeVersion,
        storeUrl: trackViewUrl,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('iOS update check skipped: $e');
      }
    }
    return null;
  }

  Future<StoreUpdateOutcome> _performAndroidImmediateUpdate() async {
    try {
      final result = await InAppUpdate.performImmediateUpdate();
      switch (result) {
        case AppUpdateResult.success:
          return StoreUpdateOutcome.success;
        case AppUpdateResult.userDeniedUpdate:
          return StoreUpdateOutcome.userDenied;
        case AppUpdateResult.inAppUpdateFailed:
          return StoreUpdateOutcome.failed;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Android immediate update failed: $e');
      }
      return StoreUpdateOutcome.failed;
    }
  }

  Future<StoreUpdateOutcome> _openIosAppStore(String? storeUrl) async {
    final url = storeUrl ?? _iosStoreUrl;
    if (url == null) return StoreUpdateOutcome.failed;
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return launched ? StoreUpdateOutcome.storeOpened : StoreUpdateOutcome.failed;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to open App Store: $e');
      }
      return StoreUpdateOutcome.failed;
    }
  }

  bool _isVersionBehind(String current, String latest) {
    final currentParts = _parseVersionParts(current);
    final latestParts = _parseVersionParts(latest);
    final length = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (var i = 0; i < length; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      if (currentPart < latestPart) return true;
      if (currentPart > latestPart) return false;
    }
    return false;
  }

  List<int> _parseVersionParts(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
