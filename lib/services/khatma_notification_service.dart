import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/khatma.dart';

class KhatmaNotificationService {
  static const MethodChannel _channel = MethodChannel('com.helal.quran/khatma_alarms');

  /// Schedule a daily notification for a Khatma
  static Future<bool> scheduleKhatmaNotification(Khatma khatma) async {
    if (khatma.notificationTime == null) {
      return false;
    }

    try {
      // Parse notification time (HH:mm format)
      final parts = khatma.notificationTime!.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

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
        'alarmId': khatma.id.hashCode,
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
        'alarmId': khatmaId.hashCode,
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
      // Parse notification time
      final parts = khatma.notificationTime!.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

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
        'alarmId': khatma.id.hashCode + 1000, // Different ID from main reminder
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
