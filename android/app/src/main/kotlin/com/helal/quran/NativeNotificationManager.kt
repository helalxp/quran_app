package com.helal.quran

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log

/**
 * Native notification manager for prayer time reminders.
 * Works even when the app is killed.
 */
class NativeNotificationManager(private val context: Context) {

    companion object {
        private const val TAG = "NativeNotificationMgr"
        private const val CHANNEL_ID = "prayer_reminders"
        private const val CHANNEL_NAME = "Prayer Reminders"
    }

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for upcoming prayer times"
            }
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Notification channel created")
        }
    }

    /**
     * Send a prayer time reminder notification.
     * @param prayerName Arabic name of the prayer (e.g., "الفجر")
     * @param minutesBefore Minutes before prayer time
     */
    fun sendPrayerReminder(prayerName: String, minutesBefore: Int) {
        try {
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("تذكير الصلاة")
                .setContentText("تبقى على موعد صلاة $prayerName $minutesBefore دقائق")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .build()

            val notificationId = System.currentTimeMillis().toInt()
            notificationManager.notify(notificationId, notification)

            Log.d(TAG, "✅ Prayer reminder sent for $prayerName ($minutesBefore min before)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error sending prayer reminder: ${e.message}", e)
        }
    }
}
