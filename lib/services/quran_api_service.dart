// lib/services/quran_api_service.dart - Quran API Service with Caching

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/app_data.dart';
import '../data/quran_data.dart';
import 'cache_service.dart';

class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool isSuccess;
  final bool fromCache;

  const ApiResponse._({
    this.data,
    this.error,
    required this.isSuccess,
    this.fromCache = false,
  });

  factory ApiResponse.success(T data, {bool fromCache = false}) {
    return ApiResponse._(
      data: data,
      isSuccess: true,
      fromCache: fromCache,
    );
  }

  factory ApiResponse.error(String error) {
    return ApiResponse._(
      error: error,
      isSuccess: false,
    );
  }
}

class AyahText {
  final String arabic;
  final String? translation;
  final int surahNumber;
  final int ayahNumber;

  const AyahText({
    required this.arabic,
    this.translation,
    required this.surahNumber,
    required this.ayahNumber,
  });

  factory AyahText.fromJson(Map<String, dynamic> json) {
    return AyahText(
      arabic: json['text'] ?? '',
      translation: json['translation'],
      surahNumber: json['surah']['number'] ?? 0,
      ayahNumber: json['numberInSurah'] ?? 0,
    );
  }
}

class TafsirText {
  final String text;
  final String sourceName;
  final int surahNumber;
  final int ayahNumber;

  const TafsirText({
    required this.text,
    required this.sourceName,
    required this.surahNumber,
    required this.ayahNumber,
  });

  factory TafsirText.fromJson(Map<String, dynamic> json, String sourceName) {
    return TafsirText(
      text: json['text'] ?? '',
      sourceName: sourceName,
      surahNumber: json['surah']['number'] ?? 0,
      ayahNumber: json['numberInSurah'] ?? 0,
    );
  }
}

class QuranApiService {
  static final QuranApiService _instance = QuranApiService._internal();
  factory QuranApiService() => _instance;
  QuranApiService._internal();

  final CacheService _cache = CacheService();
  final http.Client _client = http.Client();

  static const Duration _requestTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  Future<void> initialize() async {
    await _cache.initialize();
    debugPrint('✅ QuranApiService initialized');
  }

  // Get Ayah text (Arabic and optional translation)
  Future<ApiResponse<AyahText>> getAyahText(
    int surahNumber,
    int ayahNumber, {
    String? translationLanguage,
  }) async {
    // Validate input
    if (!QuranData.isValidAyah(surahNumber, ayahNumber)) {
      return ApiResponse.error('Invalid ayah reference: $surahNumber:$ayahNumber');
    }

    final cacheKey = _buildAyahCacheKey(surahNumber, ayahNumber, translationLanguage);

    try {
      // Check cache first
      final cachedData = await _cache.get(cacheKey);
      if (cachedData != null) {
        final json = jsonDecode(cachedData) as Map<String, dynamic>;
        final ayahText = AyahText.fromJson(json);
        return ApiResponse.success(ayahText, fromCache: true);
      }

      // Fetch from API
      final arabicUrl = 'https://api.alquran.cloud/v1/ayah/$surahNumber:$ayahNumber/ar.alafasy';
      final arabicResponse = await _makeRequest(arabicUrl);

      if (!arabicResponse.isSuccess) {
        return ApiResponse.error(arabicResponse.error!);
      }

      final arabicJson = jsonDecode(arabicResponse.data!)['data'];
      String? translation;

      // Fetch translation if requested
      if (translationLanguage != null) {
        final translationConfig = AppData.translationSources[translationLanguage];
        if (translationConfig != null) {
          final translationUrl = translationConfig['endpoint']!
              .replaceAll('{surah}', surahNumber.toString())
              .replaceAll('{ayah}', ayahNumber.toString());

          final translationResponse = await _makeRequest(translationUrl);
          if (translationResponse.isSuccess) {
            final translationJson = jsonDecode(translationResponse.data!)['data'];
            translation = translationJson['text'];
          }
        }
      }

      // Create combined response
      final combinedJson = <String, dynamic>{
        ...Map<String, dynamic>.from(arabicJson),
        'translation': translation,
      };

      final ayahText = AyahText.fromJson(combinedJson);

      // Cache the result
      await _cache.store(cacheKey, jsonEncode(combinedJson));

      return ApiResponse.success(ayahText);

    } catch (e) {
      debugPrint('❌ Error fetching ayah text: $e');
      return ApiResponse.error('فشل في جلب نص الآية: ${e.toString()}');
    }
  }

  // Get Tafsir for an ayah
  Future<ApiResponse<TafsirText>> getTafsir(
    int surahNumber,
    int ayahNumber,
    String tafsirSourceId,
  ) async {
    // Validate input
    if (!QuranData.isValidAyah(surahNumber, ayahNumber)) {
      return ApiResponse.error('Invalid ayah reference: $surahNumber:$ayahNumber');
    }

    if (!AppData.isValidTafsirSource(tafsirSourceId)) {
      return ApiResponse.error('Invalid tafsir source: $tafsirSourceId');
    }

    final cacheKey = _buildTafsirCacheKey(surahNumber, ayahNumber, tafsirSourceId);

    try {
      // Check cache first
      final cachedData = await _cache.get(cacheKey);
      if (cachedData != null) {
        final json = jsonDecode(cachedData) as Map<String, dynamic>;
        final tafsirSource = AppData.getTafsirSource(tafsirSourceId)!;
        final tafsirText = TafsirText.fromJson(json, tafsirSource.nameArabic);
        return ApiResponse.success(tafsirText, fromCache: true);
      }

      // Get tafsir source configuration
      final tafsirSource = AppData.getTafsirSource(tafsirSourceId)!;
      final url = tafsirSource.apiEndpoint
          .replaceAll('{surah}', surahNumber.toString())
          .replaceAll('{ayah}', ayahNumber.toString());

      final response = await _makeRequest(url);

      if (!response.isSuccess) {
        return ApiResponse.error(response.error!);
      }

      final json = jsonDecode(response.data!)['data'];
      final tafsirText = TafsirText.fromJson(json, tafsirSource.nameArabic);

      // Cache the result with longer expiry for tafsir (it changes less frequently)
      await _cache.store(
        cacheKey,
        jsonEncode(json),
        customExpiry: const Duration(days: 7),
      );

      return ApiResponse.success(tafsirText);

    } catch (e) {
      debugPrint('❌ Error fetching tafsir: $e');
      return ApiResponse.error('فشل في جلب التفسير: ${e.toString()}');
    }
  }

