import FirebaseCore
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let pushDelegate = BemPushDelegate()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase (FCM): конфигурируем ДО регистрации плагинов/super, чтобы
    // firebase_messaging получил APNs-токен через swizzling и выдал FCM-токен.
    FirebaseApp.configure()
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Свой делегат уведомлений (баннер в foreground + роутинг по тапу).
    UNUserNotificationCenter.current().delegate = pushDelegate
    // Пуши iOS (APNs): запрашиваем разрешение и регистрируемся в APNs.
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
      if granted {
        DispatchQueue.main.async { application.registerForRemoteNotifications() }
      }
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // Device-token APNs → в UserDefaults (Dart прочитает через shared_preferences).
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    UserDefaults.standard.set(token, forKey: "flutter.bem_apns_token")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}

/// Делегат уведомлений: показывать баннер когда приложение ОТКРЫТО (foreground)
/// и сохранять route при ТАПЕ — Dart затем откроет его в WebView.
class BemPushDelegate: NSObject, UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    if let route = info["route"] as? String, !route.isEmpty {
      UserDefaults.standard.set(route, forKey: "flutter.bem_push_route")
    }
    completionHandler()
  }
}
