enum StoreUpdateOutcome {
  success,
  userDenied,
  failed,
  storeOpened,
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.isRequired,
    required this.currentVersion,
    this.latestVersion,
    required this.platform,
    this.storeUrl,
  });

  final bool isRequired;
  final String currentVersion;
  final String? latestVersion;
  final String platform;
  final String? storeUrl;

  factory AppUpdateInfo.android({
    required String currentVersion,
    String? latestVersion,
  }) {
    return AppUpdateInfo(
      isRequired: true,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      platform: 'android',
    );
  }

  factory AppUpdateInfo.ios({
    required String currentVersion,
    required String latestVersion,
    required String storeUrl,
  }) {
    return AppUpdateInfo(
      isRequired: true,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      platform: 'ios',
      storeUrl: storeUrl,
    );
  }

  bool get isAndroid => platform == 'android';
  bool get isIos => platform == 'ios';
}
