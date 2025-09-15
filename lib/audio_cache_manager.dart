// lib/audio_cache_manager.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/api_constants.dart';

/// Cache entry metadata
class CacheEntry {
  final String url;
  final String filePath;
  final int size;
  final DateTime lastAccessed;
  final DateTime downloadDate;
  final String reciter;
  final int surah;
  final int ayah;

  const CacheEntry({
    required this.url,
    required this.filePath,
    required this.size,
    required this.lastAccessed,
    required this.downloadDate,
    required this.reciter,
    required this.surah,
    required this.ayah,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'filePath': filePath,
    'size': size,
    'lastAccessed': lastAccessed.millisecondsSinceEpoch,
    'downloadDate': downloadDate.millisecondsSinceEpoch,
    'reciter': reciter,
    'surah': surah,
    'ayah': ayah,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    url: json['url'],
    filePath: json['filePath'],
    size: json['size'],
    lastAccessed: DateTime.fromMillisecondsSinceEpoch(json['lastAccessed']),
    downloadDate: DateTime.fromMillisecondsSinceEpoch(json['downloadDate']),
    reciter: json['reciter'],
    surah: json['surah'],
    ayah: json['ayah'],
  );
}

/// Download progress callback
typedef DownloadProgressCallback = void Function(int downloaded, int total, double percentage);

/// Cache size limits
class CacheLimits {
  static const int maxCacheSizeMB = 500; // 500MB max cache
  static const int maxCacheEntries = 1000; // Max 1000 audio files
  static const Duration cacheExpiry = Duration(days: 30); // Auto-cleanup after 30 days
  static const int bufferSizeAheadCount = 5; // Buffer 5 ayahs ahead
  static const int bufferSizeBehindCount = 2; // Keep 2 ayahs behind
}

/// Intelligent audio caching and buffering system
class AudioCacheManager {
  static final AudioCacheManager _instance = AudioCacheManager._internal();
  factory AudioCacheManager() => _instance;
  AudioCacheManager._internal();

  // Cache storage
  final Map<String, CacheEntry> _cacheIndex = {};
  Directory? _cacheDirectory;
  SharedPreferences? _prefs;
  bool _initialized = false;

  // Buffer management
  final Map<String, Uint8List> _memoryBuffer = {}; // In-memory buffer for fast access
  final List<String> _bufferQueue = []; // LRU queue for memory buffer
  static const int maxMemoryBufferMB = 50; // 50MB memory buffer
  int _currentMemoryUsage = 0;

  // Download management - optimized for speed
  final Map<String, http.StreamedResponse> _activeDownloads = {};
  final Map<String, List<DownloadProgressCallback>> _downloadCallbacks = {};

  // Persistent HTTP client for connection reuse and better performance
  static final http.Client _httpClient = http.Client();

