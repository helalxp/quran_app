package com.helal.quran

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import io.flutter.Log

/**
 * BroadcastReceiver that handles azan playback and prayer notifications from background alarms.
 * This works even when the app is killed because it's registered in AndroidManifest.xml.
 */
class AzanBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AzanBroadcastReceiver"
        const val ACTION_PLAY_AZAN = "com.helal.quran.PLAY_AZAN"
        const val ACTION_STOP_AZAN = "com.helal.quran.STOP_AZAN"
        const val ACTION_SEND_NOTIFICATION = "com.helal.quran.SEND_NOTIFICATION"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_TIME = "prayer_time"
        const val EXTRA_MINUTES_BEFORE = "minutes_before"

        // Singleton instances to persist across receiver invocations
        private var notificationManager: NativeNotificationManager? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "📻 Broadcast received: ${intent.action}")

        when (intent.action) {
            ACTION_PLAY_AZAN -> {
                val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
                val prayerTime = intent.getStringExtra(EXTRA_PRAYER_TIME) ?: ""
                val alarmId = intent.getIntExtra("alarm_id", 0)

                Log.d(TAG, "🔔 Alarm triggered for $prayerName (ID: $alarmId) at $prayerTime")

                // Check if azan is enabled for this prayer
                val azanEnabled = isAzanEnabled(context, alarmId)
                if (!azanEnabled) {
                    Log.d(TAG, "🔕 Azan disabled for $prayerName - skipping playback")
                    return
                }

                Log.d(TAG, "▶️ Starting AzanService for $prayerName at $prayerTime")

                // Start foreground service to play azan
                // This ensures playback completes even if receiver is killed
                val serviceIntent = Intent(context, AzanService::class.java).apply {
                    action = AzanService.ACTION_PLAY_AZAN
                    putExtra(AzanService.EXTRA_PRAYER_NAME, prayerName)
                    putExtra(AzanService.EXTRA_PRAYER_TIME, prayerTime)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }

                Log.d(TAG, "✅ AzanService started")
            }

            ACTION_STOP_AZAN -> {
                Log.d(TAG, "⏹️ Stopping azan service")

                // Stop the foreground service
                val serviceIntent = Intent(context, AzanService::class.java).apply {
                    action = AzanService.ACTION_STOP_AZAN
                }
                context.startService(serviceIntent)
            }

            ACTION_SEND_NOTIFICATION -> {
                val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
                val minutesBefore = intent.getIntExtra(EXTRA_MINUTES_BEFORE, 10)
                val alarmId = intent.getIntExtra("alarm_id", 0)

                Log.d(TAG, "📬 Notification alarm for $prayerName (ID: $alarmId), $minutesBefore min before")

                // Check if notification is enabled for this prayer
                val notificationEnabled = isNotificationEnabled(context, alarmId)
                if (!notificationEnabled) {
                    Log.d(TAG, "🔕 Notification disabled for $prayerName - skipping")
                    return
                }

                // Initialize notification manager if needed
                if (notificationManager == null) {
                    notificationManager = NativeNotificationManager(context.applicationContext)
                    Log.d(TAG, "📬 NativeNotificationManager initialized")
                }

                // Send notification
                notificationManager?.sendPrayerReminder(prayerName, minutesBefore)
            }

            else -> {
                Log.d(TAG, "⚠️ Unknown action: ${intent.action}")
            }
        }
    }

    /**
     * Check if azan is enabled for a specific prayer.
     * Reads from SharedPreferences using the prayer alarm ID.
     */
    private fun isAzanEnabled(context: Context, alarmId: Int): Boolean {
        val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Map alarm ID to prayer name key (same format used in Flutter)
        val prayerKey = when (alarmId) {
            1 -> "azan_fajr"
            2 -> "azan_dhuhr"
            3 -> "azan_asr"
            4 -> "azan_maghrib"
            5 -> "azan_isha"
            else -> null
        }

        if (prayerKey == null) {
            Log.w(TAG, "⚠️ Unknown alarm ID: $alarmId")
            return false
        }

        // Flutter shared_preferences prefixes keys with "flutter."
        val fullKey = "flutter.$prayerKey"
        // Default to false - user must explicitly enable azan to avoid false positives
        val enabled = prefs.getBoolean(fullKey, false)

        Log.d(TAG, "🔍 Checking azan toggle for alarm ID $alarmId ($prayerKey): $enabled")
        return enabled
    }

    /**
     * Check if notification is enabled for a specific prayer.
     * Reads from SharedPreferences using the prayer alarm ID.
     */
    private fun isNotificationEnabled(context: Context, alarmId: Int): Boolean {
        val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Map alarm ID to prayer name key (same format used in Flutter)
        val prayerKey = when (alarmId) {
            1 -> "notification_fajr"
            2 -> "notification_dhuhr"
            3 -> "notification_asr"
            4 -> "notification_maghrib"
            5 -> "notification_isha"
            else -> null
        }

        if (prayerKey == null) {
            Log.w(TAG, "⚠️ Unknown alarm ID: $alarmId")
            return false
        }

        // Flutter shared_preferences prefixes keys with "flutter."
        val fullKey = "flutter.$prayerKey"
        // Default to true for most prayers (except isha)
        val defaultValue = alarmId != 5 // false only for isha (ID=5)
        val enabled = prefs.getBoolean(fullKey, defaultValue)

        Log.d(TAG, "🔍 Checking notification toggle for alarm ID $alarmId ($prayerKey): $enabled")
        return enabled
    }
}
