// lib/utils/input_sanitizer.dart


/// Comprehensive input sanitization utility for security and data integrity
class InputSanitizer {
  // Private constructor to prevent instantiation
  InputSanitizer._();

  // Character limits for different input types
  static const int maxTextLength = 1000;
  static const int maxNumberLength = 10;
  static const int maxSearchLength = 200;

  /// Sanitize general text input
  static String sanitizeText(String? input, {int? maxLength}) {
    if (input == null || input.isEmpty) return '';

    String sanitized = input.trim();

    // Remove potentially dangerous characters
    sanitized = _removeDangerousChars(sanitized);

    // Normalize whitespace
    sanitized = _normalizeWhitespace(sanitized);

    // Apply length limit
    final limit = maxLength ?? maxTextLength;
    if (sanitized.length > limit) {
      sanitized = sanitized.substring(0, limit).trim();
    }

    return sanitized;
  }

  /// Sanitize numeric input with range validation
  static int? sanitizeNumber(String? input, {int? min, int? max}) {
    if (input == null || input.isEmpty) return null;

    String sanitized = input.trim();

    // Remove non-numeric characters except minus sign
    sanitized = sanitized.replaceAll(RegExp(r'[^\d-]'), '');

    // Limit length to prevent overflow
    if (sanitized.length > maxNumberLength) {
      sanitized = sanitized.substring(0, maxNumberLength);
    }

    try {
      int number = int.parse(sanitized);

      // Apply range constraints
      if (min != null) number = number < min ? min : number;
      if (max != null) number = number > max ? max : number;

      return number;
    } catch (e) {
      return null;
    }
  }

  /// Sanitize ayah number input (1-286 for verses)
  static int? sanitizeAyahNumber(String? input, int maxAyah) {
    return sanitizeNumber(input, min: 1, max: maxAyah);
  }

  /// Sanitize surah number input (1-114)
  static int? sanitizeSurahNumber(String? input) {
    return sanitizeNumber(input, min: 1, max: 114);
  }

  /// Sanitize juz number input (1-30)
  static int? sanitizeJuzNumber(String? input) {
    return sanitizeNumber(input, min: 1, max: 30);
  }

  /// Sanitize page number input (1-604)
  static int? sanitizePageNumber(String? input) {
    return sanitizeNumber(input, min: 1, max: 604);
  }

  /// Sanitize search query
  static String sanitizeSearchQuery(String? input) {
    if (input == null || input.isEmpty) return '';

    String sanitized = input.trim();

    // Remove dangerous characters but preserve Arabic text and spaces
    sanitized = sanitized.replaceAll(RegExp(r'[<>"\\;(){}|`~]'), '');

    // Normalize whitespace
    sanitized = _normalizeWhitespace(sanitized);

    // Apply search-specific length limit
    if (sanitized.length > maxSearchLength) {
      sanitized = sanitized.substring(0, maxSearchLength).trim();
    }

    return sanitized;
  }

  /// Sanitize file path input (for settings, bookmarks, etc.)
  static String? sanitizeFilePath(String? input) {
    if (input == null || input.isEmpty) return null;

    String sanitized = input.trim();

    // Remove dangerous path characters
    sanitized = sanitized.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '');

    // Remove path traversal attempts
    sanitized = sanitized.replaceAll(RegExp(r'\.\.[\\/]'), '');
    sanitized = sanitized.replaceAll('..\\', '');
    sanitized = sanitized.replaceAll('../', '');

    // Normalize path separators
    sanitized = sanitized.replaceAll('\\', '/');

