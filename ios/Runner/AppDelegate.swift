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

    // Notifications, not overrides: FlutterSceneDelegate keeps its own
    // handling of these lifecycle events.
    let center = NotificationCenter.default
    center.addObserver(
      forName: UIScene.willDeactivateNotification, object: scene, queue: .main
    ) { [weak self] _ in self?.showPrivacyCover(on: scene) }
    center.addObserver(
      forName: UIScene.didActivateNotification, object: scene, queue: .main
    ) { [weak self] _ in self?.hidePrivacyCover() }
  }

  // The app switcher shows a plain cover instead of billing or router Wi-Fi
  // details.
  private var privacyCover: UIView?

  private func showPrivacyCover(on scene: UIScene) {
    guard privacyCover == nil, let window = (scene as? UIWindowScene)?.windows.first else { return }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = .systemBackground
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(cover)
    privacyCover = cover
  }

  private func hidePrivacyCover() {
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}
