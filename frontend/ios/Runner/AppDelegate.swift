import Flutter
import UIKit
import FirebaseAuth
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // When the user taps a notification action ("Mark all done" / "Snooze")
    // with the app not running, flutter_local_notifications spins up a
    // headless engine to run the Dart handler — this callback registers the
    // plugins that handler needs (http, shared_preferences, ...).
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // ── Firebase phone auth: silent APNs verification ─────────────────────────
  // Firebase proves the app is genuine by sending it a silent push. These two
  // hooks hand the APNs device token and any incoming silent push to
  // FirebaseAuth. If Auth consumes the notification, we stop; otherwise we pass
  // it along so normal notifications still work.

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // .unknown lets Firebase auto-detect sandbox vs production APNs environment.
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification notification: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if Auth.auth().canHandleNotification(notification) {
      completionHandler(.noData)
      return
    }
    super.application(
      application,
      didReceiveRemoteNotification: notification,
      fetchCompletionHandler: completionHandler
    )
  }
}
