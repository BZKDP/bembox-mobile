import 'dart:convert';

import 'package:flutter_rustore_push/flutter_rustore_push.dart';
import 'package:flutter_rustore_push/pigeons/rustore_push.dart';

/// Пуши через RuStore (без Google-сервисов). Доставка идёт ЧЕРЕЗ приложение
/// RuStore на устройстве — на телефоне должен быть установлен RuStore и выполнен
/// в нём вход, иначе токен не выдаётся и пуши не приходят (аналог Google Play
/// Services для FCM). Project ID берётся из meta-data в AndroidManifest.
///
/// Этот сервис только получает токен и события; навигацию по тапу и регистрацию
/// токена на сервере делает WebView-оболочка через колбэки [onOpenUrl]/[onToken]
/// (регистрация выполняется fetch-ом ВНУТРИ страницы, чтобы автоматически
/// подставилась cookie-сессия bemboks_sid).
class BemboxPush {
  /// Открыть путь/URL внутри WebView (по тапу на пуш). Может прийти как
  /// относительный путь ('/orders/123'), так и абсолютный URL.
  void Function(String url)? onOpenUrl;

  /// Зарегистрировать (обновить) пуш-токен на бэкенде bembox.
  Future<void> Function(String token)? onToken;

  String? _token;
  String? get token => _token;

  bool _started = false;

  /// Инициализация: проверяем доступность RuStore, вешаем колбэки, берём токен
  /// и проверяем «холодный» старт по тапу на пуш. Все ошибки гасим — отсутствие
  /// RuStore на устройстве не должно влиять на работу приложения.
  Future<void> init() async {
    if (_started) return;
    _started = true;

    try {
      await RustorePushClient.attachCallbacks(
        onNewToken: (String token) {
          _token = token;
          onToken?.call(token);
        },
        onMessageReceived: (Message message) {
          // Уведомление с полем title RuStore-SDK показывает сам. Здесь ничего
          // делать не нужно — оставлено для возможной аналитики/бейджей.
        },
        onMessageOpenedApp: (Message? message) {
          _handleOpened(message);
        },
        onError: (Object err) {
          // тихо: например, RuStore не установлен
        },
      );
    } catch (_) {}

    // Доступность RuStore-транспорта (для логов/диагностики).
    try {
      await RustorePushClient.available();
    } catch (_) {}

    // Текущий токен (если RuStore доступен и пользователь в нём авторизован).
    try {
      final t = await RustorePushClient.getToken();
      if (t.isNotEmpty) {
        _token = t;
        onToken?.call(t);
      }
    } catch (_) {}

    // Приложение запустили тапом по пушу из «холодного» старта.
    try {
      final initial = await RustorePushClient.getInitialMessage();
      _handleOpened(initial);
    } catch (_) {}
  }

  void _handleOpened(Message? message) {
    if (message == null) return;
    final url = message.data['url'];
    if (url != null && url.isNotEmpty) {
      onOpenUrl?.call(url);
    }
  }

  /// JS для регистрации токена силами самой страницы (cookie подставится
  /// автоматически). Эндпоинт /api/push/register реализует разработчик —
  /// пока его нет, fetch просто молча отвалится (обёрнут в try/catch).
  static String buildRegisterJs(String token) {
    final body = jsonEncode({
      'token': token,
      'platform': 'android',
      'channel': 'rustore',
      'appVersion': '1.0.0',
    });
    return '''
(function(){
  try {
    fetch('/api/push/register', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: ${jsonEncode(body)}
    }).catch(function(){});
  } catch(e){}
})();
''';
  }

  /// JS для регистрации FCM-токена (Firebase). Тот же эндпоинт, channel='fcm',
  /// platform — 'ios' или 'android' в зависимости от устройства.
  static String buildRegisterJsFcm(String token, {required bool ios}) {
    final body = jsonEncode({
      'token': token,
      'platform': ios ? 'ios' : 'android',
      'channel': 'fcm',
      'appVersion': '1.0.4',
    });
    return '''
(function(){
  try {
    fetch('/api/push/register', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: ${jsonEncode(body)}
    }).catch(function(){});
  } catch(e){}
})();
''';
  }

  /// JS для регистрации iOS APNs-токена (cookie подставится автоматически).
  /// Тот же эндпоинт /api/push/register, но platform='ios', channel='apns'.
  static String buildRegisterJsIos(String token) {
    final body = jsonEncode({
      'token': token,
      'platform': 'ios',
      'channel': 'apns',
      'appVersion': '1.0.2',
    });
    return '''
(function(){
  try {
    fetch('/api/push/register', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: ${jsonEncode(body)}
    }).catch(function(){});
  } catch(e){}
})();
''';
  }
}
