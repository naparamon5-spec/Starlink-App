import Flutter
import UIKit
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

class SceneDelegate: FlutterSceneDelegate {
  // A link that launches the app arrives here, and app_links only listens on
  // the app delegate, so it would never see the link without this hand-off.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    let url =
      connectionOptions.urlContexts.first?.url
      ?? connectionOptions.userActivities.first?.webpageURL
    if let url { AppLinks.shared.handleLink(url: url) }
  }
}
