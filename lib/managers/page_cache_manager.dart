// lib/managers/page_cache_manager.dart

import 'package:flutter/material.dart';
import '../models/ayah_marker.dart';

/// Manages page caching and preloading for optimal performance
class PageCacheManager {
  static const int maxCachedPages = 5;
  static const int preloadDistance = 2;

  final Map<int, List<AyahMarker>> _pageCache = {};
  final Set<int> _loadingPages = {};

  /// Get cached page or null if not cached
  List<AyahMarker>? getCachedPage(int pageNumber) {
    return _pageCache[pageNumber];
  }

  /// Check if a page is currently being loaded
  bool isPageLoading(int pageNumber) {
    return _loadingPages.contains(pageNumber);
  }

  /// Clean up old cached pages to maintain memory efficiency
  void cleanupCache(int currentPage) {
    final pagesToRemove = <int>[];

    for (final pageNumber in _pageCache.keys) {
      final distance = (pageNumber - currentPage).abs();
      if (distance > maxCachedPages) {
        pagesToRemove.add(pageNumber);
      }
    }

    for (final pageNumber in pagesToRemove) {
      _pageCache.remove(pageNumber);
      debugPrint('📄 Removed page $pageNumber from cache');
    }
  }

  /// Preload adjacent pages for smooth navigation
  void preloadAdjacentPages(int currentPage) {
    final pagesToPreload = <int>[];

    // Add pages within preload distance
    for (int i = 1; i <= preloadDistance; i++) {
      final nextPage = currentPage + i;
      final prevPage = currentPage - i;

      if (nextPage >= 1 && nextPage <= 604 && !_pageCache.containsKey(nextPage) && !_loadingPages.contains(nextPage)) {
        pagesToPreload.add(nextPage);
      }
      if (prevPage >= 1 && prevPage <= 604 && !_pageCache.containsKey(prevPage) && !_loadingPages.contains(prevPage)) {
        pagesToPreload.add(prevPage);
      }
    }

    // Load pages in batch
    for (final pageNumber in pagesToPreload) {
      _loadPageInBackground(pageNumber);
    }
  }

  /// Load a specific page and cache it
  Future<List<AyahMarker>?> loadPage(int pageNumber, {bool forceReload = false}) async {
    if (!forceReload && _pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber];
    }

    if (_loadingPages.contains(pageNumber)) {
      // Wait for existing load to complete
      while (_loadingPages.contains(pageNumber)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _pageCache[pageNumber];
    }

    return await _fetchPage(pageNumber);
  }

  /// Load page in background without waiting
  void _loadPageInBackground(int pageNumber) async {
    try {
      await _fetchPage(pageNumber);
    } catch (e) {
      debugPrint('⚠️ Background page load failed for page $pageNumber: $e');
    }
  }

  /// Fetch page data from API - Currently simplified for refactoring
  Future<List<AyahMarker>?> _fetchPage(int pageNumber) async {
    if (_loadingPages.contains(pageNumber)) {
      return null;
    }

    _loadingPages.add(pageNumber);
    debugPrint('📄 Loading page $pageNumber... (simplified loader)');

    try {
      // TODO: Integrate with actual API once ViewerScreen refactoring is complete
      // For now, just simulate loading delay and return empty list
      await Future.delayed(const Duration(milliseconds: 100));

      final emptyMarkers = <AyahMarker>[];
      _pageCache[pageNumber] = emptyMarkers;
      debugPrint('✅ Page $pageNumber simulated load completed');

      return emptyMarkers;
    } catch (e) {
      debugPrint('❌ Error loading page $pageNumber: $e');
      return null;
    } finally {
      _loadingPages.remove(pageNumber);
    }
  }

  /// Clear all cached pages
  void clearCache() {
    _pageCache.clear();
    _loadingPages.clear();
    debugPrint('🗑️ Page cache cleared');
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedPages': _pageCache.length,
      'loadingPages': _loadingPages.length,
      'cachedPageNumbers': _pageCache.keys.toList()..sort(),
      'loadingPageNumbers': _loadingPages.toList()..sort(),
    };
  }
}