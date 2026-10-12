import '../../core/network/dio_client.dart';
import '../models/user.dart';

/// API текущего пользователя.
/// Эндпоинт: `apps/web/app/api/me/route.ts`.
class MeApi {
  MeApi(this._client);

  final DioClient _client;

  /// `GET /me` → текущий пользователь или null (если сессии нет/истекла).
  /// Бэкенд отвечает `{ user: {...} | null }` и попутно продлевает сессию.
  Future<User?> getMe() async {
    final res = await _client.get('/me');
    final data = res.data;
    if (data is Map && data['user'] is Map) {
      return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    }
    return null;
  }

  /// Сохранить выбранный адрес: `PATCH /me { lastAddress }`.
  Future<void> setLastAddress(String address) async {
    await _client.patch('/me', data: {'lastAddress': address});
  }

  /// Выход: `DELETE /me` — сервер удаляет сессию и обнуляет cookie.
  Future<void> logout() async {
    await _client.delete('/me');
  }
}
