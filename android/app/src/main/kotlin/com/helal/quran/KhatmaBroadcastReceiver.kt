package com.helal.quran

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * BroadcastReceiver for Khatma daily reminders.
 * Triggers notifications to remind users to read their daily Khatma goal.
 */
class KhatmaBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KhatmaBroadcastReceiver"
        const val ACTION_KHATMA_REMINDER = "com.helal.quran.ACTION_KHATMA_REMINDER"
        const val ACTION_PROGRESS_REMINDER = "com.helal.quran.ACTION_PROGRESS_REMINDER"
        const val EXTRA_KHATMA_NAME = "khatma_name"
        const val EXTRA_KHATMA_ID = "khatma_id"
        const val EXTRA_PAGES_TODAY = "pages_today"
        const val EXTRA_PAGES_READ = "pages_read"
        const val EXTRA_PAGES_REMAINING = "pages_remaining"
        const val NOTIFICATION_CHANNEL_ID = "khatma_reminders"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received broadcast: ${intent.action}")

        when (intent.action) {
            ACTION_KHATMA_REMINDER -> handleKhatmaReminder(context, intent)
            ACTION_PROGRESS_REMINDER -> handleProgressReminder(context, intent)
        }
    }

    private fun handleKhatmaReminder(context: Context, intent: Intent) {
        val khatmaName = intent.getStringExtra(EXTRA_KHATMA_NAME) ?: "الختمة"
        val khatmaId = intent.getStringExtra(EXTRA_KHATMA_ID) ?: ""
        val pagesToday = intent.getIntExtra(EXTRA_PAGES_TODAY, 0)

        Log.d(TAG, "Showing Khatma reminder for: $khatmaName ($pagesToday pages)")

        createNotificationChannel(context)
        showNotification(context, khatmaName, khatmaId, pagesToday)
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "تذكير الختمة"
            val descriptionText = "تذكير يومي لقراءة الختمة"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                setShowBadge(true)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(context: Context, khatmaName: String, khatmaId: String, pagesToday: Int) {
        // Check notification permission for Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ActivityCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                Log.w(TAG, "⚠️ Notification permission not granted for Android 13+")
                return
            }
        }

        // Create intent to open app when notification is tapped
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("open_khatma", khatmaId)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            khatmaId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val (title, message, bigText) = if (pagesToday > 0) {
            Triple(
                "📖 وقت القراءة • $khatmaName",
                "اليوم $pagesToday صفحة من كتاب الله",
                "السلام عليكم 🌙\n\nحان وقت قراءة ختمتك اليومية\n\n📊 هدف اليوم: $pagesToday صفحة\n\nاللهم اجعل القرآن ربيع قلوبنا\nبارك الله في وقتك ✨"
            )
        } else {
            Triple(
                "📖 وقت القراءة • $khatmaName",
                "اقرأ من كتاب الله ما تيسر لك",
                "السلام عليكم 🌙\n\nحان وقت قراءة ختمتك اليومية\n\n📖 اقرأ ما تيسر لك من القرآن\n\nاللهم اجعل القرآن ربيع قلوبنا\nبارك الله في وقتك ✨"
            )
        }

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_today)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 300, 200, 300))
            .build()

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(khatmaId.hashCode(), notification)

        Log.d(TAG, "✅ Khatma notification shown for: $khatmaName")
    }

    private fun handleProgressReminder(context: Context, intent: Intent) {
        val khatmaName = intent.getStringExtra(EXTRA_KHATMA_NAME) ?: "الختمة"
        val khatmaId = intent.getStringExtra(EXTRA_KHATMA_ID) ?: ""
        val pagesRead = intent.getIntExtra(EXTRA_PAGES_READ, 0)
        val pagesRemaining = intent.getIntExtra(EXTRA_PAGES_REMAINING, 0)

        Log.d(TAG, "Showing progress reminder for: $khatmaName ($pagesRead read, $pagesRemaining remaining)")

        createNotificationChannel(context)
        showProgressNotification(context, khatmaName, khatmaId, pagesRead, pagesRemaining)
    }

    private fun showProgressNotification(context: Context, khatmaName: String, khatmaId: String, pagesRead: Int, pagesRemaining: Int) {
        // Check notification permission for Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ActivityCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                Log.w(TAG, "⚠️ Notification permission not granted for Android 13+")
                return
            }
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("open_khatma", khatmaId)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            khatmaId.hashCode() + 1000, // Different ID for progress reminder
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val message = if (pagesRemaining > 0) {
            "لا تزال $pagesRemaining صفحة لإكمال هدف اليوم"
        } else {
            "تبقى القليل لإنهاء هدفك اليومي!"
        }

        val bigText = "مرحباً 🌟\n\nقرأت $pagesRead صفحة اليوم\n" +
                if (pagesRemaining > 0) {
                    "متبقي $pagesRemaining صفحة لإكمال هدفك\n\n"
                } else {
                    "أكمل قراءتك اليومية\n\n"
                } +
                "وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا\nلا تفوت الأجر ✨"

        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_today)
            .setContentTitle("⏰ تذكير • $khatmaName")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(khatmaId.hashCode() + 1000, notification)

        Log.d(TAG, "✅ Progress reminder shown for: $khatmaName")
    }
}
