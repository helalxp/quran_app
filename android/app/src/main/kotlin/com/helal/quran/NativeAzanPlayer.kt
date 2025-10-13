package com.helal.quran

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.VolumeProviderCompat
import io.flutter.Log

class NativeAzanPlayer(private val context: Context) {
    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var volumeReceiver: BroadcastReceiver? = null
    private var screenUnlockReceiver: BroadcastReceiver? = null
    private var mediaSession: MediaSessionCompat? = null
    val notificationId = 9998  // Match AzanService notification ID
    private val channelId = "azan_playback"
    private var isPlaying = false
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var initialAlarmVolume: Int = 0
    private var stopHandler: Handler? = null
    private var stopRunnable: Runnable? = null

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

            // Set up MediaSession to capture volume buttons on lockscreen
            setupMediaSession()

            // Initialize MediaPlayer with alarm stream
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM) // Use alarm volume
                        .build()
                )

                // Load azan audio from Flutter assets (accessible even when app is killed)
                val afd = context.assets.openFd("flutter_assets/assets/audio/azan.mp3")
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

            // Check azan duration setting
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val azanDuration = prefs.getString("flutter.azan_duration", "long")

            // If short version, stop after 15 seconds
            if (azanDuration == "short") {
                Log.d(TAG, "🕌 Playing short azan (15 seconds)")
                stopHandler = Handler(Looper.getMainLooper())
                stopRunnable = Runnable {
                    if (isPlaying) {
                        Log.d(TAG, "🕌 Short azan completed, stopping...")
                        stopAzan()

                        // Send broadcast to stop the service
                        val stopIntent = Intent(AzanService.ACTION_STOP_AZAN).apply {
                            setPackage(context.packageName)
                        }
                        context.sendBroadcast(stopIntent)
                    }
                }
                stopHandler?.postDelayed(stopRunnable!!, 15000) // 15 seconds
            }

            // Start monitoring volume changes for stop functionality
            startVolumeMonitoring()

            // Start monitoring screen unlock
            startScreenUnlockMonitoring()

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

            // Cancel any pending stop runnable
            stopRunnable?.let {
                stopHandler?.removeCallbacks(it)
            }
            stopRunnable = null
            stopHandler = null

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

            // Stop screen unlock monitoring
            stopScreenUnlockMonitoring()

            // Release wake lock
            releaseWakeLock()

            // Abandon audio focus
            abandonAudioFocus()

            // Release MediaSession
            releaseMediaSession()

            // Hide notification
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)

            Log.d(TAG, "Azan stopped successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Error stopping azan: ${e.message}", e)
        }
    }

    /**
     * Monitor volume changes using BroadcastReceiver to allow stopping azan with volume buttons.
     * This approach works even when screen is locked.
     */
    private fun startVolumeMonitoring() {
        try {
            // Store initial volume
            initialAlarmVolume = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 0

            volumeReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                        // Check if still playing before processing
                        if (!isPlaying) {
                            return
                        }

                        val currentVolume = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 0

                        // Stop azan if volume changed (either up or down)
                        if (currentVolume != initialAlarmVolume) {
                            Log.d(TAG, "🔊 Alarm volume changed from $initialAlarmVolume to $currentVolume - stopping azan")
                            stopAzan()

                            // Send broadcast to stop the service
                            context?.let { ctx ->
                                val stopIntent = Intent(AzanService.ACTION_STOP_AZAN).apply {
                                    setPackage(ctx.packageName)
                                }
                                ctx.sendBroadcast(stopIntent)
                            }
                        }
                    }
                }
            }

            // Register broadcast receiver for volume changes
            val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(volumeReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(volumeReceiver, filter)
            }

            Log.d(TAG, "📊 Volume monitoring started via BroadcastReceiver (initial alarm volume: $initialAlarmVolume)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting volume monitoring: ${e.message}", e)
        }
    }

    /**
     * Stop monitoring volume changes
     */
    private fun stopVolumeMonitoring() {
        try {
            volumeReceiver?.let {
                try {
                    context.unregisterReceiver(it)
                } catch (e: IllegalArgumentException) {
                    // Receiver already unregistered, ignore
                    Log.d(TAG, "Volume receiver already unregistered")
                }
                volumeReceiver = null
                Log.d(TAG, "📊 Volume monitoring stopped")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping volume monitoring: ${e.message}", e)
        }
    }

    /**
     * Monitor screen unlock (USER_PRESENT) to stop azan when user unlocks device.
     * This provides a natural way to stop azan - unlock device and it stops.
     */
    private fun startScreenUnlockMonitoring() {
        try {
            screenUnlockReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == Intent.ACTION_USER_PRESENT) {
                        // User unlocked the device - stop azan
                        if (!isPlaying) return

                        Log.d(TAG, "🔓 Device unlocked - stopping azan")
                        stopAzan()

                        // Send broadcast to stop the service
                        context?.let { ctx ->
                            val stopIntent = Intent(AzanService.ACTION_STOP_AZAN).apply {
                                setPackage(ctx.packageName)
                            }
                            ctx.sendBroadcast(stopIntent)
                        }
                    }
                }
            }

            // Register broadcast receiver for screen unlock
            val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(screenUnlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(screenUnlockReceiver, filter)
            }

            Log.d(TAG, "🔓 Screen unlock monitoring started")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting screen unlock monitoring: ${e.message}", e)
        }
    }

    /**
     * Stop monitoring screen unlock
     */
    private fun stopScreenUnlockMonitoring() {
        try {
            screenUnlockReceiver?.let {
                try {
                    context.unregisterReceiver(it)
                } catch (e: IllegalArgumentException) {
                    // Receiver already unregistered, ignore
                    Log.d(TAG, "Screen unlock receiver already unregistered")
                }
                screenUnlockReceiver = null
                Log.d(TAG, "🔓 Screen unlock monitoring stopped")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping screen unlock monitoring: ${e.message}", e)
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

    /**
     * Set up MediaSession to intercept volume button events when screen is locked.
     * This is the ONLY reliable way to handle volume buttons on lockscreen.
     */
    private fun setupMediaSession() {
        try {
            // Create MediaSession
            mediaSession = MediaSessionCompat(context, "AzanMediaSession").apply {
                // Set playback state to PLAYING so system routes volume events to us
                setPlaybackState(
                    PlaybackStateCompat.Builder()
                        .setState(PlaybackStateCompat.STATE_PLAYING, 0, 1.0f)
                        .build()
                )

                // Create custom VolumeProvider that intercepts volume button events
                val volumeProvider = object : VolumeProviderCompat(
                    VOLUME_CONTROL_RELATIVE, // Allow volume up/down
                    100, // Max volume
                    50  // Current volume
                ) {
                    override fun onAdjustVolume(direction: Int) {
                        // Volume button pressed (UP=1, DOWN=-1) - stop azan!
                        if (isPlaying) {
                            Log.d(TAG, "🔊 Volume button pressed (screen locked, direction=$direction) - stopping azan")
                            stopAzan()

                            // Send broadcast to stop the service
                            val stopIntent = Intent(AzanService.ACTION_STOP_AZAN).apply {
                                setPackage(context.packageName)
                            }
                            context.sendBroadcast(stopIntent)
                        }
                    }
                }

                // Use our custom volume provider
                setPlaybackToRemote(volumeProvider)

                // Activate the session
                isActive = true
            }

            Log.d(TAG, "📻 MediaSession created and activated for volume button handling")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting up MediaSession: ${e.message}", e)
        }
    }

    /**
     * Release MediaSession when azan stops
     */
    private fun releaseMediaSession() {
        try {
            mediaSession?.let {
                it.isActive = false
                it.release()
            }
            mediaSession = null
            Log.d(TAG, "📻 MediaSession released")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error releasing MediaSession: ${e.message}", e)
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
        // Stop button intent
        val stopIntent = Intent(ACTION_STOP_AZAN).apply {
            setPackage(context.packageName)
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Dismiss intent - stops azan when notification is swiped away
        val dismissIntent = Intent(ACTION_STOP_AZAN).apply {
            setPackage(context.packageName)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Tap intent - opens app AND stops azan
        val tapIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("stop_azan", true)
        }
        val tapPendingIntent = PendingIntent.getActivity(
            context,
            2,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("🕌 $prayerTime - $prayerName")
            .setContentText("حان الان موعد صلاة $prayerName")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(false) // Allow dismissal
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(tapPendingIntent) // Tap notification to open app and stop
            .setDeleteIntent(dismissPendingIntent) // Swipe to dismiss stops azan
            .addAction(
                android.R.drawable.ic_media_pause,
                "إيقاف",
                stopPendingIntent
            )
            .setAutoCancel(true) // Auto-dismiss when tapped
            .build()
    }
}
