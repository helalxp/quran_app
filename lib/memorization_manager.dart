// lib/memorization_manager.dart - Memorization system for Quran learning

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/ayah_marker.dart';
import 'continuous_audio_manager.dart';

/// Types of memorization modes
enum MemorizationMode {
  singleAyah,    // Repeat single ayah
  ayahRange,     // Repeat range of ayahs
  fullSurah,     // Repeat entire surah
}

/// Memorization settings
class MemorizationSettings {
  final int repetitionCount;
  final double playbackSpeed;
  final bool pauseBetweenRepetitions;
  final Duration pauseDuration;
  final MemorizationMode mode;
  final bool showProgress;
  
  const MemorizationSettings({
    this.repetitionCount = 3,
    this.playbackSpeed = 1.0,
    this.pauseBetweenRepetitions = true,
    this.pauseDuration = const Duration(seconds: 2),
    this.mode = MemorizationMode.singleAyah,
    this.showProgress = true,
  });
  
  MemorizationSettings copyWith({
    int? repetitionCount,
    double? playbackSpeed,
    bool? pauseBetweenRepetitions,
    Duration? pauseDuration,
    MemorizationMode? mode,
    bool? showProgress,
  }) {
    return MemorizationSettings(
      repetitionCount: repetitionCount ?? this.repetitionCount,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      pauseBetweenRepetitions: pauseBetweenRepetitions ?? this.pauseBetweenRepetitions,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      mode: mode ?? this.mode,
      showProgress: showProgress ?? this.showProgress,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'repetitionCount': repetitionCount,
    'playbackSpeed': playbackSpeed,
    'pauseBetweenRepetitions': pauseBetweenRepetitions,
    'pauseDurationSeconds': pauseDuration.inSeconds,
    'mode': mode.index,
    'showProgress': showProgress,
  };
  
  factory MemorizationSettings.fromJson(Map<String, dynamic> json) {
    return MemorizationSettings(
      repetitionCount: json['repetitionCount'] ?? 3,
      playbackSpeed: json['playbackSpeed']?.toDouble() ?? 1.0,
      pauseBetweenRepetitions: json['pauseBetweenRepetitions'] ?? true,
      pauseDuration: Duration(seconds: json['pauseDurationSeconds'] ?? 2),
      mode: MemorizationMode.values[json['mode'] ?? 0],
      showProgress: json['showProgress'] ?? true,
    );
  }
}

/// Current memorization session state
class MemorizationSession {
  final List<AyahMarker> ayahs;
  final String reciterName;
  final MemorizationSettings settings;
  int currentAyahIndex;
  int currentRepetition;
  bool isActive;
  
  MemorizationSession({
    required this.ayahs,
    required this.reciterName,
    required this.settings,
    this.currentAyahIndex = 0,
    this.currentRepetition = 1,
    this.isActive = false,
  });
  
  AyahMarker? get currentAyah => 
      currentAyahIndex < ayahs.length ? ayahs[currentAyahIndex] : null;
  
  bool get isComplete => 
      currentAyahIndex >= ayahs.length;
  
  bool get isCurrentAyahComplete => 
      currentRepetition > settings.repetitionCount;
      
  double get progress {
    if (ayahs.isEmpty) return 0.0;
    final totalRepetitions = ayahs.length * settings.repetitionCount;
    final completedRepetitions = (currentAyahIndex * settings.repetitionCount) + 
        (currentRepetition - 1);
    return completedRepetitions / totalRepetitions;
  }
}

/// Manages memorization sessions and settings
class MemorizationManager {
  static const String _settingsKey = 'memorization_settings';
  
  final ContinuousAudioManager _audioManager;
  MemorizationSession? _currentSession;
  MemorizationSettings _settings = const MemorizationSettings();
  Timer? _pauseTimer;
  
  // Notifiers for UI updates
  final ValueNotifier<MemorizationSession?> sessionNotifier = ValueNotifier(null);
  final ValueNotifier<MemorizationSettings> settingsNotifier = 
      ValueNotifier(const MemorizationSettings());
      
  MemorizationManager(this._audioManager) {
    _loadSettings();
  }
  
  /// Current memorization session
  MemorizationSession? get currentSession => _currentSession;
  
  /// Current memorization settings
  MemorizationSettings get settings => _settings;
  
