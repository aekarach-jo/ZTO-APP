import FirebaseCore
import FirebaseMessaging
import Flutter
import GoogleMaps
import UIKit
import UserNotifications

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

    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Explicitly bridge APNs to Firebase. The FlutterFire plugin also receives
    // this callback through `super`, but setting it here removes the startup
    // race before Dart asks Firebase for its registration token.
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
#if DEBUG
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    NSLog("[FCM_IOS] APNs registered token=\(token)")

    Messaging.messaging().token { fcmToken, error in
      if let error {
        NSLog("[FCM_IOS] FCM token request failed error=\(error.localizedDescription)")
      } else {
        NSLog("[FCM_IOS] FCM registered token=\(fcmToken ?? "<nil>")")
      }
    }
#endif
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
#if DEBUG
    NSLog("[FCM_IOS] APNs registration failed error=\(error.localizedDescription)")
#endif
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
#if DEBUG
    NSLog("[FCM_IOS] willPresent userInfo=\(notification.request.content.userInfo)")
#endif
    super.userNotificationCenter(
      center,
      willPresent: notification,
      withCompletionHandler: completionHandler
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
#if DEBUG
    NSLog("[FCM_IOS] didReceive response userInfo=\(response.notification.request.content.userInfo)")
#endif
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }
}
