import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

/// Хранилище сессии пользователя.
///
/// Бэкенд авторизует по cookie `bemboks_sid` (httpOnly, см.
/// `apps/web/lib/server/auth.ts`). На мобилке мы:
///   1) при логине забираем значение cookie из ответа сервера (Set-Cookie);
///   2) храним его ЗАШИФРОВАННО в [FlutterSecureStorage] (Keystore на Android /
///      Keychain на iOS) — не в открытом cookie-файле;
///   3) на каждый запрос подставляем заголовок `Cookie: bemboks_sid=<token>`.
///
/// В памяти держим кэш токена, чтобы не читать защищённое хранилище на каждом
/// запросе (это относительно медленно).
class SessionStore {
  SessionStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'bemboks_sid';

  String? _cached;
  bool _loaded = false;

  /// Текущий токен сессии (или null, если не залогинен). Доступен синхронно
  /// после [load].
  String? get token => _cached;

  /// Залогинен ли пользователь (есть сохранённый токен).
  bool get isAuthed => _cached != null && _cached!.isNotEmpty;

  /// Подгружает токен из защищённого хранилища в кэш. Вызывать один раз на старте.
  Future<void> load() async {
    if (_loaded) return;
    _cached = await _storage.read(key: _key);
    _loaded = true;
  }

  /// Сохраняет новый токен сессии (после успешного входа или продления).
  Future<void> save(String token) async {
    _cached = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  /// Удаляет сессию (выход из аккаунта).
  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _key);
  }

  /// Значение заголовка Cookie для запроса, или null если нет сессии.
  String? get cookieHeader =>
      isAuthed ? '${AppConfig.sessionCookieName}=$_cached' : null;
}
