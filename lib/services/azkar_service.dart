import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dhikr_model.dart';

/// Service for managing Azkar data
class AzkarService {
  static final AzkarService _instance = AzkarService._internal();
  factory AzkarService() => _instance;
  AzkarService._internal();

  List<DhikrCategory> _allCategories = [];
  bool _isLoaded = false;
  static const String _lastResetDateKey = 'azkar_last_reset_date';

  /// Get all categories
  List<DhikrCategory> get allCategories => _allCategories;

  /// Check if data is loaded
  bool get isLoaded => _isLoaded;

  /// Load azkar data from JSON
  Future<void> loadAzkar() async {
    if (_isLoaded) return;

    try {
      debugPrint('📚 Loading azkar data...');

      // Load JSON file
      final jsonString = await rootBundle.loadString('assets/data/adhkar.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      // Parse into DhikrCategory objects
      _allCategories = jsonData
          .map((json) => DhikrCategory.fromJson(json))
          .toList();

      _isLoaded = true;
      debugPrint('✅ Loaded ${_allCategories.length} azkar categories');

      // Check if we need to reset counters for a new day
      await _checkAndResetForNewDay();

    } catch (e) {
      debugPrint('❌ Error loading azkar: $e');
      rethrow;
    }
  }

  /// Check if it's a new day and reset counters if needed
  Future<void> _checkAndResetForNewDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastResetDateStr = prefs.getString(_lastResetDateKey);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastResetDateStr != null) {
        final lastResetDate = DateTime.parse(lastResetDateStr);
        final lastResetDay = DateTime(lastResetDate.year, lastResetDate.month, lastResetDate.day);

        // If last reset was on a different day, reset all counters
        if (today.isAfter(lastResetDay)) {
          resetAllCounters();
          await prefs.setString(_lastResetDateKey, today.toIso8601String());
          debugPrint('🌅 New day detected - All azkar counters have been reset');
        } else {
          debugPrint('📅 Same day - Azkar counters preserved');
        }
      } else {
        // First time - set today as the last reset date
        await prefs.setString(_lastResetDateKey, today.toIso8601String());
        debugPrint('📅 First launch - Setting initial reset date');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking reset date: $e');
    }
  }

  /// Get category by ID
  DhikrCategory? getCategoryById(int id) {
    try {
      return _allCategories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Search categories by name
  List<DhikrCategory> searchCategories(String query, {bool searchInText = false}) {
    if (query.isEmpty) return _allCategories;

    final lowerQuery = query.toLowerCase();

    return _allCategories.where((category) {
      // Always search in category name
      if (category.category.toLowerCase().contains(lowerQuery)) {
        return true;
      }

      // Optionally search in dhikr text
      if (searchInText) {
        return category.dhikrs.any((dhikr) =>
          dhikr.text.toLowerCase().contains(lowerQuery)
        );
      }

      return false;
    }).toList();
  }

  /// Get grouped categories (organized by main themes)
  Map<String, List<DhikrCategory>> getGroupedCategories() {
    final Map<String, List<DhikrCategory>> groups = {
      'أذكار يومية': [],
      'أذكار الصلاة': [],
      'أذكار المنزل': [],
      'أذكار السفر': [],
      'أذكار الطعام': [],
      'أذكار النوم والاستيقاظ': [],
      'أذكار متنوعة': [],
    };

    for (var category in _allCategories) {
      final catName = category.category.toLowerCase();

      if (catName.contains('صباح') || catName.contains('مساء')) {
        groups['أذكار يومية']!.add(category);
      } else if (catName.contains('صلاة') || catName.contains('صلوة')) {
        groups['أذكار الصلاة']!.add(category);
      } else if (catName.contains('منزل') || catName.contains('بيت') || catName.contains('دخول') || catName.contains('خروج')) {
        groups['أذكار المنزل']!.add(category);
      } else if (catName.contains('سفر') || catName.contains('ركوب')) {
        groups['أذكار السفر']!.add(category);
      } else if (catName.contains('طعام') || catName.contains('أكل') || catName.contains('شرب')) {
        groups['أذكار الطعام']!.add(category);
      } else if (catName.contains('نوم') || catName.contains('استيقاظ')) {
        groups['أذكار النوم والاستيقاظ']!.add(category);
      } else {
        groups['أذكار متنوعة']!.add(category);
      }
    }

    // Remove empty groups
    groups.removeWhere((key, value) => value.isEmpty);

    return groups;
  }

  /// Reset all counters
  void resetAllCounters() {
    for (var category in _allCategories) {
      category.resetAll();
    }
    debugPrint('🔄 All azkar counters reset');
  }

  /// Reset counters for a specific category
  void resetCategoryCounters(int categoryId) {
    final category = getCategoryById(categoryId);
    if (category != null) {
      category.resetAll();
      debugPrint('🔄 Reset counters for category: ${category.category}');
    }
  }

  /// Manually check if it's a new day and reset if needed
  /// Call this when app resumes from background
  Future<void> checkForNewDay() async {
    await _checkAndResetForNewDay();
  }
}