  /// Initialize the cache system
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _cacheDirectory = await _getCacheDirectory();
      await _loadCacheIndex();
      await _performCacheCleanup();
      _initialized = true;
      debugPrint('✅ AudioCacheManager initialized');
    } catch (e) {
      debugPrint('❌ Error initializing AudioCacheManager: $e');
      rethrow;
    }
  }

  /// Get or create cache directory
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/audio_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Load cache index from persistent storage
  Future<void> _loadCacheIndex() async {
    try {
      final indexJson = _prefs?.getString('audio_cache_index');
      if (indexJson != null) {
        final Map<String, dynamic> indexData = jsonDecode(indexJson);
        _cacheIndex.clear();
        
        for (final entry in indexData.entries) {
          try {
            _cacheIndex[entry.key] = CacheEntry.fromJson(entry.value);
          } catch (e) {
            debugPrint('⚠️ Invalid cache entry for ${entry.key}: $e');
          }
        }
        debugPrint('📁 Loaded ${_cacheIndex.length} cache entries');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading cache index: $e');
      _cacheIndex.clear();
    }
  }

  /// Save cache index to persistent storage
  Future<void> _saveCacheIndex() async {
    try {
      final indexData = <String, dynamic>{};
      for (final entry in _cacheIndex.entries) {
        indexData[entry.key] = entry.value.toJson();
      }
      await _prefs?.setString('audio_cache_index', jsonEncode(indexData));
    } catch (e) {
      debugPrint('⚠️ Error saving cache index: $e');
    }
  }

  /// Generate cache key for ayah
  String _generateCacheKey(String reciter, int surah, int ayah) {
    final input = '$reciter-$surah-$ayah';
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Check if ayah is cached
  bool isAyahCached(String reciter, int surah, int ayah) {
    final key = _generateCacheKey(reciter, surah, ayah);
    final entry = _cacheIndex[key];
    if (entry == null) return false;
    
    // Check if file still exists
    final file = File(entry.filePath);
    return file.existsSync();
  }

  /// Get cached file path for ayah
  String? getCachedFilePath(String reciter, int surah, int ayah) {
    if (!isAyahCached(reciter, surah, ayah)) return null;
    
    final key = _generateCacheKey(reciter, surah, ayah);
    final entry = _cacheIndex[key];
    
    // Update last accessed time
    _updateLastAccessed(key);
    
    return 'file://${entry!.filePath}';
  }

  /// Get ayah from memory buffer
  Uint8List? getFromMemoryBuffer(String reciter, int surah, int ayah) {
    final key = _generateCacheKey(reciter, surah, ayah);
    final data = _memoryBuffer[key];
    
    if (data != null) {
      // Move to end of LRU queue
      _bufferQueue.remove(key);
      _bufferQueue.add(key);
      _updateLastAccessed(key);
    }
    
    return data;
  }

  /// Cache ayah audio data
  Future<String?> cacheAyahAudio({
    required String reciter,
    required int surah,
    required int ayah,
    required String url,
    DownloadProgressCallback? onProgress,
    bool preloadToMemory = false,
  }) async {
    if (!_initialized) await initialize();
    
    final key = _generateCacheKey(reciter, surah, ayah);
    
    // Check if already cached
    if (isAyahCached(reciter, surah, ayah)) {
      final filePath = getCachedFilePath(reciter, surah, ayah);
      if (preloadToMemory) {
        await _loadToMemoryBuffer(key, _cacheIndex[key]!.filePath);
      }
      return filePath;
    }

    try {
      // Check if download already in progress (allow concurrent different ayahs)
      if (_activeDownloads.containsKey(key)) {
        if (onProgress != null) {
          _downloadCallbacks[key] ??= [];
          _downloadCallbacks[key]!.add(onProgress);
        }
        return null; // Download in progress
      }

      debugPrint('📥 Downloading $surah:$ayah from $reciter');

      // Start ultra-fast download with persistent client and shorter timeout
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await _httpClient.send(request).timeout(
        const Duration(seconds: 15), // Shorter timeout for faster failure detection
        onTimeout: () {
          throw Exception('Download timeout after 15s');
        },
      );
      _activeDownloads[key] = streamedResponse;

      if (onProgress != null) {
        _downloadCallbacks[key] = [onProgress];
      }

      if (streamedResponse.statusCode != 200) {
        throw Exception('HTTP ${streamedResponse.statusCode}: ${streamedResponse.reasonPhrase ?? 'Unknown error'} for URL: $url');
      }

      // Prepare file
      final fileName = '${reciter}_${surah}_$ayah.mp3';
      final file = File('${_cacheDirectory!.path}/$fileName');
      final sink = file.openWrite();

      int downloaded = 0;
      final total = streamedResponse.contentLength ?? 0;
      final List<int> audioData = [];

      // Download with progress
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        audioData.addAll(chunk);
        downloaded += chunk.length;
        
        final percentage = total > 0 ? (downloaded / total) * 100 : 0;
        
        // Notify all callbacks
        for (final callback in _downloadCallbacks[key] ?? []) {
          callback(downloaded, total, percentage);
        }
      }

      await sink.close();

      // Create cache entry
      final entry = CacheEntry(
        url: url,
        filePath: file.path,
        size: downloaded,
        lastAccessed: DateTime.now(),
        downloadDate: DateTime.now(),
        reciter: reciter,
        surah: surah,
        ayah: ayah,
      );

      _cacheIndex[key] = entry;
      await _saveCacheIndex();

      // Load to memory buffer if requested
      if (preloadToMemory) {
        _addToMemoryBuffer(key, Uint8List.fromList(audioData));
      }

      // Clean up download tracking
      _activeDownloads.remove(key);
      _downloadCallbacks.remove(key);

      debugPrint('✅ Cached $surah:$ayah ($downloaded bytes)');
      return 'file://${file.path}';

    } catch (e) {
      debugPrint('❌ Error caching $surah:$ayah: $e');
      _activeDownloads.remove(key);
      _downloadCallbacks.remove(key);
      return null;
    }
  }

  /// Intelligent buffer management for smooth playback
  Future<void> bufferAroundCurrentAyah({
    required String reciter,
    required List<dynamic> playlist,
    required int currentIndex,
  }) async {
    if (!_initialized) await initialize();

    final startIndex = (currentIndex - CacheLimits.bufferSizeBehindCount).clamp(0, playlist.length - 1);
    final endIndex = (currentIndex + CacheLimits.bufferSizeAheadCount).clamp(0, playlist.length - 1);

    debugPrint('🔄 Buffering ayahs $startIndex to $endIndex around current $currentIndex');

    // Buffer ayahs in background
    for (int i = startIndex; i <= endIndex; i++) {
      final ayah = playlist[i];
      final config = ApiConstants.reciterConfigs[reciter];
      if (config == null) continue;

      final url = config.getAyahUrl(ayah.surah, ayah.ayah);
      final isCurrentOrNext = (i >= currentIndex && i <= currentIndex + 1);
      
      // Cache with memory preload for current and next ayah
      cacheAyahAudio(
        reciter: reciter,
        surah: ayah.surah,
        ayah: ayah.ayah,
        url: url,
        preloadToMemory: isCurrentOrNext,
      );
    }
  }

  /// Add data to memory buffer with LRU management
  void _addToMemoryBuffer(String key, Uint8List data) {
    final sizeMB = data.length / (1024 * 1024);
    
    // Clean up memory if needed
    while (_currentMemoryUsage + sizeMB > maxMemoryBufferMB && _bufferQueue.isNotEmpty) {
      final oldestKey = _bufferQueue.removeAt(0);
      final oldData = _memoryBuffer.remove(oldestKey);
      if (oldData != null) {
        _currentMemoryUsage -= (oldData.length / (1024 * 1024)).round();
      }
    }

    _memoryBuffer[key] = data;
    _bufferQueue.add(key);
    _currentMemoryUsage += sizeMB.round();
    
    debugPrint('💾 Added to memory buffer: ${data.length} bytes ($_currentMemoryUsage MB total)');
  }

  /// Load file to memory buffer
  Future<void> _loadToMemoryBuffer(String key, String filePath) async {
    try {
      final file = File(filePath);
      final data = await file.readAsBytes();
      _addToMemoryBuffer(key, data);
    } catch (e) {
      debugPrint('⚠️ Error loading to memory buffer: $e');
    }
  }

  /// Update last accessed time
  void _updateLastAccessed(String key) {
    final entry = _cacheIndex[key];
    if (entry != null) {
      _cacheIndex[key] = CacheEntry(
        url: entry.url,
        filePath: entry.filePath,
        size: entry.size,
        lastAccessed: DateTime.now(),
        downloadDate: entry.downloadDate,
        reciter: entry.reciter,
        surah: entry.surah,
        ayah: entry.ayah,
      );
    }
  }

  /// Perform cache cleanup based on size and age limits
  Future<void> _performCacheCleanup() async {
    final now = DateTime.now();
    final entriesToRemove = <String>[];

    // Find expired or excess entries
    for (final entry in _cacheIndex.entries) {
      final cacheEntry = entry.value;
      
      // Remove expired entries
      if (now.difference(cacheEntry.lastAccessed) > CacheLimits.cacheExpiry) {
        entriesToRemove.add(entry.key);
        continue;
      }
      
      // Remove if file doesn't exist
      if (!File(cacheEntry.filePath).existsSync()) {
        entriesToRemove.add(entry.key);
        continue;
      }
    }

    // Remove excess entries (LRU)
    if (_cacheIndex.length > CacheLimits.maxCacheEntries) {
      final sortedEntries = _cacheIndex.entries.toList()
        ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
      
      final excessCount = _cacheIndex.length - CacheLimits.maxCacheEntries;
      for (int i = 0; i < excessCount; i++) {
        entriesToRemove.add(sortedEntries[i].key);
      }
    }

    // Perform cleanup
    for (final key in entriesToRemove) {
      await _removeFromCache(key);
    }

    if (entriesToRemove.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${entriesToRemove.length} cache entries');
      await _saveCacheIndex();
    }
  }

  /// Remove entry from cache
  Future<void> _removeFromCache(String key) async {
    final entry = _cacheIndex[key];
    if (entry != null) {
      try {
        await File(entry.filePath).delete();
      } catch (e) {
        debugPrint('⚠️ Error deleting cache file: $e');
      }
      _cacheIndex.remove(key);
      _memoryBuffer.remove(key);
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    if (!_initialized) return {};

    int totalSize = 0;
    for (final entry in _cacheIndex.values) {
      totalSize += entry.size;
    }

    final totalSizeMB = totalSize / (1024 * 1024);
    
    return {
      'totalEntries': _cacheIndex.length,
      'totalSizeMB': totalSizeMB.toStringAsFixed(2),
      'memoryBufferMB': _currentMemoryUsage.toStringAsFixed(2),
      'activeDownloads': _activeDownloads.length,
      'lastCleanup': DateTime.now().toIso8601String(),
    };
  }

  /// Clear all cache
  Future<void> clearCache() async {
    if (!_initialized) await initialize();

    // Clear memory buffer
    _memoryBuffer.clear();
    _bufferQueue.clear();
    _currentMemoryUsage = 0;

    // Delete all cache files
    for (final entry in _cacheIndex.values) {
      try {
        await File(entry.filePath).delete();
      } catch (e) {
        debugPrint('⚠️ Error deleting cache file: $e');
      }
    }

    _cacheIndex.clear();
    await _saveCacheIndex();
    debugPrint('🧹 Cache cleared');
  }

  /// Remove a specific cached ayah
  Future<bool> removeCachedAyah(String reciter, int surah, int ayah) async {
    final key = _generateCacheKey(reciter, surah, ayah);
    final entry = _cacheIndex[key];

    if (entry == null) {
      debugPrint('⚠️ Ayah $surah:$ayah not found in cache for $reciter');
      return false;
    }

    try {
      // Remove from memory buffer if loaded
      _memoryBuffer.remove(key);
      _bufferQueue.remove(key);
      if (entry.size <= _currentMemoryUsage) {
        _currentMemoryUsage -= entry.size;
      } else {
        _currentMemoryUsage = 0;
      }

      // Delete file
      await File(entry.filePath).delete();

      // Remove from index
      _cacheIndex.remove(key);
      await _saveCacheIndex();

      debugPrint('🗑️ Removed cached ayah $surah:$ayah for $reciter');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing cached ayah $surah:$ayah: $e');
      return false;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _memoryBuffer.clear();
    _bufferQueue.clear();
    _activeDownloads.clear();
    _downloadCallbacks.clear();
    await _saveCacheIndex();
    debugPrint('✅ AudioCacheManager disposed');
  }
}