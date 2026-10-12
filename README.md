# Bembox Mobile

Мобильное приложение Bembox для Android и iPhone. Один Flutter-проект собирает обе платформы.

Текущая версия: `1.0.5+6`. Идентификатор приложения на Android и iOS: `com.evgeniishvydchenko.bembox`.

Продакшен-приложение — тонкая нативная оболочка над `https://bembox.ru`: после нативного онбординга открывается полноэкранный WebView. В оболочке реализованы системные разрешения, офлайн-экран и восстановление WebView, загрузка файлов, геолокация, камера/микрофон, внешние платёжные и телефонные ссылки, кнопка «назад», APNs/FCM/RuStore Push и Android-уведомление живого статуса заказа.

## Быстрый старт

```bash
flutter --version
flutter pub get
flutter analyze
flutter test
flutter run
```

Android debug APK:

```bash
flutter build apk --debug
```

Android release (нужен локальный ключ подписи, см. `docs/BUILD_AND_RELEASE.md`):

```bash
flutter build apk --release
flutter build appbundle --release
```

iOS собирается только на macOS с Xcode:

```bash
flutter config --no-enable-swift-package-manager
flutter pub get
flutter build ios --release --no-codesign
```

## Документация передачи

- `docs/HANDOFF.md` — что передано и с чего начинать.
- `docs/ARTIFACTS.md` — APK и контрольные суммы.
- `docs/ARCHITECTURE.md` — устройство приложения и поток данных.
- `docs/BUILD_AND_RELEASE.md` — локальная сборка, Android и App Store/TestFlight.
- `docs/PUSH_NOTIFICATIONS.md` — RuStore, FCM, APNs и формат живого статуса заказа.
- `docs/SERVER_AND_WORKFLOW.md` — где лежит пакет на сервере и как с ним работать.
- `docs/SECRETS_AND_ACCESS.md` — какие секреты нужны и чего в архиве намеренно нет.
- `docs/KNOWN_ISSUES.md` — известные долги и безопасные следующие шаги.

## Важное разграничение

Этот репозиторий не является backend-процессом `sotrudniki` и не должен запускаться через PM2. Он зависит от живого сайта и его API на `bembox.ru`. Каталог на сервере используется как исходный handoff/архив для команды; изменение исходников там само по себе не обновляет приложения в магазинах.

Исходная контрольная точка передачи: ветка `main`, коммит `8039e5f550389c57e30628842ef8c93b669615ec` плюс документация handoff.
