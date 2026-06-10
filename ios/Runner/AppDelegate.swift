import FirebaseCore
import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
      FirebaseApp.configure()
    }

    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !mapsKey.isEmpty {
      let didRegisterKey = GMSServices.provideAPIKey(mapsKey)
#if DEBUG
      let bundleId = Bundle.main.bundleIdentifier ?? "unknown.bundle"
      let keyPreview = String(mapsKey.prefix(8))
      NSLog("[MapsDebug] bundle=\(bundleId) keyPrefix=\(keyPreview)*** keyLength=\(mapsKey.count) registered=\(didRegisterKey)")
#endif
    } else {
#if DEBUG
      NSLog("[MapsDebug] Missing GMSApiKey in Info.plist")
#endif
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
