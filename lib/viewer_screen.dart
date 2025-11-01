// lib/viewer_screen.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/feature_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'models/ayah_marker.dart';
import 'models/surah.dart';
import 'bookmark_manager.dart';
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
import 'services/navigation_service.dart';
import 'services/khatma_manager.dart';
import 'universal_search_overlay.dart';

class ViewerScreen extends StatefulWidget {
  final int? initialPage;

  const ViewerScreen({super.key, this.initialPage});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen>
    with TickerProviderStateMixin {
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
  bool _isSearchActive = false;
  bool _isUIVisible = true;
  Timer? _uiHideTimer;
  late AnimationController _uiAnimationController;
  late Animation<Offset> _appBarSlideAnimation;
  late Animation<Offset> _fabSlideAnimation;

  final ValueNotifier<int> _currentPageNotifier = ValueNotifier(1);
  Timer? _saveTimer;

  // Performance optimization: Cache expensive computations
  final Map<int, ({String surahName, String juzNumber})> _pageInfoCache = {};
  final PageCacheManager _pageCacheManager = PageCacheManager();

  // Memorization mode indicator
  final ValueNotifier<bool> _isMemorizationModeActive = ValueNotifier(false);

  // Temporary ayah highlight (from search results)
  final ValueNotifier<AyahMarker?> _highlightedAyahFromSearch = ValueNotifier(
    null,
  );

  @override
  void initState() {
    super.initState();

    // Initialize UI animation controller
    _uiAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // App bar slides up when hiding
    _appBarSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(
      CurvedAnimation(parent: _uiAnimationController, curve: Curves.easeInOut),
    );

    // FAB slides down when hiding (extra offset to ensure full hide)
    _fabSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 2), // Slide down 2x height to fully hide
    ).animate(
      CurvedAnimation(parent: _uiAnimationController, curve: Curves.easeInOut),
    );

    _initializeAudioManager();
    _initializeReader();
    _initializeKhatmaTracking(); // Load khatmas for tracking

    // Log app opened event
    AnalyticsService.logAppOpened();

