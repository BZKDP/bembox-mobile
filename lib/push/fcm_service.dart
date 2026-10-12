import 'package:firebase_messaging/firebase_messaging.dart';

/// Фоновый обработчик FCM (обязателен для плагина). Тяжёлой работы нет:
/// notification-сообщения система показывает сама, маршрут читаем при тапе.
@pragma('vm:entry-point')
Future<void> bemboxFcmBackgroundHandler(RemoteMessage message) async {
  // no-op
}

/// Пуши через Firebase Cloud Messaging (FCM) — основной канал для iOS и для
/// Android-сборки из Google Play. Параллелен RuStore-пушам: на телефонах без
/// Google Play Services FCM-токен просто не выдаётся (это нормально, там работает
/// RuStore). Как и [BemboxPush], только получает токен/события; регистрацию
/// токена на бэкенде и навигацию по тапу делает WebView-оболочка через колбэки.
class BemboxFcm {
  /// Открыть путь/URL внутри WebView по тапу на пуш.
  void Function(String url)? onOpenUrl;

  /// Зарегистрировать (обновить) FCM-токен на бэкенде bembox.
  Future<void> Function(String token)? onToken;

  String? _token;
  String? get token => _token;

  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS: системный запрос на уведомления (на Android 13+ — отдельно через
      // permission_handler в оболочке). На iOS без этого FCM-токен бесполезен.
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final t = await messaging.getToken();
      if (t != null && t.isNotEmpty) {
        _token = t;
        onToken?.call(t);
      }
      messaging.onTokenRefresh.listen((token) {
        _token = token;
        onToken?.call(token);
      });

      // Тап по пушу из фона + «холодный» старт по тапу.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpened(initial);
    } catch (_) {
      // Нет Google Play Services / нет сети / не настроен APNs — тихо.
    }
  }

  void _handleOpened(RemoteMessage message) {
    final data = message.data;
    final route = data['route'] ?? data['url'];
    if (route != null && route.isNotEmpty) {
      onOpenUrl?.call(route);
    }
  }
}
