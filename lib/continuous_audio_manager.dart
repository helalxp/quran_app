// lib/continuous_audio_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/ayah_marker.dart';
import 'theme_manager.dart';

// Constants for better maintainability
class AudioConstants {
  static const int maxConsecutiveErrors = 5;
  static const Duration playerDisposeTimeout = Duration(seconds: 3);
  static const Duration completionDebounceTimeout = Duration(milliseconds: 200);
  static const Duration urlLoadTimeout = Duration(seconds: 8);
  static const Duration transitionDelay = Duration(milliseconds: 150);
}

// Error categorization for better handling
enum AudioErrorType { network, timeout, codec, permission, unknown }

class ContinuousAudioManager {
  // Singleton
  static final ContinuousAudioManager _instance = ContinuousAudioManager._internal();
  factory ContinuousAudioManager() => _instance;
  ContinuousAudioManager._internal();

  // Page following functionality  
  PageController? _pageController;
  Function(int)? _onPageChange;
  WeakReference<BuildContext>? _contextRef; // Use WeakReference to prevent memory leaks

  AudioPlayer? _audioPlayer;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  // Current playback state
  AyahMarker? _currentAyah;
  String? _currentReciter;
  final List<AyahMarker> _playQueue = [];
  int _currentIndex = 0;
  double _playbackSpeed = 1.0;
  bool _autoPlayNext = true;
  bool _repeatSurah = false;
  int _consecutiveErrors = 0;
  // Use constant from AudioConstants
  static int get maxConsecutiveErrors => AudioConstants.maxConsecutiveErrors;

  // IMPROVED: Better transition state management
  bool _isTransitioning = false;
  bool _completionHandled = false; // NEW: Prevent multiple completion events
  Timer? _completionTimer; // NEW: Debounce completion events

