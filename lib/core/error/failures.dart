/// Типы ошибок приложения. Сетевой слой превращает любые исключения (Dio,
/// парсинг, бэкенд-ошибки) в одно из этих понятных значений, чтобы UI показывал
/// корректное сообщение, а не «голый» stacktrace.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Сообщение, готовое к показу пользователю (на русском).
  final String message;

  @override
  String toString() => 'AppFailure: $message';
}

/// Нет сети / таймаут / сервер недоступен.
class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Нет связи. Проверьте интернет']);
}

/// Сервер вернул ошибку с понятным текстом (поле `error` в JSON, статус 4xx).
class ApiFailure extends AppFailure {
  const ApiFailure(super.message, {this.statusCode});
  final int? statusCode;
}

/// Не авторизован (401 / сессия истекла) — нужно заново войти.
class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.message = 'Войдите снова']);
}

/// Неожиданная ошибка (баг/непредвиденный ответ).
class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'Что-то пошло не так']);
}
