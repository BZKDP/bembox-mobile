import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/storage/session_store.dart';
import '../../data/api/me_api.dart';
import 'auth_state.dart';

/// Управляет глобальным состоянием авторизации.
///
/// Жизненный цикл:
///   • старт приложения → [bootstrap]: если есть сохранённая сессия, тянем `/me`;
///   • успешный вход по SMS → [onLoggedIn]: подтягиваем профиль;
///   • выход → [logout].
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.unknown();

  SessionStore get _session => ref.read(sessionStoreProvider);
  MeApi get _meApi => ref.read(meApiProvider);

  /// Стартовая проверка: есть ли действующая сессия.
  Future<void> bootstrap() async {
    if (!_session.isAuthed) {
      state = const AuthState.guest();
      return;
    }
    try {
      final user = await _meApi.getMe();
      if (user != null) {
        state = AuthState.authed(user);
      } else {
        // Токен есть, но сервер сессию не признал → чистим.
        await _session.clear();
        state = const AuthState.guest();
      }
    } catch (_) {
      // Сеть недоступна на старте — пускаем как гостя, профиль подтянем позже.
      state = const AuthState.guest();
    }
  }

  /// Вызывается после успешного `/auth/sms/verify` (cookie уже сохранена
  /// интерсептором). Подтягиваем профиль и переводим в authed.
  Future<void> onLoggedIn() async {
    try {
      final user = await _meApi.getMe();
      state = user != null ? AuthState.authed(user) : const AuthState.guest();
    } catch (_) {
      state = const AuthState.guest();
    }
  }

  /// Выход из аккаунта.
  Future<void> logout() async {
    try {
      await _meApi.logout();
    } catch (_) {
      // даже если сетевой logout не прошёл — локально сессию убираем
    }
    await _session.clear();
    state = const AuthState.guest();
  }
}