  // State notifiers
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isBufferingNotifier = ValueNotifier(false);
  final ValueNotifier<AyahMarker?> currentAyahNotifier = ValueNotifier(null);
  final ValueNotifier<String?> currentReciterNotifier = ValueNotifier(null);
  final ValueNotifier<double> playbackSpeedNotifier = ValueNotifier(1.0);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);

  // Available speeds
  final List<double> _availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  int _currentSpeedIndex = 2; // index of 1.0

  // VERIFIED reciter configurations with correct URLs
  final Map<String, ReciterConfig> _reciterConfigs = {
    // Abdul Basit Abdul Samad - CORRECTED
    'عبد الباسط عبد الصمد': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Abdul_Basit_Murattal_192kbps',
      hasIndividualAyahs: true,
      fallbackUrl: 'https://www.everyayah.com/data/AbdulSamad_64kbps_QuranCentral.com',
    ),

    // Mishary Rashid Alafasy - VERIFIED
    'مشاري العفاسي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Alafasy_128kbps',
      hasIndividualAyahs: true,
      fallbackUrl: 'https://www.everyayah.com/data/Alafasy_64kbps',
    ),

    // Muhammad Siddiq Al-Minshawi - VERIFIED
    'محمد صديق المنشاوي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Minshawi_Murattal_128kbps',
      hasIndividualAyahs: true,
    ),

    // Saud Ash-Shuraim - CORRECTED
    'سعود الشريم': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Shatri_128kbps',
      hasIndividualAyahs: true,
    ),

    // Abdul Rahman As-Sudais - VERIFIED
    'عبد الرحمن السديس': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Sudais_128kbps',
      hasIndividualAyahs: true,
    ),

    // Maher Al Muaiqly - VERIFIED
    'ماهر المعيقلي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/MaherAlMuaiqly128kbps',
      hasIndividualAyahs: true,
    ),

    // Ahmad Al Ajmi - CORRECTED
    'أحمد العجمي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      hasIndividualAyahs: true,
    ),

    // Muhammad Ayyub - VERIFIED
    'محمد أيوب': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Muhammad_Ayyoub_128kbps',
      hasIndividualAyahs: true,
      fallbackUrl: 'https://www.everyayah.com/data/Muhammad_Ayyoub_64kbps',
    ),

    // Abdullah Al Matroud - CORRECTED
    'عبد الله المطرود': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Abdullah_Matroud_128kbps',
      hasIndividualAyahs: true,
    ),

    // Khalid Al Qahtani - CORRECTED
    'خالد القحطاني': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Khalid_Al-Qahtani_192kbps',
      hasIndividualAyahs: true,
    ),

    // Nasser Al Qatami - CORRECTED
    'ناصر القطامي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Nasser_Alqatami_128kbps',
      hasIndividualAyahs: true,
    ),

    // Saad Al Ghamdi - VERIFIED
    'سعد الغامدي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Ghamadi_40kbps',
      hasIndividualAyahs: true,
    ),

    // ADDITIONAL popular reciters with verified URLs:

    // Mahmoud Khalil Al-Hussary
    'محمود خليل الحصري': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Husary_128kbps',
      hasIndividualAyahs: true,
      fallbackUrl: 'https://www.everyayah.com/data/Husary_64kbps',
    ),

    // Yasser Al Dosari
    'ياسر الدوسري': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Yasser_Ad-Dussary_128kbps',
      hasIndividualAyahs: true,
    ),

    // Abdur-Rahman as-Sudais (alternative spelling)
    'عبدالرحمن السديس': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Sudais_128kbps',
      hasIndividualAyahs: true,
    ),

    // Ahmed Neana
    'أحمد نعينع': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Ahmed_Neana_128kbps',
      hasIndividualAyahs: true,
    ),
  };

  // -------- Settings loading --------
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load reciter setting
      final savedReciter = prefs.getString('selected_reciter');
      if (savedReciter != null && _reciterConfigs.containsKey(savedReciter)) {
        _currentReciter = savedReciter;
        currentReciterNotifier.value = savedReciter;
        debugPrint('🎵 Loaded reciter: $savedReciter');
      } else {
        _currentReciter = _reciterConfigs.keys.first;
        currentReciterNotifier.value = _currentReciter;
      }
      
      // Load playback speed
      _playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;
      playbackSpeedNotifier.value = _playbackSpeed;
      
      // Load auto play next
      _autoPlayNext = prefs.getBool('auto_play_next') ?? true;
      
      // Load repeat surah
      _repeatSurah = prefs.getBool('repeat_surah') ?? false;
      
      debugPrint('⚙️ Settings loaded - Speed: ${_playbackSpeed}x, AutoPlay: $_autoPlayNext, Repeat: $_repeatSurah');
      
    } catch (e) {
      debugPrint('⚠️ Error loading audio settings: $e');
      // Use defaults
      _currentReciter = _reciterConfigs.keys.first;
      _playbackSpeed = 1.0;
      _autoPlayNext = true;
      _repeatSurah = false;
    }
  }

  // -------- Initialization & disposal --------

  Future<void> initialize() async {
    if (_audioPlayer != null) return;
    try {
      _audioPlayer = AudioPlayer();
      try {
        await _audioPlayer!.setVolume(0.8);
      } catch (_) {}
      
      // Load settings from SharedPreferences
      await _loadSettings();
      
      _setupListeners();
      debugPrint('✅ Audio manager initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing audio manager: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    debugPrint('🧹 Starting ContinuousAudioManager disposal...');
    
    // Cancel completion timer first
    _completionTimer?.cancel();
    _completionTimer = null;

    // Cancel all subscriptions in parallel for faster cleanup
    try {
      await Future.wait([
        _stateSubscription?.cancel() ?? Future.value(),
        _positionSubscription?.cancel() ?? Future.value(),
        _durationSubscription?.cancel() ?? Future.value(),
      ]).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('⚠️ Error canceling subscriptions: $e');
    }
    
    _stateSubscription = null;
    _positionSubscription = null;
    _durationSubscription = null;

    // Dispose audio player with timeout to prevent hanging
    try {
      await _audioPlayer?.dispose().timeout(AudioConstants.playerDisposeTimeout);
    } catch (e) {
      debugPrint('⚠️ Error disposing audio player: $e');
    }
    _audioPlayer = null;

    _resetState();
    debugPrint('✅ ContinuousAudioManager disposed successfully');
  }

  void _resetState() {
    _currentAyah = null;
    _playQueue.clear();
    _currentIndex = 0;
    _isTransitioning = false;
    _completionHandled = false;
    _consecutiveErrors = 0;

    // Cancel any pending completion timer
    _completionTimer?.cancel();
    _completionTimer = null;

    try {
      currentAyahNotifier.value = null;
      currentReciterNotifier.value = null;
      isPlayingNotifier.value = false;
      isBufferingNotifier.value = false;
      positionNotifier.value = Duration.zero;
      durationNotifier.value = Duration.zero;
    } catch (e) {
      debugPrint('⚠️ Error resetting notifiers: $e');
    }
  }

  // -------- IMPROVED Listeners & streams --------

  void _setupListeners() {
    if (_audioPlayer == null) return;

    // Player state updates with better completion handling
    _stateSubscription = _audioPlayer!.playerStateStream.listen((state) {
      try {
        debugPrint('🎵 Player state: ${state.processingState}, playing: ${state.playing}');

        // Update playing and buffering states
        isPlayingNotifier.value = state.playing;
        isBufferingNotifier.value =
            state.processingState == ProcessingState.buffering ||
                state.processingState == ProcessingState.loading;

        // Handle different processing states
        switch (state.processingState) {
          case ProcessingState.ready:
            _consecutiveErrors = 0;
            _isTransitioning = false;
            _completionHandled = false; // Reset for next completion
            debugPrint('✅ Player ready, transition complete');
            break;

          case ProcessingState.completed:
            _handleCompletion();
            break;

          case ProcessingState.idle:
            if (_isTransitioning) {
              // This is expected during transitions
              debugPrint('🔄 Player idle during transition');
            }
            break;

          default:
          // Other states (loading, buffering) are handled by the UI state updates
            break;
        }
      } catch (e) {
        debugPrint('❌ Error in state listener: $e');
        _handleError(e);
      }
    }, onError: (error) {
      debugPrint('❌ Player state error: $error');
      _handleError(error);
    });

    // Position updates with safety checks
    _positionSubscription = _audioPlayer!.positionStream.listen((position) {
      try {
        positionNotifier.value = position;
      } catch (e) {
        debugPrint('⚠️ Error updating position: $e');
      }
    }, onError: (error) {
      debugPrint('❌ Position stream error: $error');
    });

    // Duration updates with safety checks
    _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
      try {
        durationNotifier.value = duration ?? Duration.zero;
      } catch (e) {
        debugPrint('⚠️ Error updating duration: $e');
      }
    }, onError: (error) {
      debugPrint('❌ Duration stream error: $error');
    });
  }

  // NEW: Improved completion handling with debouncing
  void _handleCompletion() {
    if (_completionHandled) {
      debugPrint('🎵 Completion already handled, ignoring');
      return;
    }

    _completionHandled = true;
    debugPrint('🎵 Ayah completed, preparing to move to next');

    // Cancel any existing completion timer
    _completionTimer?.cancel();

    // Debounce completion events to prevent rapid-fire triggering
    _completionTimer = Timer(AudioConstants.completionDebounceTimeout, () {
      if (!_completionHandled) return; // Double-check in case state changed

      debugPrint('🎵 Processing completion for ayah ${_currentAyah?.surah}:${_currentAyah?.ayah}');
      _moveToNextAyah();
    });
  }

  AudioErrorType _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('timeout') || errorString.contains('timeoutexception')) {
      return AudioErrorType.timeout;
    } else if (errorString.contains('network') || errorString.contains('connection') || 
               errorString.contains('host') || errorString.contains('resolve')) {
      return AudioErrorType.network;
    } else if (errorString.contains('codec') || errorString.contains('format') || 
               errorString.contains('unsupported')) {
      return AudioErrorType.codec;
    } else if (errorString.contains('permission') || errorString.contains('access')) {
      return AudioErrorType.permission;
    }
    return AudioErrorType.unknown;
  }
  
  String _getErrorIcon(AudioErrorType type) {
    switch (type) {
      case AudioErrorType.timeout: return '⏱️';
      case AudioErrorType.network: return '🌐';
      case AudioErrorType.codec: return '🎵';
      case AudioErrorType.permission: return '🔒';
      case AudioErrorType.unknown: return '❓';
    }
  }

  // Improved error handling with categorization
  void _handleError(dynamic error) {
    _consecutiveErrors++;
    
    final errorType = _categorizeError(error);
    final errorIcon = _getErrorIcon(errorType);
    
    debugPrint('$errorIcon Error ($_consecutiveErrors/$maxConsecutiveErrors) [${errorType.name}]: $error');
    
    // Handle specific error types differently
    switch (errorType) {
      case AudioErrorType.timeout:
        debugPrint('⏱️ Timeout error - network may be slow, trying next source faster');
        break;
      case AudioErrorType.network:
        debugPrint('🌐 Network error - connection issues detected');
        break;
      case AudioErrorType.codec:
        debugPrint('🎵 Codec error - audio format issue');
        break;
      case AudioErrorType.permission:
        debugPrint('🔒 Permission error - audio access denied');
        break;
      case AudioErrorType.unknown:
        debugPrint('❓ Unknown error type - investigating...');
        break;
    }

    if (_consecutiveErrors >= maxConsecutiveErrors) {
      debugPrint('🛑 Too many consecutive errors (${errorType.name}), stopping playback');
      Future.microtask(() => stop());
    } else {
      // Try to skip to next ayah on error with shorter delay for timeouts
      final delay = errorType == AudioErrorType.timeout ? 200 : 500;
      debugPrint('🔄 Attempting to skip to next ayah due to ${errorType.name} error');
      
      Future.delayed(Duration(milliseconds: delay), () {
        if (!_isTransitioning) {
          _moveToNextAyah();
        }
      });
    }
  }

  // -------- Playback control API (public) --------

  Future<void> startContinuousPlayback(AyahMarker startingAyah, String reciterName, List<AyahMarker> allAyahsInSurah) async {
    try {
      await initialize();

      if (!_reciterConfigs.containsKey(reciterName)) {
        _currentReciter = _reciterConfigs.keys.first;
        debugPrint('⚠️ Reciter "$reciterName" not found, using fallback: $_currentReciter');
      } else {
        _currentReciter = reciterName;
      }
      currentReciterNotifier.value = _currentReciter;

      _buildPlayQueue(startingAyah, allAyahsInSurah);

      if (_playQueue.isNotEmpty) {
        // _currentIndex is already set by _buildPlayQueue
        _consecutiveErrors = 0;
        _completionHandled = false;
        playbackSpeedNotifier.value = _playbackSpeed;

        debugPrint('🎵 Starting playback with ${_playQueue.length} ayahs');
        debugPrint('🎵 Queue: ${_playQueue.map((a) => '${a.surah}:${a.ayah}').join(', ')}');

        await _playCurrentAyah();
      } else {
        debugPrint('❌ Play queue is empty');
        throw Exception('لا توجد آيات للتشغيل');
      }
    } catch (e) {
      debugPrint('❌ Error starting continuous playback: $e');
      await stop();
      rethrow;
    }
  }

  void _buildPlayQueue(AyahMarker startingAyah, List<AyahMarker> allAyahsInSurah) {
    _playQueue.clear();
    final surahAyahs = allAyahsInSurah
        .where((ayah) => ayah.surah == startingAyah.surah)
        .toList()
      ..sort((a, b) => a.ayah.compareTo(b.ayah));

    // Always start from the beginning of the surah, not from the clicked ayah
    _playQueue.addAll(surahAyahs);
    
    // Find the index of the starting ayah to set as current
    _currentIndex = surahAyahs.indexWhere((ayah) => ayah.ayah == startingAyah.ayah);
    if (_currentIndex == -1) {
      // If exact ayah not found, find the closest one
      _currentIndex = surahAyahs.indexWhere((ayah) => ayah.ayah >= startingAyah.ayah);
      if (_currentIndex == -1) _currentIndex = 0;
    }
    
    debugPrint('📜 Built complete surah queue with ${_playQueue.length} ayahs');
    debugPrint('📜 Starting from ayah ${startingAyah.surah}:${startingAyah.ayah} (index $_currentIndex)');
    debugPrint('📜 Queue ayahs: ${_playQueue.map((a) => a.ayah).toList()}');
  }

  Future<void> _playCurrentAyah() async {
    if (_currentIndex >= _playQueue.length || _audioPlayer == null) {
      debugPrint('🏁 Reached end of queue or player is null.');
      await stop();
      return;
    }

    final ayah = _playQueue[_currentIndex];

    // Prevent overlapping transitions
    if (_isTransitioning) {
      debugPrint('⚠️ Already transitioning, ignoring request for ${ayah.surah}:${ayah.ayah}');
      return;
    }

    _isTransitioning = true;
    _completionHandled = false; // Reset completion flag for this ayah

    // Cancel any pending completion timer
    _completionTimer?.cancel();
    _completionTimer = null;

    debugPrint('🎵 Playing ayah ${ayah.surah}:${ayah.ayah} (${_currentIndex + 1}/${_playQueue.length})');

    // Update current ayah info
    _currentAyah = ayah;
    currentAyahNotifier.value = ayah;

    // Follow the ayah if enabled (check will be done in the method)
    _checkAndFollowAyah();

    try {
      final config = _reciterConfigs[_currentReciter ?? _reciterConfigs.keys.first]!;
      List<String> urlsToTry = [];

      urlsToTry.add(_buildAudioUrl(ayah, config.baseUrl));
      if (config.fallbackUrl != null) {
        urlsToTry.add(_buildAudioUrl(ayah, config.fallbackUrl!));
      }

      bool playbackStarted = false;
      String? lastError;

      // Stop any current playback and wait for it to complete
      try {
        await _audioPlayer!.stop();
        await Future.delayed(AudioConstants.transitionDelay);
      } catch (e) {
        debugPrint('⚠️ Error stopping previous playback: $e');
      }

      // Try each URL until one works
      for (int i = 0; i < urlsToTry.length; i++) {
        final audioUrl = urlsToTry[i];

        try {
          debugPrint('🎵 Loading ${ayah.surah}:${ayah.ayah} from: $audioUrl ${i > 0 ? "(fallback)" : ""}');

          await _audioPlayer!.setUrl(audioUrl).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException('URL loading timeout after ${AudioConstants.urlLoadTimeout.inSeconds}s', AudioConstants.urlLoadTimeout);
            },
          );

          await _audioPlayer!.setSpeed(_playbackSpeed);
          await _audioPlayer!.play();

          debugPrint('✅ Successfully started ${ayah.surah}:${ayah.ayah}');
          playbackStarted = true;
          break;

        } catch (e) {
          lastError = e.toString();
          debugPrint('⚠️ Failed to load $audioUrl: $e');

          if (i < urlsToTry.length - 1) {
            try {
              await _audioPlayer!.stop();
              await Future.delayed(const Duration(milliseconds: 50));
            } catch (_) {}
            continue;
          }
        }
      }

      if (!playbackStarted) {
        throw Exception('فشل في تحميل جميع المصادر الصوتية: $lastError');
      }

    } catch (e) {
      debugPrint('❌ Complete failure playing ayah ${ayah.surah}:${ayah.ayah}: $e');
      _isTransitioning = false;
      _handleError(e);
    }
  }

  String _buildAudioUrl(AyahMarker ayah, String baseUrl) {
    final surahPadded = ayah.surah.toString().padLeft(3, '0');
    final ayahPadded = ayah.ayah.toString().padLeft(3, '0');
    return '$baseUrl/$surahPadded$ayahPadded.mp3';
  }

  // -------- Settings update methods --------
  
  Future<void> updateReciter(String reciterName) async {
    if (_reciterConfigs.containsKey(reciterName)) {
      _currentReciter = reciterName;
      currentReciterNotifier.value = reciterName;
      debugPrint('🎵 Reciter updated to: $reciterName');
    }
  }
  
  Future<void> updatePlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    playbackSpeedNotifier.value = speed;
    await _audioPlayer?.setSpeed(speed);
    debugPrint('🏃 Playback speed updated to: ${speed}x');
  }
  
  Future<void> updateAutoPlayNext(bool enabled) async {
    _autoPlayNext = enabled;
    debugPrint('🔄 Auto-play next updated to: $enabled');
  }
  
  Future<void> updateRepeatSurah(bool enabled) async {
    _repeatSurah = enabled;
    debugPrint('🔁 Repeat surah updated to: $enabled');
  }

  // -------- IMPROVED Next / Previous handling --------

  Future<void> _moveToNextAyah() async {
    if (_isTransitioning) {
      debugPrint('⚠️ Transition in progress, ignoring move to next');
      return;
    }

    // Check if auto-play is enabled
    if (!_autoPlayNext) {
      debugPrint('⏸️ Auto-play disabled, stopping after current ayah');
      await stop();
      return;
    }

    if (_currentIndex < _playQueue.length - 1) {
      final oldIndex = _currentIndex;
      _currentIndex++;
      final nextAyah = _playQueue[_currentIndex];
      debugPrint('⏭️ Moving from $oldIndex to $_currentIndex: ${nextAyah.surah}:${nextAyah.ayah}');
      await _playCurrentAyah();
    } else {
      debugPrint('🏁 Reached end of surah');
      
      // Check if repeat surah is enabled
      if (_repeatSurah && _playQueue.isNotEmpty) {
        debugPrint('🔄 Repeat surah enabled, restarting from beginning');
        _currentIndex = 0;
        await _playCurrentAyah();
      } else {
        debugPrint('🛑 Stopping playback');
        await stop();
      }
    }
  }

  Future<void> playPrevious() async {
    if (_isTransitioning) {
      debugPrint('⚠️ Transition in progress, ignoring previous request');
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      final prevAyah = _playQueue[_currentIndex];
      debugPrint('⏮️ Moving to previous ayah: ${prevAyah.surah}:${prevAyah.ayah} (${_currentIndex + 1}/${_playQueue.length})');
      await _playCurrentAyah();
    } else {
      debugPrint('⏮️ Already at first ayah in queue');
    }
  }

  Future<void> playNext() async {
    debugPrint('🔄 Manual next requested');
    await _moveToNextAyah();
  }

  Future<void> togglePlayPause() async {
    try {
      if (_audioPlayer == null) return;
      if (_audioPlayer!.playing) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.play();
      }
    } catch (e) {
      debugPrint('❌ togglePlayPause error: $e');
    }
  }

  /// Play single ayah (for memorization)
  Future<void> playSingleAyah(AyahMarker ayah, String reciterName) async {
    try {
      if (!_reciterConfigs.containsKey(reciterName)) {
        throw Exception('Reciter not found: $reciterName');
      }
      
      final reciterConfig = _reciterConfigs[reciterName]!;

      // Stop current playback
      await stop();

      // Update state
      currentAyahNotifier.value = ayah;
      isPlayingNotifier.value = false;
      currentReciterNotifier.value = reciterName;

      // Try to play the ayah  
      final audioUrl = _buildAudioUrl(ayah, reciterConfig.baseUrl);
      
      debugPrint('🎵 Playing single ayah for memorization: ${ayah.surah}:${ayah.ayah} - $audioUrl');

      await _audioPlayer!.setUrl(audioUrl);
      await _audioPlayer!.play();
      
    } catch (e) {
      debugPrint('❌ Error playing single ayah: $e');
      rethrow;
    }
  }

  /// Set playback speed
  void setPlaybackSpeed(double speed) {
    playbackSpeedNotifier.value = speed;
    _audioPlayer?.setSpeed(speed);
  }

  /// Pause playback
  void pause() {
    _audioPlayer?.pause();
  }

  /// Resume playback
  void resume() {
    _audioPlayer?.play();
  }

  Future<void> stop() async {
    try {
      _completionTimer?.cancel();
      _completionTimer = null;
      await _audioPlayer?.stop();
    } catch (e) {
      debugPrint('❌ Error stopping player: $e');
    } finally {
      _resetState();
      debugPrint('⏹️ Stopped continuous playback');
    }
  }

  void changeSpeed() {
    _currentSpeedIndex = (_currentSpeedIndex + 1) % _availableSpeeds.length;
    _playbackSpeed = _availableSpeeds[_currentSpeedIndex];
    playbackSpeedNotifier.value = _playbackSpeed;
    _audioPlayer?.setSpeed(_playbackSpeed);
    debugPrint('🏃 Speed changed to: ${_playbackSpeed}x');
  }

  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer?.seek(position);
    } catch (e) {
      debugPrint('❌ Seek error: $e');
    }
  }

  bool get hasCurrentAyah => currentAyahNotifier.value != null;
  AyahMarker? get currentAyah => _currentAyah;
  String? get currentReciter => _currentReciter;

  // -------- Page Following Functionality --------

  /// Register page controller and context for follow-the-ayah functionality
  void registerPageController(PageController? controller, Function(int)? onPageChange, [BuildContext? context]) {
    _pageController = controller;
    _onPageChange = onPageChange;
    _contextRef = context != null ? WeakReference(context) : null;
  }

  /// Navigate to the page containing the current ayah
  void _followCurrentAyah() async {
    final currentAyah = currentAyahNotifier.value;
    if (currentAyah == null || _pageController == null || _onPageChange == null) return;

    final targetPage = currentAyah.page;
    
    // Check if we need to change pages
    final currentPageIndex = _pageController!.hasClients ? _pageController!.page?.round() ?? 0 : 0;
    final currentPageNumber = currentPageIndex + 1; // Convert to 1-based page numbering
    
    if (currentPageNumber != targetPage) {
      debugPrint('🔄 Following ayah: navigating to page $targetPage (currently on $currentPageNumber)');
      
      try {
        // Use the page change callback to ensure proper navigation
        _onPageChange!(targetPage - 1); // Convert back to 0-based for PageView
      } catch (e) {
        debugPrint('❌ Error following ayah to page $targetPage: $e');
      }
    }
  }

  /// Check if follow-the-ayah is enabled and follow if needed
  void _checkAndFollowAyah() {
    debugPrint('🔍 Checking follow-ayah: context=${_contextRef?.target != null}, controller=${_pageController != null}, callback=${_onPageChange != null}');
    
    // Check if follow-the-ayah is enabled
    final context = _contextRef?.target;
    if (context != null && context.mounted) {
      try {
        final themeManager = Provider.of<ThemeManager>(context, listen: false);
        debugPrint('📍 Follow-ayah setting: ${themeManager.followAyahOnPlayback}');
        if (themeManager.followAyahOnPlayback) {
          _followCurrentAyah();
        } else {
          debugPrint('⏸️ Follow-ayah disabled in settings');
        }
      } catch (e) {
        // Fallback: always follow if we can't check the setting
        debugPrint('⚠️ Could not check follow-ayah setting, following anyway: $e');
        _followCurrentAyah();
      }
    } else {
      // Fallback: always follow if no context
      debugPrint('⚠️ No context available, following anyway');
      _followCurrentAyah();
    }
  }
}

class ReciterConfig {
  final String baseUrl;
  final bool hasIndividualAyahs;
  final String? fallbackUrl;

  ReciterConfig({
    required this.baseUrl,
    this.hasIndividualAyahs = true,
    this.fallbackUrl,
  });
}