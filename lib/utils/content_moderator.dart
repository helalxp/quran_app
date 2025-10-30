// lib/utils/content_moderator.dart

import 'package:flutter/foundation.dart';

/// Content moderation utility to filter inappropriate user-generated content
/// Implements basic filtering for spam, profanity, and abusive content
/// Required for Google Play Store UGC policy compliance
class ContentModerator {
  // Private constructor to prevent instantiation
  ContentModerator._();

  /// Check if content passes moderation filters
  /// Returns true if content is appropriate, false otherwise
  static bool isContentAppropriate(String text) {
    if (text.trim().isEmpty) {
      return false;
    }

    // Check for spam patterns
    if (_isSpam(text)) {
      debugPrint('⚠️ Content blocked: Spam detected');
      return false;
    }

    // Check for excessive repetition
    if (_hasExcessiveRepetition(text)) {
      debugPrint('⚠️ Content blocked: Excessive repetition');
      return false;
    }

    // Check for profanity (basic Arabic filter)
    if (_containsProfanity(text)) {
      debugPrint('⚠️ Content blocked: Profanity detected');
      return false;
    }

    // Check for suspicious URLs (potential phishing)
    if (_containsSuspiciousUrls(text)) {
      debugPrint('⚠️ Content blocked: Suspicious URLs detected');
      return false;
    }

    return true;
  }

  /// Get moderation reason if content is blocked
  static String getModerationReason(String text) {
    if (text.trim().isEmpty) {
      return 'empty_content';
    }
    if (_isSpam(text)) {
      return 'spam';
    }
    if (_hasExcessiveRepetition(text)) {
      return 'repetition';
    }
    if (_containsProfanity(text)) {
      return 'profanity';
    }
    if (_containsSuspiciousUrls(text)) {
      return 'suspicious_url';
    }
    return 'unknown';
  }

  /// Detect spam patterns
  static bool _isSpam(String text) {
    final lowerText = text.toLowerCase();

    // Check for common spam keywords
    final spamKeywords = [
      'click here',
      'free money',
      'win now',
      'buy now',
      'limited offer',
      'act now',
      'call now',
      'اضغط هنا',
      'احصل على',
      'مجاني',
      'اربح الان',
    ];

    for (final keyword in spamKeywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        return true;
      }
    }

    // Check for excessive capitalization (>70%)
    final capitals = text.replaceAll(RegExp(r'[^A-Z]'), '');
    final letters = text.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isNotEmpty && capitals.length / letters.length > 0.7) {
      return true;
    }

    // Check for excessive exclamation marks or question marks
    final exclamations = text.split('!').length - 1;
    final questions = text.split('?').length - 1;
    if (exclamations > 5 || questions > 5) {
      return true;
    }

    return false;
  }

  /// Detect excessive character repetition
  static bool _hasExcessiveRepetition(String text) {
    // Check for same character repeated more than 5 times
    final repeatedChars = RegExp(r'(.)\1{5,}');
    if (repeatedChars.hasMatch(text)) {
      return true;
    }

    // Check for same word repeated more than 3 times
    final words = text.split(RegExp(r'\s+'));
    final wordCounts = <String, int>{};
    for (final word in words) {
      if (word.length < 3) continue; // Skip short words
      final lower = word.toLowerCase();
      wordCounts[lower] = (wordCounts[lower] ?? 0) + 1;
      if (wordCounts[lower]! > 3) {
        return true;
      }
    }

    return false;
  }

  /// Basic profanity filter (Arabic focus)
  /// Note: This is a basic implementation. For production, consider using
  /// a comprehensive profanity filtering service or library
  static bool _containsProfanity(String text) {
    final lowerText = text.toLowerCase();

    // Basic list of inappropriate words (placeholder - add actual words in production)
    // Keep this list private and comprehensive
    final profanityList = [
      // Add common profanity words here
      // This is intentionally minimal for demonstration
      'كلب', // Basic example only
    ];

    for (final word in profanityList) {
      if (lowerText.contains(word)) {
        return true;
      }
    }

    return false;
  }

  /// Detect suspicious URLs that might be phishing or malicious
  static bool _containsSuspiciousUrls(String text) {
    // Pattern for URLs
    final urlPattern = RegExp(
      r'(https?:\/\/|www\.)[^\s]+',
      caseSensitive: false,
    );

    if (urlPattern.hasMatch(text)) {
      // Found URL - check if it's suspicious
      final urls = urlPattern.allMatches(text);

      for (final match in urls) {
        final url = match.group(0)?.toLowerCase() ?? '';

        // Block common phishing patterns
        if (url.contains('bit.ly') ||
            url.contains('tinyurl') ||
            url.contains('t.co') ||
            url.contains('.tk') ||
            url.contains('.ml') ||
            url.contains('.ga') ||
            url.contains('free') ||
            url.contains('prize') ||
            url.contains('win')) {
          return true;
        }
      }
    }

    return false;
  }

  /// Analyze content and return risk score (0-100)
  /// Higher score means higher risk
  static int getContentRiskScore(String text) {
    int score = 0;

    if (_isSpam(text)) score += 40;
    if (_hasExcessiveRepetition(text)) score += 30;
    if (_containsProfanity(text)) score += 50;
    if (_containsSuspiciousUrls(text)) score += 35;

    // Additional risk factors
    // Check for excessive special characters
    final specialChars = text.replaceAll(RegExp(r'[a-zA-Z0-9\s\u0600-\u06FF]'), '');
    if (specialChars.length > text.length * 0.3) score += 20;

    // Check for very short messages (potential spam)
    if (text.trim().length < 10) score += 15;

    return score.clamp(0, 100);
  }

  /// Get user-friendly rejection message in Arabic
  static String getRejectionMessage(String reason) {
    switch (reason) {
      case 'spam':
        return 'عذراً، تم رفض الرسالة لأنها تبدو كرسالة غير مرغوب فيها';
      case 'repetition':
        return 'عذراً، يحتوي النص على تكرار مفرط';
      case 'profanity':
        return 'عذراً، يحتوي النص على كلمات غير لائقة';
      case 'suspicious_url':
        return 'عذراً، يحتوي النص على روابط مشبوهة';
      case 'empty_content':
        return 'الرجاء كتابة نص صالح';
      default:
        return 'عذراً، لم يتم قبول الرسالة. الرجاء المحاولة مرة أخرى';
    }
  }
}
