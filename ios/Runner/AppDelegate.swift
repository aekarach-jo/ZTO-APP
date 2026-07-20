import FirebaseCore
import FirebaseMessaging
import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
      FirebaseApp.configure()
      Messaging.messaging().delegate = self
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
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
#if DEBUG
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    NSLog("[FCM_IOS] APNs registered token=\(token)")
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

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
#if DEBUG
    NSLog("[FCM_IOS] FCM registration token=\(fcmToken ?? "<nil>")")
#endif
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
