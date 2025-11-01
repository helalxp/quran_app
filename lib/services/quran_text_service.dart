// lib/services/quran_text_service.dart - Service to load and search Quran text

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/quran_ayah.dart';

class QuranTextService {
  // Singleton pattern
  static final QuranTextService _instance = QuranTextService._internal();
  factory QuranTextService() => _instance;
  QuranTextService._internal();

  // Cache for loaded ayahs
  List<QuranAyah>? _ayahs;
  bool _isLoading = false;

  /// Load all ayahs from the text file
  Future<List<QuranAyah>> loadAyahs() async {
    // Return cached data if available
    if (_ayahs != null) {
      return _ayahs!;
    }

    // Prevent multiple simultaneous loads
    if (_isLoading) {
      // Wait for the current load to finish
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _ayahs!;
    }

    _isLoading = true;

    try {
      // Load the text file from assets
      final String fileContent = await rootBundle.loadString(
        'assets/data/quran.txt',
      );

      // Split into lines and parse
      final lines = fileContent.split('\n');
      _ayahs = [];

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        try {
          final ayah = QuranAyah.fromLine(trimmedLine);
          _ayahs!.add(ayah);
        } catch (e) {
          // Skip malformed lines
          debugPrint('Error parsing line: $trimmedLine - $e');
        }
      }

      debugPrint('✅ Loaded ${_ayahs!.length} ayahs from quran.txt');
      return _ayahs!;
    } catch (e) {
      debugPrint('❌ Error loading quran.txt: $e');
      _ayahs = [];
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// Get all loaded ayahs (returns empty list if not loaded)
  List<QuranAyah> get ayahs => _ayahs ?? [];

  /// Check if ayahs are loaded
  bool get isLoaded => _ayahs != null;

  /// Clear the cache (for testing or memory management)
  void clearCache() {
    _ayahs = null;
  }
}