    // Delay wakelock until after the screen is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enableWakelock();
    });
  }

  // Load khatmas so tracking works even if user hasn't opened Khatma screen
  void _initializeKhatmaTracking() async {
    try {
      await KhatmaManager().loadKhatmas();
      debugPrint('✅ Khatmas loaded for tracking');
    } catch (e) {
      debugPrint('⚠️ Failed to load khatmas for tracking: $e');
    }
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
    _isMemorizationModeActive.value =
        _memorizationManager!.sessionNotifier.value != null;
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
      await Future.wait([_loadData(), _loadLastPage()]);
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
        // Start UI hide timer after loading
        _startUIHideTimer();
      }
    }
  }

  void _startUIHideTimer() {
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isSearchActive) {
        setState(() {
          _isUIVisible = false;
        });
        _uiAnimationController.forward(); // Animate out
      }
    });
  }

  void _resetUIVisibility() {
    if (!_isUIVisible) {
      setState(() {
        _isUIVisible = true;
      });
      _uiAnimationController.reverse(); // Animate in
    }
    _startUIHideTimer();
  }

  @override
  void dispose() {
    // Cancel timers first to prevent any pending operations
    _saveTimer?.cancel();
    _saveTimer = null;
    _uiHideTimer?.cancel();
    _uiHideTimer = null;

    // Dispose animation controller
    _uiAnimationController.dispose();

    // Disable wakelock when leaving main screen
    _disableWakelock();

    // Dispose controller and notifiers
    _controller?.dispose();
    _controller = null;
    _currentPageNotifier.dispose();

    // Properly dispose audio manager and memorization manager
    _memorizationManager?.sessionNotifier.removeListener(
      _updateMemorizationMode,
    );
    _memorizationManager?.dispose();
    _audioManager?.dispose();
    _audioManager = null;
    _isMemorizationModeActive.dispose();
    _highlightedAyahFromSearch.dispose();

    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _loadAllMarkers();

      final surahsJsonString = await rootBundle.loadString(
        'assets/data/surah.json',
      );
      final List<dynamic> surahsJsonList = json.decode(surahsJsonString);
      _allSurahs = surahsJsonList.map((json) => Surah.fromJson(json)).toList();

      if (kDebugMode) {
        debugPrint(
          'Loaded ${_allSurahs.length} surahs and ${_allMarkers.length} markers',
        );
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
      final markersJsonString = await rootBundle.loadString(
        'assets/data/markers.json',
      );
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
      // Use passed initialPage if available, otherwise load from SharedPreferences
      final int lastPage;
      if (widget.initialPage != null) {
        lastPage = widget.initialPage!;
      } else {
        final prefs = await SharedPreferences.getInstance();
        lastPage = prefs.getInt('last_page') ?? 1;
      }
      _currentPageNotifier.value = lastPage;

      final initialIndex = lastPage - 1;

      _controller = PageController(
        initialPage: initialIndex,
        viewportFraction: 1.0,
        keepPage: true, // Maintain page position
      );

      _controller!.addListener(_onPageChanged);

      // Register page controller for follow-the-ayah functionality after it's created
      if (_audioManager != null && mounted) {
        _audioManager!.registerPageController(_controller, (pageIndex) {
          if (mounted && _controller != null && _controller!.hasClients) {
            _jumpToPage(pageIndex + 1); // Convert to 1-based page numbering
          }
        }, mounted ? context : null);
        debugPrint(
          '✅ Page controller registered for follow-ayah functionality',
        );
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
        debugPrint(
          '✅ Page controller registered for follow-ayah functionality (error fallback)',
        );
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

      // Track page view for Khatma progress
      KhatmaManager().trackPageView(newPage);

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
    final isBookmarked = await BookmarkManager.isBookmarked(
      _currentPageNotifier.value,
    );
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
      final surahsOnPage =
          _allSurahs.where((s) => s.pageNumber == page).toList();
      Surah primarySurah = _allSurahs.lastWhere(
        (s) => s.pageNumber <= page,
        orElse: () => _allSurahs.first,
      );

      final surahName =
          surahsOnPage.isNotEmpty
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

  void _onContinuousPlayRequested(
    AyahMarker ayahMarker,
    String reciterName,
  ) async {
    try {
      // Atomically stop memorization session if active
      if (_isMemorizationModeActive.value) {
        final wasActive = _isMemorizationModeActive.value;
        _isMemorizationModeActive.value = false; // Update UI immediately

        await _memorizationManager?.stopSession();

        if (kDebugMode && wasActive) {
          debugPrint(
            '🛑 Stopped memorization session to start normal recitation',
          );
        }
      }

      debugPrint(
        'Starting continuous playbook for ayah ${ayahMarker.surah}:${ayahMarker.ayah} with $reciterName',
      );

      final surahAyahs =
          _allMarkers
              .where((marker) => marker.surah == ayahMarker.surah)
              .toList();

      debugPrint(
        'Found ${surahAyahs.length} ayahs in surah ${ayahMarker.surah}',
      );

      // Pass all markers for continue-to-next-surah feature
      await _audioManager!.startContinuousPlayback(
        ayahMarker,
        reciterName,
        surahAyahs,
        allAyahMarkers: _allMarkers,
      );

      // Removed annoying snackbar - user can control playback through media player controls
    } catch (e) {
      debugPrint('Error starting continuous playback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                ContinuousAudioManager.getUserFriendlyErrorMessage(e),
              ),
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
              child: Text(
                ContinuousAudioManager.getUserFriendlyErrorMessage(e),
              ),
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
      final bookmarks = await BookmarkManager.getBookmarks().timeout(
        const Duration(seconds: 10),
      );

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
        builder:
            (context) => GestureDetector(
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
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
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
                                delay: const Duration(
                                  milliseconds: 40,
                                ), // Faster for better UX
                                duration: AnimationUtils.fast,
                                child: Dismissible(
                                  key: Key(
                                    'bookmark_${bookmark.page}_${bookmark.createdAt}',
                                  ),
                                  background: Container(
                                    color: Theme.of(context).colorScheme.error,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Icon(
                                      Icons.delete,
                                      color:
                                          Theme.of(context).colorScheme.onError,
                                    ),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (direction) async {
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    if (bookmark.isAyahBookmark) {
                                      await BookmarkManager.removeAyahBookmark(
                                        bookmark.surahNumber!,
                                        bookmark.ayahNumber!,
                                      );
                                    } else {
                                      await BookmarkManager.removeBookmark(
                                        bookmark.page,
                                      );
                                    }
                                    _checkBookmarkStatus();

                                    if (mounted) {
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: Text(
                                              AppStrings.bookmarkDeleted,
                                            ),
                                          ),
                                          duration:
                                              AppConstants.snackBarLongDuration,
                                        ),
                                      );
                                    }
                                  },
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          bookmark.isAyahBookmark
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .secondary
                                                  .withValues(alpha: 0.1)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.1),
                                      child: Icon(
                                        bookmark.isAyahBookmark
                                            ? Icons.format_quote
                                            : Icons.bookmark,
                                        color:
                                            bookmark.isAyahBookmark
                                                ? Theme.of(
                                                  context,
                                                ).colorScheme.secondary
                                                : Theme.of(
                                                  context,
                                                ).colorScheme.primary,
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
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
              child: Text(
                ContinuousAudioManager.getUserFriendlyErrorMessage(e),
              ),
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
  void _openSelectionScreen() async {
    HapticUtils.navigation(); // Haptic feedback for navigation

    // Save current screen and page before navigating
    await NavigationService.saveLastScreen(
      NavigationService.routeViewer,
      pageNumber: _currentPageNotifier.value,
    );

    if (!mounted) return;

    Navigator.of(context).push(
      AnimatedRoute(
        builder:
            (context) => FeatureSelectionScreen(
              memorizationManager: _memorizationManager,
            ),
        transitionType: PageTransitionType.slideLeftToRight,
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
        body: LoadingStates.fullScreen(message: 'جاري تحميل المصحف...'),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _currentPageNotifier,
      builder: (context, currentPage, _) {
        final pageInfo = _getInfoForPage(currentPage);
        return Scaffold(
          appBar:
              _isSearchActive
                  ? null
                  : PreferredSize(
                    preferredSize: const Size.fromHeight(kToolbarHeight),
                    child: SlideTransition(
                      position: _appBarSlideAnimation,
                      child: _buildAppBar(
                        context,
                        pageInfo.surahName,
                        pageInfo.juzNumber,
                      ),
                    ),
                  ),
          resizeToAvoidBottomInset: false, // Keep background static
          body: GestureDetector(
            onTap: _resetUIVisibility,
            behavior: HitTestBehavior.translucent,
            child: Stack(
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
                        key: ValueKey(
                          'page_$pageNumber',
                        ), // Add key for better widget recycling
                        svgAssetPath: 'assets/pages/$pageNumStr.svg',
                        markers: pageMarkers,
                        currentPage: pageNumber,
                        surahName: pageInfo.surahName,
                        juzName: pageInfo.juzNumber,
                        currentlyPlayingAyah:
                            _audioManager!.currentAyahNotifier,
                        highlightedAyahFromSearch: _highlightedAyahFromSearch,
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

                // Improved Media Player - collapsible
                if (_audioManager != null)
                  ValueListenableBuilder<AyahMarker?>(
                    valueListenable: _audioManager!.currentAyahNotifier,
                    builder: (context, currentAyah, _) {
                      return ImprovedMediaPlayer(
                        currentAyah: currentAyah,
                        isPlayingNotifier: _audioManager!.isPlayingNotifier,
                        isBufferingNotifier: _audioManager!.isBufferingNotifier,
                        currentReciterNotifier:
                            _audioManager!.currentReciterNotifier,
                        playbackSpeedNotifier:
                            _audioManager!.playbackSpeedNotifier,
                        positionNotifier: _audioManager!.positionNotifier,
                        durationNotifier: _audioManager!.durationNotifier,
                        onPlayPause: () {
                          if (_isMemorizationModeActive.value) {
                            // In memorization mode, pause/resume the session
                            if (_audioManager!.isPlayingNotifier.value) {
                              _memorizationManager?.pauseSession();
                            } else {
                              _memorizationManager?.resumeSession();
                            }
                          } else {
                            // Normal playback
                            _audioManager!.togglePlayPause();
                          }
                        },
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
                        isMemorizationModeNotifier:
                            _memorizationManager != null
                                ? _isMemorizationModeActive
                                : null,
                        onMemorizationPause:
                            () => _memorizationManager?.pauseSession(),
                        onMemorizationResume:
                            () => _memorizationManager?.resumeSession(),
                        isPlaylistListeningModeNotifier:
                            _audioManager!.isPlaylistListeningModeNotifier,
                      );
                    },
                  ),

                // Search overlay (positioned at top)
                if (_isSearchActive)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildSearchOverlay(context, currentPage),
                  ),
              ],
            ),
          ),
          floatingActionButton: SlideTransition(
            position: _fabSlideAnimation,
            child: _buildFloatingButtons(currentPage),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    String surahName,
    String juzNumber,
  ) {
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
              onPressed: () {
                _openSelectionScreen();
              },
              icon: const Icon(Icons.menu),
              tooltip: 'المميزات',
            ),

            // 2. Surah name - clickable and fits content
            InkWell(
              onTap: () => _showSurahSelectionDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
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
                  color:
                      _isBookmarked
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

  Widget _buildFloatingButtons(int currentPage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Search button (circular, smaller, on the left)
          SizedBox(
            width: 40,
            height: 40,
            child: FloatingActionButton(
              heroTag: 'search_fab',
              mini: true,
              onPressed: () {
                setState(() {
                  _isSearchActive = !_isSearchActive;
                  if (_isSearchActive) {
                    _isUIVisible = true;
                    _uiHideTimer?.cancel();
                  } else {
                    _startUIHideTimer();
                  }
                });
                HapticUtils.selection();
              },
              backgroundColor:
                  _isSearchActive
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
              elevation: 2.0,
              child: Icon(
                _isSearchActive ? Icons.close : Icons.search,
                color:
                    _isSearchActive
                        ? Theme.of(context).colorScheme.onError
                        : Theme.of(context).colorScheme.onPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Page number button (rectangular, on the right)
          SizedBox(
            width: 70,
            height: 40,
            child: Material(
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
        ],
      ),
    );
  }

  Widget _buildSearchOverlay(BuildContext context, int currentPage) {
    return UniversalSearchOverlay(
      allSurahs: _allSurahs,
      allMarkers: _allMarkers,
      juzStartPages: _juzStartPages,
      currentPage: currentPage,
      onSurahSelected: (surah) {
        setState(() {
          _isSearchActive = false;
        });
        HapticUtils.selection();
        AnalyticsService.logSurahOpened(surah.nameArabic, surah.number);
        _jumpToPage(surah.pageNumber);
      },
      onJuzSelected: (pageNumber) {
        setState(() {
          _isSearchActive = false;
        });
        HapticUtils.selection();
        _jumpToPage(pageNumber);
      },
      onAyahSelected: (surah, ayahNumber, pageNumber) {
        setState(() {
          _isSearchActive = false;
        });
        HapticUtils.selection();
        AnalyticsService.logSurahOpened(surah.nameArabic, surah.number);
        _jumpToPage(pageNumber);

        // Find the marker for highlighting
        final marker = _allMarkers.firstWhere(
          (m) => m.surah == surah.number && m.ayah == ayahNumber,
          orElse: () => _allMarkers.first,
        );

        // Trigger highlight after navigation
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _highlightedAyahFromSearch.value = marker;
            // Clear highlight after 2 seconds
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                _highlightedAyahFromSearch.value = null;
              }
            });
          }
        });
      },
    );
  }

  /// FIXED: Proper dismissible dialog with smooth animations
  Future<void> _showSurahSelectionDialog(BuildContext context) async {
    if (!mounted) return;

    HapticUtils.dialogOpen(); // Haptic feedback for dialog open

    if (_allSurahs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.dataNotLoaded)));
      return;
    }

    // Find current surah index based on current page
    final currentPage = _currentPageNotifier.value;
    int currentSurahIndex = 0;
    for (int i = 0; i < _allSurahs.length; i++) {
      if (_allSurahs[i].pageNumber <= currentPage) {
        currentSurahIndex = i;
      } else {
        break;
      }
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
          child: _SurahSearchDialog(
            allSurahs: _allSurahs,
            currentSurahIndex: currentSurahIndex,
            onSurahSelected: (surah) {
              HapticUtils.selection();
              AnalyticsService.logSurahOpened(surah.nameArabic, surah.number);
              Navigator.of(context).pop();
              _jumpToPage(surah.pageNumber);
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  /// Proper dismissible Juz dialog with smooth animations and search
  Future<void> _showJuzSelectionDialog(BuildContext context) async {
    if (!mounted) return;

    HapticUtils.dialogOpen(); // Haptic feedback for dialog open

    if (_juzStartPages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.dataNotLoaded)));
      return;
    }

    // Find current juz based on current page
    final currentPage = _currentPageNotifier.value;
    final currentJuz = JuzMappings.getJuzForPage(currentPage);

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
          child: _JuzSearchDialog(
            juzStartPages: _juzStartPages,
            currentJuz: currentJuz,
            onJuzSelected: (pageNumber) {
              HapticUtils.selection();
              Navigator.of(context).pop();
              _jumpToPage(pageNumber);
            },
            onCancel: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  void _showJumpToPageDialog() {
    HapticUtils.dialogOpen(); // Haptic feedback for dialog open
    showDialog<void>(
      context: context,
      builder:
          (context) => JumpToPageDialog(
            currentPage: _currentPageNotifier.value,
            totalPages: totalPages,
            onPageSelected: _jumpToPage,
          ),
    );
  }
}

class _SurahSearchDialog extends StatefulWidget {
  final List<Surah> allSurahs;
  final int currentSurahIndex;
  final Function(Surah) onSurahSelected;
  final VoidCallback onCancel;

  const _SurahSearchDialog({
    required this.allSurahs,
    required this.currentSurahIndex,
    required this.onSurahSelected,
    required this.onCancel,
  });

  @override
  State<_SurahSearchDialog> createState() => _SurahSearchDialogState();
}

class _SurahSearchDialogState extends State<_SurahSearchDialog> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Scroll to center the current surah after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollToCurrent();
      }
    });
  }

  void _scrollToCurrent() {
    // Each item height: Card margin (8) + ListTile height (~72)
    const double itemHeight = 80.0;
    const double viewportHeight = 400.0; // Content height

    // Calculate position to center the current item
    final double targetPosition =
        (widget.currentSurahIndex * itemHeight) -
        (viewportHeight / 2) +
        (itemHeight / 2);

    // Clamp to valid scroll range
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double scrollPosition = targetPosition.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      scrollPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "السور",
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
          controller: _scrollController,
          itemCount: widget.allSurahs.length,
          itemBuilder: (context, index) {
            final surah = widget.allSurahs[index];
            final isCurrent = index == widget.currentSurahIndex;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: isCurrent ? 4 : 1,
              color:
                  isCurrent
                      ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : null,
              child: ListTile(
                title: Text(
                  "${surah.number}. ${surah.nameArabic}",
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                subtitle: Text(surah.nameEnglish),
                trailing: Text(
                  "ص ${surah.pageNumber}",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                onTap: () => widget.onSurahSelected(surah),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            "إلغاء",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _JuzSearchDialog extends StatefulWidget {
  final Map<int, int> juzStartPages;
  final int currentJuz;
  final Function(int) onJuzSelected;
  final VoidCallback onCancel;

  const _JuzSearchDialog({
    required this.juzStartPages,
    required this.currentJuz,
    required this.onJuzSelected,
    required this.onCancel,
  });

  @override
  State<_JuzSearchDialog> createState() => _JuzSearchDialogState();
}

class _JuzSearchDialogState extends State<_JuzSearchDialog> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Scroll to center the current juz after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollToCurrent();
      }
    });
  }

  void _scrollToCurrent() {
    // Each item height: Card margin (8) + ListTile with padding height (~88)
    const double itemHeight = 96.0;
    const double viewportHeight = 400.0; // Content height

    // Current juz index (juz numbers are 1-30, indices are 0-29)
    final int currentIndex = widget.currentJuz - 1;

    // Calculate position to center the current item
    final double targetPosition =
        (currentIndex * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);

    // Clamp to valid scroll range
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double scrollPosition = targetPosition.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      scrollPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create list of all juz
    final allJuzData = List.generate(30, (index) {
      final juzNumber = index + 1;
      return {
        'number': juzNumber,
        'name': JuzMappings.getJuzName(juzNumber),
        'page': widget.juzStartPages[juzNumber],
      };
    });

    final primaryContainer = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryContainer = Theme.of(context).colorScheme.onPrimaryContainer;
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "الأجزاء",
        style: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: allJuzData.length,
          itemBuilder: (context, index) {
            final juz = allJuzData[index];
            final juzNumber = juz['number'] as int;
            final juzName = juz['name'] as String;
            final pageNumber = juz['page'] as int?;
            final isCurrent = juzNumber == widget.currentJuz;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: isCurrent ? 4 : 1,
              color: isCurrent ? primaryContainer.withValues(alpha: 0.3) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side:
                    isCurrent
                        ? BorderSide(color: primary, width: 2)
                        : BorderSide.none,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: isCurrent ? primary : primaryContainer,
                  child:
                      isCurrent
                          ? Icon(Icons.bookmark, color: onPrimary, size: 20)
                          : Text(
                            '$juzNumber',
                            style: TextStyle(
                              color: onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
                title: Text(
                  "الجزء $juzNumber",
                  style: TextStyle(
                    color: isCurrent ? onPrimaryContainer : onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                subtitle: Text(
                  juzName,
                  style: TextStyle(
                    color: (isCurrent ? onPrimaryContainer : onSurface)
                        .withValues(alpha: 0.7),
                    fontSize: 14,
                    fontFamily: 'Uthmanic',
                  ),
                  textDirection: TextDirection.rtl,
                ),
                trailing:
                    pageNumber != null
                        ? Text(
                          "ص $pageNumber",
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                        : null,
                onTap: () {
                  if (pageNumber != null) {
                    widget.onJuzSelected(pageNumber);
                  }
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text("إلغاء", style: TextStyle(color: primary)),
        ),
      ],
    );
  }
}
