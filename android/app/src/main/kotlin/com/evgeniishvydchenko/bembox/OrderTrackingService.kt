package com.evgeniishvydchenko.bembox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Foreground-service «живого» статуса заказа. FGS-уведомление можно полностью
 * залить цветом (setColorized работает именно для foreground-сервиса — на любом
 * OEM, включая Samsung) и его НЕЛЬЗЯ смахнуть, пока сервис жив.
 *
 * Вид кастомный: толстая полоса прогресса + курьер-человечек, который «бежит»
 * по ней вместе с прогрессом (рисуем трек+курьера в Bitmap и кладём в ImageView).
 *
 * Старт/обновление — из BemboxPushService по data-пушу order_status; стоп — на
 * статусе delivered/cancelled (после чего уведомление становится смахиваемым).
 */
class OrderTrackingService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val status = intent?.getStringExtra("status").orEmpty()
        val finished = status == "delivered" || status == "cancelled"
        val notif = buildNotification(this, intent)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIF_ID, notif)
            }
        } catch (e: Throwable) {
            // Если FGS стартовать не дали — просто показываем уведомление.
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIF_ID, notif)
        }
        if (finished) {
            // Снимаем foreground (уведомление остаётся, но уже смахиваемое) и стопаем.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_DETACH)
            } else {
                @Suppress("DEPRECATION") stopForeground(false)
            }
            stopSelf()
        }
        return START_NOT_STICKY
    }

    companion object {
        const val NOTIF_ID = 7001
        const val CHANNEL_ID = "bembox_order_live"
        private const val ORANGE = 0xFFFF7547.toInt()

        fun buildNotification(ctx: Context, intent: Intent?): Notification {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = NotificationChannel(CHANNEL_ID, "Статус заказа", NotificationManager.IMPORTANCE_HIGH)
                ch.description = "Живой статус вашего заказа"
                ch.setShowBadge(true)
                nm.createNotificationChannel(ch)
            }
            val number = intent?.getStringExtra("number").orEmpty()
            val statusText = (intent?.getStringExtra("statusText") ?: intent?.getStringExtra("status")).orEmpty()
            val rawProgress = intent?.getStringExtra("progress")?.toIntOrNull() ?: 0
            val orderId = intent?.getStringExtra("orderId").orEmpty()
            val status = intent?.getStringExtra("status").orEmpty()
            val finished = status == "delivered" || status == "cancelled"
            val progress = if (status == "delivered") 100 else rawProgress.coerceIn(0, 100)
            val title = if (number.isNotEmpty()) "Заказ $number" else "Ваш заказ"

            val open = Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra("bem_route", if (orderId.isNotEmpty()) "/orders/$orderId" else "/orders")
            }
            val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pi = PendingIntent.getActivity(ctx, 1, open, piFlags)

            val track = trackBitmap(ctx, progress)

            val big = RemoteViews(ctx.packageName, R.layout.notif_order)
            big.setTextViewText(R.id.bem_title, title)
            big.setTextViewText(R.id.bem_status, statusText)
            big.setImageViewBitmap(R.id.bem_track, track)

            val small = RemoteViews(ctx.packageName, R.layout.notif_order_compact)
            small.setTextViewText(R.id.bem_title, if (statusText.isNotEmpty()) "$title · $statusText" else title)
            small.setImageViewBitmap(R.id.bem_track, track)

            val b = NotificationCompat.Builder(ctx, CHANNEL_ID)
                .setSmallIcon(ctx.applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(statusText)
                .setColor(ORANGE)
                .setColorized(true)
                .setOngoing(!finished)
                .setOnlyAlertOnce(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                .setContentIntent(pi)
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(small)
                .setCustomBigContentView(big)
            return b.build()
        }

        /** Толстый трек + курьер-человечек на конце прогресса. */
        private fun trackBitmap(ctx: Context, progress: Int): Bitmap {
            val w = 1000
            val h = 116
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            val p = Paint(Paint.ANTI_ALIAS_FLAG)

            val barH = 24f                 // в 2 раза толще обычного бара
            val barTop = h - barH - 6f
            val r = barH / 2f
            val pr = progress.coerceIn(0, 100)
            val fillW = w * pr / 100f

            // фон трека (полупрозрачный белый)
            p.color = 0x55FFFFFF
            c.drawRoundRect(0f, barTop, w.toFloat(), barTop + barH, r, r, p)
            // заполненная часть (белая)
            p.color = 0xFFFFFFFF.toInt()
            if (fillW > 0f) c.drawRoundRect(0f, barTop, maxOf(fillW, barH), barTop + barH, r, r, p)

            // курьер-человечек на конце прогресса
            val cs = 68
            val courier = vectorBitmap(ctx, R.drawable.ic_courier, cs)
            val cx = (fillW - cs / 2f).coerceIn(0f, (w - cs).toFloat())
            val cy = barTop - cs + barH / 2f
            // белый кружок-подложка
            val disc = Paint(Paint.ANTI_ALIAS_FLAG)
            disc.color = 0xFFFFFFFF.toInt()
            c.drawCircle(cx + cs / 2f, cy + cs / 2f, cs / 2f + 5f, disc)
            // сам курьер — оранжевый внутри кружка
            val courierPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            courierPaint.colorFilter = PorterDuffColorFilter(ORANGE, PorterDuff.Mode.SRC_IN)
            c.drawBitmap(courier, cx, cy, courierPaint)
            return bmp
        }

        private fun vectorBitmap(ctx: Context, resId: Int, size: Int): Bitmap {
            val d = ContextCompat.getDrawable(ctx, resId)!!
            val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val cv = Canvas(b)
            d.setBounds(0, 0, size, size)
            d.draw(cv)
            return b
        }
    }
}
