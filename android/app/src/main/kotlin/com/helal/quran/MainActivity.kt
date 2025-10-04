package com.helal.quran

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val azanChannelName = "com.helal.quran/azan"
    private val alarmChannelName = "com.helal.quran/alarm"
    private val vibrationChannelName = "com.helal.quran/vibration"
    private var azanPlayer: NativeAzanPlayer? = null
    private var alarmScheduler: PrayerAlarmScheduler? = null
    private var stopAzanReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        // Register broadcast receiver for stop action from notification
        registerStopAzanReceiver()
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

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(stopAzanReceiver)
        } catch (e: Exception) {
            // Receiver not registered
        }
        azanPlayer?.stopAzan()
    }
}