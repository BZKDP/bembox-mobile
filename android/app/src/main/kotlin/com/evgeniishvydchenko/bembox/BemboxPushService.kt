package com.evgeniishvydchenko.bembox

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import ru.rustore.flutter_rustore_push.FlutterRustorePushService
import ru.rustore.flutter_rustore_push.pigeons.Message
import ru.rustore.flutter_rustore_push.pigeons.Notification
import ru.rustore.sdk.pushclient.messaging.exception.RuStorePushClientException
import ru.rustore.sdk.pushclient.messaging.model.RemoteMessage
import ru.rustore.sdk.pushclient.messaging.service.RuStoreMessagingService

/**
 * Свой messaging-сервис RuStore. Заменяет сервис плагина (см. манифест:
 * FlutterRustorePushService удалён через tools:node="remove").
 *
 * data-пуш type=order_status → запускаем foreground-service OrderTrackingService
 * (живой несмахиваемый статус заказа). ВСЕ остальные сообщения/токен
 * переадресуем в плагин точь-в-точь, чтобы не сломать регистрацию пуш-токена.
 */
class BemboxPushService : RuStoreMessagingService() {
    private val ui = Handler(Looper.getMainLooper())

    override fun onNewToken(token: String) {
        ui.post { FlutterRustorePushService.client?.newToken(token) { } }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        if (data["type"] == "order_status") {
            startOrderTracking(data)
        }

        // Точная копия логики плагина (форвардинг в Flutter).
        message.messageId?.let { FlutterRustorePushService.messages[it] = message }
        var notification: Notification? = null
        if (message.notification != null) {
            notification = Notification(
                title = message.notification?.title.orEmpty(),
                body = message.notification?.body.orEmpty(),
                channelId = message.notification?.channelId.orEmpty(),
                clickAction = message.notification?.clickAction.orEmpty(),
                icon = message.notification?.icon.orEmpty(),
                color = message.notification?.color.orEmpty(),
                imageUrl = message.notification?.imageUrl.toString(),
            )
        }
        val msg = Message(
            messageId = message.messageId,
            data = message.data as Map<String?, String?>,
            priority = message.priority.toLong(),
            ttl = message.ttl.toLong(),
            collapseKey = message.collapseKey,
            notification = notification,
        )
        ui.post { FlutterRustorePushService.client?.messageReceived(msg) { } }
    }

    override fun onDeletedMessages() {
        ui.post { FlutterRustorePushService.client?.deletedMessages { } }
    }

    override fun onError(errors: List<RuStorePushClientException>) {
        ui.post { FlutterRustorePushService.client?.error(errors.toString()) { } }
    }

    private fun startOrderTracking(data: Map<String, String>) {
        val svc = Intent(this, OrderTrackingService::class.java)
        for ((k, v) in data) svc.putExtra(k, v)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(svc)
            } else {
                startService(svc)
            }
        } catch (e: Throwable) {
            // Фоновый старт FGS заблокирован (приложение убито) → обычное уведомление.
            try {
                val fallback = Intent().also { for ((k, v) in data) it.putExtra(k, v) }
                (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .notify(OrderTrackingService.NOTIF_ID, OrderTrackingService.buildNotification(applicationContext, fallback))
            } catch (_: Throwable) {
            }
        }
    }
}
