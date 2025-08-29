// lib/widgets/floating_media_player.dart - Updated to match viewer_screen interface
// Compatible with ContinuousAudioManager from viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ayah_marker.dart';

class FloatingMediaPlayer extends StatefulWidget {
  final AyahMarker currentAyah;
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

  const FloatingMediaPlayer({
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
  });

  @override
  State<FloatingMediaPlayer> createState() => _FloatingMediaPlayerState();
}

class _FloatingMediaPlayerState extends State<FloatingMediaPlayer>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  String _getSurahName(int surahNumber) {
    const surahNames = {
      1: 'الفاتحة', 2: 'البقرة', 3: 'آل عمران', 4: 'النساء', 5: 'المائدة',
      6: 'الأنعام', 7: 'الأعراف', 8: 'الأنفال', 9: 'التوبة', 10: 'يونس',
      11: 'هود', 12: 'يوسف', 13: 'الرعد', 14: 'إبراهيم', 15: 'الحجر',
      16: 'النحل', 17: 'الإسراء', 18: 'الكهف', 19: 'مريم', 20: 'طه',
      21: 'الأنبياء', 22: 'الحج', 23: 'المؤمنون', 24: 'النور', 25: 'الفرقان',
      26: 'الشعراء', 27: 'النمل', 28: 'القصص', 29: 'العنكبوت', 30: 'الروم',
      31: 'لقمان', 32: 'السجدة', 33: 'الأحزاب', 34: 'سبأ', 35: 'فاطر',
      36: 'يس', 37: 'الصافات', 38: 'ص', 39: 'الزمر', 40: 'غافر',
      41: 'فصلت', 42: 'الشورى', 43: 'الزخرف', 44: 'الدخان', 45: 'الجاثية',
      46: 'الأحقاف', 47: 'محمد', 48: 'الفتح', 49: 'الحجرات', 50: 'ق',
      51: 'الذاريات', 52: 'الطور', 53: 'النجم', 54: 'القمر', 55: 'الرحمن',
      56: 'الواقعة', 57: 'الحديد', 58: 'المجادلة', 59: 'الحشر', 60: 'الممتحنة',
      61: 'الصف', 62: 'الجمعة', 63: 'المنافقون', 64: 'التغابن', 65: 'الطلاق',
      66: 'التحريم', 67: 'الملك', 68: 'القلم', 69: 'الحاقة', 70: 'المعارج',
      71: 'نوح', 72: 'الجن', 73: 'المزمل', 74: 'المدثر', 75: 'القيامة',
      76: 'الإنسان', 77: 'المرسلات', 78: 'النبأ', 79: 'النازعات', 80: 'عبس',
      81: 'التكوير', 82: 'الانفطار', 83: 'المطففين', 84: 'الانشقاق', 85: 'البروج',
      86: 'الطارق', 87: 'الأعلى', 88: 'الغاشية', 89: 'الفجر', 90: 'البلد',
      91: 'الشمس', 92: 'الليل', 93: 'الضحى', 94: 'الشرح', 95: 'التين',
      96: 'العلق', 97: 'القدر', 98: 'البينة', 99: 'الزلزلة', 100: 'العاديات',
      101: 'القارعة', 102: 'التكاثر', 103: 'العصر', 104: 'الهمزة', 105: 'الفيل',
      106: 'قريش', 107: 'الماعون', 108: 'الكوثر', 109: 'الكافرون', 110: 'النصر',
      111: 'المسد', 112: 'الإخلاص', 113: 'الفلق', 114: 'الناس'
    };
    return surahNames[surahNumber] ?? 'سورة $surahNumber';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact header with basic controls
            GestureDetector(
              onTap: _toggleExpanded,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Play/Pause button
                    ValueListenableBuilder<bool>(
                      valueListenable: widget.isBufferingNotifier,
                      builder: (context, isBuffering, _) {
                        if (isBuffering) {
                          return Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          );
                        }
                        return ValueListenableBuilder<bool>(
                          valueListenable: widget.isPlayingNotifier,
                          builder: (context, isPlaying, _) {
                            return IconButton(
                              onPressed: widget.onPlayPause,
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 28,
                              ),
                              tooltip: isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(width: 12),

                    // Ayah info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getSurahName(widget.currentAyah.surah)} - آية ${widget.currentAyah.ayah}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          ValueListenableBuilder<String?>(
                            valueListenable: widget.currentReciterNotifier,
                            builder: (context, reciter, _) {
                              return Text(
                                reciter ?? 'قارئ غير محدد',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Expand/collapse icon
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),

            // Expandable section
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Progress bar
                    ValueListenableBuilder<Duration>(
                      valueListenable: widget.positionNotifier,
                      builder: (context, position, _) {
                        return ValueListenableBuilder<Duration>(
                          valueListenable: widget.durationNotifier,
                          builder: (context, duration, _) {
                            final progress = duration.inMilliseconds > 0
                                ? position.inMilliseconds / duration.inMilliseconds
                                : 0.0;

                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                  ),
                                  child: Slider(
                                    value: progress.clamp(0.0, 1.0),
                                    onChanged: _isDragging
                                        ? (value) {
                                      final newPosition = Duration(
                                        milliseconds: (value * duration.inMilliseconds).round(),
                                      );
                                      widget.onSeek(newPosition);
                                    }
                                        : null,
                                    onChangeStart: (_) {
                                      _isDragging = true;
                                    },
                                    onChangeEnd: (_) {
                                      _isDragging = false;
                                    },
                                    activeColor: Theme.of(context).colorScheme.primary,
                                    inactiveColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Full control row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Stop button
                        IconButton(
                          onPressed: widget.onStop,
                          icon: const Icon(Icons.stop),
                          tooltip: 'إيقاف',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),

                        // Previous button
                        IconButton(
                          onPressed: widget.onPrevious,
                          icon: const Icon(Icons.skip_previous),
                          tooltip: 'الآية السابقة',
                        ),

                        // Play/Pause (larger)
                        ValueListenableBuilder<bool>(
                          valueListenable: widget.isBufferingNotifier,
                          builder: (context, isBuffering, _) {
                            if (isBuffering) {
                              return Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            return ValueListenableBuilder<bool>(
                              valueListenable: widget.isPlayingNotifier,
                              builder: (context, isPlaying, _) {
                                return IconButton(
                                  onPressed: widget.onPlayPause,
                                  icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    size: 32,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                    minimumSize: const Size(56, 56),
                                  ),
                                  tooltip: isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                                );
                              },
                            );
                          },
                        ),

                        // Next button
                        IconButton(
                          onPressed: widget.onNext,
                          icon: const Icon(Icons.skip_next),
                          tooltip: 'الآية التالية',
                        ),

                        // Speed button with indicator
                        ValueListenableBuilder<double>(
                          valueListenable: widget.playbackSpeedNotifier,
                          builder: (context, speed, _) {
                            return IconButton(
                              onPressed: widget.onSpeedChange,
                              icon: Stack(
                                children: [
                                  const Icon(Icons.speed),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${speed}x',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              tooltip: 'تغيير السرعة (${speed}x)',
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}