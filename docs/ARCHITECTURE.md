# Архитектура

## Общая схема

```text
Пользователь
  -> Flutter: splash / первый онбординг / системные разрешения
  -> InAppWebView: https://bembox.ru/?cb=20260622
  -> cookie-сессия сайта bemboks_sid
  -> API сайта /api/*

RuStore Push / FCM / APNs
  -> нативный или Flutter-обработчик
  -> route/url
  -> WebView открывает страницу заказа/раздела
```

Backend и веб-интерфейс не встроены в приложение. Бизнес-логика заказов, авторизация, корзина и контент приходят с `bembox.ru`; мобильная сборка отвечает за нативный контейнер и интеграции устройства.

## Запуск

`lib/main.dart`:

- инициализирует Flutter и локальный `CrashReporter`;
- best-effort инициализирует Firebase/FCM;
- блокирует портретную ориентацию;
- при смене версии чистит HTTP-кэш WebView, а на Android также web storage, не удаляя cookie-сессию;
- читает `bem-onboarding-done` из SharedPreferences;
- открывает `OnboardingScreen` либо `WebViewShell`.

`lib/features/onboarding/onboarding_screen.dart` — три нативных экрана. После завершения записывается флаг и показывается WebView.

## WebViewShell

`lib/shell/webview_shell.dart` — активное ядро приложения:

- стартовый URL `https://bembox.ru/?cb=20260622` с ручным cache-buster;
- разрешённая внутренняя зона — `bembox.ru` и поддомены; внешние/платёжные схемы уходят в системные приложения;
- JS-инъекция safe-area для iPhone и скрытие cookie-баннера внутри приложения;
- запрос геопозиции, камеры, микрофона и уведомлений;
- поддержка HTML file input и внешних ссылок;
- pull-to-refresh, индикатор загрузки, офлайн-экран;
- проверка «мёртвой» React-страницы и очистка состояния с повторной загрузкой;
- Android back: история сайта, затем выход;
- регистрация push-токенов fetch-запросом из контекста страницы. Благодаря этому браузерная cookie пользователя автоматически попадает в `/api/push/register`;
- маршрутизация тапов по пушам обратно в WebView.

## Push

- Android без Google Services: RuStore Push (`lib/push/push_service.dart`).
- Android с Google Play Services и iOS: FCM (`lib/push/fcm_service.dart`).
- iOS дополнительно сохраняет прямой APNs device token в `ios/Runner/AppDelegate.swift`.
- Android `type=order_status`: `BemboxPushService.kt` запускает `OrderTrackingService.kt`, который рисует цветное ongoing-уведомление с прогрессом.

Подробности payload — в `PUSH_NOTIFICATIONS.md`.

## Crash reporting

`lib/core/crash_reporter.dart` перехватывает Flutter и zone errors, но сейчас хранит их только в локальном буфере. Sentry/AppMetrica/другая внешняя система мониторинга не подключена.

## Легаси native UI

Каталоги `lib/features/` (кроме onboarding), `lib/data/`, `lib/domain/` и часть `lib/core/` содержат раннюю полноценную Flutter-реализацию приложения на Riverpod/GoRouter/Dio. Она не связана с текущим `MaterialApp` и не используется в production flow. Зависимости для неё пока оставлены в `pubspec.yaml`, поэтому обновлять/удалять пакеты нужно после проверки, не механически.

## Идентификаторы и ограничения

- Android applicationId/namespace: `com.evgeniishvydchenko.bembox`.
- iOS bundle id: `com.evgeniishvydchenko.bembox`.
- Android minSdk фактически задаётся текущим Flutter SDK; исходная конфигурация рассчитана на API 24+.
- iOS deployment target: 13.0.
- Основной режим — iPhone, portrait.
