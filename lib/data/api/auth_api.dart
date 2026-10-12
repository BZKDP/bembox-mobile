import '../../core/network/dio_client.dart';

/// API авторизации по SMS (sms.ru).
/// Эндпоинты: `apps/web/app/api/auth/sms/{send,verify}/route.ts`.
class AuthApi {
  AuthApi(this._client);

  final DioClient _client;

  /// Шаг 1 — отправить 6-значный код в SMS на [phone].
  /// Бэкенд: `POST /auth/sms/send { phone }` → `{ ok, expiresAt }`.
  /// Анти-спам: не чаще 1 SMS в 60 сек на номер (иначе вернёт ошибку с текстом).
  Future<void> sendSmsCode(String phone) async {
    await _client.post('/auth/sms/send', data: {'phone': phone});
  }

  /// Шаг 2 — проверить [code], создать сессию.
  /// Бэкенд: `POST /auth/sms/verify { phone, code }` → `{ ok, userId }` +
  /// ставит cookie `bemboks_sid` (её ловит [AuthInterceptor]).
  /// Возвращает userId (или пустую строку, если бэкенд его не прислал).
  Future<String> verifySmsCode(String phone, String code) async {
    final res = await _client.post(
      '/auth/sms/verify',
      data: {'phone': phone, 'code': code},
    );
    final data = res.data;
    if (data is Map && data['userId'] is String) return data['userId'] as String;
    return '';
  }
}
