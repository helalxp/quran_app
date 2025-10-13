import 'package:flutter/material.dart';
import '../services/azkar_audio_service.dart';
import '../utils/haptic_utils.dart';

/// Mini audio player that appears at the bottom when audio is playing
class AzkarMiniPlayer extends StatelessWidget {
  final AzkarAudioService audioService;

  const AzkarMiniPlayer({
    super.key,
    required this.audioService,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  IconData _getRepeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none:
        return Icons.repeat;
      case RepeatMode.single:
        return Icons.repeat_one;
      case RepeatMode.all:
        return Icons.repeat_on;
    }
  }

  Color _getRepeatColor(RepeatMode mode, BuildContext context) {
    switch (mode) {
      case RepeatMode.none:
        return Colors.white38;
      case RepeatMode.single:
      case RepeatMode.all:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: audioService.isPlayingNotifier,
      builder: (context, isPlaying, child) {
        return ValueListenableBuilder(
          valueListenable: audioService.currentDhikrNotifier,
          builder: (context, currentDhikr, child) {
            // Only show mini player if there's audio loaded
            if (currentDhikr == null && !isPlaying) {
              return const SizedBox.shrink();
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    ValueListenableBuilder<Duration>(
                      valueListenable: audioService.positionNotifier,
                      builder: (context, position, child) {
                        return ValueListenableBuilder<Duration>(
                          valueListenable: audioService.durationNotifier,
                          builder: (context, duration, child) {
                            final progress = duration.inMilliseconds > 0
                                ? position.inMilliseconds / duration.inMilliseconds
                                : 0.0;

                            return SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white24,
                              ),
                              child: Slider(
                                value: progress.clamp(0.0, 1.0),
                                onChanged: (value) {
                                  final newPosition = Duration(
                                    milliseconds: (value * duration.inMilliseconds).round(),
                                  );
                                  audioService.seek(newPosition);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Controls
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          // Dhikr info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (currentDhikr != null)
                                  Text(
                                    currentDhikr.text.length > 40
                                        ? '${currentDhikr.text.substring(0, 40)}...'
                                        : currentDhikr.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'Uthmanic',
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.rtl,
                                  ),
                                const SizedBox(height: 4),
                                ValueListenableBuilder<Duration>(
                                  valueListenable: audioService.positionNotifier,
                                  builder: (context, position, child) {
                                    return ValueListenableBuilder<Duration>(
                                      valueListenable: audioService.durationNotifier,
                                      builder: (context, duration, child) {
                                        return Text(
                                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Playback speed button
                          ValueListenableBuilder<double>(
                            valueListenable: audioService.playbackSpeedNotifier,
                            builder: (context, speed, child) {
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    HapticUtils.lightImpact();
                                    audioService.cyclePlaybackSpeed();
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${speed.toStringAsFixed(2)}x',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(width: 8),

                          // Repeat mode button
                          ValueListenableBuilder<RepeatMode>(
                            valueListenable: audioService.repeatModeNotifier,
                            builder: (context, repeatMode, child) {
                              return IconButton(
                                icon: Icon(
                                  _getRepeatIcon(repeatMode),
                                  color: _getRepeatColor(repeatMode, context),
                                ),
                                onPressed: () {
                                  HapticUtils.lightImpact();
                                  audioService.cycleRepeatMode();
                                },
                              );
                            },
                          ),

                          // Play/Pause button
                          ValueListenableBuilder<bool>(
                            valueListenable: audioService.isLoadingNotifier,
                            builder: (context, isLoading, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: isLoading
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          isPlaying ? Icons.pause : Icons.play_arrow,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          HapticUtils.lightImpact();
                                          audioService.togglePlayPause();
                                        },
                                ),
                              );
                            },
                          ),

                          const SizedBox(width: 8),

                          // Close button
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () {
                              HapticUtils.lightImpact();
                              audioService.stop();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
