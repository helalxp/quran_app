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