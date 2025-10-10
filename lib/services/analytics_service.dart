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

  // Khatma events
  static Future<void> logKhatmaCreated(String name, int pagesPerDay, int duration) async {
    await _logEvent('khatma_created', {
      'khatma_name': name,
      'pages_per_day': pagesPerDay,
      'duration_days': duration,
    });
  }

  static Future<void> logKhatmaUpdated(String name, int pagesRead) async {
    await _logEvent('khatma_updated', {
      'khatma_name': name,
      'pages_read': pagesRead,
    });
  }

  static Future<void> logKhatmaCompleted(String name, int totalDays) async {
    await _logEvent('khatma_completed', {
      'khatma_name': name,
      'total_days': totalDays,
    });
  }

  static Future<void> logKhatmaDeleted(String name, int progressPercent) async {
    await _logEvent('khatma_deleted', {
      'khatma_name': name,
      'progress_percent': progressPercent,
    });
  }

  // Tasbih events
  static Future<void> logTasbihIncrement(String mode, int count) async {
    await _logEvent('tasbih_increment', {
      'mode': mode, // 'after_prayer', 'custom'
      'count': count,
    });
  }

  static Future<void> logTasbihReset(String mode) async {
    await _logEvent('tasbih_reset', {
      'mode': mode,
    });
  }

  static Future<void> logTasbihMilestone(String mode, int milestone) async {
    await _logEvent('tasbih_milestone', {
      'mode': mode,
      'milestone': milestone, // 33, 100, 1000, etc.
    });
  }

  // Qibla events
  static Future<void> logQiblaOpened() async {
    await _logEvent('qibla_opened');
  }

  static Future<void> logQiblaDirectionFound(double direction) async {
    await _logEvent('qibla_direction_found', {
      'direction_degrees': direction.toInt(),
    });
  }

  // Feature selection events
  static Future<void> logFeatureSelected(String featureName) async {
    await _logEvent('feature_selected', {
      'feature_name': featureName,
    });
  }

  // Download events
  static Future<void> logAudioDownloadStarted(String reciter, String surahName) async {
    await _logEvent('audio_download_started', {
      'reciter': reciter,
      'surah_name': surahName,
    });
  }

  static Future<void> logAudioDownloadCompleted(String reciter, String surahName, double sizeMB) async {
    await _logEvent('audio_download_completed', {
      'reciter': reciter,
      'surah_name': surahName,
      'size_mb': sizeMB.toInt(),
    });
  }

  static Future<void> logAudioDownloadFailed(String reciter, String surahName, String error) async {
    await _logEvent('audio_download_failed', {
      'reciter': reciter,
      'surah_name': surahName,
      'error': error,
    });
  }

  static Future<void> logAudioDeleted(String reciter, String surahName) async {
    await _logEvent('audio_deleted', {
      'reciter': reciter,
      'surah_name': surahName,
    });
  }

  // Playlist events
  static Future<void> logPlaylistCreated(int surahCount) async {
    await _logEvent('playlist_created', {
      'surah_count': surahCount,
    });
  }

  static Future<void> logPlaylistPlayed(int surahCount, String reciter) async {
    await _logEvent('playlist_played', {
      'surah_count': surahCount,
      'reciter': reciter,
    });
  }

  // Navigation events
  static Future<void> logScreenOpened(String screenName) async {
    await _logEvent('screen_opened', {
      'screen_name': screenName,
    });
  }

  // Settings events
  static Future<void> logReciterChanged(String oldReciter, String newReciter) async {
    await _logEvent('reciter_changed', {
      'old_reciter': oldReciter,
      'new_reciter': newReciter,
    });
  }

  static Future<void> logAutoPlayChanged(bool enabled) async {
    await _logEvent('auto_play_changed', {
      'enabled': enabled,
    });
  }

  static Future<void> logRepeatModeChanged(String mode) async {
    await _logEvent('repeat_mode_changed', {
      'mode': mode, // 'none', 'one', 'all'
    });
  }
}