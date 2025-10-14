import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dhikr_model.dart';
import '../utils/haptic_utils.dart';
import '../services/azkar_audio_service.dart';
import '../services/analytics_service.dart';
import '../widgets/azkar_mini_player.dart';

class AzkarViewerScreen extends StatefulWidget {
  final DhikrCategory category;
  final int initialIndex;

  const AzkarViewerScreen({
    super.key,
    required this.category,
    this.initialIndex = 0,
  });

  @override
  State<AzkarViewerScreen> createState() => _AzkarViewerScreenState();
}

class _AzkarViewerScreenState extends State<AzkarViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final AzkarAudioService _audioService = AzkarAudioService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _audioService.initialize();

    // Set up audio completion callback for auto-play next
    _audioService.onAudioComplete = _onAudioComplete;

    // Log azkar category opened
    AnalyticsService.logAzkarCategoryOpened(
      widget.category.category,
      widget.category.dhikrs.length,
    );
  }

  void _onAudioComplete() {
    if (!mounted) return;

    // Check if auto-play next is enabled and we're not at the last dhikr
    if (_audioService.autoPlayNextNotifier.value &&
        _currentIndex < widget.category.dhikrs.length - 1) {
      // Auto-advance to next dhikr
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ).then((_) {
        if (!mounted) return;
        // Auto-play the next dhikr's audio
        final nextDhikr = widget.category.dhikrs[_currentIndex];
        _audioService.playDhikr(nextDhikr, category: widget.category);
      });
    } else if (_audioService.repeatModeNotifier.value == RepeatMode.all &&
        _currentIndex == widget.category.dhikrs.length - 1) {
      // If repeat all and at last dhikr, go back to first
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ).then((_) {
        if (!mounted) return;
        // Auto-play the first dhikr's audio
        final firstDhikr = widget.category.dhikrs[0];
        _audioService.playDhikr(firstDhikr, category: widget.category);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioService.stop();
    _audioService.onAudioComplete = null;
    super.dispose();
  }

  void _incrementCounter() {
    final dhikr = widget.category.dhikrs[_currentIndex];

    if (!dhikr.isCompleted) {
      HapticUtils.lightImpact();
      setState(() {
        dhikr.increment();
      });

      // Only show completion message and auto-advance when dhikr completes
      if (dhikr.isCompleted) {
        HapticUtils.success();

        // Only show snackbar if it's the last dhikr in category
        if (_currentIndex == widget.category.dhikrs.length - 1) {
          _showCategoryCompletionMessage();
        }

        // Auto-advance to next dhikr after 800ms if not last
        if (_currentIndex < widget.category.dhikrs.length - 1) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      }
    } else {
      HapticUtils.lightImpact();
    }
  }

  void _showCategoryCompletionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'أحسنت! اكتملت الأذكار ✓',
                style: const TextStyle(fontSize: 15, fontFamily: 'Uthmanic'),
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final dhikr = widget.category.dhikrs[_currentIndex];
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Section title
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'إعدادات الصوت',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Uthmanic',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),

                    // Auto-play next toggle
                    ValueListenableBuilder<bool>(
                      valueListenable: _audioService.autoPlayNextNotifier,
                      builder: (context, autoPlayNext, child) {
                        return SwitchListTile(
                          secondary: Icon(
                            Icons.skip_next,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text(
                            'تشغيل تلقائي للذكر التالي',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontFamily: 'Uthmanic', fontSize: 16),
                          ),
                          value: autoPlayNext,
                          onChanged: (value) {
                            HapticUtils.lightImpact();
                            setModalState(() {
                              _audioService.toggleAutoPlayNext();
                            });
                          },
                        );
                      },
                    ),

                    const Divider(),

                    // Text options section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'خيارات النص',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Uthmanic',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),

                    ListTile(
                      leading: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary),
                      title: const Text(
                        'نسخ النص',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontFamily: 'Uthmanic', fontSize: 16),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        HapticUtils.lightImpact();
                        await Clipboard.setData(ClipboardData(text: dhikr.text));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('تم نسخ النص ✓'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),

                    if (!dhikr.isCompleted)
                      ListTile(
                        leading: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
                        title: const Text(
                          'إعادة تعيين العداد',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(fontFamily: 'Uthmanic', fontSize: 16),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          HapticUtils.mediumImpact();
                          setState(() {
                            dhikr.reset();
                          });
                        },
                      ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      bottomNavigationBar: AzkarMiniPlayer(audioService: _audioService),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.category.category,
          style: const TextStyle(
            fontFamily: 'Uthmanic',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: _showOptionsMenu,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Main PageView
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                // Stop audio when changing pages
                _audioService.stop();
                HapticUtils.selectionClick();
              },
              itemCount: widget.category.dhikrs.length,
              itemBuilder: (context, index) {
                return _buildDhikrPage(widget.category.dhikrs[index], index);
              },
            ),

            // Progress Indicator at Top
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        widget.category.dhikrs.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == _currentIndex ? 24 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: index == _currentIndex
                                ? Colors.white
                                : index < _currentIndex
                                    ? Colors.green.shade300
                                    : Colors.white38,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDhikrPage(Dhikr dhikr, int index) {
    return GestureDetector(
      onTap: _incrementCounter,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Dhikr Text - Large and readable
                  SelectableText(
                    dhikr.text,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 2.2,
                      fontFamily: 'Uthmanic',
                      fontWeight: FontWeight.w600,
                    ),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                  ),

                  // Progress indicator
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${dhikr.currentCount} / ${dhikr.count}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontFamily: 'Uthmanic',
                      ),
                    ),
                  ),

                  // Small completion indicator
                  if (dhikr.isCompleted) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'مكتمل',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontFamily: 'Uthmanic',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Audio Control - Larger
                  _buildAudioControl(dhikr),

                  const SizedBox(height: 24),

                  // Tap Hint
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'اضغط في أي مكان للعد',
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Uthmanic',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioControl(Dhikr dhikr) {
    return ValueListenableBuilder<bool>(
      valueListenable: _audioService.isPlayingNotifier,
      builder: (context, isPlaying, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: _audioService.isLoadingNotifier,
          builder: (context, isLoading, child) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isLoading ? null : () async {
                  HapticUtils.lightImpact();
                  try {
                    if (isPlaying) {
                      await _audioService.pause();
                    } else {
                      await _audioService.playDhikr(dhikr, category: widget.category);
                      // Log audio played
                      AnalyticsService.logDhikrAudioPlayed(
                        widget.category.category,
                        dhikr.text,
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ في تشغيل الصوت'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      else
                        Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      const SizedBox(width: 12),
                      Text(
                        isLoading
                            ? 'جاري التحميل...'
                            : (isPlaying ? 'إيقاف مؤقت' : 'استمع للذكر'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Uthmanic',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
