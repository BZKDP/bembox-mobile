import '../../data/models/user.dart';

/// Статус авторизации приложения.
enum AuthStatus {
  /// Ещё не определились (идёт стартовая проверка сессии) — показываем splash.
  unknown,

  /// Пользователь вошёл — есть валидная сессия и профиль.
  authed,

  /// Гость — сессии нет. Каталог смотреть можно, но профиль/оформление требуют входа.
  guest,
}

/// Иммутабельное состояние авторизации, которым управляет AuthController.
class AuthState {
  const AuthState(this.status, {this.user});

  const AuthState.unknown() : this(AuthStatus.unknown);
  const AuthState.guest() : this(AuthStatus.guest);
  const AuthState.authed(User user) : this(AuthStatus.authed, user: user);

  final AuthStatus status;
  final User? user;

  bool get isAuthed => status == AuthStatus.authed;
  bool get isUnknown => status == AuthStatus.unknown;
}
