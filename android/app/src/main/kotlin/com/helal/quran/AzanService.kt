package com.helal.quran

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import android.util.Log

/**
 * Foreground Service that plays azan.
 * This ensures the azan plays completely even when the app is killed.
 * Foreground services have higher priority and won't be killed by the system.
 */
class AzanService : Service() {

    companion object {
        private const val TAG = "AzanService"
        private const val NOTIFICATION_ID = 9998
        private const val CHANNEL_ID = "azan_service"

        const val ACTION_PLAY_AZAN = "com.helal.quran.AzanService.PLAY_AZAN"
        const val ACTION_STOP_AZAN = "com.helal.quran.AzanService.STOP_AZAN"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_TIME = "prayer_time"
    }

    private var azanPlayer: NativeAzanPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🚀 AzanService created")

        // Create notification channel
        createNotificationChannel()

        // Initialize azan player with error handling
        // NativeAzanPlayer handles azan playback and volume monitoring
        try {
            azanPlayer = NativeAzanPlayer(this)
            Log.d(TAG, "✅ NativeAzanPlayer initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize NativeAzanPlayer: ${e.message}", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "📥 onStartCommand: ${intent?.action}")

        when (intent?.action) {
            ACTION_PLAY_AZAN -> {
                val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
                val prayerTime = intent.getStringExtra(EXTRA_PRAYER_TIME) ?: ""

                Log.d(TAG, "▶️ Playing azan for $prayerName at $prayerTime")

                // Initialize player if needed
                try {
                    if (azanPlayer == null) {
                        Log.e(TAG, "❌ AzanPlayer is null! Attempting to reinitialize...")
                        azanPlayer = NativeAzanPlayer(this)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Exception initializing azanPlayer: ${e.message}", e)
                    e.printStackTrace()
                }

                // Start foreground service with notification from NativeAzanPlayer
                // This ensures we only show ONE notification instead of two
                val notification = azanPlayer?.getNotificationForService(prayerName, prayerTime)
                    ?: createMinimalNotification() // Fallback in case player is null
                startForeground(NOTIFICATION_ID, notification)

                // Acquire wake lock to keep screen on
                acquireWakeLock()

                // Play azan - service will stop automatically when playback completes
                try {
                    Log.d(TAG, "📢 Calling azanPlayer.playAzan($prayerName, $prayerTime)")
                    azanPlayer?.playAzan(prayerName, prayerTime)
                    Log.d(TAG, "✅ playAzan() call completed")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Exception in playAzan: ${e.message}", e)
                    e.printStackTrace()
                }

                // Schedule auto-stop after 5 minutes as failsafe
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    Log.d(TAG, "⏱️ Failsafe timeout reached - stopping service")
                    stopAzan()
                }, 5 * 60 * 1000L) // 5 minutes
            }

            ACTION_STOP_AZAN -> {
                Log.d(TAG, "⏹️ Stopping azan")
                stopAzan()
            }
        }

        // If service is killed, don't restart
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "💀 AzanService destroyed")
        stopAzan()
    }

    private fun stopAzan() {
        azanPlayer?.stopAzan()
        releaseWakeLock()
        stopForeground(true)
        stopSelf()
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "QuranByHelal:AzanServiceWakeLock"
            )
            wakeLock?.acquire(5 * 60 * 1000L) // 5 minutes max
            Log.d(TAG, "🔒 Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error acquiring wake lock: ${e.message}", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "🔓 Wake lock released")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error releasing wake lock: ${e.message}", e)
        }
    }

    private fun createMinimalNotification(): Notification {
        // Fallback notification in case NativeAzanPlayer is null
        // Normally, the service uses the notification from NativeAzanPlayer
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Azan Service")
            .setContentText("Running...")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Azan Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Plays azan at prayer times"
                setSound(null, null) // No notification sound (azan plays separately)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
