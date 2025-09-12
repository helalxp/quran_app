// lib/widgets/improved_media_player.dart

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/ayah_marker.dart';
import '../constants/surah_names.dart';
import '../utils/haptic_utils.dart';

class ImprovedMediaPlayer extends StatefulWidget {
  final AyahMarker? currentAyah;
  final ValueNotifier<bool> isPlayingNotifier;
  final ValueNotifier<bool> isBufferingNotifier;
  final ValueNotifier<String?> currentReciterNotifier;
  final ValueNotifier<double> playbackSpeedNotifier;
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<Duration> durationNotifier;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSpeedChange;
  final Function(Duration) onSeek;
  final VoidCallback? onReciterChange;

  const ImprovedMediaPlayer({
    super.key,
    required this.currentAyah,
    required this.isPlayingNotifier,
    required this.isBufferingNotifier,
    required this.currentReciterNotifier,
    required this.playbackSpeedNotifier,
    required this.positionNotifier,
    required this.durationNotifier,
    required this.onPlayPause,
    required this.onStop,
    required this.onPrevious,
    required this.onNext,
    required this.onSpeedChange,
    required this.onSeek,
    this.onReciterChange,
  });

  @override
  State<ImprovedMediaPlayer> createState() => _ImprovedMediaPlayerState();
}

class _ImprovedMediaPlayerState extends State<ImprovedMediaPlayer>
    with TickerProviderStateMixin {
  bool _isCollapsed = true; // Start collapsed by default
  bool _isVisible = false;
  late final AnimationController _expandController;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Controller for expand/collapse animation
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    // Controller for slide in/out animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5), // Slide up from bottom
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Show immediately if audio is playing
    if (widget.currentAyah != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _show();
      });
    }
  }

  void _show() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });
      // Ensure slide controller starts from beginning
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _hide() {
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
          _isCollapsed = true; // Reset to collapsed state when hidden
        });
        // Reset expand controller to prevent state issues
        _expandController.reset();
      }
    });
    // Immediately collapse if expanded
    if (!_isCollapsed) {
      _expandController.reverse();
    }
  }

  void _toggleCollapsed() {
    HapticUtils.selectionClick(); // Haptic feedback for expand/collapse
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (_isCollapsed) {
        _expandController.reverse();
      } else {
        _expandController.forward();
      }
    });
  }

  @override
  void dispose() {
    _expandController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ImprovedMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle visibility changes based on currentAyah
    if (widget.currentAyah != null && oldWidget.currentAyah == null) {
      // Audio started - ensure proper state reset
      if (mounted) {
        setState(() {
          _isCollapsed = true; // Start collapsed by default
        });
        _expandController.reset(); // Reset animation state
        _show();
        debugPrint('🎵 Media player shown for new audio');
      }
    } else if (widget.currentAyah == null && oldWidget.currentAyah != null) {
      // Audio stopped
      _hide();
      debugPrint('⏹️ Media player hidden after audio stop');
    }
  }

  String _getSurahName(int surahNumber) {
    // Use centralized surah names from constants
    return SurahNames.getArabicName(surahNumber);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Safety check: hide if no audio or not visible
    if (widget.currentAyah == null || !_isVisible) {
      return const SizedBox.shrink();
    }

    // Additional safety check for controller readiness
    if (!_slideController.isCompleted && !_slideController.isAnimating && _isVisible) {
      // Controller might be in wrong state, reset it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isVisible) {
          _slideController.forward();
        }
      });
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Stack(
        children: [
          // Full player with animation
          if (!_isCollapsed)
            AnimatedBuilder(
              animation: _expandController,
              builder: (context, child) => _buildAnimatedFullPlayer(),
            ),
          
          // Collapsed button with animation
          if (_isCollapsed)
            AnimatedBuilder(
              animation: _expandController,
              builder: (context, child) => _buildAnimatedCollapsedButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFullPlayer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 80,
      child: FadeTransition(
        opacity: _expandController,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: _expandController,
            curve: Curves.easeOutBack,
          )),
          child: _buildFullPlayerContent(),
        ),
      ),
    );
  }

  Widget _buildAnimatedCollapsedButton() {
    return Positioned(
      left: 16,
      bottom: 37.0,
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).animate(_expandController),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 1.0,
            end: 0.8,
          ).animate(CurvedAnimation(
            parent: _expandController,
            curve: Curves.easeInCubic,
          )),
          child: _buildCollapsedButtonContent(),
        ),
      ),
    );
  }

  Widget _buildCollapsedButtonContent() {
    return Material(
      elevation: 2.0,
      borderRadius: BorderRadius.circular(8),
      color: Colors.transparent,
      child: Container(
          width: 70, // Same size as jump-to-page button
          height: 40, // Same size as jump-to-page button
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: _toggleCollapsed,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.isBufferingNotifier,
                builder: (context, isBuffering, _) {
                  if (isBuffering) {
                    return SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }

                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.isPlayingNotifier,
                    builder: (context, isPlaying, _) => Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildFullPlayerContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildProgressBar(),
              const SizedBox(height: 12),
              _buildControls(),
            ],
          ),
        ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            // Surah info - positioned on the right side for Arabic layout
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Start from right in RTL
                children: [
                  Text(
                    _getSurahName(widget.currentAyah!.surah),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<String?>(
                    valueListenable: widget.currentReciterNotifier,
                    builder: (context, reciter, _) => Text(
                      'الآية ${widget.currentAyah!.ayah} • ${reciter ?? 'قارئ'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Collapse button - positioned on the left side in RTL layout
            InkWell(
              onTap: _toggleCollapsed,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ValueListenableBuilder<Duration>(
        valueListenable: widget.positionNotifier,
        builder: (context, position, _) => ValueListenableBuilder<Duration>(
          valueListenable: widget.durationNotifier,
          builder: (context, duration, _) => Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  thumbColor: Theme.of(context).colorScheme.primary,
                  overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: duration.inMilliseconds > 0 
                      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0.0,
                  onChanged: (value) {
                    final newPosition = Duration(
                      milliseconds: (duration.inMilliseconds * value).round(),
                    );
                    widget.onSeek(newPosition);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Previous button (right side in RTL = visually first)
            _buildControlButton(
              icon: Icons.skip_next_rounded,
              onPressed: () {
                HapticUtils.mediaControl();
                widget.onPrevious();
              },
              size: 24,
            ),

            // Play/Pause button
            _buildPlayButton(),

            // Next button (left side in RTL = visually last)
            _buildControlButton(
              icon: Icons.skip_previous_rounded,
              onPressed: () {
                HapticUtils.mediaControl();
                widget.onNext();
              },
              size: 24,
            ),

            // Speed control
            _buildSpeedControl(),

            // Stop button
            _buildControlButton(
              icon: Icons.stop_rounded,
              onPressed: () {
                HapticUtils.mediaControl();
                widget.onStop();
                // Don't call _hide() here - let didUpdateWidget handle it
              },
              size: 24,
              backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              iconColor: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isBufferingNotifier,
      builder: (context, isBuffering, _) {
        if (isBuffering) {
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: widget.isPlayingNotifier,
          builder: (context, isPlaying, _) => Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticUtils.mediaControl();
                  widget.onPlayPause();
                },
                borderRadius: BorderRadius.circular(28),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 32,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 24,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            icon,
            size: size,
            color: iconColor ?? Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedControl() {
    return ValueListenableBuilder<double>(
      valueListenable: widget.playbackSpeedNotifier,
      builder: (context, speed, _) => GestureDetector(
        onTap: () {
          HapticUtils.mediaControl();
          widget.onSpeedChange();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${speed}x',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}