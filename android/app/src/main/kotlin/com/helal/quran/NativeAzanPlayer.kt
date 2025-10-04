package com.helal.quran

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import io.flutter.Log

class NativeAzanPlayer(private val context: Context) {
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var volumeObserver: ContentObserver? = null
    val notificationId = 9998  // Match AzanService notification ID
    private val channelId = "azan_playback"
    private var isPlaying = false
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var initialAlarmVolume: Int = 0

    companion object {
        private const val TAG = "NativeAzanPlayer"
        const val ACTION_STOP_AZAN = "com.helal.quran.STOP_AZAN"
    }

    init {
        try {
            Log.d(TAG, "🏗️ NativeAzanPlayer initializing...")
            createNotificationChannel()
            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            Log.d(TAG, "✅ NativeAzanPlayer initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing NativeAzanPlayer: ${e.message}", e)
            throw e
        }
    }

    fun playAzan(prayerName: String, prayerTime: String) {
        Log.d(TAG, "🔊 playAzan() called with prayerName=$prayerName, prayerTime=$prayerTime")
        try {
            if (isPlaying) {
                Log.d(TAG, "Azan already playing, ignoring")
                return
            }

            Log.d(TAG, "Starting azan for $prayerName at $prayerTime")

            // Acquire wake lock to turn on screen
            acquireWakeLock()

            // Request audio focus to handle volume button events
            requestAudioFocus()

            // Initialize MediaPlayer with alarm stream
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM) // Use alarm volume
                        .build()
                )

                // Load azan audio from Flutter assets (accessible even when app is killed)
                val afd = context.assets.openFd("flutter_assets/assets/azan.mp3")
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()

                prepare()

                // Set completion listener
                setOnCompletionListener {
                    Log.d(TAG, "Azan playback completed")
                    stopAzan()

                    // Send broadcast to stop the foreground service
                    val stopIntent = Intent(AzanService.ACTION_STOP_AZAN).apply {
                        setPackage(context.packageName)
                    }
                    context.sendBroadcast(stopIntent)
                }

                // Set error listener
                setOnErrorListener { mp, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    stopAzan()
                    true
                }

                start()
            }

            isPlaying = true

            // Start monitoring volume changes for stop functionality
            startVolumeMonitoring()

            // Note: Notification is shown by AzanService via getNotificationForService()
            // No need to show it here to avoid duplicate notifications

            Log.d(TAG, "Azan playback started successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Error playing azan: ${e.message}", e)
            stopAzan()
        }
    }

    fun stopAzan() {
        try {
            Log.d(TAG, "Stopping azan")

            // Stop media player
            mediaPlayer?.apply {
                if (isPlaying()) {
                    stop()
                }
                release()
            }
            mediaPlayer = null
            isPlaying = false

            // Stop volume monitoring
            stopVolumeMonitoring()

            // Release wake lock
            releaseWakeLock()

            // Abandon audio focus
            abandonAudioFocus()

            // Hide notification
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)

            Log.d(TAG, "Azan stopped successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Error stopping azan: ${e.message}", e)
        }
    }

    /**
     * Monitor alarm volume changes to allow stopping azan with volume buttons.
     * Since we use USAGE_ALARM, MediaSessionCompat doesn't work, but we can detect
     * when user changes alarm volume and stop playback.
     */
    private fun startVolumeMonitoring() {
        try {
            // Store initial volume
            initialAlarmVolume = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 0

            volumeObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) {
                    val currentVolume = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 0
                    if (currentVolume != initialAlarmVolume && isPlaying) {
                        Log.d(TAG, "🔊 Alarm volume changed - stopping azan")
                        stopAzan()

                        // Send broadcast to stop the service
                        val stopIntent = Intent(AzanService.ACTION_STOP_AZAN).apply {
                            setPackage(context.packageName)
                        }
                        context.sendBroadcast(stopIntent)
                    }
                }
            }

            context.contentResolver.registerContentObserver(
                Settings.System.CONTENT_URI,
                true,
                volumeObserver!!
            )

            Log.d(TAG, "📊 Volume monitoring started (initial volume: $initialAlarmVolume)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting volume monitoring: ${e.message}", e)
        }
    }

    /**
     * Stop monitoring volume changes
     */
    private fun stopVolumeMonitoring() {
        try {
            volumeObserver?.let {
                context.contentResolver.unregisterContentObserver(it)
                volumeObserver = null
                Log.d(TAG, "📊 Volume monitoring stopped")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping volume monitoring: ${e.message}", e)
        }
    }

    private fun acquireWakeLock() {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "QuranByHelal:AzanWakeLock"
            )
            wakeLock?.acquire(5 * 60 * 1000L) // 5 minutes max
            Log.d(TAG, "Wake lock acquired - screen should turn on")
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock: ${e.message}", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "Wake lock released")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock: ${e.message}", e)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Azan Playback",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for azan playback"
                setSound(null, null) // No sound for notification (azan plays separately)
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun requestAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()

                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(audioAttributes)
                    .setOnAudioFocusChangeListener { focusChange ->
                        if (focusChange == AudioManager.AUDIOFOCUS_LOSS ||
                            focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
                            Log.d(TAG, "🔇 Audio focus lost - stopping azan")
                            stopAzan()
                        }
                    }
                    .build()

                audioManager?.requestAudioFocus(audioFocusRequest!!)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(
                    { focusChange ->
                        if (focusChange == AudioManager.AUDIOFOCUS_LOSS ||
                            focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
                            Log.d(TAG, "🔇 Audio focus lost - stopping azan")
                            stopAzan()
                        }
                    },
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                )
            }
            Log.d(TAG, "🎵 Audio focus requested")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error requesting audio focus: ${e.message}", e)
        }
    }

    private fun abandonAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let {
                    audioManager?.abandonAudioFocusRequest(it)
                }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
            Log.d(TAG, "🔇 Audio focus abandoned")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error abandoning audio focus: ${e.message}", e)
        }
    }

    fun isCurrentlyPlaying(): Boolean = isPlaying

    /**
     * Clean up resources when player is no longer needed
     */
    fun release() {
        stopAzan()
    }

    /**
     * Get notification for use as foreground service notification
     */
    fun getNotificationForService(prayerName: String, prayerTime: String): android.app.Notification {
        val stopIntent = Intent(ACTION_STOP_AZAN).apply {
            setPackage(context.packageName)
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("🕌 $prayerTime - $prayerName")
            .setContentText("حان الان موعد صلاة $prayerName")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(
                android.R.drawable.ic_media_pause,
                "إيقاف",
                stopPendingIntent
            )
            .setAutoCancel(false)
            .build()
    }
}
