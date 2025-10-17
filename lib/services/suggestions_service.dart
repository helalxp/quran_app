// lib/services/suggestions_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SuggestionsService {
  static final SuggestionsService _instance = SuggestionsService._internal();
  factory SuggestionsService() => _instance;
  SuggestionsService._internal();

  static bool _isInitialized = false;
  static FirebaseFirestore? _firestore;

  /// Initialize Firebase services
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
      debugPrint('✅ SuggestionsService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize SuggestionsService: $e');
      _isInitialized = false;
    }
  }

  /// Submit user suggestion/feedback (text only)
  /// Returns true if successful, false otherwise
  static Future<bool> submitSuggestion({
    required String message,
  }) async {
    if (!_isInitialized || _firestore == null) {
      debugPrint('❌ SuggestionsService not initialized');
      return false;
    }

    if (message.trim().isEmpty) {
      debugPrint('❌ Cannot submit empty suggestion');
      return false;
    }

    try {
      // Get app version and device info
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;

      // Prepare suggestion data
      final suggestionData = {
        'message': message.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'status': 'pending', // pending, reviewed, implemented, rejected
      };

      // Submit to Firestore
      await _firestore!.collection('suggestions').add(suggestionData);

      debugPrint('✅ Suggestion submitted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to submit suggestion: $e');
      return false;
    }
  }

  /// Get suggestion statistics (optional - for admin dashboard)
  static Future<Map<String, int>> getStatistics() async {
    if (!_isInitialized || _firestore == null) {
      return {
        'total': 0,
        'pending': 0,
        'reviewed': 0,
        'implemented': 0,
      };
    }

    try {
      final snapshot = await _firestore!.collection('suggestions').get();

      final stats = {
        'total': snapshot.docs.length,
        'pending': 0,
        'reviewed': 0,
        'implemented': 0,
      };

      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? 'pending';
        if (stats.containsKey(status)) {
          stats[status] = (stats[status] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Failed to get suggestion statistics: $e');
      return {
        'total': 0,
        'pending': 0,
        'reviewed': 0,
        'implemented': 0,
      };
    }
  }
}
