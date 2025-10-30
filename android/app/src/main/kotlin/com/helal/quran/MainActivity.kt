package com.helal.quran

import android.Manifest
import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val azanChannelName = "com.helal.quran/azan"
    private val alarmChannelName = "com.helal.quran/alarm"
    private val khatmaAlarmChannelName = "com.helal.quran/khatma_alarms"
    private val vibrationChannelName = "com.helal.quran/vibration"
    private val permissionChannelName = "com.helal.quran/permissions"
    private var azanPlayer: NativeAzanPlayer? = null
    private var alarmScheduler: PrayerAlarmScheduler? = null
    private var stopAzanReceiver: BroadcastReceiver? = null

    companion object {
        private const val REQUEST_EXACT_ALARM_PERMISSION = 1001
        private const val REQUEST_POST_NOTIFICATIONS = 1002
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Request SCHEDULE_EXACT_ALARM permission on Android 12+ (API 31+)
        requestExactAlarmPermissionIfNeeded()

        // Initialize azan player and alarm scheduler
        azanPlayer = NativeAzanPlayer(this)
        alarmScheduler = PrayerAlarmScheduler(this)

        // Setup method channel for azan control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, azanChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAzan" -> {
                    val prayerName = call.argument<String>("prayerName") ?: "Prayer"
                    val prayerTime = call.argument<String>("prayerTime") ?: ""
                    azanPlayer?.playAzan(prayerName, prayerTime)
                    result.success(true)
                }
                "playAzanViaBroadcast" -> {
                    // Send broadcast intent - works even when app is killed
                    val prayerName = call.argument<String>("prayerName") ?: "Prayer"
                    val prayerTime = call.argument<String>("prayerTime") ?: ""

                    val intent = Intent(AzanBroadcastReceiver.ACTION_PLAY_AZAN).apply {
                        setPackage(packageName)
                        putExtra(AzanBroadcastReceiver.EXTRA_PRAYER_NAME, prayerName)
                        putExtra(AzanBroadcastReceiver.EXTRA_PRAYER_TIME, prayerTime)
                    }
                    sendBroadcast(intent)

                    io.flutter.Log.d("MainActivity", "📻 Sent azan broadcast for $prayerName")
                    result.success(true)
                }
                "stopAzan" -> {
                    azanPlayer?.stopAzan()
                    result.success(true)
                }
                "isPlaying" -> {
                    result.success(azanPlayer?.isCurrentlyPlaying() ?: false)
                }
                "stopAzanFromFlutter" -> {
                    // Called when user taps anywhere in the app while azan is playing
                    azanPlayer?.stopAzan()
                    // Also stop the service
                    val stopIntent = Intent(this, AzanService::class.java).apply {
                        action = AzanService.ACTION_STOP_AZAN
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Setup method channel for alarm scheduling
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    val timeInMillis = call.argument<Long>("timeInMillis") ?: 0L
                    val prayerName = call.argument<String>("prayerName") ?: ""
                    val prayerTime = call.argument<String>("prayerTime") ?: ""

                    val success = alarmScheduler?.scheduleAlarm(alarmId, timeInMillis, prayerName, prayerTime) ?: false
                    result.success(success)
                }
                "scheduleNotificationAlarm" -> {
                    val notificationId = call.argument<Int>("notificationId") ?: 0
                    val prayerId = call.argument<Int>("prayerId") ?: 0
                    val timeInMillis = call.argument<Long>("timeInMillis") ?: 0L
                    val prayerName = call.argument<String>("prayerName") ?: ""
                    val minutesBefore = call.argument<Int>("minutesBefore") ?: 10

                    val success = alarmScheduler?.scheduleNotificationAlarm(
                        notificationId, prayerId, timeInMillis, prayerName, minutesBefore
                    ) ?: false
                    result.success(success)
                }
                "cancelAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    alarmScheduler?.cancelAlarm(alarmId)
                    result.success(true)
                }
                "cancelAllAlarms" -> {
                    alarmScheduler?.cancelAllAlarms()
                    result.success(true)
                }
                "scheduleMidnightReschedule" -> {
                    val timeInMillis = call.argument<Long>("timeInMillis") ?: 0L
                    val success = alarmScheduler?.scheduleMidnightReschedule(timeInMillis) ?: false
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }

        // Setup method channel for vibration fallback
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vibrationChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    val duration = call.argument<Int>("duration") ?: 100
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(duration.toLong(), VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(duration.toLong())
                    }

                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Setup method channel for Khatma alarm scheduling
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, khatmaAlarmChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleKhatmaAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    val timeInMillis = call.argument<Long>("timeInMillis") ?: 0L
                    val khatmaName = call.argument<String>("khatmaName") ?: ""
                    val khatmaId = call.argument<String>("khatmaId") ?: ""
                    val pagesToday = call.argument<Int>("pagesToday") ?: 0

                    val success = scheduleKhatmaAlarm(alarmId, timeInMillis, khatmaName, khatmaId, pagesToday)
                    result.success(success)
                }
                "scheduleProgressReminder" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    val timeInMillis = call.argument<Long>("timeInMillis") ?: 0L
                    val khatmaName = call.argument<String>("khatmaName") ?: ""
                    val khatmaId = call.argument<String>("khatmaId") ?: ""
                    val pagesRead = call.argument<Int>("pagesRead") ?: 0
                    val pagesRemaining = call.argument<Int>("pagesRemaining") ?: 0

                    val success = scheduleProgressReminder(alarmId, timeInMillis, khatmaName, khatmaId, pagesRead, pagesRemaining)
                    result.success(success)
                }
                "cancelKhatmaAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    cancelKhatmaAlarm(alarmId)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Setup method channel for permission management
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestExactAlarmPermission" -> {
                    val hasPermission = requestExactAlarmPermissionIfNeeded()
                    result.success(hasPermission)
                }
                "hasExactAlarmPermission" -> {
                    val hasPermission = hasExactAlarmPermission()
                    result.success(hasPermission)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                REQUEST_POST_NOTIFICATIONS
                            )
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true) // Not needed on older Android versions
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Register broadcast receiver for stop action from notification
        registerStopAzanReceiver()
    }

    // Request SCHEDULE_EXACT_ALARM permission for Android 12+
    private fun requestExactAlarmPermissionIfNeeded(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivityForResult(intent, REQUEST_EXACT_ALARM_PERMISSION)
                    io.flutter.Log.d("MainActivity", "⏰ Requesting SCHEDULE_EXACT_ALARM permission")
                    return false
                } catch (e: Exception) {
                    io.flutter.Log.e("MainActivity", "❌ Error requesting SCHEDULE_EXACT_ALARM permission: ${e.message}")
                    return false
                }
            }
            return true
        }
        return true // Not needed on older Android versions
    }

    private fun hasExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            return alarmManager.canScheduleExactAlarms()
        }
        return true // Not needed on older Android versions
    }

    private fun registerStopAzanReceiver() {
        stopAzanReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "com.helal.quran.STOP_AZAN") {
                    azanPlayer?.stopAzan()
                }
            }
        }

        val filter = IntentFilter("com.helal.quran.STOP_AZAN")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopAzanReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(stopAzanReceiver, filter)
        }
    }

    private fun scheduleKhatmaAlarm(
        alarmId: Int,
        timeInMillis: Long,
        khatmaName: String,
        khatmaId: String,
        pagesToday: Int
    ): Boolean {
        return try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(this, KhatmaBroadcastReceiver::class.java).apply {
                action = KhatmaBroadcastReceiver.ACTION_KHATMA_REMINDER
                putExtra(KhatmaBroadcastReceiver.EXTRA_KHATMA_NAME, khatmaName)
                putExtra(KhatmaBroadcastReceiver.EXTRA_KHATMA_ID, khatmaId)
                putExtra(KhatmaBroadcastReceiver.EXTRA_PAGES_TODAY, pagesToday)
            }

            val pendingIntent = android.app.PendingIntent.getBroadcast(
                this,
                alarmId,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        android.app.AlarmManager.RTC_WAKEUP,
                        timeInMillis,
                        pendingIntent
                    )
                    io.flutter.Log.d("MainActivity", "✅ Khatma alarm scheduled for $khatmaName")
                    true
                } else {
                    io.flutter.Log.e("MainActivity", "❌ Cannot schedule exact alarms")
                    false
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    timeInMillis,
                    pendingIntent
                )
                io.flutter.Log.d("MainActivity", "✅ Khatma alarm scheduled for $khatmaName")
                true
            }
        } catch (e: Exception) {
            io.flutter.Log.e("MainActivity", "❌ Error scheduling Khatma alarm: ${e.message}")
            false
        }
    }

    private fun scheduleProgressReminder(
        alarmId: Int,
        timeInMillis: Long,
        khatmaName: String,
        khatmaId: String,
        pagesRead: Int,
        pagesRemaining: Int
    ): Boolean {
        return try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(this, KhatmaBroadcastReceiver::class.java).apply {
                action = KhatmaBroadcastReceiver.ACTION_PROGRESS_REMINDER
                putExtra(KhatmaBroadcastReceiver.EXTRA_KHATMA_NAME, khatmaName)
                putExtra(KhatmaBroadcastReceiver.EXTRA_KHATMA_ID, khatmaId)
                putExtra(KhatmaBroadcastReceiver.EXTRA_PAGES_READ, pagesRead)
                putExtra(KhatmaBroadcastReceiver.EXTRA_PAGES_REMAINING, pagesRemaining)
            }

            val pendingIntent = android.app.PendingIntent.getBroadcast(
                this,
                alarmId,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        android.app.AlarmManager.RTC_WAKEUP,
                        timeInMillis,
                        pendingIntent
                    )
                    io.flutter.Log.d("MainActivity", "✅ Progress reminder scheduled for $khatmaName")
                    true
                } else {
                    io.flutter.Log.e("MainActivity", "❌ Cannot schedule exact alarms")
                    false
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    timeInMillis,
                    pendingIntent
                )
                io.flutter.Log.d("MainActivity", "✅ Progress reminder scheduled for $khatmaName")
                true
            }
        } catch (e: Exception) {
            io.flutter.Log.e("MainActivity", "❌ Error scheduling progress reminder: ${e.message}")
            false
        }
    }

    private fun cancelKhatmaAlarm(alarmId: Int) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(this, KhatmaBroadcastReceiver::class.java).apply {
                action = KhatmaBroadcastReceiver.ACTION_KHATMA_REMINDER
            }

            val pendingIntent = android.app.PendingIntent.getBroadcast(
                this,
                alarmId,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()

            io.flutter.Log.d("MainActivity", "✅ Cancelled Khatma alarm $alarmId")
        } catch (e: Exception) {
            io.flutter.Log.e("MainActivity", "❌ Error cancelling Khatma alarm: ${e.message}")
        }
    }

    override fun onResume() {
        super.onResume()
        // Stop azan when app comes to foreground
        stopAzanIfPlaying("App resumed")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Update the intent
        // Stop azan when app is opened (e.g., from notification tap)
        if (intent.getBooleanExtra("stop_azan", false)) {
            stopAzanIfPlaying("App opened from notification")
        } else {
            stopAzanIfPlaying("App opened")
        }
    }

    private fun stopAzanIfPlaying(reason: String) {
        if (azanPlayer?.isCurrentlyPlaying() == true) {
            io.flutter.Log.d("MainActivity", "🛑 Stopping azan: $reason")
            azanPlayer?.stopAzan()

            // Also stop the service
            val stopIntent = Intent(this, AzanService::class.java).apply {
                action = AzanService.ACTION_STOP_AZAN
            }
            startService(stopIntent)
        }
    }

    override fun onKeyDown(keyCode: Int, event: android.view.KeyEvent?): Boolean {
        // Intercept volume buttons when app is in foreground and azan is playing
        if ((keyCode == android.view.KeyEvent.KEYCODE_VOLUME_UP ||
             keyCode == android.view.KeyEvent.KEYCODE_VOLUME_DOWN)) {
            if (azanPlayer?.isCurrentlyPlaying() == true) {
                io.flutter.Log.d("MainActivity", "🔊 Volume button pressed (app foreground) - stopping azan")
                azanPlayer?.stopAzan()

                // Also stop the service
                val stopIntent = Intent(this, AzanService::class.java).apply {
                    action = AzanService.ACTION_STOP_AZAN
                }
                startService(stopIntent)

                return true // Consume the event
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onDestroy() {
        super.onDestroy()

        // Unregister receiver safely
        stopAzanReceiver?.let {
            try {
                unregisterReceiver(it)
                io.flutter.Log.d("MainActivity", "Stop azan receiver unregistered")
            } catch (e: IllegalArgumentException) {
                // Already unregistered, ignore
                io.flutter.Log.d("MainActivity", "Stop receiver already unregistered")
            }
        }
        stopAzanReceiver = null

        // Clean up azan player
        azanPlayer?.release()
        azanPlayer = null

        // Clean up alarm scheduler
        alarmScheduler = null
    }
}