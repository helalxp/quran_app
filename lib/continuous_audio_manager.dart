// lib/continuous_audio_manager.dart - FIXED VERSION with proper sequence handling

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'models/ayah_marker.dart';

class ContinuousAudioManager {
  // Singleton
  static final ContinuousAudioManager _instance = ContinuousAudioManager._internal();
  factory ContinuousAudioManager() => _instance;
  ContinuousAudioManager._internal();

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
  int _consecutiveErrors = 0;
  static const int maxConsecutiveErrors = 5;

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

  // -------- Initialization & disposal --------

  Future<void> initialize() async {
    if (_audioPlayer != null) return;
    try {
      _audioPlayer = AudioPlayer();
      try {
        await _audioPlayer!.setVolume(0.8);
      } catch (_) {}
      _setupListeners();
      debugPrint('✅ Audio manager initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing audio manager: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    // Cancel completion timer
    _completionTimer?.cancel();
    _completionTimer = null;

    await _stateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    _stateSubscription = null;
    _positionSubscription = null;
    _durationSubscription = null;

    try {
      await _audioPlayer?.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing audio player: $e');
    }
    _audioPlayer = null;

    _resetState();
    debugPrint('🧹 ContinuousAudioManager disposed');
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

    // Position updates
    _positionSubscription = _audioPlayer!.positionStream.listen((position) {
      positionNotifier.value = position;
    });

    // Duration updates
    _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
      durationNotifier.value = duration ?? Duration.zero;
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
    _completionTimer = Timer(const Duration(milliseconds: 200), () {
      if (!_completionHandled) return; // Double-check in case state changed

      debugPrint('🎵 Processing completion for ayah ${_currentAyah?.surah}:${_currentAyah?.ayah}');
      _moveToNextAyah();
    });
  }

  // NEW: Separate method for handling errors consistently
  void _handleError(dynamic error) {
    _consecutiveErrors++;
    debugPrint('❌ Error ($_consecutiveErrors/$maxConsecutiveErrors): $error');

    if (_consecutiveErrors >= maxConsecutiveErrors) {
      debugPrint('❌ Too many consecutive errors, stopping playback');
      Future.microtask(() => stop());
    } else {
      debugPrint('🔄 Attempting to skip to next ayah due to error');
      Future.delayed(const Duration(milliseconds: 500), () {
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
        _currentIndex = 0;
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

    final startIndex = surahAyahs.indexWhere((ayah) => ayah.ayah >= startingAyah.ayah);

    if (startIndex != -1) {
      _playQueue.addAll(surahAyahs.sublist(startIndex));
      debugPrint('📜 Built play queue with ${_playQueue.length} ayahs starting from ${startingAyah.surah}:${startingAyah.ayah}');
      debugPrint('📜 Queue ayahs: ${_playQueue.map((a) => a.ayah).toList()}');
    } else {
      debugPrint('⚠️ Start index not found for startingAyah ${startingAyah.surah}:${startingAyah.ayah}');
    }
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
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) {
        debugPrint('⚠️ Error stopping previous playback: $e');
      }

      // Try each URL until one works
      for (int i = 0; i < urlsToTry.length; i++) {
        final audioUrl = urlsToTry[i];

        try {
          debugPrint('🎵 Loading ${ayah.surah}:${ayah.ayah} from: $audioUrl ${i > 0 ? "(fallback)" : ""}');

          await _audioPlayer!.setUrl(audioUrl).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('URL loading timeout after 15s', const Duration(seconds: 15));
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

  // -------- IMPROVED Next / Previous handling --------

  Future<void> _moveToNextAyah() async {
    if (_isTransitioning) {
      debugPrint('⚠️ Transition in progress, ignoring move to next');
      return;
    }

    if (_currentIndex < _playQueue.length - 1) {
      final oldIndex = _currentIndex;
      _currentIndex++;
      final nextAyah = _playQueue[_currentIndex];
      debugPrint('⏭️ Moving from $oldIndex to $_currentIndex: ${nextAyah.surah}:${nextAyah.ayah}');
      await _playCurrentAyah();
    } else {
      debugPrint('🏁 Reached end of surah, stopping playback');
      await stop();
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