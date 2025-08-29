// lib/viewer_screen.dart - COMPLETELY FIXED VERSION with proper media player positioning

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/ayah_marker.dart';
import 'models/surah.dart';
import 'bookmark_manager.dart';
import 'settings_screen.dart';
import 'svg_page_viewer.dart';
import 'widgets/floating_media_player.dart';
import 'continuous_audio_manager.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> with TickerProviderStateMixin {
  static const int totalPages = 604;

  // Layout constants
  static const double pageVerticalOffset = 50.0;
  static const double mediaPlayerHeight = 80.0;

  PageController? _controller;
  ContinuousAudioManager? _audioManager;

  late AnimationController _mediaPlayerAnimationController;
  late Animation<double> _mediaPlayerAnimation;

  Map<int, List<AyahMarker>> _markersByPage = {};
  List<AyahMarker> _allMarkers = [];
  List<Surah> _allSurahs = [];
  Map<int, int> _juzStartPages = {};
  bool _isLoading = true;
  bool _isBookmarked = false;

  final ValueNotifier<int> _currentPageNotifier = ValueNotifier(1);
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudioManager();
    _initializeReader();
  }

  void _initializeAnimations() {
    _mediaPlayerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _mediaPlayerAnimation = CurvedAnimation(
      parent: _mediaPlayerAnimationController,
      curve: Curves.easeInOut,
    );
  }

  void _initializeAudioManager() {
    _audioManager = ContinuousAudioManager();
    _audioManager!.initialize();

    // Listen to audio manager state changes to control animation
    _audioManager!.currentAyahNotifier.addListener(_onAudioStateChanged);
  }

  void _onAudioStateChanged() {
    if (_audioManager!.currentAyahNotifier.value != null) {
      _mediaPlayerAnimationController.forward();
    } else {
      _mediaPlayerAnimationController.reverse();
    }
  }

  Future<void> _initializeReader() async {
    try {
      await Future.wait([
        _loadData(),
        _loadLastPage(),
      ]);
      await _checkBookmarkStatus();
    } catch (e) {
      debugPrint('Error initializing reader: $e');
      _currentPageNotifier.value = 1;
      _controller = PageController(initialPage: 0);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _currentPageNotifier.dispose();
    _saveTimer?.cancel();
    _mediaPlayerAnimationController.dispose();

    // Stop audio and remove listeners
    _audioManager?.currentAyahNotifier.removeListener(_onAudioStateChanged);
    // If your ContinuousAudioManager has dispose(), this is ideal; otherwise stop() is a safe fallback.
    try {
      // ignore: invalid_use_of_protected_member
      // Attempt to call dispose if it exists in your implementation.
      // If not, fall back to stop.
      // This try/catch avoids hard compile errors across branches.
      // @ts-ignore (Dart comment placeholder)
      // ignore_for_file: unnecessary_statements
      (_audioManager as dynamic)?.dispose?.call();
    } catch (_) {
      _audioManager?.stop();
    }

    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _loadAllMarkers();

      final surahsJsonString = await rootBundle.loadString('assets/surah.json');
      final List<dynamic> surahsJsonList = json.decode(surahsJsonString);
      _allSurahs = surahsJsonList.map((json) => Surah.fromJson(json)).toList();

      debugPrint('Loaded ${_allSurahs.length} surahs and ${_allMarkers.length} markers');

      if (_allSurahs.isNotEmpty) {
        _juzStartPages = <int, int>{};
        for (var juz = 1; juz <= 30; juz++) {
          try {
            final firstSurahInJuz = _allSurahs.firstWhere((s) => s.juzNumber == juz);
            _juzStartPages[juz] = firstSurahInJuz.pageNumber;
          } catch (e) {
            _juzStartPages[juz] = _allSurahs.last.pageNumber;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      _markersByPage = {};
      _allSurahs = [];
      _juzStartPages = {};
    }
  }

  Future<void> _loadAllMarkers() async {
    try {
      final markersJsonString = await rootBundle.loadString('assets/markers.json');
      final List<dynamic> markersJsonList = json.decode(markersJsonString);

      _allMarkers.clear();
      for (var json in markersJsonList) {
        final marker = AyahMarker.fromJson(json);
        _allMarkers.add(marker);
      }

      _markersByPage = <int, List<AyahMarker>>{};
      for (var marker in _allMarkers) {
        _markersByPage.putIfAbsent(marker.page, () => []).add(marker);
      }

      _markersByPage.forEach((page, markers) {
        markers.sort((a, b) {
          final surahCompare = a.surah.compareTo(b.surah);
          if (surahCompare != 0) return surahCompare;
          return a.ayah.compareTo(b.ayah);
        });
      });

      debugPrint('Loaded markers for ${_markersByPage.length} pages');
    } catch (e) {
      debugPrint('Error loading markers: $e');
      _markersByPage = {};
      _allMarkers = [];
    }
  }

  Future<void> _saveLastPageOptimized(int page) async {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_page', page);
      } catch (e) {
        debugPrint('Error saving last page: $e');
      }
    });
  }

  Future<void> _loadLastPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPage = prefs.getInt('last_page') ?? 1;
      _currentPageNotifier.value = lastPage;

      final initialIndex = lastPage - 1;

      _controller = PageController(
        initialPage: initialIndex,
        viewportFraction: 1.0,
      );

      _controller!.addListener(_onPageChanged);
    } catch (e) {
      debugPrint('Error loading last page: $e');
      _currentPageNotifier.value = 1;
      _controller = PageController(initialPage: 0);
    }
  }

  void _onPageChanged() {
    if (!mounted || _controller?.page == null) return;

    final pageValue = _controller!.page;
    if (pageValue == null) return;

    final pageIndex = pageValue.round();
    final newPage = pageIndex + 1;

    if (newPage != _currentPageNotifier.value &&
        newPage > 0 &&
        newPage <= totalPages) {
      _currentPageNotifier.value = newPage;
      _saveLastPageOptimized(newPage);
      _checkBookmarkStatus();
    }
  }

  Future<void> _checkBookmarkStatus() async {
    final isBookmarked = await BookmarkManager.isBookmarked(_currentPageNotifier.value);
    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
      });
    }
  }

  ({String surahName, String juzNumber}) _getInfoForPage(int page) {
    if (_allSurahs.isEmpty) {
      return (surahName: '', juzNumber: '');
    }

    try {
      final surahsOnPage = _allSurahs.where((s) => s.pageNumber == page).toList();
      Surah primarySurah = _allSurahs.lastWhere(
            (s) => s.pageNumber <= page,
        orElse: () => _allSurahs.first,
      );

      final surahName = surahsOnPage.isNotEmpty
          ? surahsOnPage.map((s) => s.nameArabic).join(' / ')
          : primarySurah.nameArabic;

      return (surahName: surahName, juzNumber: "الجزء ${primarySurah.juzNumber}");
    } catch (e) {
      debugPrint('Error getting page info: $e');
      return (surahName: '', juzNumber: '');
    }
  }

  void _jumpToPage(int page) {
    if (page < 1 || page > totalPages || _controller == null) return;

    final int index = page - 1;
    _controller!.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onContinuousPlayRequested(AyahMarker ayahMarker, String reciterName) async {
    try {
      debugPrint('Starting continuous playback for ayah ${ayahMarker.surah}:${ayahMarker.ayah} with $reciterName');

      final surahAyahs = _allMarkers.where((marker) => marker.surah == ayahMarker.surah).toList();

      debugPrint('Found ${surahAyahs.length} ayahs in surah ${ayahMarker.surah}');

      await _audioManager!.startContinuousPlayback(ayahMarker, reciterName, surahAyahs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('بدء التشغيل المتواصل من الآية ${ayahMarker.ayah} من سورة ${_getSurahName(ayahMarker.surah)} بصوت $reciterName'),
            ),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'إيقاف',
              onPressed: () => _audioManager!.stop(),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting continuous playback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('حدث خطأ في بدء التشغيل: ${e.toString()}'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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

  Future<void> _toggleBookmarkSafe() async {
    try {
      final currentPage = _currentPageNotifier.value;
      final pageInfo = _getInfoForPage(currentPage);

      if (_isBookmarked) {
        await BookmarkManager.removeBookmark(currentPage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Text('تم إزالة الإشارة المرجعية'),
              ),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        final bookmark = Bookmark(
          page: currentPage,
          surahName: pageInfo.surahName,
          juzName: pageInfo.juzNumber,
          createdAt: DateTime.now(),
        );
        await BookmarkManager.addBookmark(bookmark);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Text('تم إضافة الإشارة المرجعية'),
              ),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }

      await _checkBookmarkStatus();
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('حدث خطأ: ${e.toString()}'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showBookmarksSafe() async {
    try {
      final bookmarks = await BookmarkManager.getBookmarks().timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (bookmarks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('لا توجد إشارات مرجعية محفوظة'),
            ),
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        builder: (context) => GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: GestureDetector(
              onTap: () {},
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmarks,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'الإشارات المرجعية (${bookmarks.length})',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: bookmarks.length,
                        itemBuilder: (context, index) {
                          final bookmark = bookmarks[index];
                          return Dismissible(
                            key: Key('bookmark_${bookmark.page}_${bookmark.createdAt}'),
                            background: Container(
                              color: Theme.of(context).colorScheme.error,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (direction) async {
                              if (bookmark.isAyahBookmark) {
                                await BookmarkManager.removeAyahBookmark(
                                  bookmark.surahNumber!,
                                  bookmark.ayahNumber!,
                                );
                              } else {
                                await BookmarkManager.removeBookmark(bookmark.page);
                              }
                              _checkBookmarkStatus();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text('تم حذف الإشارة المرجعية'),
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: bookmark.isAyahBookmark
                                    ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                child: Icon(
                                  bookmark.isAyahBookmark ? Icons.format_quote : Icons.bookmark,
                                  color: bookmark.isAyahBookmark
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                bookmark.isAyahBookmark
                                    ? '${bookmark.surahName} - آية ${bookmark.ayahNumber}'
                                    : bookmark.surahName,
                              ),
                              subtitle: Text(
                                bookmark.isAyahBookmark
                                    ? '${bookmark.juzName} - صفحة ${bookmark.page}'
                                    : '${bookmark.juzName} - صفحة ${bookmark.page}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatDate(bookmark.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.keyboard_arrow_left),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _jumpToPage(bookmark.page);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing bookmarks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('حدث خطأ: ${e.toString()}'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );

    if (result is ThemeMode && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Text('تم تغيير الثيم'),
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading Quran...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _currentPageNotifier,
      builder: (context, currentPage, _) {
        final pageInfo = _getInfoForPage(currentPage);
        return Scaffold(
          appBar: _buildAppBar(context, pageInfo.surahName, pageInfo.juzNumber),
          body: Stack(
            children: [
              // Main content with dynamic padding for media player + safe area
              ValueListenableBuilder<AyahMarker?>(
                valueListenable: _audioManager!.currentAyahNotifier,
                builder: (context, currentAyah, _) {
                  final hasMediaPlayer = currentAyah != null;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: bottomSafe + pageVerticalOffset + (hasMediaPlayer ? mediaPlayerHeight : 0),
                    ),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: totalPages,
                      reverse: true,
                      physics: const PageScrollPhysics().applyTo(
                        const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final pageNumber = index + 1;
                        final pageNumStr = pageNumber.toString().padLeft(3, '0');
                        final pageMarkers = _markersByPage[pageNumber] ?? [];
                        final pageInfo = _getInfoForPage(pageNumber);

                        return SvgPageViewer(
                          svgAssetPath: 'assets/pages/$pageNumStr.svg',
                          markers: pageMarkers,
                          currentPage: pageNumber,
                          surahName: pageInfo.surahName,
                          juzName: pageInfo.juzNumber,
                          currentlyPlayingAyah: _audioManager!.currentAyahNotifier,
                          onContinuousPlayRequested: _onContinuousPlayRequested,
                        );
                      },
                    ),
                  );
                },
              ),

              // Floating Media Player with safe-area aware positioning
              Positioned(
                bottom: bottomSafe + pageVerticalOffset,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _mediaPlayerAnimation,
                  builder: (context, child) {
                    if (_audioManager == null) return const SizedBox.shrink();

                    return ValueListenableBuilder<AyahMarker?>(
                      valueListenable: _audioManager!.currentAyahNotifier,
                      builder: (context, currentAyah, _) {
                        if (currentAyah == null) return const SizedBox.shrink();

                        return Transform.translate(
                          offset: Offset(0, (1 - _mediaPlayerAnimation.value) * 100),
                          child: Opacity(
                            opacity: _mediaPlayerAnimation.value,
                            child: FloatingMediaPlayer(
                              currentAyah: currentAyah,
                              isPlayingNotifier: _audioManager!.isPlayingNotifier,
                              isBufferingNotifier: _audioManager!.isBufferingNotifier,
                              currentReciterNotifier: _audioManager!.currentReciterNotifier,
                              playbackSpeedNotifier: _audioManager!.playbackSpeedNotifier,
                              positionNotifier: _audioManager!.positionNotifier,
                              durationNotifier: _audioManager!.durationNotifier,
                              onPlayPause: () => _audioManager!.togglePlayPause(),
                              onStop: () => _audioManager!.stop(),
                              onPrevious: () => _audioManager!.playPrevious(),
                              onNext: () => _audioManager!.playNext(),
                              onSpeedChange: () => _audioManager!.changeSpeed(),
                              onSeek: (position) => _audioManager!.seek(position),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: _buildPageNumberButton(currentPage),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, String surahName, String juzNumber) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      title: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            // 1. Hamburger menu button (leftmost)
            IconButton(
              onPressed: _openSettings,
              icon: const Icon(Icons.menu),
              tooltip: 'الإعدادات',
            ),

            // 2. Surah name - clickable and fits content
            InkWell(
              onTap: () => _showSurahSelectionDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  surahName.isNotEmpty ? surahName : 'الفاتحة',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),

            const Spacer(),

            // 3. Juz selector
            InkWell(
              onTap: () => _showJuzSelectionDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  juzNumber.isNotEmpty ? juzNumber : 'الجزء 1',
                  style: const TextStyle(fontSize: 14),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),

            // 4. Bookmark button (rightmost)
            GestureDetector(
              onTap: _toggleBookmarkSafe,
              onLongPress: _showBookmarksSafe,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: _isBookmarked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageNumberButton(int currentPage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SizedBox(
        width: 70,
        height: 40,
        child: Material(
          // Use a broadly supported color (surfaceVariant) instead of surfaceContainerHighest
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          elevation: 2.0,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _showJumpToPageDialog,
            child: Center(
              child: Text(
                currentPage.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSurahSelectionDialog(BuildContext context) async {
    if (!mounted) return;

    if (_allSurahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('البيانات لم يتم تحميلها بعد')),
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: AlertDialog(
          title: Text(
            "اختر السورة",
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: GestureDetector(
            onTap: () {},
            child: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: _allSurahs.length,
                itemBuilder: (context, index) {
                  final surah = _allSurahs[index];
                  return Directionality(
                    textDirection: TextDirection.rtl,
                    child: ListTile(
                      title: Text(
                        "${surah.number}. ${surah.nameArabic}",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        surah.nameEnglish,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _jumpToPage(surah.pageNumber);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                "إلغاء",
                style: TextStyle(color: Theme.of(dialogContext).colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showJuzSelectionDialog(BuildContext context) async {
    if (!mounted) return;

    if (_juzStartPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('البيانات لم يتم تحميلها بعد')),
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: AlertDialog(
          title: Text(
            "اختر الجزء",
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: GestureDetector(
            onTap: () {},
            child: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: 30,
                itemBuilder: (context, index) {
                  final juzNumber = index + 1;
                  return Directionality(
                    textDirection: TextDirection.rtl,
                    child: ListTile(
                      title: Text(
                        "الجزء $juzNumber",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        final page = _juzStartPages[juzNumber];
                        if (page != null) _jumpToPage(page);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                "إلغاء",
                style: TextStyle(color: Theme.of(dialogContext).colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJumpToPageDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: _JumpToPageDialog(
          onPageJump: _jumpToPage,
          maxPage: totalPages,
        ),
      ),
    );
  }
}

class _JumpToPageDialog extends StatefulWidget {
  final Function(int) onPageJump;
  final int maxPage;

  const _JumpToPageDialog({
    required this.onPageJump,
    required this.maxPage,
  });

  @override
  _JumpToPageDialogState createState() => _JumpToPageDialogState();
}

class _JumpToPageDialogState extends State<_JumpToPageDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndJump() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorText = 'يرجى إدخال رقم الصفحة';
      });
      return;
    }

    final pageNumber = int.tryParse(input);
    if (pageNumber == null) {
      setState(() {
        _errorText = 'يرجى إدخال رقم صحيح';
      });
      return;
    }

    if (pageNumber < 1 || pageNumber > widget.maxPage) {
      setState(() {
        _errorText = 'رقم الصفحة يجب أن يكون بين 1 و ${widget.maxPage}';
      });
      return;
    }

    Navigator.of(context).pop();
    widget.onPageJump(pageNumber);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: AlertDialog(
        title: Text(
          'الذهاب إلى صفحة',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
        ),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أدخل رقم الصفحة (1-${widget.maxPage}):',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                  hintText: 'رقم الصفحة',
                ),
                onChanged: (value) {
                  if (_errorText != null) {
                    setState(() {
                      _errorText = null;
                    });
                  }
                },
                onSubmitted: (value) => _validateAndJump(),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: _validateAndJump,
            child: const Text('اذهب'),
          ),
        ],
      ),
    );
  }
}
