// lib/ayah_actions_sheet.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models/ayah_marker.dart';
import 'constants/surah_names.dart';
import 'constants/app_strings.dart';
import 'constants/app_constants.dart';
import 'constants/api_constants.dart';
import 'bookmark_manager.dart';
import 'memorization_manager.dart';
import 'widgets/loading_states.dart';
import 'utils/input_sanitizer.dart';

class AyahActionsSheet extends StatefulWidget {
  final AyahMarker ayahMarker;
  final String surahName;
  final String juzName;
  final int currentPage;
  final Function(AyahMarker, String) onContinuousPlayRequested;
  final MemorizationManager? memorizationManager;

  const AyahActionsSheet({
    super.key,
    required this.ayahMarker,
    required this.surahName,
    required this.juzName,
    required this.currentPage,
    required this.onContinuousPlayRequested,
    this.memorizationManager,
  });

  @override
  State<AyahActionsSheet> createState() => _AyahActionsSheetState();
}

class _AyahActionsSheetState extends State<AyahActionsSheet> with TickerProviderStateMixin {
  bool _isBookmarked = false;
  bool _isLoadingTafsir = false;
  bool _isLoadingAyahText = false;
  String? _tafsirText;
  String? _ayahText;
  String? _error;
  String? _tafsirSource;
  String _defaultReciter = 'عبد الباسط عبد الصمد';
  String _defaultTafsir = 'تفسير ابن كثير';

  // Enhanced cache with expiration
  static final Map<String, CacheEntry> _ayahTextCache = {};
  static final Map<String, CacheEntry> _tafsirCache = {};

