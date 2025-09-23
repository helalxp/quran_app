// lib/continuous_audio_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_service/audio_service.dart';
import 'models/ayah_marker.dart';
import 'theme_manager.dart';
import 'constants/app_strings.dart';
import 'constants/api_constants.dart';
import 'audio_cache_manager.dart';
import 'audio_download_manager.dart';
import 'services/audio_service_handler.dart';
import 'services/analytics_service.dart';

// Constants for better maintainability
class AudioConstants {
  static const int maxConsecutiveErrors = 5;
  static const Duration playerDisposeTimeout = Duration(seconds: 3);
  static const Duration completionDebounceTimeout = Duration.zero; // Instant transitions
  static const Duration urlLoadTimeout = Duration(seconds: 8);
  static const Duration transitionDelay = Duration(milliseconds: 150);
  static const Duration crossfadeDuration = Duration(milliseconds: 50); // Crossfade time
  
  // Enhanced timeout controls
  static const Duration buffetingTimeout = Duration(seconds: 15); // Max buffering time
  static const Duration loadingStateTimeout = Duration(seconds: 20); // Overall loading timeout
  static const Duration retryDelay = Duration(seconds: 2); // Delay between retries
  static const int maxRetryAttempts = 3; // Maximum retry attempts
}

// Enhanced error categorization for better handling
enum AudioErrorType { 
  networkOffline,     // No internet connection
  networkDns,         // DNS resolution failure  
  networkTimeout,     // Network timeout
  networkServerError, // Server unavailable (404, 500, etc)
  networkSlow,        // Connection too slow
  timeout,            // General timeout
  codec,              // Audio format/codec error
  permission,         // Audio permission error
  unknown             // Unknown error type
}

// User-friendly error messages helper
class AudioErrorMessages {
  static String getUserFriendlyMessage(AudioErrorType errorType) {
    switch (errorType) {
      case AudioErrorType.networkOffline:
        return AppStrings.errorNetworkOffline;
      case AudioErrorType.networkDns:
        return AppStrings.errorNetworkDns;
      case AudioErrorType.networkTimeout:
        return AppStrings.errorNetworkTimeout;
      case AudioErrorType.networkServerError:
        return AppStrings.errorNetworkServer;
      case AudioErrorType.networkSlow:
        return AppStrings.errorNetworkSlow;
      case AudioErrorType.timeout:
        return AppStrings.errorTimeout;
      case AudioErrorType.codec:
        return AppStrings.errorCodec;
      case AudioErrorType.permission:
        return AppStrings.errorPermission;
      case AudioErrorType.unknown:
        return AppStrings.errorUnknown;
    }
  }
  
  static String getGeneralAudioError() {
    return AppStrings.errorAudioGeneral;
  }
  
  static String getPlaybackFailedError() {
    return AppStrings.errorPlaybackFailed;
  }
  
  static String getReciterNotFoundError() {
    return AppStrings.errorReciterNotFound;
  }
  