  /// Load memorization settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      if (settingsJson != null) {
        final Map<String, dynamic> json = 
            Map<String, dynamic>.from(Uri.splitQueryString(settingsJson));
        _settings = MemorizationSettings.fromJson(json);
        settingsNotifier.value = _settings;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading memorization settings: $e');
      }
    }
  }
  
  /// Save memorization settings to storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _settings.toJson();
      final queryString = json.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      await prefs.setString(_settingsKey, queryString);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving memorization settings: $e');
      }
    }
  }
  
  /// Update memorization settings
  Future<void> updateSettings(MemorizationSettings newSettings) async {
    _settings = newSettings;
    settingsNotifier.value = _settings;
    await _saveSettings();
  }
  
  /// Start memorization session for single ayah
  Future<void> startSingleAyahMemorization({
    required AyahMarker ayah,
    required String reciterName,
    MemorizationSettings? customSettings,
  }) async {
    final sessionSettings = customSettings ?? _settings.copyWith(mode: MemorizationMode.singleAyah);
    
    _currentSession = MemorizationSession(
      ayahs: [ayah],
      reciterName: reciterName,
      settings: sessionSettings,
    );
    
    await _startSession();
  }
  
  /// Start memorization session for ayah range
  Future<void> startRangeMemorization({
    required List<AyahMarker> ayahs,
    required String reciterName,
    MemorizationSettings? customSettings,
  }) async {
    final sessionSettings = customSettings ?? _settings.copyWith(mode: MemorizationMode.ayahRange);
    
    _currentSession = MemorizationSession(
      ayahs: ayahs,
      reciterName: reciterName,
      settings: sessionSettings,
    );
    
    await _startSession();
  }
  
  /// Start memorization session for full surah
  Future<void> startSurahMemorization({
    required List<AyahMarker> surahAyahs,
    required String reciterName,
    MemorizationSettings? customSettings,
  }) async {
    final sessionSettings = customSettings ?? _settings.copyWith(mode: MemorizationMode.fullSurah);
    
    _currentSession = MemorizationSession(
      ayahs: surahAyahs,
      reciterName: reciterName,
      settings: sessionSettings,
    );
    
    await _startSession();
  }
  
  /// Start the memorization session
  Future<void> _startSession() async {
    if (_currentSession == null) return;
    
    _currentSession!.isActive = true;
    sessionNotifier.value = _currentSession;
    
    if (kDebugMode) {
      debugPrint('🧠 Starting memorization session with ${_currentSession!.ayahs.length} ayahs');
    }
    
    await _playCurrentAyah();
  }
  
  /// Play current ayah in the session
  Future<void> _playCurrentAyah() async {
    final session = _currentSession;
    if (session == null || session.currentAyah == null || !session.isActive) {
      return;
    }
    
    // Set playback speed
    _audioManager.setPlaybackSpeed(session.settings.playbackSpeed);
    
    // Play the current ayah
    try {
      await _audioManager.playSingleAyah(
        session.currentAyah!,
        session.reciterName,
      );
      
      // Listen for playback completion
      _audioManager.isPlayingNotifier.addListener(_onPlaybackStateChanged);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error playing ayah for memorization: $e');
      }
      await _handlePlaybackError();
    }
  }
  
  /// Handle playback state changes
  void _onPlaybackStateChanged() {
    final session = _currentSession;
    if (session == null || !session.isActive) return;
    
    // If playback stopped and we're in memorization mode
    if (!_audioManager.isPlayingNotifier.value) {
      _audioManager.isPlayingNotifier.removeListener(_onPlaybackStateChanged);
      _handleAyahComplete();
    }
  }
  
  /// Handle completion of current ayah playback
  void _handleAyahComplete() {
    final session = _currentSession;
    if (session == null || !session.isActive) return;
    
    if (kDebugMode) {
      debugPrint('🧠 Ayah ${session.currentRepetition}/${session.settings.repetitionCount} completed');
    }
    
    if (session.currentRepetition < session.settings.repetitionCount) {
      // Repeat current ayah
      session.currentRepetition++;
      sessionNotifier.value = session;
      
      if (session.settings.pauseBetweenRepetitions) {
        _scheduleNextPlayback();
      } else {
        _playCurrentAyah();
      }
    } else {
      // Move to next ayah
      session.currentAyahIndex++;
      session.currentRepetition = 1;
      sessionNotifier.value = session;
      
      if (session.isComplete) {
        _completeSession();
      } else {
        if (session.settings.pauseBetweenRepetitions) {
          _scheduleNextPlayback();
        } else {
          _playCurrentAyah();
        }
      }
    }
  }
  
  /// Schedule next playback after pause
  void _scheduleNextPlayback() {
    final session = _currentSession;
    if (session == null) return;
    
    _pauseTimer?.cancel();
    _pauseTimer = Timer(session.settings.pauseDuration, () {
      if (session.isActive) {
        _playCurrentAyah();
      }
    });
  }
  
  /// Complete memorization session
  void _completeSession() {
    if (kDebugMode) {
      debugPrint('🧠 Memorization session completed successfully!');
    }
    
    _currentSession?.isActive = false;
    sessionNotifier.value = _currentSession;
  }
  
  /// Handle playback error
  Future<void> _handlePlaybackError() async {
    if (kDebugMode) {
      debugPrint('🧠 Error in memorization playback, stopping session');
    }
    await stopSession();
  }
  
  /// Stop current memorization session
  Future<void> stopSession() async {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    
    if (_currentSession?.isActive == true) {
      _currentSession!.isActive = false;
      await _audioManager.stop();
    }
    
    _currentSession = null;
    sessionNotifier.value = null;
    
    if (kDebugMode) {
      debugPrint('🧠 Memorization session stopped');
    }
  }
  
  /// Pause current session
  void pauseSession() {
    if (_currentSession?.isActive == true) {
      _currentSession!.isActive = false;
      _pauseTimer?.cancel();
      _audioManager.pause();
      sessionNotifier.value = _currentSession;
    }
  }
  
  /// Resume current session  
  void resumeSession() {
    if (_currentSession != null && !_currentSession!.isActive) {
      _currentSession!.isActive = true;
      _audioManager.resume();
      sessionNotifier.value = _currentSession;
    }
  }
  
  /// Skip to next ayah in session
  void skipToNext() {
    final session = _currentSession;
    if (session == null || !session.isActive) return;
    
    _pauseTimer?.cancel();
    _audioManager.stop();
    
    session.currentAyahIndex++;
    session.currentRepetition = 1;
    
    if (session.isComplete) {
      _completeSession();
    } else {
      sessionNotifier.value = session;
      _playCurrentAyah();
    }
  }
  
  /// Skip to previous ayah in session
  void skipToPrevious() {
    final session = _currentSession;
    if (session == null || !session.isActive || session.currentAyahIndex <= 0) return;
    
    _pauseTimer?.cancel();
    _audioManager.stop();
    
    session.currentAyahIndex--;
    session.currentRepetition = 1;
    sessionNotifier.value = session;
    
    _playCurrentAyah();
  }
  
  /// Clean up resources
  void dispose() {
    _pauseTimer?.cancel();
    sessionNotifier.dispose();
    settingsNotifier.dispose();
  }
}