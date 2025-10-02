import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'azan_service.dart';

/// DEPRECATED: This service is no longer used.
/// Prayer notifications are now handled entirely by native Android code:
/// - NativeNotificationManager.kt: Sends prayer reminder notifications
/// - AzanBroadcastReceiver.kt: Receives notification alarm triggers
/// - PrayerAlarmScheduler.kt: Schedules notification alarms
///
/// This file is kept for backwards compatibility but is not actively used.
/// Consider removing in future cleanup.
@Deprecated('Use native Android notification implementation instead')
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();

  NotificationService._();

  // Flutter Local Notifications plugin (kept for potential future use)
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Settings keys
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationTimeKey = 'notification_time_minutes';

  // Initialize the service
  Future<void> initialize() async {
    await _initializeNotifications();
    if (kDebugMode) debugPrint('✅ NotificationService initialized (native alarms handle all notifications)');
  }


  // Initialize flutter local notifications
  Future<void> _initializeNotifications() async {
    try {
      // Android initialization
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions for Android 13+
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Setup notification channels with dismissal callback
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Create azan notification channel
        const androidChannel = AndroidNotificationChannel(
          'azan_player',
          'Azan Player',
          description: 'Azan playback notifications',
          importance: Importance.high,
        );

        await androidImplementation.createNotificationChannel(androidChannel);
      }

      if (kDebugMode) debugPrint('✅ Flutter Local Notifications initialized successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error initializing notifications: $e');
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final payload = notificationResponse.payload;
    if (kDebugMode) debugPrint('🔔 Notification tapped with payload: $payload');

    // Handle different notification actions
    switch (payload) {
      case 'stop_azan':
        AzanService.instance.stopAzan();
        break;
      case 'prayer_reminder':
        // User can navigate to prayer times screen
        break;
      default:
        break;
    }
  }

  // Update notification settings (kept for compatibility)
  Future<void> updateNotificationSettings({
    bool? enabled,
    int? notificationTimeMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled != null) {
      await prefs.setBool(_notificationsEnabledKey, enabled);
    }

    if (notificationTimeMinutes != null) {
      await prefs.setInt(_notificationTimeKey, notificationTimeMinutes);
    }
  }

  // Get notification settings (kept for compatibility)
  Future<Map<String, dynamic>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_notificationsEnabledKey) ?? true,
      'notificationTimeMinutes': prefs.getInt(_notificationTimeKey) ?? 10,
    };
  }
}