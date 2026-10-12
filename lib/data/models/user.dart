import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Пользователь bembox.
///
/// Источник на бэкенде: `GET /api/me` возвращает `{ user: {...} | null }`
/// (см. `apps/web/app/api/me/route.ts`). Поля — подмножество таблицы `users`
/// (`packages/db/src/schema.ts`), которое сервер отдаёт клиенту.
@freezed
abstract class User with _$User {
  const factory User({
    /// UUID пользователя.
    required String id,

    /// Имя (может быть null — задаётся в профиле).
    String? name,

    /// Телефон в формате `+7XXXXXXXXXX` (может быть null для tg-only аккаунтов).
    String? phone,

    /// Роль: `user` | `admin` | `courier`. Для приложения почти всегда `user`.
    @Default('user') String role,

    /// Telegram ID (если входил через Telegram). В JSON приходит числом.
    @JsonKey(name: 'telegramId') int? telegramId,

    /// Последний выбранный адрес (синхронизируется между устройствами).
    @JsonKey(name: 'lastAddress') String? lastAddress,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
