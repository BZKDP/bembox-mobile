/// Глобальная конфигурация приложения.
///
/// Здесь — НИКАКИХ секретов (ключи ЮKassa/SMS/БД живут только на сервере).
/// Приложение общается исключительно с публичным REST API сайта.
abstract final class AppConfig {
  /// Базовый URL боевого API. Проверено: `https://bembox.ru/api/me` → 200.
  /// (Легаси `http://legacy-host/bemapp/api` отдаёт 301 — не используем.)
  static const String apiBaseUrl = 'https://bembox.ru/api';

  /// Источник сайта (для WebView-фолбэков, ссылок «открыть на сайте», карты).
  static const String siteBaseUrl = 'https://bembox.ru';

  /// Имя cookie сессии, которое ставит бэкенд при `POST /auth/sms/verify`.
  /// Мобилка хранит и переотправляет её через cookie-jar (см. network-слой).
  static const String sessionCookieName = 'bemboks_sid';

  /// Тайм-ауты HTTP (мс).
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// User-Agent приложения — чтобы на бэкенде отличать мобильный трафик от веба.
  static const String userAgent = 'BemboxApp/1.0 (Flutter)';

  /// Режим отладки сети (логирование запросов в консоль). В релизе выключать.
  static const bool networkLogging = true;
}
