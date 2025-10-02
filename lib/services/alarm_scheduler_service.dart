import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'prayer_times_service.dart';
import 'analytics_service.dart';

class AlarmSchedulerService {
  static AlarmSchedulerService? _instance;
  static AlarmSchedulerService get instance => _instance ??= AlarmSchedulerService._();

  AlarmSchedulerService._();

  final PrayerTimesService _prayerService = PrayerTimesService.instance;
  bool _initialized = false;

  // Method channel for native alarm scheduling
  static const MethodChannel _alarmChannel = MethodChannel('com.helal.quran/alarm');

  // Alarm IDs for azan
  static const int fajrAlarmId = 1;
  static const int dhuhrAlarmId = 2;
  static const int asrAlarmId = 3;
  static const int maghribAlarmId = 4;
  static const int ishaAlarmId = 5;
  static const int midnightAlarmId = 99;

  // Notification alarm IDs (prayer ID + 100)
  static const int fajrNotifId = 101;
  static const int dhuhrNotifId = 102;
  static const int asrNotifId = 103;
  static const int maghribNotifId = 104;
  static const int ishaNotifId = 105;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (kDebugMode) debugPrint('✅ AlarmSchedulerService initialized');
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error initializing AlarmSchedulerService: $e');
    }
  }

  // Schedule all 5 daily prayer alarms (both azan and notifications)
  Future<void> scheduleAllPrayerAlarms() async {
    int totalAlarms = 0;
    int successfulAlarms = 0;

    try {
      if (!_initialized) {
        await initialize();
      }

      if (kDebugMode) debugPrint('📅 Scheduling all prayer alarms...');

      final prefs = await SharedPreferences.getInstance();
      final notificationMinutes = prefs.getInt('notification_time_minutes') ?? 10;

      final prayerTimes = _prayerService.getCurrentPrayerTimes();
      final now = DateTime.now();

      // Schedule each prayer (azan and notification) - track success
      final fajrSuccess = await _schedulePrayer(Prayer.fajr, fajrAlarmId, fajrNotifId, prayerTimes, now, notificationMinutes);
      totalAlarms += 2; successfulAlarms += fajrSuccess;

      final dhuhrSuccess = await _schedulePrayer(Prayer.dhuhr, dhuhrAlarmId, dhuhrNotifId, prayerTimes, now, notificationMinutes);
      totalAlarms += 2; successfulAlarms += dhuhrSuccess;

      final asrSuccess = await _schedulePrayer(Prayer.asr, asrAlarmId, asrNotifId, prayerTimes, now, notificationMinutes);
      totalAlarms += 2; successfulAlarms += asrSuccess;

      final maghribSuccess = await _schedulePrayer(Prayer.maghrib, maghribAlarmId, maghribNotifId, prayerTimes, now, notificationMinutes);
      totalAlarms += 2; successfulAlarms += maghribSuccess;

      final ishaSuccess = await _schedulePrayer(Prayer.isha, ishaAlarmId, ishaNotifId, prayerTimes, now, notificationMinutes);
      totalAlarms += 2; successfulAlarms += ishaSuccess;

      // Schedule midnight reschedule for next day
      await _scheduleMidnightReschedule();

      if (kDebugMode) debugPrint('✅ All prayer alarms scheduled successfully ($successfulAlarms/$totalAlarms)');

      // Log analytics
      await AnalyticsService.logAllAlarmsScheduled(totalAlarms, successfulAlarms);

    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error scheduling prayer alarms: $e');
      await AnalyticsService.logError('alarm_scheduling', e.toString());
    }
  }

  Future<int> _schedulePrayer(
    Prayer prayer,
    int alarmId,
    int notifId,
    PrayerTimes prayerTimes,
    DateTime now,
    int notificationMinutes,
  ) async {
    int successCount = 0;

    try {
      final prayerTime = prayerTimes.timeForPrayer(prayer);
      if (prayerTime == null) {
        if (kDebugMode) debugPrint('⚠️ No prayer time for ${prayer.name}');
        await AnalyticsService.logPrayerTimesError('No prayer time for ${prayer.name}');
        return 0;
      }

      // If prayer time has already passed today, schedule for tomorrow
      DateTime scheduleTime = prayerTime;
      if (prayerTime.isBefore(now)) {
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowPrayerTimes = _prayerService.getPrayerTimesForDate(tomorrow);
        final tomorrowPrayerTime = tomorrowPrayerTimes.timeForPrayer(prayer);

        if (tomorrowPrayerTime != null) {
          scheduleTime = tomorrowPrayerTime;
          if (kDebugMode) debugPrint('⏭️ ${prayer.name} already passed, scheduling for tomorrow');
        } else {
          if (kDebugMode) debugPrint('❌ Could not get tomorrow\'s prayer time for ${prayer.name}');
          await AnalyticsService.logPrayerTimesError('Could not get tomorrow prayer time for ${prayer.name}');
          return 0;
        }
      }

      // Format prayer time for display
      final hour = scheduleTime.hour > 12 ? scheduleTime.hour - 12 : (scheduleTime.hour == 0 ? 12 : scheduleTime.hour);
      final minute = scheduleTime.minute.toString().padLeft(2, '0');
      final period = scheduleTime.hour >= 12 ? 'م' : 'ص';
      final formattedTime = '$hour:$minute $period';

      final prayerName = _prayerService.getPrayerNameInArabic(prayer);

      // Schedule azan alarm using native method channel
      final azanSuccess = await _alarmChannel.invokeMethod<bool>('scheduleAlarm', {
        'alarmId': alarmId,
        'timeInMillis': scheduleTime.millisecondsSinceEpoch,
        'prayerName': prayerName,
        'prayerTime': formattedTime,
      });

      if (azanSuccess == true) {
        successCount++;
        if (kDebugMode) {
          debugPrint('✅ ${prayer.name} azan alarm scheduled for $formattedTime');
        }
        await AnalyticsService.logAlarmScheduled(prayerName, 'azan', true);
      } else {
        if (kDebugMode) debugPrint('❌ Failed to schedule ${prayer.name} azan alarm');
        await AnalyticsService.logAlarmScheduled(prayerName, 'azan', false);
      }

      // Schedule notification alarm (X minutes before prayer time)
      final notificationTime = scheduleTime.subtract(Duration(minutes: notificationMinutes));

      // Only schedule notification if it's in the future
      if (notificationTime.isAfter(now)) {
        final notifSuccess = await _alarmChannel.invokeMethod<bool>('scheduleNotificationAlarm', {
          'notificationId': notifId,
          'prayerId': alarmId,
          'timeInMillis': notificationTime.millisecondsSinceEpoch,
          'prayerName': prayerName,
          'minutesBefore': notificationMinutes,
        });

        if (notifSuccess == true) {
          successCount++;
          if (kDebugMode) {
            debugPrint('✅ ${prayer.name} notification scheduled $notificationMinutes min before');
          }
          await AnalyticsService.logAlarmScheduled(prayerName, 'notification', true);
        } else {
          if (kDebugMode) debugPrint('❌ Failed to schedule ${prayer.name} notification');
          await AnalyticsService.logAlarmScheduled(prayerName, 'notification', false);
        }
      } else {
        if (kDebugMode) debugPrint('⏭️ ${prayer.name} notification time already passed, skipping');
      }

      return successCount;

    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error scheduling ${prayer.name}: $e');
      await AnalyticsService.logAlarmSchedulingError(prayer.name.toString(), e.toString());
      return successCount;
    }
  }

  Future<void> _scheduleMidnightReschedule() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1); // 00:00:01 next day

      // Schedule midnight reschedule using native method channel
      final success = await _alarmChannel.invokeMethod<bool>('scheduleMidnightReschedule', {
        'timeInMillis': midnight.millisecondsSinceEpoch,
      });

      if (success == true) {
        if (kDebugMode) debugPrint('✅ Midnight reschedule set for $midnight');
      } else {
        if (kDebugMode) debugPrint('❌ Failed to schedule midnight reschedule');
      }

    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error scheduling midnight reschedule: $e');
    }
  }

  // Cancel all alarms
  Future<void> cancelAllAlarms() async {
    try {
      await _alarmChannel.invokeMethod('cancelAllAlarms');
      if (kDebugMode) debugPrint('✅ All alarms cancelled');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error cancelling alarms: $e');
    }
  }
}
