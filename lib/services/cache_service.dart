// lib/services/cache_service.dart - Persistent Cache Service

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../data/app_data.dart';

class CacheEntry {
  final String data;
  final DateTime timestamp;
  final Duration? customExpiry;

  CacheEntry({
    required this.data,
    required this.timestamp,
    this.customExpiry,
  });

  bool get isExpired {
    final expiryDuration = customExpiry ?? Duration(hours: AppData.getCacheExpiryHours());
    return DateTime.now().difference(timestamp) > expiryDuration;
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'customExpiry': customExpiry?.inMilliseconds,
    };
  }

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
      customExpiry: json['customExpiry'] != null
          ? Duration(milliseconds: json['customExpiry'])
          : null,
    );
  }
}

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;
  Directory? _cacheDir;
  bool _isInitialized = false;

  // Cache statistics
  int _memoryHits = 0;
  int _diskHits = 0;
  int _misses = 0;

  // In-memory cache for frequently accessed data
  final Map<String, CacheEntry> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _cacheDir = await getApplicationCacheDirectory();
      await _cacheDir!.create(recursive: true);
      await _loadCriticalDataToMemory();
      await _cleanupExpiredEntries();
      _isInitialized = true;
      debugPrint('✅ CacheService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize CacheService: $e');
      rethrow;
    }
  }

  // Store data in cache
  Future<bool> store(
      String key,
      String data, {
        Duration? customExpiry,
        bool memoryOnly = false,
      }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final entry = CacheEntry(
        data: data,
        timestamp: DateTime.now(),
        customExpiry: customExpiry,
      );

      // Always store in memory cache
      _memoryCache[key] = entry;
      _enforceMemoryCacheLimit();

      // Store on disk unless memoryOnly is true
      if (!memoryOnly) {
        await _storeToDisk(key, entry);
      }

      return true;
    } catch (e) {
      debugPrint('❌ Failed to store cache entry for $key: $e');
      return false;
    }
  }

  // Retrieve data from cache
  Future<String?> get(String key) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Check memory cache first
      if (_memoryCache.containsKey(key)) {
        final entry = _memoryCache[key]!;
        if (!entry.isExpired) {
          _memoryHits++;
          return entry.data;
        } else {
          _memoryCache.remove(key);
        }
      }

      // Check disk cache
      final entry = await _loadFromDisk(key);
      if (entry != null && !entry.isExpired) {
        _diskHits++;
        // Promote to memory cache
        _memoryCache[key] = entry;
        _enforceMemoryCacheLimit();
        return entry.data;
      } else if (entry != null) {
        // Entry expired, clean up
        await _deleteFromDisk(key);
      }

      _misses++;
      return null;
    } catch (e) {
      debugPrint('❌ Failed to retrieve cache entry for $key: $e');
      return null;
    }
  }

  // Check if key exists and is not expired
  Future<bool> exists(String key) async {
    final data = await get(key);
    return data != null;
  }

  // Delete specific cache entry
  Future<bool> delete(String key) async {
    try {
      _memoryCache.remove(key);
      await _deleteFromDisk(key);
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete cache entry for $key: $e');
      return false;
    }
  }

  // Clear all cache
  Future<void> clearAll() async {
    try {
      _memoryCache.clear();
      if (_cacheDir != null && _cacheDir!.existsSync()) {
        await for (final file in _cacheDir!.list()) {
          if (file is File && file.path.endsWith('.cache')) {
            await file.delete();
          }
        }
      }
      await _prefs?.clear();
      _resetStats();
      debugPrint('🧹 Cache cleared successfully');
    } catch (e) {
      debugPrint('❌ Failed to clear cache: $e');
    }
  }

  // Get cache statistics
  Map<String, dynamic> getStats() {
    final totalRequests = _memoryHits + _diskHits + _misses;
    final hitRate = totalRequests > 0 ? (_memoryHits + _diskHits) / totalRequests : 0.0;

    return {
      'memoryHits': _memoryHits,
      'diskHits': _diskHits,
      'misses': _misses,
      'totalRequests': totalRequests,
      'hitRate': hitRate,
      'memoryCacheSize': _memoryCache.length,
    };
  }

  // Private helper methods
  Future<void> _storeToDisk(String key, CacheEntry entry) async {
    final file = File('${_cacheDir!.path}/${_sanitizeKey(key)}.cache');
    await file.writeAsString(jsonEncode(entry.toJson()));
  }

  Future<CacheEntry?> _loadFromDisk(String key) async {
    try {
      final file = File('${_cacheDir!.path}/${_sanitizeKey(key)}.cache');
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CacheEntry.fromJson(json);
    } catch (e) {
      debugPrint('⚠️ Failed to load cache from disk for $key: $e');
      return null;
    }
  }

  Future<void> _deleteFromDisk(String key) async {
    try {
      final file = File('${_cacheDir!.path}/${_sanitizeKey(key)}.cache');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to delete cache file for $key: $e');
    }
  }

  void _enforceMemoryCacheLimit() {
    while (_memoryCache.length > _maxMemoryCacheSize) {
      // Remove oldest entry
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
  }

  String _sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[^\w\-_]'), '_');
  }

  Future<void> _loadCriticalDataToMemory() async {
    // Pre-load frequently accessed data like settings
    try {
      final settingsKey = 'app_settings';
      final settings = await _loadFromDisk(settingsKey);
      if (settings != null && !settings.isExpired) {
        _memoryCache[settingsKey] = settings;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to preload critical data: $e');
    }
  }

  Future<void> _cleanupExpiredEntries() async {
    try {
      if (_cacheDir == null || !_cacheDir!.existsSync()) return;

      int deletedFiles = 0;
      await for (final file in _cacheDir!.list()) {
        if (file is File && file.path.endsWith('.cache')) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final entry = CacheEntry.fromJson(json);

            if (entry.isExpired) {
              await file.delete();
              deletedFiles++;
            }
          } catch (e) {
            // If we can't parse the file, delete it
            await file.delete();
            deletedFiles++;
          }
        }
      }

      if (deletedFiles > 0) {
        debugPrint('🧹 Cleaned up $deletedFiles expired cache files');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup expired entries: $e');
    }
  }

  void _resetStats() {
    _memoryHits = 0;
    _diskHits = 0;
    _misses = 0;
  }

  // Dispose resources
  Future<void> dispose() async {
    _memoryCache.clear();
    _resetStats();
    _isInitialized = false;
  }
}