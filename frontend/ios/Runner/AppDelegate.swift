import Flutter
import UIKit
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

  // Note: Firebase phone-auth APNs handling is done automatically by the
  // firebase_auth plugin (method swizzling) — no manual AppDelegate hooks
  // needed. Adding an explicit `import FirebaseAuth` here breaks linking under
  // Swift Package Manager (the module isn't linked into the Runner target), so
  // we deliberately do NOT import it.
}
