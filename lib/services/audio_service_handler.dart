// lib/services/audio_service_handler.dart

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class AudioServiceHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  static final _instance = AudioServiceHandler._internal();
  factory AudioServiceHandler() => _instance;
  AudioServiceHandler._internal();

  late AudioPlayer _player;
  bool _isInitialized = false;

  void initialize(AudioPlayer player) {
    debugPrint('🔄 AudioServiceHandler.initialize() called');
    if (_isInitialized) {
      debugPrint('⚠️ AudioServiceHandler already initialized, skipping');
      return;
    }
    _player = player;
    _isInitialized = true;
    debugPrint('✅ AudioServiceHandler initialized with player');

    // Set default media item immediately to activate media session
    mediaItem.add(MediaItem(
      id: 'quran_audio',
      album: '\u202B' 'القرآن الكريم' '\u202C',
      title: '\u202B' 'القرآن الكريم' '\u202C',
      artist: '\u202B' 'قارئ' '\u202C',
      duration: null,
      extras: {
        'language': 'ar',
        'direction': 'rtl',
      },
    ));

    // Listen to player state changes
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = switch (playerState.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };

      playbackState.add(PlaybackState(
        controls: [
          MediaControl.rewind,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.playFromMediaId,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2], // Show rewind, play/pause, fast forward in compact view
        processingState: processingState,
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: 0,
      ));
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // Initialize with default state that shows media controls
    playbackState.add(PlaybackState(
      controls: [MediaControl.play],
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  String? _currentTitle;
  String? _currentArtist;

  void setMediaItem({
    required String title,
    required String artist,
    String? artUri,
  }) {
    // Only update if the content has actually changed to prevent flickering
    if (_currentTitle == title && _currentArtist == artist) {
      return;
    }

    _currentTitle = title;
    _currentArtist = artist;

    // Add RTL mark to force right-to-left text display
    final String rtlTitle = '\u202B$title\u202C'; // RLE + text + PDF
    final String rtlArtist = '\u202B$artist\u202C'; // RLE + text + PDF
    final String rtlAlbum = '\u202B' 'القرآن الكريم' '\u202C';

    debugPrint('🎵 Updating media item: $rtlTitle by $rtlArtist');
    mediaItem.add(MediaItem(
      id: 'quran_audio_${DateTime.now().millisecondsSinceEpoch}', // Unique ID to prevent caching issues
      album: rtlAlbum,
      title: rtlTitle,
      artist: rtlArtist,
      duration: _player.duration,
      artUri: artUri != null ? Uri.parse(artUri) : null,
      extras: {
        'isQuran': true,
        'language': 'ar',
        'direction': 'rtl',
      },
    ));
  }

  @override
  Future<void> play() async {
    debugPrint('🔄 AudioServiceHandler.play() called, initialized: $_isInitialized');
    if (_isInitialized) {
      await _player.play();
      // Ensure media session is active when playing starts
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ));
      debugPrint('🎵 Audio service play called - media controls should be visible');
    } else {
      debugPrint('❌ AudioServiceHandler not initialized, cannot play');
    }
  }

  @override
  Future<void> pause() async {
    if (_isInitialized) {
      await _player.pause();
      // Update playback state for media controls
      playbackState.add(playbackState.value.copyWith(
        playing: false,
      ));
      debugPrint('⏸️ Audio service pause called - media controls updated');
    }
  }

  @override
  Future<void> stop() async {
    if (_isInitialized) {
      await _player.stop();
      // Update playback state for media controls
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ));
      debugPrint('⏹️ Audio service stop called - media controls updated');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isInitialized) {
      await _player.seek(position);
    }
  }

  @override
  Future<void> fastForward() async {
    if (_isInitialized) {
      final newPosition = _player.position + const Duration(seconds: 10);
      await _player.seek(newPosition);
    }
  }

  @override
  Future<void> rewind() async {
    if (_isInitialized) {
      final newPosition = _player.position - const Duration(seconds: 10);
      await _player.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
    }
  }
}