    return sanitized.isEmpty ? null : sanitized;
  }

  /// Validate and sanitize URL input
  static String? sanitizeUrl(String? input) {
    if (input == null || input.isEmpty) return null;

    String sanitized = input.trim().toLowerCase();

    // Basic URL validation
    if (!RegExp(r'^https?://').hasMatch(sanitized)) {
      return null; // Only allow HTTP/HTTPS
    }

    // Remove dangerous characters
    sanitized = sanitized.replaceAll(RegExp(r'[<>"\\s]'), '');

    // Basic URL structure validation
    try {
      Uri.parse(sanitized);
      return sanitized;
    } catch (e) {
      return null;
    }
  }

  /// Remove potentially dangerous characters
  static String _removeDangerousChars(String input) {
    // Remove control characters and dangerous symbols
    return input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F<>"\\\/;]'), '');
  }

  /// Normalize whitespace (replace multiple spaces with single space)
  static String _normalizeWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Validate Arabic text (for Quran-specific inputs)
  static bool isValidArabicText(String input) {
    if (input.isEmpty) return true;

    // Allow Arabic characters, spaces, punctuation, and numbers
    return RegExp(r'^[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\s\d\p{Punctuation}]+$',
                 unicode: true).hasMatch(input);
  }

  /// Create sanitized input validator for TextFormField
  static String? Function(String?) createValidator({
    required String fieldName,
    bool required = false,
    int? minLength,
    int? maxLength,
    int? minValue,
    int? maxValue,
    bool isNumeric = false,
    bool isArabicOnly = false,
  }) {
    return (String? value) {
      // Check if required
      if (required && (value == null || value.trim().isEmpty)) {
        return 'حقل $fieldName مطلوب';
      }

      if (value == null || value.trim().isEmpty) {
        return null; // Valid if not required and empty
      }

      String sanitized;

      if (isNumeric) {
        final number = sanitizeNumber(value, min: minValue, max: maxValue);
        if (number == null) {
          return 'يجب إدخال رقم صحيح في حقل $fieldName';
        }
        if (minValue != null && number < minValue) {
          return 'يجب أن يكون $fieldName أكبر من أو يساوي $minValue';
        }
        if (maxValue != null && number > maxValue) {
          return 'يجب أن يكون $fieldName أقل من أو يساوي $maxValue';
        }
        sanitized = number.toString();
      } else {
        sanitized = sanitizeText(value, maxLength: maxLength);
      }

      // Check length constraints
      if (minLength != null && sanitized.length < minLength) {
        return 'يجب أن يكون $fieldName على الأقل $minLength حروف';
      }

      if (maxLength != null && sanitized.length > maxLength) {
        return 'يجب أن يكون $fieldName أقل من $maxLength حرف';
      }

      // Check Arabic text if required
      if (isArabicOnly && !isValidArabicText(sanitized)) {
        return 'يجب إدخال نص عربي صحيح في حقل $fieldName';
      }

      return null; // Valid input
    };
  }

  /// Real-time input formatter for TextFormField
  static String formatInput(String input, {
    bool isNumeric = false,
    int? maxLength,
    bool arabicOnly = false,
  }) {
    if (input.isEmpty) return input;

    String formatted = input;

    if (isNumeric) {
      // Keep only digits
      formatted = formatted.replaceAll(RegExp(r'[^\d]'), '');
    } else if (arabicOnly) {
      // Keep only Arabic characters, spaces, and numbers
      formatted = formatted.replaceAll(
        RegExp(r'[^\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\s\d]'),
        '',
      );
    }

    // Apply length limit
    if (maxLength != null && formatted.length > maxLength) {
      formatted = formatted.substring(0, maxLength);
    }

    return formatted;
  }
}

/// Input formatters for common use cases
class QuranInputFormatters {
  /// Formatter for ayah numbers
  static String formatAyahNumber(String input, int maxAyah) {
    return InputSanitizer.formatInput(input, isNumeric: true, maxLength: 3);
  }

  /// Formatter for surah numbers
  static String formatSurahNumber(String input) {
    return InputSanitizer.formatInput(input, isNumeric: true, maxLength: 3);
  }

  /// Formatter for search queries
  static String formatSearchQuery(String input) {
    return InputSanitizer.formatInput(input, maxLength: 200);
  }

  /// Formatter for Arabic text
  static String formatArabicText(String input) {
    return InputSanitizer.formatInput(input, arabicOnly: true, maxLength: 1000);
  }
}