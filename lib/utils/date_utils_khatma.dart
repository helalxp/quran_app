// lib/utils/date_utils_khatma.dart

/// Date utilities for Khatma system
class DateUtilsKhatma {
  /// Format date as date key (yyyy-MM-dd)
  static String formatDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }

  /// Get today's date key
  static String getTodayKey() {
    return formatDateKey(DateTime.now());
  }

  /// Get normalized date (without time component)
  static DateTime getNormalizedDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get today's normalized date
  static DateTime getToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Format date for display (e.g., "15 يناير")
  static String formatDateDisplay(DateTime date) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  /// Check if a date is today
  static bool isToday(DateTime date) {
    final today = getToday();
    final normalized = getNormalizedDate(date);
    return normalized.isAtSameMomentAs(today);
  }

  /// Check if a date is in the future
  static bool isFuture(DateTime date) {
    return getNormalizedDate(date).isAfter(getToday());
  }

  /// Check if a date is in the past
  static bool isPast(DateTime date) {
    return getNormalizedDate(date).isBefore(getToday());
  }
}
