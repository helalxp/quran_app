package com.helal.quran

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val alarmChannelName = "com.helal.quran/alarm"
    private var alarmScheduler: PrayerAlarmScheduler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize alarm scheduler
        alarmScheduler = PrayerAlarmScheduler(this)

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
    }
}