# Push-уведомления

## Регистрация токена

После загрузки страницы приложение выполняет внутри WebView:

```http
POST /api/push/register
Content-Type: application/json
Cookie: bemboks_sid=...
```

Тело:

```json
{
  "token": "DEVICE_TOKEN",
  "platform": "android|ios",
  "channel": "rustore|fcm|apns",
  "appVersion": "..."
}
```

Fetch запускается в origin `bembox.ru`, поэтому cookie авторизованного пользователя прикладывается браузером. Backend должен делать регистрацию идемпотентной, обновлять привязку токена к текущему пользователю и учитывать обновление/отзыв токенов.

## Каналы

- `rustore`: Android-устройства с установленным и авторизованным RuStore. Project ID выбирается отдельно для debug/release.
- `fcm`: Android с Google Play Services и iOS через Firebase Messaging.
- `apns`: прямой iOS device token из `AppDelegate.swift`.

FCM/APNs на iOS сейчас частично дублируются. Backend должен ясно определить основной канал и дедупликацию, иначе одно событие может прийти дважды.

## Навигация

Обычный payload должен содержать `route` или `url`, например `/orders/123`. На Android/iOS маршрут сохраняется/получается обработчиком и загружается в существующем WebView. Абсолютные URL вне доверенного домена открываются внешним приложением по правилам оболочки.

## Живой статус заказа на Android/RuStore

Data-push с `type=order_status` ожидает строки:

```json
{
  "type": "order_status",
  "orderId": "123",
  "number": "№123",
  "status": "courier",
  "statusText": "Курьер уже рядом",
  "progress": "70"
}
```

`BemboxPushService` передаёт такой payload в `OrderTrackingService`. Уведомление имеет постоянный ID `7001` и канал `bembox_order_live`, поэтому новый статус обновляет существующую карточку. При `delivered` прогресс становится 100%; при `delivered` или `cancelled` foreground-service завершается и уведомление становится смахиваемым. Тап открывает `/orders/{orderId}`.

## Известное несоответствие

Значение `appVersion` сейчас жёстко зашито по-разному: RuStore `1.0.0`, APNs `1.0.2`, FCM `1.0.4`, при версии приложения `1.0.5+6`. Следующая правка должна получать версию через `package_info_plus` и передавать её в builder, а не хранить литералы.

## Проверка

Проверять отдельно:

- свежая установка и отказ/разрешение уведомлений;
- Android с Google Play Services;
- Android без GMS, но с RuStore и выполненным входом;
- получение токена после логина на сайте;
- foreground/background/killed-state;
- тап по уведомлению и правильный маршрут;
- обновление ongoing-заказа и завершение delivered/cancelled;
- отсутствие дублей между FCM/APNs или FCM/RuStore.
