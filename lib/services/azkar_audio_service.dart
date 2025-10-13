import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/dhikr_model.dart';
import '../continuous_audio_manager.dart';

/// Repeat modes for audio playback
enum RepeatMode {
  none,    // Don't repeat
  single,  // Repeat current dhikr
  all,     // Repeat entire category
}

/// Service for streaming and playing Azkar audio with caching
class AzkarAudioService {
  static final AzkarAudioService _instance = AzkarAudioService._internal();
  factory AzkarAudioService() => _instance;
  AzkarAudioService._internal();

  // GitHub raw content base URL for audio files
  // TODO: Replace with actual repository URL when available
  static const String audioBaseUrl = 'https://raw.githubusercontent.com/rn0x/Adhkar-json/main/audio/';

  // Audio player instance
  AudioPlayer? _audioPlayer;

  // Current playback state
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<String?> currentAudioNotifier = ValueNotifier(null);
  final ValueNotifier<Dhikr?> currentDhikrNotifier = ValueNotifier(null);
  final ValueNotifier<DhikrCategory?> currentCategoryNotifier = ValueNotifier(null);

  // Playback settings
  final ValueNotifier<double> playbackSpeedNotifier = ValueNotifier(1.0);
  final ValueNotifier<RepeatMode> repeatModeNotifier = ValueNotifier(RepeatMode.none);
  final ValueNotifier<bool> autoPlayNextNotifier = ValueNotifier(false);

  bool _initialized = false;

