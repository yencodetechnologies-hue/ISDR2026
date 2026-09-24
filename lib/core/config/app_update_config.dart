/// Store identifiers and static release notes for the in-app update screen.
class AppUpdateConfig {
  AppUpdateConfig._();

  static const String androidPackageId = 'com.yencode.isdr';
  static const String iosBundleId = 'com.yencode.isdr';

  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$androidPackageId';

  static String get appStoreLookupUrl =>
      'https://itunes.apple.com/lookup?bundleId=$iosBundleId';

  /// Edit per release until a backend version endpoint exists.
  static const List<String> releaseNotes = [
    'Improved performance and stability',
    'Enhanced security and visitor management',
    'Bug fixes and UI improvements',
  ];
}
