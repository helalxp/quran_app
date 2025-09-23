// lib/viewer_screen.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'models/ayah_marker.dart';
import 'models/surah.dart';
import 'bookmark_manager.dart';
import 'settings_screen.dart';
import 'svg_page_viewer.dart';
import 'widgets/improved_media_player.dart';
import 'continuous_audio_manager.dart';
import 'memorization_manager.dart';
import 'constants/app_constants.dart';
import 'constants/juz_mappings.dart';
import 'constants/app_strings.dart';
import 'utils/animation_utils.dart';
import 'utils/haptic_utils.dart';
import 'widgets/loading_states.dart';
import 'widgets/jump_to_page_dialog.dart';
import 'managers/page_cache_manager.dart';
import 'services/analytics_service.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> with TickerProviderStateMixin {
  // Use constants from AppConstants
  static int get totalPages => AppConstants.totalPages;
  static double get pageVerticalOffset => AppConstants.pageVerticalOffset;

  PageController? _controller;
  ContinuousAudioManager? _audioManager;
  MemorizationManager? _memorizationManager;

  Map<int, List<AyahMarker>> _markersByPage = {};
  List<AyahMarker> _allMarkers = [];
  List<Surah> _allSurahs = [];
  Map<int, int> _juzStartPages = {};
  bool _isLoading = true;
  bool _isBookmarked = false;

  final ValueNotifier<int> _currentPageNotifier = ValueNotifier(1);
  Timer? _saveTimer;
  
  // Performance optimization: Cache expensive computations
  final Map<int, ({String surahName, String juzNumber})> _pageInfoCache = {};
  final PageCacheManager _pageCacheManager = PageCacheManager();
  
  // Memorization mode indicator
  final ValueNotifier<bool> _isMemorizationModeActive = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _initializeAudioManager();
    _initializeReader();

    // Log app opened event
    AnalyticsService.logAppOpened();

    // Delay wakelock until after the screen is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enableWakelock();
    });
  }


  void _initializeAudioManager() {
    _audioManager = ContinuousAudioManager();
    _audioManager!.initialize();
    _memorizationManager = MemorizationManager(_audioManager!);
    
    // Listen to memorization session changes
    _memorizationManager!.sessionNotifier.addListener(_updateMemorizationMode);
    
    // Note: Page controller registration moved to _loadLastPage() after controller is created
  }

  void _updateMemorizationMode() {
    _isMemorizationModeActive.value = _memorizationManager!.sessionNotifier.value != null;
  }

  void _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
      // Retry after a short delay if activity isn't ready
      Future.delayed(const Duration(seconds: 1), () {
        try {
          WakelockPlus.enable();
        } catch (e) {
          debugPrint('Failed to enable wakelock on retry: $e');
        }
      });
    }
  }

  void _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Failed to disable wakelock: $e');
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
    // Cancel timer first to prevent any pending saves
    _saveTimer?.cancel();
    _saveTimer = null;

    // Disable wakelock when leaving main screen
    _disableWakelock();

    // Dispose controller and notifiers
    _controller?.dispose();
    _controller = null;
    _currentPageNotifier.dispose();

    // Properly dispose audio manager and memorization manager
    _memorizationManager?.sessionNotifier.removeListener(_updateMemorizationMode);
    _memorizationManager?.dispose();
    _audioManager?.dispose();
    _audioManager = null;
    _isMemorizationModeActive.dispose();

    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _loadAllMarkers();

      final surahsJsonString = await rootBundle.loadString('assets/surah.json');
      final List<dynamic> surahsJsonList = json.decode(surahsJsonString);
      _allSurahs = surahsJsonList.map((json) => Surah.fromJson(json)).toList();

      if (kDebugMode) {
        debugPrint('Loaded ${_allSurahs.length} surahs and ${_allMarkers.length} markers');
      }

      // Use correct juz mappings instead of calculating from surahs
      _juzStartPages = Map<int, int>.from(JuzMappings.juzToPage);
    } catch (e) {
      debugPrint('Error loading data: $e');
      _markersByPage = {};
      _allSurahs = [];
      _juzStartPages = Map<int, int>.from(JuzMappings.juzToPage);
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
    _saveTimer = Timer(AppConstants.saveDebounceTimeout, () async {
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
        keepPage: true,  // Maintain page position
      );

      _controller!.addListener(_onPageChanged);
      
      // Register page controller for follow-the-ayah functionality after it's created
      if (_audioManager != null && mounted) {
        _audioManager!.registerPageController(_controller, (pageIndex) {
          if (mounted && _controller != null && _controller!.hasClients) {
            _jumpToPage(pageIndex + 1); // Convert to 1-based page numbering
          }
        }, mounted ? context : null);
        debugPrint('✅ Page controller registered for follow-ayah functionality');
      }
    } catch (e) {
      debugPrint('Error loading last page: $e');
      _currentPageNotifier.value = 1;
      _controller = PageController(initialPage: 0);
      
      // Register page controller for follow-ayah functionality after it's created (error case)
      if (_audioManager != null && mounted) {
        _audioManager!.registerPageController(_controller, (pageIndex) {
          if (mounted && _controller != null && _controller!.hasClients) {
            _jumpToPage(pageIndex + 1); // Convert to 1-based page numbering
          }
        }, mounted ? context : null);
        debugPrint('✅ Page controller registered for follow-ayah functionality (error fallback)');
      }
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
      // Add subtle haptic feedback for smooth page turns
      HapticUtils.lightImpact();

      _currentPageNotifier.value = newPage;
      _saveLastPageOptimized(newPage);
      _checkBookmarkStatus();

      // Log page viewed analytics
      final pageInfo = _getInfoForPage(newPage);
      AnalyticsService.logPageViewed(newPage, pageInfo.surahName);

      // Preload adjacent pages for smoother swiping - only when page actually changes
      _preloadAdjacentPages(newPage);

      // Performance: Clean up old cached pages to prevent memory leaks
      _pageCacheManager.cleanupCache(newPage);
    }
  }
  
  
  void _preloadAdjacentPages(int currentPage) {
    _pageCacheManager.preloadAdjacentPages(currentPage);

    // Still preload page info for UI display
    final pagesToPreload = [currentPage - 1, currentPage + 1];
    for (final pageNumber in pagesToPreload) {
      if (pageNumber > 0 && pageNumber <= totalPages) {
        _getInfoForPage(pageNumber);
      }
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
    // Check cache first for performance
    if (_pageInfoCache.containsKey(page)) {
      return _pageInfoCache[page]!;
    }
    
    if (_allSurahs.isEmpty) {
      final result = (surahName: '', juzNumber: '');
      _pageInfoCache[page] = result;
      return result;
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

      // Get the correct juz for the current page, not just the surah's starting juz
      final currentJuz = JuzMappings.getJuzForPage(page);
      final result = (surahName: surahName, juzNumber: "الجزء $currentJuz");
      
      // Cache the result for performance
      _pageInfoCache[page] = result;
      return result;
    } catch (e) {
      debugPrint('Error getting page info: $e');
      final result = (surahName: '', juzNumber: '');
      _pageInfoCache[page] = result;
      return result;
    }
  }

  void _jumpToPage(int page) {
    if (page < 1 || page > totalPages || _controller == null) return;

    HapticUtils.pageTurn(); // Haptic feedback for page navigation
    final int index = page - 1;
    
    // Use jumpToPage for instant navigation instead of slow animation
    _controller!.jumpToPage(index);
  }

  void _onContinuousPlayRequested(AyahMarker ayahMarker, String reciterName) async {
    try {
      // Stop memorization session if active
      if (_isMemorizationModeActive.value) {
        await _memorizationManager?.stopSession();
        _isMemorizationModeActive.value = false;
        debugPrint('🛑 Stopped memorization session to start normal recitation');
      }
      
      debugPrint('Starting continuous playbook for ayah ${ayahMarker.surah}:${ayahMarker.ayah} with $reciterName');

      final surahAyahs = _allMarkers.where((marker) => marker.surah == ayahMarker.surah).toList();

      debugPrint('Found ${surahAyahs.length} ayahs in surah ${ayahMarker.surah}');

      await _audioManager!.startContinuousPlayback(ayahMarker, reciterName, surahAyahs);

      // Removed annoying snackbar - user can control playback through media player controls
    } catch (e) {
      debugPrint('Error starting continuous playback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(ContinuousAudioManager.getUserFriendlyErrorMessage(e)),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }


  Future<void> _toggleBookmarkSafe() async {
    try {
      HapticUtils.bookmark(); // Haptic feedback for bookmark action
      final currentPage = _currentPageNotifier.value;
      final pageInfo = _getInfoForPage(currentPage);

      if (_isBookmarked) {
        await BookmarkManager.removeBookmark(currentPage);
        // Log bookmark removed analytics
        AnalyticsService.logBookmarkRemoved(pageInfo.surahName, currentPage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(AppStrings.bookmarkRemoved),
              ),
              duration: AppConstants.snackBarShortDuration,
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
        // Log bookmark added analytics
        AnalyticsService.logBookmarkAdded(pageInfo.surahName, currentPage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(AppStrings.bookmarkAdded),
              ),
              duration: AppConstants.snackBarShortDuration,
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
              child: Text(ContinuousAudioManager.getUserFriendlyErrorMessage(e)),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showBookmarksSafe() async {
    try {
      HapticUtils.longPress(); // Haptic feedback for long press action
      final bookmarks = await BookmarkManager.getBookmarks().timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (bookmarks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(AppStrings.bookmarkNoBookmarks),
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
        transitionAnimationController: AnimationController(
          duration: AnimationUtils.normal,
          vsync: this,
        ),
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
                          return AnimatedListItem(
                            index: index,
                            delay: const Duration(milliseconds: 40), // Faster for better UX
                            duration: AnimationUtils.fast,
                            child: Dismissible(
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
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              if (bookmark.isAyahBookmark) {
                                await BookmarkManager.removeAyahBookmark(
                                  bookmark.surahNumber!,
                                  bookmark.ayahNumber!,
                                );
                              } else {
                                await BookmarkManager.removeBookmark(bookmark.page);
                              }
                              _checkBookmarkStatus();

                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text(AppStrings.bookmarkDeleted),
                                  ),
                                  duration: AppConstants.snackBarLongDuration,
                                ),
                              );
                              }
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: bookmark.isAyahBookmark
                                    ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)
                                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
              child: Text(ContinuousAudioManager.getUserFriendlyErrorMessage(e)),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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

  // Navigate to settings with smooth animation
  void _openSettings() {
    HapticUtils.navigation(); // Haptic feedback for navigation
    Navigator.of(context).push(
      AnimatedRoute(
        builder: (context) => SettingsScreen(memorizationManager: _memorizationManager),
        transitionType: PageTransitionType.slideUp,
        transitionDuration: AnimationUtils.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false, // Keep background static
        body: LoadingStates.fullScreen(
          message: 'جاري تحميل المصحف...',
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _currentPageNotifier,
      builder: (context, currentPage, _) {
        final pageInfo = _getInfoForPage(currentPage);
        return Scaffold(
          appBar: _buildAppBar(context, pageInfo.surahName, pageInfo.juzNumber),
          resizeToAvoidBottomInset: false, // Keep background static
          body: Stack(
            children: [
              // Main content with safe area padding
              Padding(
                padding: EdgeInsets.only(
                  bottom: bottomSafe + pageVerticalOffset,
                ),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: totalPages,
                      reverse: true,
                      allowImplicitScrolling: true, // Pre-cache adjacent pages
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemBuilder: (context, index) {
                        final pageNumber = index + 1;

                        final pageNumStr = pageNumber.toString().padLeft(3, '0');
                        final pageMarkers = _markersByPage[pageNumber] ?? [];
                        final pageInfo = _getInfoForPage(pageNumber);

                        final pageWidget = SvgPageViewer(
                          key: ValueKey('page_$pageNumber'), // Add key for better widget recycling
                          svgAssetPath: 'assets/pages/$pageNumStr.svg',
                          markers: pageMarkers,
                          currentPage: pageNumber,
                          surahName: pageInfo.surahName,
                          juzName: pageInfo.juzNumber,
                          currentlyPlayingAyah: _audioManager!.currentAyahNotifier,
                          onContinuousPlayRequested: _onContinuousPlayRequested,
                          memorizationManager: _memorizationManager,
                        );
                        
                        // Widget caching now handled by PageCacheManager
                        
                        // Wrap in themed container to prevent white flash during loading
                        return Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: RepaintBoundary(
                            key: ValueKey('repaint_$pageNumber'),
                            child: pageWidget,
                          ),
                        );
                      },
                ),
              ),

              // Improved Media Player - collapsible with fixed button functions
              if (_audioManager != null)
                ValueListenableBuilder<AyahMarker?>(
                  valueListenable: _audioManager!.currentAyahNotifier,
                  builder: (context, currentAyah, _) {
                    return ImprovedMediaPlayer(
                      currentAyah: currentAyah,
                      isPlayingNotifier: _audioManager!.isPlayingNotifier,
                      isBufferingNotifier: _audioManager!.isBufferingNotifier,
                      currentReciterNotifier: _audioManager!.currentReciterNotifier,
                      playbackSpeedNotifier: _audioManager!.playbackSpeedNotifier,
                      positionNotifier: _audioManager!.positionNotifier,
                      durationNotifier: _audioManager!.durationNotifier,
                      onPlayPause: () => _audioManager!.togglePlayPause(),
                      onStop: () {
                        _audioManager!.stop();
                        if (_isMemorizationModeActive.value) {
                          _memorizationManager?.stopSession();
                          _isMemorizationModeActive.value = false;
                        }
                      },
                      onPrevious: () {
                        if (_isMemorizationModeActive.value) {
                          _memorizationManager?.skipToPrevious();
                        } else {
                          _audioManager!.playPrevious();
                        }
                      },
                      onNext: () {
                        if (_isMemorizationModeActive.value) {
                          _memorizationManager?.skipToNext();
                        } else {
                          _audioManager!.playNext();
                        }
                      },
                      onSpeedChange: () => _audioManager!.changeSpeed(),
                      onSeek: (position) => _audioManager!.seek(position),
                      isMemorizationModeNotifier: _memorizationManager != null 
                          ? _isMemorizationModeActive
                          : null,
                      onMemorizationPause: () => _memorizationManager?.pauseSession(),
                      onMemorizationResume: () => _memorizationManager?.resumeSession(),
                    );
                  },
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
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
          // Use surface container color for better compatibility
          color: Theme.of(context).colorScheme.surface,
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

  /// FIXED: Proper dismissible dialog with smooth animations
  Future<void> _showSurahSelectionDialog(BuildContext context) async {
    if (!mounted) return;

    HapticUtils.dialogOpen(); // Haptic feedback for dialog open

    if (_allSurahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.dataNotLoaded)),
      );
      return;
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: AnimationUtils.normal,
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return AnimationUtils.scaleTransition(
          animation: animation1,
          child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "اختر السورة",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _allSurahs.length,
            itemBuilder: (context, index) {
              final surah = _allSurahs[index];
              return AnimatedListItem(
                index: index,
                delay: const Duration(milliseconds: 15), // Much faster for dialogs
                duration: AnimationUtils.ultraFast,
                child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    "${surah.number}. ${surah.nameArabic}",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  subtitle: Text(
                    surah.nameEnglish,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  trailing: Text(
                    "ص ${surah.pageNumber}",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    HapticUtils.selection(); // Haptic feedback for selection
                    Navigator.of(context).pop();
                    _jumpToPage(surah.pageNumber);
                  },
                ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "إلغاء",
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
        ),
        );
      },
    );
  }

  /// FIXED: Proper dismissible Juz dialog with smooth animations
  Future<void> _showJuzSelectionDialog(BuildContext context) async {
    if (!mounted) return;

    HapticUtils.dialogOpen(); // Haptic feedback for dialog open

    if (_juzStartPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.dataNotLoaded)),
      );
      return;
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: AnimationUtils.normal,
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return AnimationUtils.scaleTransition(
          animation: animation1,
          child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "اختر الجزء",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: 30,
            itemBuilder: (context, index) {
              final juzNumber = index + 1;
              final pageNumber = _juzStartPages[juzNumber];
              
              return AnimatedListItem(
                index: index,
                delay: const Duration(milliseconds: 10), // Much faster for dialogs  
                duration: AnimationUtils.ultraFast,
                child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      '$juzNumber',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    "الجزء $juzNumber",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  trailing: pageNumber != null ? Text(
                    "ص $pageNumber",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ) : null,
                  onTap: () {
                    HapticUtils.selection(); // Haptic feedback for selection
                    Navigator.of(context).pop();
                    if (pageNumber != null) _jumpToPage(pageNumber);
                  },
                ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "إلغاء",
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
        ),
        );
      },
    );
  }

  void _showJumpToPageDialog() {
    HapticUtils.dialogOpen(); // Haptic feedback for dialog open
    showDialog<void>(
      context: context,
      builder: (context) => JumpToPageDialog(
        currentPage: _currentPageNotifier.value,
        totalPages: totalPages,
        onPageSelected: _jumpToPage,
      ),
    );
  }

}
