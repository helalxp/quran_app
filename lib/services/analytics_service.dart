// lib/services/analytics_service.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static bool _isInitialized = false;
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;

  static FirebaseAnalytics? get analytics => _analytics;
  static FirebaseAnalyticsObserver? get observer => _observer;

  // Safe initialization
  static Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      await _analytics!.setAnalyticsCollectionEnabled(true);
      _isInitialized = true;
      debugPrint('✅ Analytics initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize analytics: $e');
      _analytics = null;
      _observer = null;
      _isInitialized = false;
      // Continue without analytics - app should still work
    }
  }

  // Safe logging method
  static Future<void> _logEvent(String name, [Map<String, Object>? parameters]) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint('Analytics not initialized, skipping event: $name');
      return;
    }

    try {
      await _analytics!.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      debugPrint('Failed to log analytics event $name: $e');
    }
  }

  // Quran reading events
  static Future<void> logSurahOpened(String surahName, int surahNumber) async {
    await _logEvent('surah_opened', {
      'surah_name': surahName,
      'surah_number': surahNumber,
    });
  }

  static Future<void> logPageViewed(int pageNumber, String surahName) async {
    await _logEvent('page_viewed', {
      'page_number': pageNumber,
      'surah_name': surahName,
    });
  }

  // Audio events
  static Future<void> logAudioStarted(String reciter, String surahName) async {
    await _logEvent('audio_started', {
      'reciter': reciter,
      'surah_name': surahName,
    });
  }

  static Future<void> logAudioPaused(String surahName) async {
    await _logEvent('audio_paused', {
      'surah_name': surahName,
    });
  }

  static Future<void> logAudioCompleted(String surahName, int duration) async {
    await _logEvent('audio_completed', {
      'surah_name': surahName,
      'duration_seconds': duration,
    });
  }

  // Bookmark events
  static Future<void> logBookmarkAdded(String surahName, int pageNumber) async {
    await _logEvent('bookmark_added', {
      'surah_name': surahName,
      'page_number': pageNumber,
    });
  }

  static Future<void> logBookmarkRemoved(String surahName, int pageNumber) async {
    await _logEvent('bookmark_removed', {
      'surah_name': surahName,
      'page_number': pageNumber,
    });
  }

  // Search events
  static Future<void> logSearchPerformed(String query, int resultsCount) async {
    await _logEvent('search_performed', {
      'search_query': query,
      'results_count': resultsCount,
    });
  }

  // Theme events
  static Future<void> logThemeChanged(String theme, bool isDarkMode) async {
    await _logEvent('theme_changed', {
      'theme_name': theme,
      'is_dark_mode': isDarkMode,
    });
  }

  // Settings events
  static Future<void> logSettingsOpened() async {
    await _logEvent('settings_opened');
  }

  // App lifecycle events
  static Future<void> logAppOpened() async {
    await _logEvent('app_opened');
  }

  static Future<void> logSessionLength(int durationMinutes) async {
    await _logEvent('session_length', {
      'duration_minutes': durationMinutes,
    });
  }

  // Prayer times events
  static Future<void> logPrayerTimesViewed(String location) async {
    await _logEvent('prayer_times_viewed', {
      'location': location,
    });
  }

  static Future<void> logLocationChanged(String newLocation, String countryCode, String calculationMethod) async {
    await _logEvent('location_changed', {
      'location': newLocation,
      'country_code': countryCode,
      'calculation_method': calculationMethod,
    });
  }

  static Future<void> logNotificationSettingChanged(String prayerName, bool enabled) async {
    await _logEvent('notification_setting_changed', {
      'prayer_name': prayerName,
      'enabled': enabled,
    });
  }

  static Future<void> logAzanSettingChanged(String prayerName, bool enabled) async {
    await _logEvent('azan_setting_changed', {
      'prayer_name': prayerName,
      'enabled': enabled,
    });
  }

  static Future<void> logAzanPlayed(String prayerName) async {
    await _logEvent('azan_played', {
      'prayer_name': prayerName,
    });
  }

  static Future<void> logAzanStopped(String reason) async {
    await _logEvent('azan_stopped', {
      'reason': reason, // 'button', 'swipe', 'app_opened', 'completed'
    });
  }

  // Native azan playback events
  static Future<void> logNativeAzanPlayed(String prayerName, String prayerTime) async {
    await _logEvent('native_azan_played', {
      'prayer_name': prayerName,
      'prayer_time': prayerTime,
    });
  }

  static Future<void> logNativeAzanError(String prayerName, String error) async {
    await _logEvent('native_azan_error', {
      'prayer_name': prayerName,
      'error_message': error,
    });
  }

  static Future<void> logNativeAzanStopped(String prayerName, String method) async {
    await _logEvent('native_azan_stopped', {
      'prayer_name': prayerName,
      'stop_method': method, // 'volume_button', 'stop_button', 'completed'
    });
  }

  // Alarm scheduling events
  static Future<void> logAlarmScheduled(String prayerName, String type, bool success) async {
    await _logEvent('alarm_scheduled', {
      'prayer_name': prayerName,
      'alarm_type': type, // 'azan' or 'notification'
      'success': success,
    });
  }

  static Future<void> logAlarmSchedulingError(String prayerName, String error) async {
    await _logEvent('alarm_scheduling_error', {
      'prayer_name': prayerName,
      'error_message': error,
    });
  }

  static Future<void> logAllAlarmsScheduled(int totalCount, int successCount) async {
    await _logEvent('all_alarms_scheduled', {
      'total_alarms': totalCount,
      'successful_alarms': successCount,
      'success_rate': (successCount / totalCount * 100).round(),
    });
  }

  // Prayer notification events
  static Future<void> logPrayerNotificationDelivered(String prayerName, int minutesBefore) async {
    await _logEvent('prayer_notification_delivered', {
      'prayer_name': prayerName,
      'minutes_before': minutesBefore,
    });
  }

  // Location events
  static Future<void> logLocationDetected(String location, bool autoDetected) async {
    await _logEvent('location_detected', {
      'location_name': location,
      'auto_detected': autoDetected,
    });
  }

  static Future<void> logLocationError(String errorType, String errorMessage) async {
    await _logEvent('location_error', {
      'error_type': errorType,
      'error_message': errorMessage,
    });
  }

  // Prayer times calculation events
  static Future<void> logPrayerTimesCalculated(String location, String method) async {
    await _logEvent('prayer_times_calculated', {
      'location': location,
      'calculation_method': method,
    });
  }

  static Future<void> logPrayerTimesError(String error) async {
    await _logEvent('prayer_times_error', {
      'error_message': error,
    });
  }

  // Feature usage events
  static Future<void> logFeatureSelected(String featureName) async {
    await _logEvent('feature_selected', {
      'feature_name': featureName,
    });
  }

  static Future<void> logQiblaOpened() async {
    await _logEvent('qibla_opened');
  }

  // Error tracking
  static Future<void> logError(String context, String error, {Map<String, Object>? additionalData}) async {
    final parameters = {
      'error_context': context,
      'error_message': error,
    };

    if (additionalData != null) {
      parameters.addAll(additionalData);
    }

    await _logEvent('app_error', parameters);
  }

  // User properties
  static Future<void> setUserProperty(String name, String value) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint('Analytics not initialized, skipping user property: $name');
      return;
    }

    try {
      await _analytics!.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Failed to set user property: $e');
    }
  }

  // Set user ID
  static Future<void> setUserId(String? userId) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint('Analytics not initialized, skipping user ID');
      return;
    }

    try {
      await _analytics!.setUserId(id: userId);
    } catch (e) {
      debugPrint('Failed to set user ID: $e');
    }
  }
}