  static String getNoAyahsError() {
    return AppStrings.errorNoAyahs;
  }
}

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

  // Audio service handler
  late AudioServiceHandler _audioServiceHandler;

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
  
  // Enhanced timeout controls
  Timer? _loadingTimer; // Track loading timeout
  Timer? _bufferingTimer; // Track buffering timeout
  int _currentRetryAttempt = 0; // Track retry attempts
  
  // Network recovery tracking
  bool _networkRecoveryMode = false; // Track if we're in network recovery
  DateTime? _lastNetworkError; // Track when last network error occurred
  
  // Seamless playback enhancement
  bool _isPreloadingNext = false;
  int? _preloadedIndex;
  String? _preloadedAudioUrl;
  AudioSource? _preloadedAudioSource; // Pre-initialized AudioSource for instant switching
  bool _seamlessModeEnabled = true;
  
  // Audio cache and download managers
  final AudioCacheManager _cacheManager = AudioCacheManager();
  final AudioDownloadManager _downloadManager = AudioDownloadManager();

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

  // Use centralized reciter configurations from ApiConstants
  Map<String, ReciterConfig> get _reciterConfigs => ApiConstants.reciterConfigs;

  // -------- Seamless Transition Methods --------
  
  /// Smart preloading based on ayah position
  void _checkForSmartPreload(Duration position) {
    if (!_seamlessModeEnabled || _isPreloadingNext || _preloadedIndex == _currentIndex + 1) return;
    
    final duration = durationNotifier.value;
    if (duration == Duration.zero) return;
    
    // Start preloading when 30% through current ayah for maximum preparation time
    final progressRatio = position.inMilliseconds / duration.inMilliseconds;
    if (progressRatio >= 0.3) {
      debugPrint('📅 Smart preload triggered at ${(progressRatio * 100).toStringAsFixed(1)}%');
      _preloadNextAyah(); // This will set _isPreloadingNext=true, preventing repeated calls
    }
  }
  
  /// Preload the next ayah for seamless playback
  Future<void> _preloadNextAyah() async {
    if (_isPreloadingNext) return;
    
    // Calculate next ayah index
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _playQueue.length) {
      // If repeat is enabled, preload first ayah
      if (_repeatSurah && _playQueue.isNotEmpty) {
        await _preloadAyahAtIndex(0);
      }
      return;
    }
    
    await _preloadAyahAtIndex(nextIndex);
  }
  
  Future<void> _preloadAyahAtIndex(int index) async {
    if (_isPreloadingNext || index >= _playQueue.length) return;
    
    _isPreloadingNext = true;
    final ayah = _playQueue[index];
    
    try {
      final reciterName = _currentReciter ?? _reciterConfigs.keys.first;
      
      // Check cache first
      String? urlToPreload = _cacheManager.getCachedFilePath(reciterName, ayah.surah, ayah.ayah);
      
      if (urlToPreload != null) {
        debugPrint('📦 Preloaded cached ayah ${ayah.surah}:${ayah.ayah}');
      } else {
        // Use network URL and trigger background caching
        final config = _reciterConfigs[reciterName]!;
        urlToPreload = config.getAyahUrl(ayah.surah, ayah.ayah);
        debugPrint('📦 Preloaded network ayah ${ayah.surah}:${ayah.ayah}');
        
        // Start background caching for future use
        _cacheManager.cacheAyahAudio(
          reciter: reciterName,
          surah: ayah.surah,
          ayah: ayah.ayah,
          url: urlToPreload,
          preloadToMemory: true,
        );
      }
      
      // Try to get audio from memory buffer for fastest access
      final memoryData = _cacheManager.getFromMemoryBuffer(reciterName, ayah.surah, ayah.ayah);
      
      if (memoryData != null) {
        // Ultra-fast: Create AudioSource from memory buffer
        debugPrint('🚀 Using memory buffer for ultra-fast access');
        _preloadedAudioSource = AudioSource.uri(Uri.dataFromBytes(memoryData));
      } else if (urlToPreload.startsWith('file://')) {
        // Fast: Create AudioSource from cached file
        _preloadedAudioSource = AudioSource.uri(Uri.parse(urlToPreload));
      } else {
        // Standard: Create AudioSource from network URL
        _preloadedAudioSource = AudioSource.uri(Uri.parse(urlToPreload));
      }
      
      _preloadedAudioUrl = urlToPreload;
      _preloadedIndex = index;
      
      debugPrint('✅ AudioSource pre-initialized for ayah ${ayah.surah}:${ayah.ayah}');
    } catch (e) {
      debugPrint('⚠️ Failed to prepare ayah ${ayah.surah}:${ayah.ayah}: $e');
      _preloadedIndex = null;
      _preloadedAudioUrl = null;
      _preloadedAudioSource = null;
    } finally {
      _isPreloadingNext = false;
    }
  }
  
  /// Ultra-fast transition with pre-initialized AudioSource
  Future<bool> _instantTransitionToPreloaded() async {
    if (_preloadedIndex == null || _preloadedIndex != _currentIndex) {
      return false;
    }
    
    debugPrint('⚡ Starting ultra-fast transition');
    
    try {
      // Try AudioSource first for fastest loading, fallback to URL if needed
      if (_preloadedAudioSource != null) {
        await _audioPlayer!.setAudioSource(_preloadedAudioSource!);
      } else if (_preloadedAudioUrl != null) {
        await _audioPlayer!.setUrl(_preloadedAudioUrl!);
      } else {
        return false;
      }
      
      // Set speed and play in parallel operations where possible
      final speedFuture = _audioPlayer!.setSpeed(_playbackSpeed);
      final playFuture = _audioPlayer!.play();
      
      await Future.wait([speedFuture, playFuture]);
      
      debugPrint('⚡ Ultra-fast transition completed');
      
      // Clear preloaded data
      _preloadedIndex = null;
      _preloadedAudioUrl = null;
      _preloadedAudioSource = null;
      return true;
      
    } catch (e) {
      debugPrint('⚠️ Ultra-fast transition failed: $e');
      return false;
    }
  }

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
      
      // Initialize audio service handler with error handling
      try {
        // Only initialize if AudioService was successfully started
        if (!kIsWeb) {
          // Use the singleton instance that was created in main.dart
          debugPrint('🔄 Getting AudioServiceHandler instance...');
          _audioServiceHandler = AudioServiceHandler();
          debugPrint('🔄 Initializing AudioServiceHandler with player...');
          _audioServiceHandler.initialize(_audioPlayer!);
          debugPrint('✅ Audio service handler connected successfully');
        }
      } catch (e) {
        debugPrint('❌ Failed to initialize audio service handler: $e');
        // Continue without audio service if it fails
      }

      // Load settings from SharedPreferences
      await _loadSettings();

      // Initialize cache and download managers
      await _cacheManager.initialize();
      await _downloadManager.initialize();

      _setupListeners();
      debugPrint('✅ Audio manager initialized successfully with background audio service');
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

    // Cancel timeout timers
    _loadingTimer?.cancel();
    _bufferingTimer?.cancel();
    _completionTimer?.cancel();
    _loadingTimer = null;
    _bufferingTimer = null;
    _completionTimer = null;

    // Dispose cache and download managers
    await _cacheManager.dispose();
    await _downloadManager.dispose();
    
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
    _isPreloadingNext = false;
    _preloadedIndex = null;
    _preloadedAudioUrl = null;
    _preloadedAudioSource = null;

    // Cancel any pending timers
    _completionTimer?.cancel();
    _completionTimer = null;
    _clearTimeouts();
    
    // Clear network recovery state
    _networkRecoveryMode = false;
    _lastNetworkError = null;
    _currentRetryAttempt = 0;

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

  // -------- Enhanced Timeout Management --------
  
  void _startLoadingTimeout() {
    _loadingTimer?.cancel();
    _loadingTimer = Timer(AudioConstants.loadingStateTimeout, () {
      debugPrint('⏱️ Audio loading timeout - attempting recovery');
      _handleLoadingTimeout();
    });
  }
  
  void _startBufferingTimeout() {
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer(AudioConstants.buffetingTimeout, () {
      debugPrint('⏱️ Audio buffering timeout - attempting recovery');
      _handleBufferingTimeout();
    });
  }
  
  void _clearTimeouts() {
    _loadingTimer?.cancel();
    _bufferingTimer?.cancel();
    _loadingTimer = null;
    _bufferingTimer = null;
  }
  
  void _handleLoadingTimeout() {
    if (_currentRetryAttempt < AudioConstants.maxRetryAttempts) {
      _currentRetryAttempt++;
      debugPrint('🔄 Loading timeout - retry attempt $_currentRetryAttempt/${AudioConstants.maxRetryAttempts}');
      
      Future.delayed(AudioConstants.retryDelay, () {
        if (_currentAyah != null && _currentReciter != null && _currentReciter!.isNotEmpty) {
          playSingleAyah(_currentAyah!, _currentReciter!);
        } else {
          debugPrint('⚠️ Cannot retry - current ayah or reciter is null');
          _handleError(Exception('Cannot retry playback - missing ayah or reciter'));
        }
      });
    } else {
      debugPrint('❌ Max retry attempts reached - moving to next ayah');
      _currentRetryAttempt = 0;
      _handleError(TimeoutException('Audio loading failed after ${AudioConstants.maxRetryAttempts} attempts'));
    }
  }
  
  void _handleBufferingTimeout() {
    debugPrint('⏱️ Buffering timeout - attempting to recover');
    _handleError(TimeoutException('Audio buffering timeout'));
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
          case ProcessingState.loading:
            debugPrint('⏳ Audio loading...');
            _startLoadingTimeout();
            break;
            
          case ProcessingState.buffering:
            debugPrint('📡 Audio buffering...');
            _startBufferingTimeout();
            break;
            
          case ProcessingState.ready:
            _consecutiveErrors = 0;
            _currentRetryAttempt = 0; // Reset retry attempts on success
            _isTransitioning = false;
            _completionHandled = false; // Reset for next completion
            _clearTimeouts(); // Clear any pending timeouts
            
            // Check if we should exit network recovery mode
            if (_shouldExitNetworkRecovery()) {
              _networkRecoveryMode = false;
              debugPrint('🔧 Network recovery mode deactivated - connection stable');
            }
            
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
        _checkForSmartPreload(position);
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

  // Ultra-fast completion handling - no debounce delays
  void _handleCompletion() {
    if (_completionHandled) {
      debugPrint('🎵 Completion already handled, ignoring');
      return;
    }

    _completionHandled = true;
    debugPrint('🎵 Ayah completed, moving to next instantly');

    // Log audio completed analytics
    if (_currentAyah != null) {
      final duration = _audioPlayer?.duration?.inSeconds ?? 0;
      AnalyticsService.logAudioCompleted('سورة ${_currentAyah!.surah}', duration);
    }

    // Move to next ayah immediately - no timer delays
    _moveToNextAyah();
  }

  AudioErrorType _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network-specific error categorization
    if (errorString.contains('failed host lookup') || 
        errorString.contains('name resolution failed') ||
        errorString.contains('dns') || errorString.contains('resolve')) {
      return AudioErrorType.networkDns;
    } else if (errorString.contains('no internet connection') ||
               errorString.contains('network is unreachable') ||
               errorString.contains('connection refused') ||
               errorString.contains('offline')) {
      return AudioErrorType.networkOffline;
    } else if (errorString.contains('http') && (errorString.contains('404') || 
               errorString.contains('500') || errorString.contains('503') ||
               errorString.contains('server error') || errorString.contains('not found'))) {
      return AudioErrorType.networkServerError;
    } else if (errorString.contains('connection timeout') ||
               errorString.contains('read timeout') ||
               errorString.contains('socket timeout')) {
      return AudioErrorType.networkTimeout;
    } else if (errorString.contains('connection reset') ||
               errorString.contains('broken pipe') ||
               errorString.contains('connection aborted')) {
      return AudioErrorType.networkSlow;
    } else if (errorString.contains('timeout') || errorString.contains('timeoutexception')) {
      return AudioErrorType.timeout;
    } else if (errorString.contains('network') || errorString.contains('connection') || 
               errorString.contains('host')) {
      // Generic network error fallback
      return AudioErrorType.networkOffline;
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
      case AudioErrorType.networkOffline: return '📶';
      case AudioErrorType.networkDns: return '🔍';
      case AudioErrorType.networkTimeout: return '🌐⏱️';
      case AudioErrorType.networkServerError: return '🔴';
      case AudioErrorType.networkSlow: return '🐌';
      case AudioErrorType.timeout: return '⏱️';
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
    
    // Track network-related errors for recovery mode
    _trackNetworkError(errorType);
    
    // Handle specific error types with tailored strategies
    switch (errorType) {
      case AudioErrorType.networkOffline:
        debugPrint('📶 Device appears offline - will retry when connection returns');
        break;
      case AudioErrorType.networkDns:
        debugPrint('🔍 DNS resolution failed - trying fallback servers');
        break;
      case AudioErrorType.networkTimeout:
        debugPrint('🌐⏱️ Network timeout - connection is slow, reducing timeout for next attempt');
        break;
      case AudioErrorType.networkServerError:
        debugPrint('🔴 Server error - trying different reciter source');
        break;
      case AudioErrorType.networkSlow:
        debugPrint('🐌 Connection unstable - switching to lower quality if available');
        break;
      case AudioErrorType.timeout:
        debugPrint('⏱️ General timeout - trying next source faster');
        break;
      case AudioErrorType.codec:
        debugPrint('🎵 Codec error - audio format issue, trying different source');
        break;
      case AudioErrorType.permission:
        debugPrint('🔒 Permission error - audio access denied');
        break;
      case AudioErrorType.unknown:
        debugPrint('❓ Unknown error type - applying general recovery strategy');
        break;
    }

    if (_consecutiveErrors >= maxConsecutiveErrors) {
      debugPrint('🛑 Too many consecutive errors (${errorType.name}), stopping playback');
      Future.microtask(() => stop());
    } else {
      // Intelligent retry delay based on error type
      final delay = _getRetryDelayForErrorType(errorType);
      debugPrint('🔄 Attempting to skip to next ayah due to ${errorType.name} error (delay: ${delay}ms)');
      
      Future.delayed(Duration(milliseconds: delay), () {
        if (!_isTransitioning) {
          _moveToNextAyah();
        }
      });
    }
  }

  // Get user-friendly error message for any exception
  static String getUserFriendlyErrorMessage(dynamic error) {
    // First check if it's already a user-friendly message (contains Arabic)
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(error.toString())) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    
    // Categorize the error and get user-friendly message
    final errorType = _categorizeErrorStatic(error);
    return AudioErrorMessages.getUserFriendlyMessage(errorType);
  }
  
  // Static version of error categorization for public access
  static AudioErrorType _categorizeErrorStatic(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Network-specific error categorization
    if (errorString.contains('failed host lookup') || 
        errorString.contains('name resolution failed') ||
        errorString.contains('dns') || errorString.contains('resolve')) {
      return AudioErrorType.networkDns;
    } else if (errorString.contains('no internet connection') ||
               errorString.contains('network is unreachable') ||
               errorString.contains('connection refused') ||
               errorString.contains('offline')) {
      return AudioErrorType.networkOffline;
    } else if (errorString.contains('http') && (errorString.contains('404') || 
               errorString.contains('500') || errorString.contains('503') ||
               errorString.contains('server error') || errorString.contains('not found'))) {
      return AudioErrorType.networkServerError;
    } else if (errorString.contains('connection timeout') ||
               errorString.contains('read timeout') ||
               errorString.contains('socket timeout')) {
      return AudioErrorType.networkTimeout;
    } else if (errorString.contains('connection reset') ||
               errorString.contains('broken pipe') ||
               errorString.contains('connection aborted')) {
      return AudioErrorType.networkSlow;
    } else if (errorString.contains('timeout') || errorString.contains('timeoutexception')) {
      return AudioErrorType.timeout;
    } else if (errorString.contains('network') || errorString.contains('connection') || 
               errorString.contains('host')) {
      // Generic network error fallback
      return AudioErrorType.networkOffline;
    } else if (errorString.contains('codec') || errorString.contains('format') || 
               errorString.contains('unsupported')) {
      return AudioErrorType.codec;
    } else if (errorString.contains('permission') || errorString.contains('access')) {
      return AudioErrorType.permission;
    }
    return AudioErrorType.unknown;
  }

  // Track network errors for recovery mode
  void _trackNetworkError(AudioErrorType errorType) {
    final isNetworkError = [
      AudioErrorType.networkOffline,
      AudioErrorType.networkDns,
      AudioErrorType.networkTimeout,
      AudioErrorType.networkServerError,
      AudioErrorType.networkSlow,
    ].contains(errorType);
    
    if (isNetworkError) {
      _networkRecoveryMode = true;
      _lastNetworkError = DateTime.now();
      debugPrint('🔧 Network recovery mode activated');
    }
  }
  
  // Check if we should exit network recovery mode
  bool _shouldExitNetworkRecovery() {
    if (!_networkRecoveryMode || _lastNetworkError == null) return false;
    
    final timeSinceLastError = DateTime.now().difference(_lastNetworkError!);
    return timeSinceLastError.inSeconds > 30; // Exit after 30 seconds of no network errors
  }

  // Intelligent retry delay strategy based on error type  
  int _getRetryDelayForErrorType(AudioErrorType errorType) {
    // Apply longer delays if in network recovery mode
    final baseDelay = switch (errorType) {
      AudioErrorType.networkOffline => 3000,  // Wait longer for connection to return
      AudioErrorType.networkDns => 1000,     // Quick retry for DNS issues
      AudioErrorType.networkTimeout => 2000, // Moderate delay for timeouts
      AudioErrorType.networkServerError => 1500, // Quick retry for server issues
      AudioErrorType.networkSlow => 2500,    // Wait for connection to stabilize
      AudioErrorType.timeout => 200,         // Fast retry for general timeouts
      AudioErrorType.codec => 500,           // Quick retry for codec issues
      AudioErrorType.permission => 5000,     // Long delay for permission issues
      AudioErrorType.unknown => 1000,        // Standard delay for unknown errors
    };
    
    // Apply network recovery multiplier if needed
    return _networkRecoveryMode ? (baseDelay * 1.5).round() : baseDelay;
  }

  // -------- Playback control API (public) --------

  Future<void> startContinuousPlayback(AyahMarker startingAyah, String reciterName, List<AyahMarker> allAyahsInSurah) async {
    try {
      await initialize();
      
      // Reset timeout counters for new playback session
      _currentRetryAttempt = 0;
      _clearTimeouts();

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
        throw Exception(AudioErrorMessages.getNoAyahsError());
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

      urlsToTry.add(config.getAyahUrl(ayah.surah, ayah.ayah));
      final fallbackUrl = config.getFallbackAyahUrl(ayah.surah, ayah.ayah);
      if (fallbackUrl != null) {
        urlsToTry.add(fallbackUrl);
      }

      bool playbackStarted = false;

      // Stop any current playback quickly
      try {
        await _audioPlayer!.stop();
        // Remove artificial delay for faster transitions
      } catch (e) {
        debugPrint('⚠️ Error stopping previous playback: $e');
      }

      // Try cache first, then network
      String? urlToLoad;
      
      // Check cache first
      final reciterName = _currentReciter ?? _reciterConfigs.keys.first;
      final cachedPath = _cacheManager.getCachedFilePath(reciterName, ayah.surah, ayah.ayah);
      
      if (cachedPath != null) {
        urlToLoad = cachedPath;
        debugPrint('💾 Loading ${ayah.surah}:${ayah.ayah} from cache: $cachedPath');
      } else {
        // Try network URLs
        debugPrint('🌐 Loading ${ayah.surah}:${ayah.ayah} from network...');
      }

      // Try each URL until one works
      for (int i = 0; i < urlsToTry.length; i++) {
        final audioUrl = urlToLoad ?? urlsToTry[i];

        try {
          if (urlToLoad == null) {
            debugPrint('🎵 Loading ${ayah.surah}:${ayah.ayah} from: ${urlsToTry[i]} ${i > 0 ? "(fallback)" : ""}');
          }

          // Progressive timeout reduction during network issues
          final timeoutDuration = _networkRecoveryMode 
              ? const Duration(seconds: 5)  // Shorter timeout during network recovery
              : const Duration(seconds: 8); // Normal timeout
              
          await _audioPlayer!.setUrl(audioUrl).timeout(
            timeoutDuration,
            onTimeout: () {
              throw TimeoutException('URL loading timeout after ${timeoutDuration.inSeconds}s', timeoutDuration);
            },
          );

          await _audioPlayer!.setSpeed(_playbackSpeed);
          await _audioPlayer!.play();

          // Log audio started analytics
          final reciterName = _currentReciter ?? _reciterConfigs.keys.first;
          AnalyticsService.logAudioStarted(reciterName, 'سورة ${ayah.surah}');

          // Update media item BEFORE activating media session
          _updateMediaItem(ayah);

          // Notify audio service handler that playback started
          try {
            if (!kIsWeb) {
              debugPrint('🔄 Calling audio service handler play...');
              await _audioServiceHandler.play();
              debugPrint('✅ Audio service handler play completed');
            }
          } catch (e) {
            debugPrint('❌ Failed to notify audio service of play: $e');
          }

          debugPrint('✅ Successfully started ${ayah.surah}:${ayah.ayah}');
          playbackStarted = true;
          
          // Cache the ayah if loaded from network and start intelligent buffering
          if (urlToLoad == null) {
            final originalUrl = urlsToTry[i];
            _cacheManager.cacheAyahAudio(
              reciter: reciterName,
              surah: ayah.surah,
              ayah: ayah.ayah,
              url: originalUrl,
              preloadToMemory: true,
            );
          }
          
          // Start intelligent buffering around current ayah
          _cacheManager.bufferAroundCurrentAyah(
            reciter: reciterName,
            playlist: _playQueue,
            currentIndex: _currentIndex,
          );
          
          // Start preloading next ayah for seamless transition
          _preloadNextAyah();
          break;

        } catch (e) {
          debugPrint('⚠️ Failed to load $audioUrl: $e');
          
          // If cached file failed, try network
          if (urlToLoad != null) {
            urlToLoad = null;
            continue;
          }

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
        throw Exception(AudioErrorMessages.getPlaybackFailedError());
      }

    } catch (e) {
      debugPrint('❌ Complete failure playing ayah ${ayah.surah}:${ayah.ayah}: $e');
      _isTransitioning = false;
      _handleError(e);
    }
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

  // -------- Cache Management Methods --------
  
  /// Get cache statistics for UI display
  Map<String, dynamic> getCacheStats() {
    return _cacheManager.getCacheStats();
  }
  
  /// Clear all cached audio
  Future<void> clearAudioCache() async {
    await _cacheManager.clearCache();
    debugPrint('🧹 Audio cache cleared by user request');
  }
  
  /// Check if specific ayah is cached
  bool isAyahCached(String reciter, int surah, int ayah) {
    return _cacheManager.isAyahCached(reciter, surah, ayah);
  }
  
  // -------- Download Management Methods --------
  
  /// Download complete surah for offline playback
  Future<String> downloadSurah(int surahNumber, String reciter) async {
    return await _downloadManager.downloadSurah(surahNumber, reciter);
  }
  
  /// Download complete juz for offline playback
  Future<String> downloadJuz(int juzNumber, String reciter) async {
    return await _downloadManager.downloadJuz(juzNumber, reciter);
  }
  
  /// Get all download tasks
  List<DownloadTask> getDownloadTasks() {
    return _downloadManager.getAllDownloadTasks();
  }
  
  /// Get download progress stream
  Stream<DownloadTask> getDownloadProgress(String taskId) {
    return _downloadManager.getDownloadProgress(taskId);
  }
  
  /// Cancel download
  Future<void> cancelDownload(String taskId) async {
    await _downloadManager.cancelDownload(taskId);
  }
  
  /// Pause download
  Future<void> pauseDownload(String taskId) async {
    await _downloadManager.pauseDownload(taskId);
  }
  
  /// Resume download
  Future<void> resumeDownload(String taskId) async {
    await _downloadManager.resumeDownload(taskId);
  }
  
  /// Delete download and cached files
  Future<void> deleteDownload(String taskId) async {
    await _downloadManager.deleteDownload(taskId);
  }
  
  /// Check if surah/juz is downloaded
  bool isDownloaded(DownloadType type, int number, String reciter) {
    return _downloadManager.isDownloaded(type, number, reciter);
  }
  
  /// Get download statistics
  Map<String, dynamic> getDownloadStats() {
    return _downloadManager.getDownloadStats();
  }
  
  /// Enable/disable seamless mode
  void setSeamlessMode(bool enabled) {
    _seamlessModeEnabled = enabled;
    debugPrint('🎜️ Seamless mode ${enabled ? "enabled" : "disabled"}');
  }
  
  /// Get current seamless mode status
  bool get isSeamlessModeEnabled => _seamlessModeEnabled;
  
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
      
      // Try instant seamless transition first
      if (_seamlessModeEnabled && _preloadedIndex == _currentIndex) {
        final success = await _instantTransitionToPreloaded();
        if (success) {
          // Update current ayah info
          final nextAyah = _playQueue[_currentIndex];
          _currentAyah = nextAyah;
          currentAyahNotifier.value = nextAyah;
          _updateMediaItem(nextAyah);
          _checkAndFollowAyah();
          
          // Start preloading next ayah in background
          _preloadNextAyah();
          return;
        }
      }
      
      // Fall back to regular loading
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
      // Reset timeout counters for new playback
      _currentRetryAttempt = 0;
      _clearTimeouts();
      
      if (!_reciterConfigs.containsKey(reciterName)) {
        throw Exception(AudioErrorMessages.getReciterNotFoundError());
      }
      
      final reciterConfig = _reciterConfigs[reciterName]!;

      // Stop current playback
      await stop();

      // Update state
      currentAyahNotifier.value = ayah;
      isPlayingNotifier.value = false;
      currentReciterNotifier.value = reciterName;

      // Try to play the ayah  
      final audioUrl = reciterConfig.getAyahUrl(ayah.surah, ayah.ayah);
      
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

    // Log audio paused analytics
    if (_currentAyah != null) {
      AnalyticsService.logAudioPaused('سورة ${_currentAyah!.surah}');
    }

    // Notify audio service handler
    try {
      if (!kIsWeb) {
        _audioServiceHandler.pause();
      }
    } catch (e) {
      debugPrint('❌ Failed to notify audio service of pause: $e');
    }
  }

  /// Resume playbook
  void resume() {
    _audioPlayer?.play();
    // Notify audio service handler
    try {
      if (!kIsWeb) {
        _audioServiceHandler.play();
      }
    } catch (e) {
      debugPrint('❌ Failed to notify audio service of resume: $e');
    }
  }

  Future<void> stop() async {
    try {
      _completionTimer?.cancel();
      _completionTimer = null;
      _clearTimeouts(); // Clear all timeout timers
      await _audioPlayer?.stop();
      // Notify audio service handler
      try {
        if (!kIsWeb) {
          await _audioServiceHandler.stop();
        }
      } catch (e) {
        debugPrint('❌ Failed to notify audio service of stop: $e');
      }
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

  /// Update media item for background playback controls
  void _updateMediaItem(AyahMarker ayah) {
    try {
      final reciterName = _currentReciter ?? 'قارئ';
      final title = 'سورة ${_getSurahName(ayah.surah)} - آية ${ayah.ayah}';

      _audioServiceHandler.setMediaItem(
        title: title,
        artist: reciterName,
      );
    } catch (e) {
      debugPrint('❌ Failed to update media item: $e');
      // Continue without updating media item if it fails
    }
  }

  /// Get Arabic name for surah number
  String _getSurahName(int surahNumber) {
    const surahNames = [
      'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة', 'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
      'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر', 'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
      'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان', 'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
      'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر', 'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
      'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية', 'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
      'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن', 'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
      'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق', 'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
      'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة', 'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
      'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج', 'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
      'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين', 'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
      'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل', 'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
      'المسد', 'الإخلاص', 'الفلق', 'الناس'
    ];

    if (surahNumber >= 1 && surahNumber <= surahNames.length) {
      return surahNames[surahNumber - 1];
    }
    return '$surahNumber'; // Fallback to number if name not found
  }
}