  // Get multiple ayahs (for surah or range)
  Future<ApiResponse<List<AyahText>>> getAyahRange(
    int surahNumber,
    int startAyah,
    int endAyah, {
    String? translationLanguage,
  }) async {
    // Validate input
    if (!QuranData.isValidSurah(surahNumber)) {
      return ApiResponse.error('Invalid surah number: $surahNumber');
    }

    final maxAyah = QuranData.getAyahCount(surahNumber);
    if (startAyah < 1 || endAyah > maxAyah || startAyah > endAyah) {
      return ApiResponse.error('Invalid ayah range: $startAyah-$endAyah');
    }

    try {
      final List<AyahText> ayahs = [];
      final List<Future<ApiResponse<AyahText>>> futures = [];

      // Create requests for all ayahs in range
      for (int ayah = startAyah; ayah <= endAyah; ayah++) {
        futures.add(getAyahText(surahNumber, ayah, translationLanguage: translationLanguage));
      }

      // Wait for all requests to complete
      final responses = await Future.wait(futures);

      // Collect successful responses
      for (final response in responses) {
        if (response.isSuccess && response.data != null) {
          ayahs.add(response.data!);
        }
      }

      if (ayahs.isEmpty) {
        return ApiResponse.error('لم يتم العثور على آيات في النطاق المحدد');
      }

      // Sort by ayah number to ensure correct order
      ayahs.sort((a, b) => a.ayahNumber.compareTo(b.ayahNumber));

      return ApiResponse.success(ayahs);

    } catch (e) {
      debugPrint('❌ Error fetching ayah range: $e');
      return ApiResponse.error('فشل في جلب الآيات: ${e.toString()}');
    }
  }

  // Get complete surah
  Future<ApiResponse<List<AyahText>>> getSurah(
    int surahNumber, {
    String? translationLanguage,
  }) async {
    if (!QuranData.isValidSurah(surahNumber)) {
      return ApiResponse.error('Invalid surah number: $surahNumber');
    }

    final ayahCount = QuranData.getAyahCount(surahNumber);
    return getAyahRange(surahNumber, 1, ayahCount, translationLanguage: translationLanguage);
  }

  // Private helper methods
  Future<ApiResponse<String>> _makeRequest(String url) async {
    int retries = 0;

    while (retries < _maxRetries) {
      try {
        debugPrint('🌐 Making API request to: $url (attempt ${retries + 1})');

        final response = await _client.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'QuranReader/1.0',
          },
        ).timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['code'] == 200 && json['status'] == 'OK') {
            return ApiResponse.success(response.body);
          } else {
            return ApiResponse.error('API returned error: ${json['data'] ?? 'Unknown error'}');
          }
        } else if (response.statusCode == 429) {
          // Rate limiting - wait before retry
          final delay = Duration(seconds: (retries + 1) * 2);
          debugPrint('⏳ Rate limited, waiting ${delay.inSeconds}s before retry');
          await Future.delayed(delay);
          retries++;
          continue;
        } else {
          return ApiResponse.error('HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }

      } on TimeoutException {
        retries++;
        if (retries >= _maxRetries) {
          return ApiResponse.error('انتهت مهلة الاتصال بالخادم');
        }
        debugPrint('⏳ Request timeout, retrying in ${retries * 2}s...');
        await Future.delayed(Duration(seconds: retries * 2));

      } catch (e) {
        retries++;
        if (retries >= _maxRetries) {
          return ApiResponse.error('خطأ في الاتصال: ${e.toString()}');
        }
        debugPrint('🔄 Request failed, retrying: $e');
        await Future.delayed(Duration(seconds: retries));
      }
    }

    return ApiResponse.error('فشل الطلب بعد $retries محاولات');
  }

  String _buildAyahCacheKey(int surah, int ayah, String? translation) {
    final base = 'ayah_${surah}_$ayah';
    return translation != null ? '${base}_$translation' : base;
  }

  String _buildTafsirCacheKey(int surah, int ayah, String sourceId) {
    return 'tafsir_${surah}_${ayah}_$sourceId';
  }

  // Cache management methods
  Future<void> clearCache() async {
    await _cache.clearAll();
  }

  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }

  // Preload commonly accessed data
  Future<void> preloadCommonData() async {
    try {
      debugPrint('📥 Preloading common Quran data...');

      // Preload Al-Fatiha (most commonly recited)
      await getSurah(1);

      // Preload short surahs (commonly memorized)
      final shortSurahs = [112, 113, 114, 103, 108]; // Al-Ikhlas, Al-Falaq, An-Nas, Al-Asr, Al-Kawthar
      for (final surahNumber in shortSurahs) {
        await getSurah(surahNumber);
      }

      debugPrint('✅ Common data preloading completed');
    } catch (e) {
      debugPrint('⚠️ Preloading failed: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _client.close();
    _cache.dispose();
  }
}