import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    // With the scene lifecycle, applicationDidBecomeActive is not a reliable
    // place to register. iOS only returns an APNs token after this call.
    UIApplication.shared.registerForRemoteNotifications()
  }
}
