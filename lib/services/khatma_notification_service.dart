import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/khatma.dart';

class KhatmaNotificationService {
  static const MethodChannel _channel = MethodChannel('com.helal.quran/khatma_alarms');

  /// Generate unique alarm ID from khatma ID string (prevents hash collisions)
  static int _getAlarmId(String khatmaId, {bool isProgressReminder = false}) {
    // Use a simple but effective string hash
    int hash = 0;
    for (int i = 0; i < khatmaId.length; i++) {
      hash = ((hash << 5) - hash) + khatmaId.codeUnitAt(i);
      hash = hash & 0x7FFFFFFF; // Keep it positive and within 32-bit range
    }
    // Add large offset for progress reminders to avoid collision
    return isProgressReminder ? hash + 1000000 : hash;
  }

  /// Schedule a daily notification for a Khatma
  static Future<bool> scheduleKhatmaNotification(Khatma khatma) async {
    if (khatma.notificationTime == null) {
      return false;
    }

    try {
      // Parse notification time (HH:mm format) with validation
      final parts = khatma.notificationTime!.split(':');

      if (parts.length != 2) {
        debugPrint('⚠️ ERROR: Invalid time format: ${khatma.notificationTime}');
        return false;
      }

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour == null || minute == null) {
        debugPrint('⚠️ ERROR: Failed to parse time: ${khatma.notificationTime}');
        return false;
      }

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        debugPrint('⚠️ ERROR: Invalid time values: $hour:$minute');
        return false;
      }

      // Calculate next notification time
      final now = DateTime.now();
      var nextNotification = DateTime(now.year, now.month, now.day, hour, minute);

      // If time has passed today, schedule for tomorrow
      if (nextNotification.isBefore(now)) {
        nextNotification = nextNotification.add(const Duration(days: 1));
      }

      final timeInMillis = nextNotification.millisecondsSinceEpoch;
      final pagesPerDay = khatma.getCurrentPagesPerDay();

      final result = await _channel.invokeMethod('scheduleKhatmaAlarm', {
        'alarmId': _getAlarmId(khatma.id),
        'timeInMillis': timeInMillis,
        'khatmaName': khatma.name,
        'khatmaId': khatma.id,
        'pagesToday': pagesPerDay,
      });

      if (kDebugMode) {
        debugPrint('✅ Scheduled Khatma notification for ${khatma.name} at $hour:$minute');
      }

      return result == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error scheduling Khatma notification: $e');
      }
      return false;
    }
  }

  /// Cancel a Khatma notification
  static Future<bool> cancelKhatmaNotification(String khatmaId) async {
    try {
      await _channel.invokeMethod('cancelKhatmaAlarm', {
        'alarmId': _getAlarmId(khatmaId),
      });

      if (kDebugMode) {
        debugPrint('✅ Cancelled Khatma notification for ID: $khatmaId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error cancelling Khatma notification: $e');
      }
      return false;
    }
  }

  /// Reschedule all active Khatma notifications
  static Future<void> rescheduleAllKhatmaNotifications(List<Khatma> khatmas) async {
    for (var khatma in khatmas) {
      if (!khatma.isCompleted && khatma.notificationTime != null) {
        await scheduleKhatmaNotification(khatma);
      }
    }
  }

  /// Cancel all Khatma notifications
  static Future<void> cancelAllKhatmaNotifications(List<Khatma> khatmas) async {
    for (var khatma in khatmas) {
      await cancelKhatmaNotification(khatma.id);
    }
  }

  /// Schedule a progress reminder notification (1-2 hours after the initial reminder)
  static Future<bool> scheduleProgressReminder(
    Khatma khatma,
    int hoursAfter, {
    int? pagesRead,
  }) async {
    if (khatma.notificationTime == null || khatma.mode == KhatmaMode.tracking) {
      return false;
    }

    try {
      // Parse notification time with validation
      final parts = khatma.notificationTime!.split(':');

      if (parts.length != 2) {
        debugPrint('⚠️ ERROR: Invalid time format for progress reminder: ${khatma.notificationTime}');
        return false;
      }

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour == null || minute == null) {
        debugPrint('⚠️ ERROR: Failed to parse time for progress reminder: ${khatma.notificationTime}');
        return false;
      }

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        debugPrint('⚠️ ERROR: Invalid time values for progress reminder: $hour:$minute');
        return false;
      }

      // Calculate reminder time (hoursAfter hours after the initial notification)
      final now = DateTime.now();
      var reminderTime = DateTime(now.year, now.month, now.day, hour, minute)
          .add(Duration(hours: hoursAfter));

      // If time has passed today, schedule for tomorrow
      if (reminderTime.isBefore(now)) {
        reminderTime = reminderTime.add(const Duration(days: 1));
      }

      final timeInMillis = reminderTime.millisecondsSinceEpoch;
      final pagesPerDay = khatma.getCurrentPagesPerDay();
      final currentPagesRead = pagesRead ?? 0;
      final pagesRemaining = pagesPerDay - currentPagesRead;

      if (pagesRemaining <= 0) {
        // Already completed, no need for reminder
        return false;
      }

      final result = await _channel.invokeMethod('scheduleProgressReminder', {
        'alarmId': _getAlarmId(khatma.id, isProgressReminder: true),
        'timeInMillis': timeInMillis,
        'khatmaName': khatma.name,
        'khatmaId': khatma.id,
        'pagesRead': currentPagesRead,
        'pagesRemaining': pagesRemaining,
      });

      if (kDebugMode) {
        debugPrint('✅ Scheduled progress reminder for ${khatma.name} at ${hour + hoursAfter}:$minute');
      }

      return result == true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error scheduling progress reminder: $e');
      }
      return false;
    }
  }
}
