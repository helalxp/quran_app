package com.helal.quran

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/**
 * Native alarm scheduler for prayer times.
 * Schedules alarms that directly trigger AzanBroadcastReceiver without Dart callbacks.
 * This works even when the app is completely killed.
 */
class PrayerAlarmScheduler(private val context: Context) {

    companion object {
        private const val TAG = "PrayerAlarmScheduler"

        // Alarm request codes for azan (same as prayer IDs)
        const val FAJR_ALARM_ID = 1
        const val DHUHR_ALARM_ID = 2
        const val ASR_ALARM_ID = 3
        const val MAGHRIB_ALARM_ID = 4
        const val ISHA_ALARM_ID = 5
        const val MIDNIGHT_ALARM_ID = 99

        // Notification alarm request codes (prayer ID + 100 to avoid conflicts)
        const val FAJR_NOTIF_ID = 101
        const val DHUHR_NOTIF_ID = 102
        const val ASR_NOTIF_ID = 103
        const val MAGHRIB_NOTIF_ID = 104
        const val ISHA_NOTIF_ID = 105
    }

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    /**
     * Schedule a prayer alarm that will trigger AzanBroadcastReceiver.
     * @param alarmId Unique ID for this prayer (1-5)
     * @param timeInMillis Exact time to trigger the alarm
     * @param prayerName Arabic name of the prayer
     * @param prayerTime Formatted time string (e.g., "5:31 ص")
     * @return true if scheduled successfully
     */
    fun scheduleAlarm(
        alarmId: Int,
        timeInMillis: Long,
        prayerName: String,
        prayerTime: String
    ): Boolean {
        try {
            Log.d(TAG, "Scheduling alarm $alarmId for $prayerName at $prayerTime (${timeInMillis}ms)")

            // Create intent for AzanBroadcastReceiver
            val intent = Intent(context, AzanBroadcastReceiver::class.java).apply {
                action = AzanBroadcastReceiver.ACTION_PLAY_AZAN
                putExtra(AzanBroadcastReceiver.EXTRA_PRAYER_NAME, prayerName)
                putExtra(AzanBroadcastReceiver.EXTRA_PRAYER_TIME, prayerTime)
                putExtra("alarm_id", alarmId)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Schedule exact alarm with wake-up
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ - check if we can schedule exact alarms
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        timeInMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Alarm $alarmId scheduled successfully (API 31+)")
                    return true
                } else {
                    Log.e(TAG, "❌ Cannot schedule exact alarms - permission not granted")
                    return false
                }
            } else {
                // Android 11 and below
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    timeInMillis,
                    pendingIntent
                )
                Log.d(TAG, "✅ Alarm $alarmId scheduled successfully")
                return true
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error scheduling alarm $alarmId: ${e.message}", e)
            return false
        }
    }

    /**
     * Cancel a prayer alarm.
     * @param alarmId ID of the alarm to cancel
     */
    fun cancelAlarm(alarmId: Int) {
        try {
            val intent = Intent(context, AzanBroadcastReceiver::class.java).apply {
                action = AzanBroadcastReceiver.ACTION_PLAY_AZAN
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()

            Log.d(TAG, "✅ Cancelled alarm $alarmId")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error cancelling alarm $alarmId: ${e.message}", e)
        }
    }

    /**
     * Schedule a notification alarm before prayer time.
     * @param notificationId Unique notification ID (101-105)
     * @param prayerId Original prayer ID (1-5) for settings lookup
     * @param timeInMillis Exact time to trigger the notification
     * @param prayerName Arabic name of the prayer
     * @param minutesBefore Minutes before prayer time
     * @return true if scheduled successfully
     */
    fun scheduleNotificationAlarm(
        notificationId: Int,
        prayerId: Int,
        timeInMillis: Long,
        prayerName: String,
        minutesBefore: Int
    ): Boolean {
        try {
            Log.d(TAG, "Scheduling notification $notificationId for $prayerName, $minutesBefore min before (${timeInMillis}ms)")

            // Create intent for AzanBroadcastReceiver to send notification
            val intent = Intent(context, AzanBroadcastReceiver::class.java).apply {
                action = AzanBroadcastReceiver.ACTION_SEND_NOTIFICATION
                putExtra(AzanBroadcastReceiver.EXTRA_PRAYER_NAME, prayerName)
                putExtra(AzanBroadcastReceiver.EXTRA_MINUTES_BEFORE, minutesBefore)
                putExtra("alarm_id", prayerId) // Use original prayer ID for settings check
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Schedule exact alarm with wake-up
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        timeInMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Notification $notificationId scheduled successfully")
                    return true
                } else {
                    Log.e(TAG, "❌ Cannot schedule exact alarms - permission not granted")
                    return false
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    timeInMillis,
                    pendingIntent
                )
                Log.d(TAG, "✅ Notification $notificationId scheduled successfully")
                return true
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error scheduling notification $notificationId: ${e.message}", e)
            return false
        }
    }

    /**
     * Cancel a notification alarm.
     * @param notificationId ID of the notification alarm to cancel
     */
    fun cancelNotificationAlarm(notificationId: Int) {
        try {
            val intent = Intent(context, AzanBroadcastReceiver::class.java).apply {
                action = AzanBroadcastReceiver.ACTION_SEND_NOTIFICATION
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()

            Log.d(TAG, "✅ Cancelled notification alarm $notificationId")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error cancelling notification $notificationId: ${e.message}", e)
        }
    }

    /**
     * Cancel all prayer alarms (both azan and notifications).
     */
    fun cancelAllAlarms() {
        // Cancel azan alarms
        cancelAlarm(FAJR_ALARM_ID)
        cancelAlarm(DHUHR_ALARM_ID)
        cancelAlarm(ASR_ALARM_ID)
        cancelAlarm(MAGHRIB_ALARM_ID)
        cancelAlarm(ISHA_ALARM_ID)
        cancelAlarm(MIDNIGHT_ALARM_ID)

        // Cancel notification alarms
        cancelNotificationAlarm(FAJR_NOTIF_ID)
        cancelNotificationAlarm(DHUHR_NOTIF_ID)
        cancelNotificationAlarm(ASR_NOTIF_ID)
        cancelNotificationAlarm(MAGHRIB_NOTIF_ID)
        cancelNotificationAlarm(ISHA_NOTIF_ID)

        Log.d(TAG, "✅ Cancelled all prayer and notification alarms")
    }

    /**
     * Schedule midnight alarm for rescheduling next day's prayers.
     * This will trigger a Dart callback to reschedule.
     */
    fun scheduleMidnightReschedule(timeInMillis: Long): Boolean {
        try {
            Log.d(TAG, "Scheduling midnight reschedule at ${timeInMillis}ms")

            val intent = Intent(context, MidnightRescheduleReceiver::class.java)

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                MIDNIGHT_ALARM_ID,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExact(
                        AlarmManager.RTC,
                        timeInMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Midnight reschedule alarm scheduled")
                    return true
                } else {
                    Log.e(TAG, "❌ Cannot schedule exact alarms for midnight reschedule")
                    return false
                }
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC,
                    timeInMillis,
                    pendingIntent
                )
                Log.d(TAG, "✅ Midnight reschedule alarm scheduled")
                return true
            }

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error scheduling midnight reschedule: ${e.message}", e)
            return false
        }
    }
}
