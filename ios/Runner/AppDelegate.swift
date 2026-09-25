import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Dart also calls Firebase.initializeApp. Configure here so the APNs
    // token can be stored even if it arrives before the Dart isolate is up.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    // The messaging plugin registers for APNs at plugin init, which is before
    // the user grants notification permission. iOS only delivers the device
    // token after permission, so register again once the app is active.
    application.registerForRemoteNotifications()
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    // Assign after super. The plugin types the token from the DEBUG flag, so a
    // Release/Profile build with the development entitlement was sent to
    // production APNs and never arrived. `apnsToken` follows the signed
    // aps-environment instead.
    Messaging.messaging().apnsToken = deviceToken
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs registration failed: %@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
