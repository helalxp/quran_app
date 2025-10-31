import 'package:flutter/material.dart';
import '../services/azkar_service.dart';
import '../models/dhikr_model.dart';
import '../utils/haptic_utils.dart';
import 'azkar_list_screen.dart';

class AzkarCategoriesScreen extends StatefulWidget {
  const AzkarCategoriesScreen({super.key});

  @override
  State<AzkarCategoriesScreen> createState() => _AzkarCategoriesScreenState();
}

class _AzkarCategoriesScreenState extends State<AzkarCategoriesScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final AzkarService _azkarService = AzkarService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _searchInText = false;
  String _searchQuery = '';
  final Map<String, bool> _expandedSections = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _loadAzkar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Check for new day when app resumes
    if (state == AppLifecycleState.resumed) {
      _checkForNewDay();
    }
  }

  Future<void> _checkForNewDay() async {
    await _azkarService.checkForNewDay();
    // Refresh UI if counters were reset
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadAzkar() async {
    try {
      await _azkarService.loadAzkar();
      // Initialize all sections as collapsed
      final groups = _azkarService.getGroupedCategories();
      for (var groupName in groups.keys) {
        _expandedSections[groupName] = false;
      }
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      debugPrint('Error loading azkar: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  List<DhikrCategory> _getFilteredCategories() {
    if (_searchQuery.isEmpty) {
      return _azkarService.allCategories;
    }
    return _azkarService.searchCategories(_searchQuery, searchInText: _searchInText);
  }

  /// Get matching dhikrs from a category for the current search
  List<Dhikr> _getMatchingDhikrs(DhikrCategory category) {
    if (_searchQuery.isEmpty || !_searchInText) return [];

    final lowerQuery = _searchQuery.toLowerCase();
    return category.dhikrs
        .where((dhikr) => dhikr.text.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get highlighted text snippet showing the match
  String _getHighlightedSnippet(String text, String query) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) return '';

    // Get context around the match (50 chars before and after)
    const contextLength = 50;
    final start = (index - contextLength).clamp(0, text.length);
    final end = (index + query.length + contextLength).clamp(0, text.length);

    String snippet = text.substring(start, end);

    // Add ellipsis if truncated
    if (start > 0) snippet = '...$snippet';
    if (end < text.length) snippet = '$snippet...';

    return snippet;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'جاري تحميل الأذكار...',
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Uthmanic',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // App Bar with Gradient
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                    ],
                  ),
                ),
                child: FlexibleSpaceBar(
                  centerTitle: true,
                  title: const Text(
                    'الأذكار والأدعية',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Uthmanic',
                      fontSize: 24,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Decorative pattern overlay
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.1,
                          child: Image.asset(
                            'assets/images/kaaba.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildSearchBar(),
              ),
            ),

            // Categories List
            _searchQuery.isEmpty
                ? _buildGroupedCategoriesSliver()
                : _buildSearchResultsSliver(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search TextField
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Uthmanic'),
            decoration: InputDecoration(
              hintText: 'ابحث في الأذكار...',
              hintTextDirection: TextDirection.rtl,
              hintStyle: const TextStyle(fontFamily: 'Uthmanic'),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.primary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: 12),

          // Search in text toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'البحث في النص',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Uthmanic',
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _searchInText,
                onChanged: (value) {
                  HapticUtils.lightImpact();
                  setState(() {
                    _searchInText = value;
                    if (_searchQuery.isNotEmpty) {
                      _onSearchChanged(_searchQuery);
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedCategoriesSliver() {
    final groups = _azkarService.getGroupedCategories();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final groupName = groups.keys.elementAt(index);
          final categories = groups[groupName]!;
          final isExpanded = _expandedSections[groupName] ?? false;

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Section Header
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticUtils.selectionClick();
                        setState(() {
                          _expandedSections[groupName] = !isExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: isExpanded
                              ? LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                groupName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  fontFamily: 'Uthmanic',
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${categories.length}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.expand_more,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Expanded Categories
                  if (isExpanded)
                    ...categories.map((category) => _buildCategoryTile(category)),
                ],
              ),
            ),
          );
        },
        childCount: groups.length,
      ),
    );
  }

  Widget _buildSearchResultsSliver() {
    final filteredCategories = _getFilteredCategories();

    if (filteredCategories.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد نتائج',
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'Uthmanic',
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'جرّب البحث بكلمات أخرى',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Uthmanic',
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildCategoryTile(filteredCategories[index]),
            );
          },
          childCount: filteredCategories.length,
        ),
      ),
    );
  }

  Widget _buildCategoryTile(DhikrCategory category) {
    final matchingDhikrs = _getMatchingDhikrs(category);
    final isSearchResult = _searchInText && matchingDhikrs.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isSearchResult
              ? [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  Colors.transparent,
                ]
              : [
                  Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
        ),
        border: isSearchResult
            ? Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticUtils.selectionClick();
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => AzkarListScreen(category: category),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            category.category,
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Uthmanic',
                              fontWeight: FontWeight.w600,
                              color: isSearchResult
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          if (category.completedCount > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'اكتمل ${category.completedCount} من ${category.totalDhikrs}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${category.totalDhikrs}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_back_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),

                // Show matching snippets when searching in text
                if (isSearchResult && matchingDhikrs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'تم العثور على ${matchingDhikrs.length} ${matchingDhikrs.length == 1 ? "نتيجة" : "نتائج"}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Uthmanic',
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...matchingDhikrs.take(2).map((dhikr) {
                          final snippet = _getHighlightedSnippet(dhikr.text, _searchQuery);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _buildHighlightedText(snippet, _searchQuery),
                          );
                        }),
                        if (matchingDhikrs.length > 2) ...[
                          const SizedBox(height: 6),
                          Text(
                            '+ ${matchingDhikrs.length - 2} نتائج أخرى',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Uthmanic',
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build text with highlighted search query
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontFamily: 'Uthmanic',
          height: 1.6,
        ),
        textDirection: TextDirection.rtl,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];

    int start = 0;
    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);

      if (index == -1) {
        // No more matches, add remaining text
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          fontFamily: 'Uthmanic',
          height: 1.6,
          color: Colors.black87,
        ),
        children: spans,
      ),
      textDirection: TextDirection.rtl,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
