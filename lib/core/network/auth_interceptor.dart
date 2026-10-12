import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/session_store.dart';

/// Интерсептор авторизации по cookie-сессии bembox.
///
/// • onRequest  — подставляет `Cookie: bemboks_sid=<token>`, если есть сессия.
/// • onResponse — ловит `Set-Cookie` от сервера (приходит при входе через
///   `/auth/sms/verify` и при sliding-продлении в `/me`) и сохраняет свежее
///   значение `bemboks_sid` в защищённое хранилище.
///
/// Так мы держим один источник правды о сессии ([SessionStore]) и не зависим
/// от системного cookie-хранилища, которое в нативном HTTP-клиенте не всегда
/// переносится между запусками приложения.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._session);

  final SessionStore _session;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final cookie = _session.cookieHeader;
    if (cookie != null) {
      options.headers['Cookie'] = cookie;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _captureSessionCookie(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Даже на ошибочном ответе сервер мог прислать Set-Cookie — учитываем.
    if (err.response != null) _captureSessionCookie(err.response!);
    handler.next(err);
  }

  /// Извлекает значение `bemboks_sid` из заголовков Set-Cookie и сохраняет его.
  void _captureSessionCookie(Response response) {
    final raw = response.headers.map['set-cookie'];
    if (raw == null) return;
    for (final line in raw) {
      // Формат: "bemboks_sid=<value>; Path=/; HttpOnly; Expires=..."
      final firstPair = line.split(';').first.trim();
      final eq = firstPair.indexOf('=');
      if (eq <= 0) continue;
      final name = firstPair.substring(0, eq).trim();
      final value = firstPair.substring(eq + 1).trim();
      if (name == AppConfig.sessionCookieName) {
        if (value.isEmpty) {
          // Сервер обнулил cookie → разлогин.
          _session.clear();
        } else if (value != _session.token) {
          _session.save(value);
        }
      }
    }
  }
}