  @override
  void initState() {
    super.initState();
    _checkBookmarkStatus();
    _loadAyahText();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _defaultReciter = prefs.getString('selected_reciter') ?? 'عبد الباسط عبد الصمد';
        _defaultTafsir = prefs.getString('default_tafsir') ?? 'تفسير ابن كثير';
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _checkBookmarkStatus() async {
    final isBookmarked = await BookmarkManager.isAyahBookmarked(
      widget.ayahMarker.surah,
      widget.ayahMarker.ayah,
    );
    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
      });
    }
  }

  // ENHANCED: Improved Ayah text loading with better error handling and multiple fallbacks
  Future<void> _loadAyahText() async {
    final cacheKey = '${widget.ayahMarker.surah}:${widget.ayahMarker.ayah}';

    // Check cache first (with expiration)
    if (_ayahTextCache.containsKey(cacheKey)) {
      final cacheEntry = _ayahTextCache[cacheKey]!;
      if (!cacheEntry.isExpired) {
        if (mounted) {
          setState(() {
            _ayahText = cacheEntry.data;
            _isLoadingAyahText = false;
          });
        }
        return;
      } else {
        _ayahTextCache.remove(cacheKey);
      }
    }

    setState(() {
      _isLoadingAyahText = true;
      _error = null;
    });

    // Enhanced API endpoints with better reliability
    final apiStrategies = [
      // Strategy 1: AlQuran.cloud (most reliable)
          () async {
        final response = await http.get(
          Uri.parse(ApiConstants.getAyahTranslation(widget.ayahMarker.surah, widget.ayahMarker.ayah, 'ar.asad')),
          headers: {'Accept': 'application/json', 'User-Agent': 'QuranApp/1.0'},
        ).timeout(AppConstants.apiTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['data']['text'] as String?;
        }
        return null;
      },

      // Strategy 2: Alternative AlQuran endpoint
          () async {
        final response = await http.get(
          Uri.parse(ApiConstants.getAyahSimple(widget.ayahMarker.surah, widget.ayahMarker.ayah)),
          headers: {'Accept': 'application/json'},
        ).timeout(AppConstants.apiTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['data']['text'] as String?;
        }
        return null;
      },

      // Strategy 3: Quran.com API
          () async {
        final response = await http.get(
          Uri.parse(ApiConstants.getVerseUthmani(widget.ayahMarker.surah, widget.ayahMarker.ayah)),
          headers: {'Accept': 'application/json'},
        ).timeout(AppConstants.apiTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['verse']['text_uthmani'] as String?;
        }
        return null;
      },

      // Strategy 4: Static fallback data
          () async {
        return _getStaticAyahText(widget.ayahMarker.surah, widget.ayahMarker.ayah);
      },
    ];

    String? result;
    String lastError = '';

    for (int i = 0; i < apiStrategies.length && result == null; i++) {
      try {
        debugPrint('Trying Ayah API strategy ${i + 1}');
        result = await apiStrategies[i]();
        if (result != null && result.trim().isNotEmpty) {
          debugPrint('Ayah API strategy ${i + 1} succeeded');
          break;
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('Ayah API strategy ${i + 1} failed: $e');
        continue;
      }
    }

    if (mounted) {
      setState(() {
        if (result != null && result.trim().isNotEmpty) {
          _ayahText = result.trim();
          _ayahTextCache[cacheKey] = CacheEntry(result.trim(), DateTime.now());
          _error = null;
        } else {
          _error = 'فشل في تحميل نص الآية - يرجى المحاولة مرة أخرى';
          debugPrint('All Ayah API strategies failed. Last error: $lastError');
        }
        _isLoadingAyahText = false;
      });
    }
  }

  // ENHANCED: Improved Tafsir loading with configurable source
  Future<void> _loadTafsir() async {
    if (_isLoadingTafsir) return;

    final cacheKey = 'tafsir_${_defaultTafsir}_${widget.ayahMarker.surah}:${widget.ayahMarker.ayah}';

    // Check cache first
    if (_tafsirCache.containsKey(cacheKey)) {
      final cacheEntry = _tafsirCache[cacheKey]!;
      if (!cacheEntry.isExpired) {
        if (mounted) {
          setState(() {
            _tafsirText = cacheEntry.data;
            _tafsirSource = cacheEntry.source;
            _isLoadingTafsir = false;
          });
        }
        return;
      } else {
        _tafsirCache.remove(cacheKey);
      }
    }

    setState(() {
      _isLoadingTafsir = true;
      _error = null;
    });

    // Get tafsir based on default setting
    final tafsirStrategies = _getTafsirStrategies();
    final selectedStrategy = tafsirStrategies.firstWhere(
          (strategy) => strategy.name == _defaultTafsir,
      orElse: () => tafsirStrategies.first,
    );

    String? tafsirResult;
    String lastError = '';

    try {
      debugPrint('Loading tafsir: ${selectedStrategy.name}');
      tafsirResult = await selectedStrategy.apiCall();
      if (tafsirResult != null && tafsirResult.trim().isNotEmpty) {
        debugPrint('Tafsir loaded successfully: ${selectedStrategy.name}');
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint('Tafsir loading failed: $e');

      // Try fallback strategies
      for (var strategy in tafsirStrategies) {
        if (strategy.name != selectedStrategy.name) {
          try {
            tafsirResult = await strategy.apiCall();
            if (tafsirResult != null && tafsirResult.trim().isNotEmpty) {
              _defaultTafsir = strategy.name; // Update to working tafsir
              break;
            }
          } catch (e) {
            continue;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        if (tafsirResult != null && tafsirResult.trim().isNotEmpty) {
          _tafsirText = _cleanTafsirText(tafsirResult.trim());
          _tafsirSource = _defaultTafsir;
          _tafsirCache[cacheKey] = CacheEntry(_tafsirText!, DateTime.now(), source: _defaultTafsir);
        } else {
          _tafsirText = 'عذراً، لا يمكن تحميل التفسير في الوقت الحالي. يرجى المحاولة مرة أخرى.';
          _tafsirSource = null;
          debugPrint('All Tafsir strategies failed. Last error: $lastError');
        }
        _isLoadingTafsir = false;
      });
    }
  }

  List<TafsirStrategy> _getTafsirStrategies() {
    return [
      // Strategy 1: Tafsir Ibn Kathir (most comprehensive)
      TafsirStrategy(
        name: 'تفسير ابن كثير',
        apiCall: () async {
          try {
            final url = ApiConstants.getVerseTranslation(widget.ayahMarker.surah, widget.ayahMarker.ayah, 4);
            if (kDebugMode) print('Ibn Kathir URL: $url');
            final response = await http.get(
              Uri.parse(url),
              headers: {'Accept': 'application/json'},
            ).timeout(AppConstants.tafsirTimeout);

            if (kDebugMode) print('Ibn Kathir Response status: ${response.statusCode}');
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              if (kDebugMode) print('Ibn Kathir Response data: $data');
              return data['text'] as String?;
            } else {
              if (kDebugMode) print('Ibn Kathir Response error: ${response.body}');
            }
          } catch (e) {
            if (kDebugMode) print('Ibn Kathir Exception: $e');
          }
          return null;
        },
      ),

      // Strategy 2: Tafsir Jalalayn (concise)
      TafsirStrategy(
        name: 'تفسير الجلالين',
        apiCall: () async {
          final response = await http.get(
            Uri.parse(ApiConstants.getAyahTranslation(widget.ayahMarker.surah, widget.ayahMarker.ayah, 'ar.jalalayn')),
            headers: {'Accept': 'application/json'},
          ).timeout(AppConstants.tafsirTimeout);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            return data['data']['text'] as String?;
          }
          return null;
        },
      ),

      // Strategy 3: Tafsir Muyassar (simplified)
      TafsirStrategy(
        name: 'التفسير الميسر',
        apiCall: () async {
          final response = await http.get(
            Uri.parse(ApiConstants.getAyahTranslation(widget.ayahMarker.surah, widget.ayahMarker.ayah, 'ar.muyassar')),
            headers: {'Accept': 'application/json'},
          ).timeout(AppConstants.tafsirTimeout);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            return data['data']['text'] as String?;
          }
          return null;
        },
      ),

      // Strategy 4: Tafsir As-Sa'di
      TafsirStrategy(
        name: 'تفسير السعدي',
        apiCall: () async {
          try {
            final url = ApiConstants.getVerseTranslation(widget.ayahMarker.surah, widget.ayahMarker.ayah, ApiConstants.translationIds['تفسير السعدي']!);
            if (kDebugMode) print('As-Sa\'di URL: $url');
            final response = await http.get(
              Uri.parse(url),
              headers: {'Accept': 'application/json'},
            ).timeout(AppConstants.tafsirTimeout);

            if (kDebugMode) print('As-Sa\'di Response status: ${response.statusCode}');
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              if (kDebugMode) print('As-Sa\'di Response data: $data');
              return data['text'] as String?;
            } else {
              if (kDebugMode) print('As-Sa\'di Response error: ${response.body}');
            }
          } catch (e) {
            if (kDebugMode) print('As-Sa\'di Exception: $e');
          }
          return null;
        },
      ),

      // Strategy 5: Tafsir Al-Tabari
      TafsirStrategy(
        name: 'تفسير الطبري',
        apiCall: () async {
          try {
            final url = ApiConstants.getVerseTranslation(widget.ayahMarker.surah, widget.ayahMarker.ayah, 8);
            if (kDebugMode) print('Al-Tabari URL: $url');
            final response = await http.get(
              Uri.parse(url),
              headers: {'Accept': 'application/json'},
            ).timeout(AppConstants.tafsirTimeout);

            if (kDebugMode) print('Al-Tabari Response status: ${response.statusCode}');
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              if (kDebugMode) print('Al-Tabari Response data: $data');
              return data['text'] as String?;
            } else {
              if (kDebugMode) print('Al-Tabari Response error: ${response.body}');
            }
          } catch (e) {
            if (kDebugMode) print('Al-Tabari Exception: $e');
          }
          return null;
        },
      ),

      // Strategy 6: Tafsir Al-Qurtubi
      TafsirStrategy(
        name: 'تفسير القرطبي',
        apiCall: () async {
          final response = await http.get(
            Uri.parse(ApiConstants.getAyahTranslation(widget.ayahMarker.surah, widget.ayahMarker.ayah, 'ar.qurtubi')),
            headers: {'Accept': 'application/json'},
          ).timeout(AppConstants.tafsirTimeout);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            return data['data']['text'] as String?;
          }
          return null;
        },
      ),
    ];
  }

  // Clean tafsir text from HTML tags and extra formatting
  String _cleanTafsirText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  // Static fallback for common ayahs
  String? _getStaticAyahText(int surah, int ayah) {
    final staticData = {
      '1:1': 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      '1:2': 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
      '1:3': 'الرَّحْمَٰنِ الرَّحِيمِ',
      '1:4': 'مَالِكِ يَوْمِ الدِّينِ',
      '1:5': 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
      '1:6': 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
      '1:7': 'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
      '2:255': 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ...',
    };

    return staticData['$surah:$ayah'];
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await BookmarkManager.removeAyahBookmark(
        widget.ayahMarker.surah,
        widget.ayahMarker.ayah,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('تم إزالة إشارة الآية المرجعية'),
            ),
            duration: AppConstants.snackBarShortDuration,
          ),
        );
      }
    } else {
      final bookmark = Bookmark(
        page: widget.currentPage,
        surahName: widget.surahName,
        juzName: widget.juzName,
        createdAt: DateTime.now(),
        surahNumber: widget.ayahMarker.surah,
        ayahNumber: widget.ayahMarker.ayah,
        type: BookmarkType.ayah,
      );
      await BookmarkManager.addBookmark(bookmark);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('تم إضافة إشارة الآية المرجعية'),
            ),
            duration: AppConstants.snackBarShortDuration,
          ),
        );
      }
    }
    await _checkBookmarkStatus();
  }

  // SIMPLIFIED: Single play button that starts continuous playback
  void _playAyah() {
    Navigator.of(context).pop(); // Close the sheet
    widget.onContinuousPlayRequested(widget.ayahMarker, _defaultReciter);
  }

  // Start memorization session for this ayah
  void _startMemorization() {
    final manager = widget.memorizationManager;
    if (manager == null) {
      _showError('Memorization manager not available');
      return;
    }

    final currentMode = manager.settings.mode;
    
    Navigator.of(context).pop(); // Close the sheet
    
    // Check memorization mode and act accordingly
    switch (currentMode) {
      case MemorizationMode.singleAyah:
        // Start single ayah memorization
        manager.startSingleAyahMemorization(
          ayah: widget.ayahMarker,
          reciterName: _defaultReciter,
        );
        _showMemorizationFeedback('بدء جلسة التحفيظ للآية ${widget.ayahMarker.ayah}');
        break;

      case MemorizationMode.ayahRange:
        // Show range selection dialog
        _showAyahRangeDialog();
        break;

      case MemorizationMode.fullSurah:
        // Start full surah memorization - create markers for all ayahs in the surah
        final ayahCount = SurahNames.getAyahCount(widget.ayahMarker.surah);
        final List<AyahMarker> surahAyahs = [];
        for (int ayahNum = 1; ayahNum <= ayahCount; ayahNum++) {
          surahAyahs.add(AyahMarker(
            surah: widget.ayahMarker.surah,
            ayah: ayahNum,
            page: widget.ayahMarker.page,
            bboxes: [],
          ));
        }
        manager.startRangeMemorization(
          ayahs: surahAyahs,
          reciterName: _defaultReciter,
        );
        _showMemorizationFeedback('بدء جلسة التحفيظ للسورة كاملة ($ayahCount آية)');
        break;
    }
  }

  void _showMemorizationFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(message),
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: AppConstants.snackBarLongDuration,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(message),
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: AppConstants.snackBarShortDuration,
      ),
    );
  }

  void _showAyahRangeDialog() {
    showDialog(
      context: context,
      builder: (context) => _AyahRangeDialog(
        startAyah: widget.ayahMarker,
        surahName: widget.surahName,
        memorizationManager: widget.memorizationManager!,
        defaultReciter: _defaultReciter,
      ),
    );
  }

  String _getMemorizationSubtitle() {
    if (widget.memorizationManager == null) return 'تكرار 3 مرات افتراضياً';
    
    final settings = widget.memorizationManager!.settings;
    final count = settings.repetitionCount;
    final times = count == 1 ? 'مرة' : 'مرات';
    
    return 'تكرار $count $times';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: AppConstants.actionSheetHandleWidth,
                    height: AppConstants.actionSheetHandleHeight,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(AppConstants.actionSheetHandleBorderRadius),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppConstants.actionSheetSpacing),
                        Expanded(
                          child: Text(
                            'سورة ${_getSurahName(widget.ayahMarker.surah)} - آية ${widget.ayahMarker.ayah}',
                            style: TextStyle(
                              fontSize: AppConstants.actionSheetTitleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleBookmark,
                          icon: Icon(
                            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: _isBookmarked
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: AppConstants.actionSheetDividerHeight),

                  // Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppConstants.actionSheetPadding),
                      children: [
                        // Error display
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(AppConstants.actionSheetInnerPadding),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _loadAyahText(),
                                  child: const Text(AppStrings.retry),
                                ),
                              ],
                            ),
                          ),

                        // Ayah text
                        if (_isLoadingAyahText)
                          Center(child: LoadingStates.circular(size: 24))
                        else if (_ayahText != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppConstants.actionSheetPadding),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _ayahText!,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                height: 1.8,
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // SIMPLIFIED: Single play button with enhanced design
                        _buildSectionTitle('استماع الآية'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _playAyah,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.play_circle_filled,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'تشغيل الآية مع التتابع',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                      Text(
                                        'بصوت $_defaultReciter',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8),
                                          fontSize: 12,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Memorization section
                        if (widget.memorizationManager != null) ...[
                          _buildSectionTitle('التحفيظ'),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.secondary,
                                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _startMemorization,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      color: Theme.of(context).colorScheme.onSecondary,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'التحفيظ',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSecondary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textDirection: TextDirection.rtl,
                                        ),
                                        Text(
                                          _getMemorizationSubtitle(),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSecondary.withValues(alpha: 0.8),
                                            fontSize: 12,
                                          ),
                                          textDirection: TextDirection.rtl,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Tafsir section
                        Row(
                          children: [
                            _buildSectionTitle('التفسير'),
                            if (_tafsirSource != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _tafsirSource!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_tafsirText == null)
                          Card(
                            elevation: 0,
                            color: Theme.of(context).colorScheme.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Icon(
                                Icons.book_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: const Text(
                                'عرض التفسير',
                                textDirection: TextDirection.rtl,
                              ),
                              subtitle: Text(
                                'من $_defaultTafsir',
                                textDirection: TextDirection.rtl,
                              ),
                              trailing: _isLoadingTafsir
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : const Icon(Icons.keyboard_arrow_left),
                              onTap: _isLoadingTafsir ? null : _loadTafsir,
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(AppConstants.actionSheetPadding),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _tafsirText!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                                if (_tafsirText!.contains('عذراً'))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: ElevatedButton(
                                      onPressed: _loadTafsir,
                                      child: const Text(AppStrings.retry),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
      textDirection: TextDirection.rtl,
    );
  }

  String _getSurahName(int surahNumber) {
    return SurahNames.getArabicName(surahNumber);
  }
}

// Helper classes for better organization
class CacheEntry {
  final String data;
  final DateTime createdAt;
  final String? source;
  static const Duration cacheExpiry = Duration(hours: 24);

  CacheEntry(this.data, this.createdAt, {this.source});

  bool get isExpired => DateTime.now().difference(createdAt) > cacheExpiry;
}

class TafsirStrategy {
  final String name;
  final Future<String?> Function() apiCall;

  TafsirStrategy({required this.name, required this.apiCall});
}

// Smart Ayah Range Selection Dialog
class _AyahRangeDialog extends StatefulWidget {
  final AyahMarker startAyah;
  final String surahName;
  final MemorizationManager memorizationManager;
  final String defaultReciter;

  const _AyahRangeDialog({
    required this.startAyah,
    required this.surahName,
    required this.memorizationManager,
    required this.defaultReciter,
  });

  @override
  State<_AyahRangeDialog> createState() => _AyahRangeDialogState();
}

class _AyahRangeDialogState extends State<_AyahRangeDialog> {
  late int _fromAyah;
  late int _toAyah;
  late int _maxAyahInSurah;
  String? _validationError;
  
  late TextEditingController _toAyahController;

  @override
  void initState() {
    super.initState();
    _fromAyah = widget.startAyah.ayah;
    _toAyah = widget.startAyah.ayah; // Default to same ayah
    _maxAyahInSurah = SurahNames.getAyahCount(widget.startAyah.surah);
    _toAyahController = TextEditingController(text: _toAyah.toString());
  }
  
  @override
  void dispose() {
    _toAyahController.dispose();
    super.dispose();
  }
  
  void _validateInput(String value, bool isToAyah) {
    setState(() {
      _validationError = null;
    });
    
    final num = int.tryParse(value);
    if (num == null) {
      setState(() {
        _validationError = 'يرجى إدخال رقم صحيح';
      });
      return;
    }
    
    if (num <= 0) {
      setState(() {
        _validationError = 'رقم الآية يجب أن يكون أكبر من صفر';
      });
      return;
    }
    
    if (num > _maxAyahInSurah) {
      setState(() {
        _validationError = 'رقم الآية يجب أن يكون بين 1 و $_maxAyahInSurah (عدد آيات السورة)';
      });
      return;
    }
    
    if (isToAyah && num < _fromAyah) {
      setState(() {
        _validationError = 'آية النهاية يجب أن تكون أكبر من أو تساوي آية البداية ($_fromAyah)';
      });
      return;
    }
    
    // Input is valid
    setState(() {
      if (isToAyah) {
        _toAyah = num;
      } else {
        _fromAyah = num;
        if (_toAyah < _fromAyah) {
          _toAyah = _fromAyah;
          _toAyahController.text = _toAyah.toString();
        }
      }
    });
  }

  void _startRangeMemorization() {
    Navigator.of(context).pop();
    
    // Create ayah markers for the range
    final List<AyahMarker> rangeAyahs = [];
    for (int ayahNum = _fromAyah; ayahNum <= _toAyah; ayahNum++) {
      rangeAyahs.add(AyahMarker(
        surah: widget.startAyah.surah,
        ayah: ayahNum,
        page: widget.startAyah.page,
        bboxes: [], // Empty bounding boxes for memorization-only markers
      ));
    }
    
    widget.memorizationManager.startRangeMemorization(
      ayahs: rangeAyahs,
      reciterName: widget.defaultReciter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'تحديد نطاق الآيات للتحفيظ',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.right,
      ),
      content: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'السورة: ${SurahNames.getArabicName(widget.startAyah.surah)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            // From Ayah
            Row(
              children: [
                const Expanded(child: Text(AppStrings.fromAyah)),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: TextEditingController(text: _fromAyah.toString()),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      counterText: '', // Hide character counter
                    ),
                    validator: InputSanitizer.createValidator(
                      fieldName: 'الآية الأولى',
                      required: true,
                      isNumeric: true,
                      minValue: 1,
                      maxValue: _maxAyahInSurah,
                    ),
                    onChanged: (value) {
                      final formatted = QuranInputFormatters.formatAyahNumber(value, _maxAyahInSurah);
                      if (formatted != value) {
                        final controller = TextEditingController(text: formatted);
                        controller.selection = TextSelection.collapsed(offset: formatted.length);
                      }
                      _validateInput(formatted, false);
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // To Ayah
            Row(
              children: [
                const Expanded(child: Text(AppStrings.toAyah)),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _toAyahController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      counterText: '', // Hide character counter
                    ),
                    validator: InputSanitizer.createValidator(
                      fieldName: 'الآية الأخيرة',
                      required: true,
                      isNumeric: true,
                      minValue: 1,
                      maxValue: _maxAyahInSurah,
                    ),
                    onChanged: (value) {
                      final formatted = QuranInputFormatters.formatAyahNumber(value, _maxAyahInSurah);
                      if (formatted != value) {
                        _toAyahController.value = _toAyahController.value.copyWith(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                      _validateInput(formatted, true);
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Show acceptable range info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'النطاق المتاح: من 1 إلى $_maxAyahInSurah (${SurahNames.getArabicName(widget.startAyah.surah)})',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            if (_validationError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'سيتم تكرار الآيات من $_fromAyah إلى $_toAyah',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
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
          onPressed: _validationError != null ? null : _startRangeMemorization,
          child: const Text(AppStrings.startMemorization),
        ),
      ],
    );
  }
}