  // Callback for when audio completes
  Function()? onAudioComplete;

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _audioPlayer = AudioPlayer();
      _setupListeners();
      _initialized = true;
      debugPrint('✅ AzkarAudioService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing AzkarAudioService: $e');
      rethrow;
    }
  }

  /// Setup audio player listeners
  void _setupListeners() {
    if (_audioPlayer == null) return;

    // Playing state
    _audioPlayer!.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      isLoadingNotifier.value = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      // Handle audio completion
      if (state.processingState == ProcessingState.completed) {
        _handleAudioComplete();
      }
    });

    // Position updates
    _audioPlayer!.positionStream.listen((position) {
      positionNotifier.value = position;
    });

    // Duration updates
    _audioPlayer!.durationStream.listen((duration) {
      durationNotifier.value = duration ?? Duration.zero;
    });
  }

  /// Handle audio completion based on repeat mode
  void _handleAudioComplete() {
    final repeatMode = repeatModeNotifier.value;

    switch (repeatMode) {
      case RepeatMode.single:
        // Replay current audio
        _audioPlayer?.seek(Duration.zero);
        _audioPlayer?.play();
        break;
      case RepeatMode.all:
      case RepeatMode.none:
        // Notify completion (let the UI handle next track)
        onAudioComplete?.call();
        break;
    }
  }

  /// Convert JSON audio path to full URL
  String getAudioUrl(String audioPath) {
    // Remove leading slash if present
    String cleanPath = audioPath.startsWith('/') ? audioPath.substring(1) : audioPath;

    // Remove 'audio/' prefix if present since base URL already includes it
    if (cleanPath.startsWith('audio/')) {
      cleanPath = cleanPath.substring(6); // Remove 'audio/'
    }

    return '$audioBaseUrl$cleanPath';
  }

  /// Play dhikr audio
  Future<void> playDhikr(Dhikr dhikr, {DhikrCategory? category}) async {
    if (!_initialized) await initialize();

    try {
      // Stop Quran audio if it's playing to prevent audio conflicts
      try {
        final quranAudio = ContinuousAudioManager();
        if (quranAudio.isPlayingNotifier.value) {
          debugPrint('🔇 Stopping Quran audio to play Azkar');
          await quranAudio.stop();
        }
      } catch (e) {
        debugPrint('⚠️ Error stopping Quran audio: $e');
      }

      debugPrint('🎵 Playing dhikr audio: ${dhikr.audio}');

      final audioUrl = getAudioUrl(dhikr.audio);
      currentAudioNotifier.value = audioUrl;
      currentDhikrNotifier.value = dhikr;
      currentCategoryNotifier.value = category;

      // Stop current playback
      await _audioPlayer!.stop();

      // Load and play new audio
      await _audioPlayer!.setUrl(audioUrl);
      await _audioPlayer!.setSpeed(playbackSpeedNotifier.value);
      await _audioPlayer!.play();

      debugPrint('✅ Dhikr audio started');
    } catch (e) {
      debugPrint('❌ Error playing dhikr audio: $e');
      isLoadingNotifier.value = false;
      currentDhikrNotifier.value = null;
      rethrow;
    }
  }

  /// Play category audio
  Future<void> playCategory(DhikrCategory category) async {
    if (!_initialized) await initialize();

    try {
      // Stop Quran audio if it's playing to prevent audio conflicts
      try {
        final quranAudio = ContinuousAudioManager();
        if (quranAudio.isPlayingNotifier.value) {
          debugPrint('🔇 Stopping Quran audio to play Azkar');
          await quranAudio.stop();
        }
      } catch (e) {
        debugPrint('⚠️ Error stopping Quran audio: $e');
      }

      debugPrint('🎵 Playing category audio: ${category.audio}');

      final audioUrl = getAudioUrl(category.audio);
      currentAudioNotifier.value = audioUrl;

      // Stop current playback
      await _audioPlayer!.stop();

      // Load and play new audio
      await _audioPlayer!.setUrl(audioUrl);
      await _audioPlayer!.play();

      debugPrint('✅ Category audio started');
    } catch (e) {
      debugPrint('❌ Error playing category audio: $e');
      isLoadingNotifier.value = false;
      rethrow;
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_audioPlayer == null || !_initialized) return;

    try {
      if (_audioPlayer!.playing) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.play();
      }
    } catch (e) {
      debugPrint('❌ Error toggling play/pause: $e');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    if (_audioPlayer == null || !_initialized) return;

    try {
      await _audioPlayer!.pause();
    } catch (e) {
      debugPrint('❌ Error pausing: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    if (_audioPlayer == null || !_initialized) return;

    try {
      await _audioPlayer!.play();
    } catch (e) {
      debugPrint('❌ Error resuming: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    if (_audioPlayer == null || !_initialized) return;

    try {
      await _audioPlayer!.stop();
      currentAudioNotifier.value = null;
      currentDhikrNotifier.value = null; // Clear dhikr so mini player disappears
      currentCategoryNotifier.value = null;
      positionNotifier.value = Duration.zero;
      durationNotifier.value = Duration.zero;
    } catch (e) {
      debugPrint('❌ Error stopping: $e');
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (_audioPlayer == null || !_initialized) return;

    try {
      await _audioPlayer!.seek(position);
    } catch (e) {
      debugPrint('❌ Error seeking: $e');
    }
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    if (_audioPlayer == null || !_initialized) return;

    try {
      playbackSpeedNotifier.value = speed;
      await _audioPlayer!.setSpeed(speed);
      debugPrint('✅ Playback speed set to ${speed}x');
    } catch (e) {
      debugPrint('❌ Error setting playback speed: $e');
    }
  }

  /// Cycle through playback speeds (0.75x -> 1x -> 1.25x -> 1.5x)
  Future<void> cyclePlaybackSpeed() async {
    double currentSpeed = playbackSpeedNotifier.value;
    double newSpeed;

    if (currentSpeed < 0.8) {
      newSpeed = 1.0;
    } else if (currentSpeed < 1.1) {
      newSpeed = 1.25;
    } else if (currentSpeed < 1.3) {
      newSpeed = 1.5;
    } else {
      newSpeed = 0.75;
    }

    await setPlaybackSpeed(newSpeed);
  }

  /// Set repeat mode
  void setRepeatMode(RepeatMode mode) {
    repeatModeNotifier.value = mode;
    debugPrint('✅ Repeat mode set to $mode');
  }

  /// Cycle through repeat modes
  void cycleRepeatMode() {
    final currentMode = repeatModeNotifier.value;
    RepeatMode newMode;

    switch (currentMode) {
      case RepeatMode.none:
        newMode = RepeatMode.single;
        break;
      case RepeatMode.single:
        newMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        newMode = RepeatMode.none;
        break;
    }

    setRepeatMode(newMode);
  }

  /// Toggle auto-play next
  void toggleAutoPlayNext() {
    autoPlayNextNotifier.value = !autoPlayNextNotifier.value;
    debugPrint('✅ Auto-play next: ${autoPlayNextNotifier.value}');
  }

  /// Get current playing state
  bool get isPlaying => isPlayingNotifier.value;

  /// Get current loading state
  bool get isLoading => isLoadingNotifier.value;

  /// Get current dhikr
  Dhikr? get currentDhikr => currentDhikrNotifier.value;

  /// Get current category
  DhikrCategory? get currentCategory => currentCategoryNotifier.value;

  /// Dispose resources
  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _initialized = false;

    // Clean up notifiers
    isPlayingNotifier.dispose();
    isLoadingNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    currentAudioNotifier.dispose();
    currentDhikrNotifier.dispose();
    currentCategoryNotifier.dispose();
    playbackSpeedNotifier.dispose();
    repeatModeNotifier.dispose();
    autoPlayNextNotifier.dispose();

    debugPrint('✅ AzkarAudioService disposed');
  }
}
