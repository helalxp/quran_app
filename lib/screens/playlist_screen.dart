import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/haptic_utils.dart';
import '../constants/api_constants.dart';
import '../models/surah.dart';
import '../models/ayah_marker.dart';
import '../continuous_audio_manager.dart';
import '../audio_download_manager.dart' show AudioDownloadManager, DownloadType;

import '../services/analytics_service.dart';
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ContinuousAudioManager _audioManager = ContinuousAudioManager();
  final GlobalKey<_PlaylistsTabState> _playlistsTabKey = GlobalKey<_PlaylistsTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _audioManager.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            HapticUtils.navigation();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_outlined),
        ),
        title: const Text(
          "السمعيات",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Uthmanic',
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.person),
              text: "القراء",
            ),
            Tab(
              icon: Icon(Icons.playlist_play),
              text: "قوائم التشغيل",
            ),
          ],
          onTap: (_) => HapticUtils.selectionClick(),
        ),
      ),
      body: Column(
        children: [
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _RecitersTab(),
                _PlaylistsTab(key: _playlistsTabKey),
              ],
            ),
          ),

          // Media Player at bottom
          ValueListenableBuilder(
            valueListenable: _audioManager.isPlayingNotifier,
            builder: (context, isPlaying, child) {
              return ValueListenableBuilder(
                valueListenable: _audioManager.currentAyahNotifier,
                builder: (context, currentAyah, child) {
                  if (currentAyah == null) {
                    return const SizedBox.shrink();
                  }

                  return _MiniMediaPlayer(
                    audioManager: _audioManager,
                    onPrevious: () {
                      _playlistsTabKey.currentState?._playPreviousPlaylist();
                    },
                    onNext: () {
                      _playlistsTabKey.currentState?._playNextPlaylist();
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// Mini Media Player Widget
class _MiniMediaPlayer extends StatelessWidget {
  final ContinuousAudioManager audioManager;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _MiniMediaPlayer({
    required this.audioManager,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surface,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
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
            ValueListenableBuilder(
              valueListenable: audioManager.positionNotifier,
              builder: (context, position, child) {
                return ValueListenableBuilder(
                  valueListenable: audioManager.durationNotifier,
                  builder: (context, duration, child) {
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;

                    return LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                );
              },
            ),

            // Player content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  // Surah info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: audioManager.currentAyahNotifier,
                          builder: (context, currentAyah, child) {
                            if (currentAyah == null) return const SizedBox.shrink();

                            return FutureBuilder<String>(
                              future: _getSurahName(currentAyah.surah),
                              builder: (context, snapshot) {
                                final surahName = snapshot.data ?? 'سورة ${currentAyah.surah}';
                                return Text(
                                  surahName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Uthmanic',
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder(
                          valueListenable: audioManager.currentReciterNotifier,
                          builder: (context, reciter, child) {
                            return Text(
                              reciter ?? 'جاري التحميل...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Control buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Previous playlist button
                      if (onPrevious != null)
                        IconButton(
                          onPressed: () {
                            HapticUtils.selectionClick();
                            onPrevious?.call();
                          },
                          icon: const Icon(Icons.skip_previous),
                          iconSize: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),

                      // Play/Pause button
                      ValueListenableBuilder(
                        valueListenable: audioManager.isPlayingNotifier,
                        builder: (context, isPlaying, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () {
                                HapticUtils.selectionClick();
                                audioManager.togglePlayPause();
                              },
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              iconSize: 32,
                            ),
                          );
                        },
                      ),

                      // Next playlist button
                      if (onNext != null)
                        IconButton(
                          onPressed: () {
                            HapticUtils.selectionClick();
                            onNext?.call();
                          },
                          icon: const Icon(Icons.skip_next),
                          iconSize: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),

                      // Repeat button (cycles: off -> 1 -> 2 -> ∞)
                      ValueListenableBuilder(
                        valueListenable: audioManager.repeatModeNotifier,
                        builder: (context, repeatMode, child) {
                          IconData icon;
                          Color color;
                          Widget? badge;

                          switch (repeatMode) {
                            case 0: // Off
                              icon = Icons.repeat;
                              color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
                              badge = null;
                              break;
                            case 1: // Repeat once
                              icon = Icons.repeat;
                              color = Theme.of(context).colorScheme.tertiary;
                              badge = Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.tertiary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onTertiary,
                                    ),
                                  ),
                                ),
                              );
                              break;
                            case 2: // Repeat twice
                              icon = Icons.repeat;
                              color = Theme.of(context).colorScheme.tertiary;
                              badge = Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.tertiary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '2',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onTertiary,
                                    ),
                                  ),
                                ),
                              );
                              break;
                            case 3: // Infinite
                              icon = Icons.repeat;
                              color = Theme.of(context).colorScheme.tertiary;
                              badge = Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.tertiary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '∞',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onTertiary,
                                    ),
                                  ),
                                ),
                              );
                              break;
                            default:
                              icon = Icons.repeat;
                              color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
                              badge = null;
                          }

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                onPressed: () {
                                  HapticUtils.selectionClick();
                                  audioManager.cycleRepeatMode();
                                },
                                icon: Icon(icon),
                                iconSize: 24,
                                color: color,
                              ),
                              if (badge != null) badge,
                            ],
                          );
                        },
                      ),

                      // Speed button
                      ValueListenableBuilder(
                        valueListenable: audioManager.playbackSpeedNotifier,
                        builder: (context, speed, child) {
                          return IconButton(
                            onPressed: () {
                              HapticUtils.selectionClick();
                              _showSpeedSelector(context, audioManager);
                            },
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.speed),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${speed}x',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            iconSize: 24,
                            color: speed != 1.0
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          );
                        },
                      ),

                      // Stop button
                      IconButton(
                        onPressed: () {
                          HapticUtils.selectionClick();
                          audioManager.stop();
                        },
                        icon: const Icon(Icons.close),
                        iconSize: 24,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getSurahName(int surahNumber) async {
    try {
      final surahsJsonString = await rootBundle.loadString('assets/data/surah.json');
      final List<dynamic> surahsJsonList = json.decode(surahsJsonString);
      final surahs = surahsJsonList.map((json) => Surah.fromJson(json)).toList();
      final surah = surahs.firstWhere((s) => s.number == surahNumber);
      return surah.nameArabic;
    } catch (e) {
      return 'سورة $surahNumber';
    }
  }

  void _showSpeedSelector(BuildContext context, ContinuousAudioManager audioManager) {
    HapticUtils.dialogOpen();

    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];
    final currentSpeed = audioManager.playbackSpeedNotifier.value;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'سرعة التشغيل',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Uthmanic',
                ),
                textDirection: TextDirection.rtl,
              ),
            ),

            const Divider(height: 1),

            // Speed list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: speeds.length,
                itemBuilder: (context, index) {
                  final speed = speeds[index];
                  final isSelected = speed == currentSpeed;

                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                              )
                            : null,
                        color: isSelected ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        Icons.speed,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    title: Text(
                      speed == 1.0 ? 'عادي' : '${speed}x',
                      style: TextStyle(
                        fontFamily: 'Uthmanic',
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      HapticUtils.selectionClick();
                      audioManager.updatePlaybackSpeed(speed);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Tab 1: Reciters List
class _RecitersTab extends StatefulWidget {
  const _RecitersTab();

  @override
  State<_RecitersTab> createState() => _RecitersTabState();
}

class _RecitersTabState extends State<_RecitersTab> {
  late final List<String> _reciters;

  @override
  void initState() {
    super.initState();
    _reciters = ApiConstants.reciterConfigs.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reciters.length,
        itemBuilder: (context, index) {
          final reciterName = _reciters[index];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 150 + (index * 20)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticUtils.selectionClick();
                    _showSurahSelectionSheet(context, reciterName);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Reciter Avatar with gradient
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.mic,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Reciter Name
                        Expanded(
                          child: Text(
                            reciterName,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Uthmanic',
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),

                        // Arrow icon
                        Icon(
                          Icons.keyboard_arrow_left,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSurahSelectionSheet(BuildContext context, String reciterName) async {
    HapticUtils.dialogOpen();

    // Load surahs
    final surahsJsonString = await rootBundle.loadString('assets/data/surah.json');
    final List<dynamic> surahsJsonList = json.decode(surahsJsonString);
    final surahs = surahsJsonList.map((json) => Surah.fromJson(json)).toList();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header with reciter name
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.mic,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reciterName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Uthmanic',
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'اختر السورة',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Surahs list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: surahs.length,
                    itemBuilder: (context, index) {
                      final surah = surahs[index];
                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 100 + (index * 15)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(30 * (1 - value), 0),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                                Theme.of(context).colorScheme.surface,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticUtils.selectionClick();
                                Navigator.pop(context);
                                _showSurahActionsDialog(context, reciterName, surah);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Surah number badge
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Theme.of(context).colorScheme.primaryContainer,
                                            Theme.of(context).colorScheme.secondaryContainer,
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${surah.number}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Surah info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            surah.nameArabic,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Uthmanic',
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${surah.nameEnglish} • ${surah.ayahCount} آية',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Play icon
                                    Icon(
                                      Icons.play_circle_outline,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 32,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _downloadSurah(BuildContext context, String reciterName, Surah surah) async {
    HapticUtils.success();

    try {
      // Load ayah markers for the surah
      final ayahMarkersJsonString = await rootBundle.loadString('assets/data/markers.json');
      final List<dynamic> ayahMarkersJsonList = json.decode(ayahMarkersJsonString);
      final ayahMarkers = ayahMarkersJsonList.map((json) => AyahMarker.fromJson(json)).toList();

      // Get all ayahs for this surah
      final surahAyahs = ayahMarkers.where((marker) => marker.surah == surah.number).toList();

      if (surahAyahs.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'لم يتم العثور على الآيات',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Start download
      final downloadManager = AudioDownloadManager();
      await downloadManager.initialize();

      await downloadManager.downloadSurah(
        surah.number,
        reciterName,
      );

      if (!context.mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.download_for_offline,
                color: Theme.of(context).colorScheme.onTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'بدأ تحميل ${surah.nameArabic} • $reciterName',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'Uthmanic'),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'عرض',
            textColor: Colors.white,
            onPressed: () {
              // TODO: Navigate to downloads screen
            },
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Error downloading surah: $e');
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء التحميل: $e',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _playSurah(BuildContext context, String reciterName, Surah surah) async {
    HapticUtils.success();

    try {
      // Get the reciter config
      final reciterConfig = ApiConstants.reciterConfigs[reciterName];
      if (reciterConfig == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'لم يتم العثور على القارئ',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Load ayah markers for the surah
      final ayahMarkersJsonString = await rootBundle.loadString('assets/data/markers.json');
      final List<dynamic> ayahMarkersJsonList = json.decode(ayahMarkersJsonString);
      final ayahMarkers = ayahMarkersJsonList.map((json) => AyahMarker.fromJson(json)).toList();

      // Get all ayahs for this surah
      final surahAyahs = ayahMarkers.where((marker) => marker.surah == surah.number).toList();

      if (surahAyahs.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'لم يتم العثور على الآيات',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Initialize audio manager
      final audioManager = ContinuousAudioManager();
      await audioManager.initialize();

      // Unregister page controller so playback doesn't affect mushaf screen
      audioManager.registerPageController(null, null, null);

      // Start playing from the first ayah of the surah
      // NOTE: Don't pass allAyahMarkers to prevent continuing beyond this surah
      final firstAyah = surahAyahs.first;
      await audioManager.startContinuousPlayback(
        firstAyah,
        reciterName,
        surahAyahs,
      );

      // Log analytics for playlist played (single surah)
      AnalyticsService.logPlaylistPlayed(
        1, // Playing single surah
        reciterName,
      );

    } catch (e) {
      if (kDebugMode) print('Error playing surah: $e');
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء التشغيل: $e',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSurahActionsDialog(BuildContext context, String reciterName, Surah surah) {
    HapticUtils.dialogOpen();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Surah info header
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    surah.nameArabic,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Uthmanic',
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reciterName,
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Uthmanic',
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Play button
                  _buildActionButton(
                    context: context,
                    icon: Icons.play_circle_fill,
                    label: 'تشغيل السورة',
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    onTap: () {
                      HapticUtils.selectionClick();
                      Navigator.pop(context);
                      _playSurah(context, reciterName, surah);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Download button
                  _buildActionButton(
                    context: context,
                    icon: Icons.download_for_offline,
                    label: 'تحميل السورة',
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.tertiary,
                        Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8),
                      ],
                    ),
                    onTap: () {
                      HapticUtils.selectionClick();
                      Navigator.pop(context);
                      _downloadSurah(context, reciterName, surah);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Uthmanic',
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Tab 2: Playlists
class _PlaylistsTab extends StatefulWidget {
  const _PlaylistsTab({super.key});

  @override
  State<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<_PlaylistsTab> {
  final List<Map<String, dynamic>> _playlists = [];
  bool _isLoading = true;
  int? _currentPlaylistIndex;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = prefs.getString('playlists');

      if (playlistsJson != null) {
        final List<dynamic> decoded = json.decode(playlistsJson);
        setState(() {
          _playlists.clear();
          _playlists.addAll(decoded.cast<Map<String, dynamic>>());
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading playlists: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = json.encode(_playlists);
      await prefs.setString('playlists', playlistsJson);
    } catch (e) {
      debugPrint('Error saving playlists: $e');
    }
  }

  Future<void> _deletePlaylist(int index) async {
    HapticUtils.heavyImpact();

    final playlist = _playlists[index];
    setState(() {
      _playlists.removeAt(index);
    });
    await _savePlaylists();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.onError,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'تم حذف "${playlist['name']}"',
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Uthmanic'),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'تراجع',
          textColor: Theme.of(context).colorScheme.onError,
          onPressed: () {
            setState(() {
              _playlists.insert(index, playlist);
            });
            _savePlaylists();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          // Create new playlist button with gradient
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticUtils.selectionClick();
                    _showCreatePlaylistSheet(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          "إنشاء قائمة تشغيل جديدة",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Uthmanic',
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Playlists list
          Expanded(
            child: _playlists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.playlist_play_outlined,
                            size: 60,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "لا توجد قوائم تشغيل",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontFamily: 'Uthmanic',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            "أنشئ قائمة تشغيل مخصصة للآيات المفضلة لديك",
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      return Dismissible(
                        key: Key(playlist['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.onError,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'حذف',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onError,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Uthmanic',
                                ),
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text(
                                  'تأكيد الحذف',
                                  style: TextStyle(fontFamily: 'Uthmanic'),
                                  textDirection: TextDirection.rtl,
                                ),
                                content: Text(
                                  'هل أنت متأكد من حذف "${playlist['name']}"؟',
                                  style: const TextStyle(fontFamily: 'Uthmanic'),
                                  textDirection: TextDirection.rtl,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text(
                                      'إلغاء',
                                      style: TextStyle(fontFamily: 'Uthmanic'),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text(
                                      'حذف',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                        fontFamily: 'Uthmanic',
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          _deletePlaylist(index);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                                Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.2),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticUtils.selectionClick();
                                _playPlaylist(playlist, index);
                              },
                              onLongPress: () {
                                HapticUtils.heavyImpact();
                                _showCreatePlaylistSheet(
                                  context,
                                  editingPlaylist: playlist,
                                  editingIndex: index,
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Theme.of(context).colorScheme.secondary,
                                            Theme.of(context).colorScheme.tertiary,
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.playlist_play,
                                        color: Theme.of(context).colorScheme.onSecondary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            playlist['name'],
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Uthmanic',
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'القارئ: ${playlist['reciter']} • ${playlist['description']}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                  ),
                                                  textDirection: TextDirection.rtl,
                                                ),
                                              ),
                                              if (playlist['repeatCount'] > 1)
                                                Container(
                                                  margin: const EdgeInsets.only(right: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.primaryContainer,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.repeat,
                                                        size: 12,
                                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '×${playlist['repeatCount']}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.play_circle_fill,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 40,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistSheet(BuildContext context, {Map<String, dynamic>? editingPlaylist, int? editingIndex}) {
    HapticUtils.dialogOpen();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => _PlaylistCreationSheet(
        existingPlaylist: editingPlaylist,
        onPlaylistCreated: (playlist) {
          setState(() {
            if (editingIndex != null) {
              // Edit existing playlist
              _playlists[editingIndex] = playlist;
            } else {
              // Add new playlist
              _playlists.add(playlist);
            }
          });
          _savePlaylists();
        },
      ),
    );
  }

  Future<void> _playPlaylist(Map<String, dynamic> playlist, int playlistIndex) async {
    HapticUtils.success();

    setState(() {
      _currentPlaylistIndex = playlistIndex;
    });

    try {
      // Load all ayah markers
      final ayahMarkersJsonString = await rootBundle.loadString('assets/data/markers.json');
      final List<dynamic> ayahMarkersJsonList = json.decode(ayahMarkersJsonString);
      final allAyahMarkers = ayahMarkersJsonList.map((json) => AyahMarker.fromJson(json)).toList();

      // Extract playlist data
      final fromSurah = playlist['fromSurah'] as int;
      final fromAyah = playlist['fromAyah'] as int?;
      final toSurah = playlist['toSurah'] as int;
      final toAyah = playlist['toAyah'] as int?;
      final reciter = playlist['reciter'] as String;
      final repeatCount = playlist['repeatCount'] as int;

      // Build the queue of ayahs for the playlist (unique ayahs only for download check)
      List<AyahMarker> uniqueAyahs = [];

      for (int surahNum = fromSurah; surahNum <= toSurah; surahNum++) {
        // Get all ayahs for this surah
        final surahAyahs = allAyahMarkers
            .where((marker) => marker.surah == surahNum)
            .toList()
          ..sort((a, b) => a.ayah.compareTo(b.ayah));

        if (surahAyahs.isEmpty) continue;

        // Determine start and end ayah for this surah
        int startAyah = 1;
        int endAyah = surahAyahs.last.ayah;

        if (surahNum == fromSurah && fromAyah != null) {
          startAyah = fromAyah;
        }
        if (surahNum == toSurah && toAyah != null) {
          endAyah = toAyah;
        }

        // Add ayahs in range (unique, no repeats for download check)
        for (final ayah in surahAyahs) {
          if (ayah.ayah >= startAyah && ayah.ayah <= endAyah) {
            uniqueAyahs.add(ayah);
          }
        }
      }

      if (uniqueAyahs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'لم يتم العثور على آيات في هذا النطاق',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Download surahs in background (don't wait for download)
      final downloadManager = AudioDownloadManager();
      await downloadManager.initialize();

      // Get unique surahs in the playlist
      Set<int> surahsInPlaylist = {};
      for (final ayah in uniqueAyahs) {
        surahsInPlaylist.add(ayah.surah);
      }

      // Start downloading all surahs in background (fire and forget)
      for (final surahNum in surahsInPlaylist) {
        final isDownloaded = downloadManager.isDownloaded(DownloadType.surah, surahNum, reciter);
        if (!isDownloaded) {
          // Download in background without waiting
          downloadManager.downloadSurah(surahNum, reciter);
        }
      }

      // Build the full playlist queue with repeats
      List<AyahMarker> playlistQueue = [];
      for (final ayah in uniqueAyahs) {
        for (int i = 0; i < repeatCount; i++) {
          playlistQueue.add(ayah);
        }
      }

      // Initialize audio manager
      final audioManager = ContinuousAudioManager();
      await audioManager.initialize();

      // Unregister page controller to prevent mushaf navigation
      audioManager.registerPageController(null, null, null);

      // Start playing the playlist
      // NOTE: Don't pass allAyahMarkers to prevent continuing beyond playlist endpoint
      await audioManager.startContinuousPlayback(
        playlistQueue.first,
        reciter,
        playlistQueue,
      );
// Log analytics for playlist played      AnalyticsService.logPlaylistPlayed(        'surah_${surah.number}',        reciterName,        surahAyahs.length,      );

    } catch (e) {
      debugPrint('Error playing playlist: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تشغيل القائمة: $e',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _playPreviousPlaylist() {
    if (_playlists.isEmpty || _currentPlaylistIndex == null) return;

    final previousIndex = (_currentPlaylistIndex! - 1) % _playlists.length;
    if (previousIndex < 0) {
      // Wrap to last playlist
      _playPlaylist(_playlists[_playlists.length - 1], _playlists.length - 1);
    } else {
      _playPlaylist(_playlists[previousIndex], previousIndex);
    }
  }

  void _playNextPlaylist() {
    if (_playlists.isEmpty || _currentPlaylistIndex == null) return;

    final nextIndex = (_currentPlaylistIndex! + 1) % _playlists.length;
    _playPlaylist(_playlists[nextIndex], nextIndex);
  }
}

// Playlist Creation Sheet
class _PlaylistCreationSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onPlaylistCreated;
  final Map<String, dynamic>? existingPlaylist;

  const _PlaylistCreationSheet({
    required this.onPlaylistCreated,
    this.existingPlaylist,
  });

  @override
  State<_PlaylistCreationSheet> createState() => _PlaylistCreationSheetState();
}

class _PlaylistCreationSheetState extends State<_PlaylistCreationSheet> {
  final TextEditingController _nameController = TextEditingController();

  // From selection
  Surah? _fromSurah;
  int? _fromAyah;

  // To selection
  Surah? _toSurah;
  int? _toAyah;

  // Reciter selection
  String? _selectedReciter;

  // Repeat count
  int _repeatCount = 1;

  List<Surah> _allSurahs = [];
  String? _playlistId;

  @override
  void initState() {
    super.initState();
    _loadSurahs();
    _selectedReciter = ApiConstants.reciterConfigs.keys.first;

    // Load existing playlist data if editing
    if (widget.existingPlaylist != null) {
      final playlist = widget.existingPlaylist!;
      _playlistId = playlist['id'];
      _nameController.text = playlist['name'];
      _repeatCount = playlist['repeatCount'] ?? 1;
      _selectedReciter = playlist['reciter'];
      // Surahs will be loaded after _allSurahs is populated
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    try {
      final surahsJsonString = await rootBundle.loadString('assets/data/surah.json');
      final List<dynamic> surahsJsonList = json.decode(surahsJsonString);
      setState(() {
        _allSurahs = surahsJsonList.map((json) => Surah.fromJson(json)).toList();

        // Load existing playlist surahs after loading all surahs
        if (widget.existingPlaylist != null) {
          final playlist = widget.existingPlaylist!;
          _fromSurah = _allSurahs.firstWhere((s) => s.number == playlist['fromSurah']);
          _fromAyah = playlist['fromAyah'];
          _toSurah = _allSurahs.firstWhere((s) => s.number == playlist['toSurah']);
          _toAyah = playlist['toAyah'];
        }
      });
    } catch (e) {
      debugPrint('Error loading surahs: $e');
    }
  }

  void _updatePlaylistName() {
    if (_fromSurah != null && _toSurah != null) {
      final from = '${_fromSurah!.nameArabic}${_fromAyah != null ? ":$_fromAyah" : ""}';
      final to = '${_toSurah!.nameArabic}${_toAyah != null ? ":$_toAyah" : ""}';
      _nameController.text = 'من $from إلى $to';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.playlist_add,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.existingPlaylist != null ? "تعديل قائمة التشغيل" : "إنشاء قائمة تشغيل",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Uthmanic',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Form content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Playlist Name Section (moved to top)
                      _buildSectionHeader(context, 'اسم القائمة', Icons.label),
                      const SizedBox(height: 12),
                      Focus(
                        onFocusChange: (hasFocus) {
                          // Prevent auto-focus when opening dialogs
                        },
                        child: TextField(
                          controller: _nameController,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          enableInteractiveSelection: true,
                          autofocus: false,
                          style: const TextStyle(
                            fontFamily: 'Uthmanic',
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'أدخل اسم القائمة',
                            hintStyle: const TextStyle(
                              fontFamily: 'Uthmanic',
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // From Section
                      _buildSectionHeader(context, 'من', Icons.play_circle_outline),
                      const SizedBox(height: 12),
                      _buildSelectionRow(
                        context,
                        label: 'السورة',
                        value: _fromSurah?.nameArabic ?? 'اختر سورة',
                        onTap: () => _showSurahSelector(true),
                      ),
                      const SizedBox(height: 8),
                      _buildSelectionRow(
                        context,
                        label: 'الآية',
                        value: _fromAyah?.toString() ?? 'بداية السورة',
                        onTap: _fromSurah != null ? () => _showAyahSelector(true) : null,
                        enabled: _fromSurah != null,
                      ),

                      const SizedBox(height: 24),

                      // To Section
                      _buildSectionHeader(context, 'إلى', Icons.stop_circle_outlined),
                      const SizedBox(height: 12),
                      _buildSelectionRow(
                        context,
                        label: 'السورة',
                        value: _toSurah?.nameArabic ?? 'اختر سورة',
                        onTap: _fromSurah != null ? () => _showSurahSelector(false) : null,
                        enabled: _fromSurah != null,
                      ),
                      const SizedBox(height: 8),
                      _buildSelectionRow(
                        context,
                        label: 'الآية',
                        value: _toAyah?.toString() ?? 'نهاية السورة',
                        onTap: _toSurah != null ? () => _showAyahSelector(false) : null,
                        enabled: _toSurah != null,
                      ),

                      const SizedBox(height: 24),

                      // Reciter Section
                      _buildSectionHeader(context, 'القارئ', Icons.person),
                      const SizedBox(height: 12),
                      _buildSelectionRow(
                        context,
                        label: 'القارئ',
                        value: _selectedReciter ?? 'اختر قارئ',
                        onTap: _showReciterSelector,
                      ),

                      const SizedBox(height: 24),

                      // Repeat Count Section
                      _buildSectionHeader(context, 'عدد مرات التكرار', Icons.repeat),
                      const SizedBox(height: 12),
                      _buildRepeatCounter(context),

                      const SizedBox(height: 32),

                      // Create Button
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _canCreatePlaylist() ? _createPlaylist : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle,
                                      color: _canCreatePlaylist()
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      widget.existingPlaylist != null ? 'حفظ التعديلات' : 'إنشاء قائمة التشغيل',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Uthmanic',
                                        color: _canCreatePlaylist()
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Uthmanic',
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  Widget _buildSelectionRow(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Uthmanic',
                          color: enabled
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_back_ios,
                  size: 16,
                  color: enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatCounter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'عدد المرات',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textDirection: TextDirection.rtl,
          ),
          Row(
            textDirection: TextDirection.ltr,
            children: [
              IconButton(
                onPressed: _repeatCount > 1
                    ? () {
                        HapticUtils.selectionClick();
                        setState(() => _repeatCount--);
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: Theme.of(context).colorScheme.primary,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_repeatCount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticUtils.selectionClick();
                  setState(() => _repeatCount++);
                },
                icon: const Icon(Icons.add_circle_outline),
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSurahSelector(bool isFrom) {
    HapticUtils.dialogOpen();

    // Unfocus text field to dismiss keyboard
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    isFrom ? 'اختر السورة (من)' : 'اختر السورة (إلى)',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Uthmanic',
                    ),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                  ),
                ),

                const Divider(height: 1),

                // Surah list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _allSurahs.length,
                    itemBuilder: (context, index) {
                      final surah = _allSurahs[index];
                      final isDisabled = !isFrom && _fromSurah != null && surah.number < _fromSurah!.number;

                      return ListTile(
                        enabled: !isDisabled,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDisabled
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          ),
                          child: Center(
                            child: Text(
                              '${surah.number}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDisabled
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          surah.nameArabic,
                          style: TextStyle(
                            fontFamily: 'Uthmanic',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDisabled
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        subtitle: Text(
                          '${surah.nameEnglish} • ${surah.ayahCount} آية',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDisabled
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        onTap: isDisabled
                            ? null
                            : () {
                                HapticUtils.selectionClick();
                                setState(() {
                                  if (isFrom) {
                                    _fromSurah = surah;
                                    _fromAyah = null; // Reset ayah selection
                                    // Reset To selection if it's before From
                                    if (_toSurah != null && _toSurah!.number < surah.number) {
                                      _toSurah = null;
                                      _toAyah = null;
                                    }
                                  } else {
                                    _toSurah = surah;
                                    _toAyah = null; // Reset ayah selection
                                  }
                                  _updatePlaylistName();
                                });
                                Navigator.pop(context);
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAyahSelector(bool isFrom) {
    final surah = isFrom ? _fromSurah! : _toSurah!;
    final minAyah = !isFrom && _fromSurah != null && _fromSurah!.number == _toSurah!.number
        ? (_fromAyah ?? 1)
        : 1;

    HapticUtils.dialogOpen();

    // Unfocus text field to dismiss keyboard
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        isFrom ? 'اختر الآية (من)' : 'اختر الآية (إلى)',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Uthmanic',
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        surah.nameArabic,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Uthmanic',
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Ayah list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: surah.ayahCount + 1, // +1 for "entire surah" option
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // "Entire surah" option
                        return ListTile(
                          leading: Icon(
                            Icons.select_all,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            isFrom ? 'من بداية السورة' : 'حتى نهاية السورة',
                            style: const TextStyle(
                              fontFamily: 'Uthmanic',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          onTap: () {
                            HapticUtils.selectionClick();
                            setState(() {
                              if (isFrom) {
                                _fromAyah = null;
                              } else {
                                _toAyah = null;
                              }
                              _updatePlaylistName();
                            });
                            Navigator.pop(context);
                          },
                        );
                      }

                      final ayahNumber = index;
                      final isDisabled = ayahNumber < minAyah;

                      return ListTile(
                        enabled: !isDisabled,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDisabled
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                          ),
                          child: Center(
                            child: Text(
                              '$ayahNumber',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDisabled
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                                    : Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'الآية $ayahNumber',
                          style: TextStyle(
                            fontFamily: 'Uthmanic',
                            fontSize: 16,
                            color: isDisabled
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        onTap: isDisabled
                            ? null
                            : () {
                                HapticUtils.selectionClick();
                                setState(() {
                                  if (isFrom) {
                                    _fromAyah = ayahNumber;
                                    // Reset To ayah if it's before From ayah (in same surah)
                                    if (_toSurah != null && _toSurah!.number == _fromSurah!.number) {
                                      if (_toAyah != null && _toAyah! < ayahNumber) {
                                        _toAyah = null;
                                      }
                                    }
                                  } else {
                                    _toAyah = ayahNumber;
                                  }
                                  _updatePlaylistName();
                                });
                                Navigator.pop(context);
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReciterSelector() {
    HapticUtils.dialogOpen();

    // Unfocus text field to dismiss keyboard
    FocusScope.of(context).unfocus();

    final reciters = ApiConstants.reciterConfigs.keys.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'اختر القارئ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Uthmanic',
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
              ),
            ),

            const Divider(height: 1),

            // Reciters list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: reciters.length,
                itemBuilder: (context, index) {
                  final reciter = reciters[index];
                  final isSelected = reciter == _selectedReciter;

                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                              )
                            : null,
                        color: isSelected ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        Icons.mic,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    title: Text(
                      reciter,
                      style: TextStyle(
                        fontFamily: 'Uthmanic',
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      HapticUtils.selectionClick();
                      setState(() {
                        _selectedReciter = reciter;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canCreatePlaylist() {
    return _fromSurah != null && _toSurah != null && _selectedReciter != null;
  }

  void _createPlaylist() {
    if (!_canCreatePlaylist()) return;

    HapticUtils.success();

    final playlist = {
      'id': _playlistId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _nameController.text.isEmpty
          ? 'من ${_fromSurah!.nameArabic} إلى ${_toSurah!.nameArabic}'
          : _nameController.text,
      'fromSurah': _fromSurah!.number,
      'fromAyah': _fromAyah,
      'toSurah': _toSurah!.number,
      'toAyah': _toAyah,
      'reciter': _selectedReciter!,
      'repeatCount': _repeatCount,
      'description': '${_fromSurah!.nameArabic}${_fromAyah != null ? ":$_fromAyah" : ""} → ${_toSurah!.nameArabic}${_toAyah != null ? ":$_toAyah" : ""}',
      'created': DateTime.now().toIso8601String(),
    };

    widget.onPlaylistCreated(playlist);
    Navigator.pop(context);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.onTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.existingPlaylist != null ? 'تم حفظ التعديلات' : 'تم إنشاء قائمة التشغيل',
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontFamily: 'Uthmanic'),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
