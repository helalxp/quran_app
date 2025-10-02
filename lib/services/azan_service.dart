import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'analytics_service.dart';

/// DEPRECATED: This service is no longer used.
/// Azan playback is now handled entirely by native Android code:
/// - NativeAzanPlayer.kt: Handles azan playback with USAGE_ALARM
/// - AzanService.kt: Foreground service for background playback
/// - AzanBroadcastReceiver.kt: Receives alarm triggers
///
/// This file is kept for backwards compatibility but is not actively used.
/// Consider removing in future cleanup.
@Deprecated('Use native Android azan implementation instead')
class AzanService {
  static AzanService? _instance;
  static AzanService get instance => _instance ??= AzanService._();

  AzanService._();

  AudioPlayer? _audioPlayer;
  StreamSubscription? _playerStateSubscription;
  bool _isPlaying = false;
  bool _isInitializing = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // Settings keys
  static const String _azanVolumeKey = 'azan_volume';
  static const String _azanEnabledKey = 'azan_enabled';

  // Initialize the service
  Future<void> initialize() async {
    try {
      _audioPlayer = AudioPlayer();
      _setupPlayerStateListener();
      // Volume buttons are now handled by native MediaSessionCompat in NativeAzanPlayer
      // Load audio in background to avoid blocking UI
      Future(() async {
        await _setupAudioSession();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing azan service: $e');
    }
  }

  // Setup audio session for azan playbook
  Future<void> _setupAudioSession() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.setAudioSource(
          AudioSource.asset('assets/azan.mp3'),
        );
        if (kDebugMode) debugPrint('Azan audio loaded successfully');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading azan audio: $e');
      // Continue without audio - app should still work
    }
  }

  // Setup player state listener
  void _setupPlayerStateListener() {
    _playerStateSubscription = _audioPlayer?.playerStateStream.listen(
      (playerState) async {
        _isPlaying = playerState.playing;

        // Auto-stop when playback completes
        if (playerState.processingState == ProcessingState.completed) {
          await AnalyticsService.logAzanStopped('completed');
          _stopAzan();
        }
      },
    );
  }


  // Play azan
  Future<void> playAzan() async {
    if (_isInitializing) {
      if (kDebugMode) debugPrint('🕌 Already initializing, skipping duplicate call');
      return;
    }

    // If already playing, don't start again
    if (_isPlaying) {
      if (kDebugMode) debugPrint('🕌 Azan already playing');
      return;
    }

    try {
      _isInitializing = true;
      if (kDebugMode) debugPrint('🕌 AzanService: playAzan() called');

      // Check if azan is enabled globally
      final prefs = await SharedPreferences.getInstance();
      final azanEnabled = prefs.getBool(_azanEnabledKey) ?? true;
      if (kDebugMode) debugPrint('🕌 Global azan enabled: $azanEnabled');

      if (!azanEnabled) {
        if (kDebugMode) debugPrint('🕌 Azan disabled globally - skipping');
        return;
      }

      // Initialize if needed
      if (_audioPlayer == null) {
        if (kDebugMode) debugPrint('🕌 Audio player not initialized, initializing...');
        await initialize();
      }

      // Check if audio source is loaded
      if (_audioPlayer?.audioSource == null) {
        if (kDebugMode) debugPrint('🕌 Audio source not loaded, loading...');
        await _setupAudioSession();
      }

      if (_audioPlayer?.audioSource == null && _retryCount < _maxRetries) {
        _retryCount++;
        if (kDebugMode) debugPrint('🕌 Retrying audio setup (attempt $_retryCount/$_maxRetries)');
        await Future.delayed(const Duration(seconds: 2));
        await _setupAudioSession();
      }

      if (_audioPlayer?.audioSource == null) {
        if (kDebugMode) debugPrint('❌ Azan audio not available after $_retryCount retries');
        _showAzanNotificationFallback();
        _retryCount = 0; // Reset retry count
        return;
      }

      // Reset retry count on success
      _retryCount = 0;

      // Set volume
      final volume = prefs.getDouble(_azanVolumeKey) ?? 0.8;
      await _audioPlayer?.setVolume(volume);
      if (kDebugMode) debugPrint('🕌 Volume set to: $volume');

      // Play from beginning
      await _audioPlayer?.seek(Duration.zero);
      await _audioPlayer?.play();
      _isPlaying = true;

      if (kDebugMode) debugPrint('✅ Azan playback started successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error playing azan: $e');

      if (_retryCount < _maxRetries) {
        _retryCount++;
        if (kDebugMode) debugPrint('🕌 Retrying azan playback (attempt $_retryCount/$_maxRetries)');
        await Future.delayed(const Duration(seconds: 2));
        _isInitializing = false;
        await playAzan(); // Retry
        return;
      }

      // Exhausted retries, show fallback
      if (kDebugMode) debugPrint('❌ Azan playback failed after $_retryCount retries');
      _showAzanNotificationFallback();
      _retryCount = 0;
    } finally {
      _isInitializing = false;
    }
  }

  // Fallback notification when audio fails
  void _showAzanNotificationFallback() {
    try {
      if (kDebugMode) debugPrint('Showing azan notification without audio');
      // Fallback will be handled by NotificationService
    } catch (e) {
      if (kDebugMode) debugPrint('Error showing fallback notification: $e');
    }
  }

  // Stop azan
  Future<void> _stopAzan() async {
    try {
      await _audioPlayer?.stop();
      _isPlaying = false;
      if (kDebugMode) debugPrint('✅ Azan playback stopped');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error stopping azan: $e');
    }
  }

  // Public method to stop azan (can be called from notifications)
  Future<void> stopAzan() async {
    await _stopAzan();
  }

  // Check if azan is currently playing
  bool get isPlaying => _isPlaying;

  // Update azan settings
  Future<void> updateAzanSettings({
    double? volume,
    bool? enabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (volume != null) {
      await prefs.setDouble(_azanVolumeKey, volume);
      await _audioPlayer?.setVolume(volume);
    }

    if (enabled != null) {
      await prefs.setBool(_azanEnabledKey, enabled);
    }
  }

  // Get current azan settings
  Future<Map<String, dynamic>> getAzanSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'volume': prefs.getDouble(_azanVolumeKey) ?? 0.8,
      'enabled': prefs.getBool(_azanEnabledKey) ?? true,
    };
  }

  // Dispose resources
  Future<void> dispose() async {
    await _playerStateSubscription?.cancel();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _isPlaying = false;
  }
}