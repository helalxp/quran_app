// lib/utils/arabic_search_utils.dart - Utilities for forgiving Arabic text search

/// Utilities for searching Arabic text with forgiveness for similar letters
/// and diacritics
class ArabicSearchUtils {
  // Private constructor to prevent instantiation
  ArabicSearchUtils._();

  /// Normalize Arabic text for forgiving search
  /// - Removes diacritics (harakat/tashkeel)
  /// - Normalizes similar letters:
  ///   - ا أ إ آ ٱ → ا
  ///   - ة ه → ه
  ///   - ى ي → ي
  /// - Converts Arabic-Indic numerals to Latin numerals
  /// - Removes extra spaces
  /// - Converts to lowercase (for English parts)
  static String normalize(String text) {
    if (text.isEmpty) return text;

    String normalized = text;

    // Remove all Arabic diacritics (harakat/tashkeel)
    // Unicode ranges for Arabic diacritics:
    // \u064B-\u065F: Main diacritics (fatha, damma, kasra, sukun, shadda, etc.)
    // \u0670: Superscript alef
    // \u0674-\u0678: High hamza variations
    // \u06D6-\u06DC: Quranic annotation marks
    // \u06DF-\u06E4: Additional marks
    // \u06E7-\u06E8: Quranic pause marks
    // \u06EA-\u06ED: More marks
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0674-\u0678\u06D6-\u06DC\u06DF-\u06E4\u06E7-\u06E8\u06EA-\u06ED]'), '');

    // Normalize Alef variations to simple Alef (ا)
    // أ (Alef with hamza above) → ا
    // إ (Alef with hamza below) → ا
    // آ (Alef with madda) → ا
    // ٱ (Alef wasla) → ا
    normalized = normalized.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

    // Normalize Ta Marbuta (ة) and Ha (ه)
    // Both become Ha (ه) for search flexibility
    normalized = normalized.replaceAll('ة', 'ه');

    // Normalize Alef Maksura (ى) to Ya (ي)
    normalized = normalized.replaceAll('ى', 'ي');

    // Convert Arabic-Indic numerals (Eastern Arabic numerals) to Latin numerals
    // ٠١٢٣٤٥٦٧٨٩ → 0123456789
    const arabicNumerals = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabicNumerals.length; i++) {
      normalized = normalized.replaceAll(arabicNumerals[i], i.toString());
    }

    // Normalize all whitespace to single space and trim
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Convert to lowercase for English text parts
    normalized = normalized.toLowerCase();

    return normalized;
  }

  /// Check if the query matches the text using forgiving Arabic search
  /// Returns true if the normalized query is found in the normalized text
  static bool matches(String text, String query) {
    if (query.isEmpty) return true;
    if (text.isEmpty) return false;

    final normalizedText = normalize(text);
    final normalizedQuery = normalize(query);

    return normalizedText.contains(normalizedQuery);
  }

  /// Check if the query matches the text at word boundaries
  /// Useful for more precise matching when needed
  static bool matchesWord(String text, String query) {
    if (query.isEmpty) return true;
    if (text.isEmpty) return false;

    final normalizedText = normalize(text);
    final normalizedQuery = normalize(query);

    // Split into words and check if any word starts with the query
    final words = normalizedText.split(' ');
    return words.any((word) => word.startsWith(normalizedQuery));
  }

  /// Get a relevance score for sorting search results
  /// Higher score = better match
  /// - Exact match at start: highest score
  /// - Word boundary match: high score
  /// - Contains match: medium score
  static int getRelevanceScore(String text, String query) {
    if (query.isEmpty) return 0;
    if (text.isEmpty) return -1;

    final normalizedText = normalize(text);
    final normalizedQuery = normalize(query);

    // Exact match at the start of text
    if (normalizedText.startsWith(normalizedQuery)) {
      return 1000;
    }

    // Match at word boundary
    final words = normalizedText.split(' ');
    for (int i = 0; i < words.length; i++) {
      if (words[i].startsWith(normalizedQuery)) {
        // Earlier words get higher scores
        return 500 - (i * 50);
      }
    }

    // Contains match anywhere
    if (normalizedText.contains(normalizedQuery)) {
      // Earlier position gets higher score
      final position = normalizedText.indexOf(normalizedQuery);
      return 100 - (position ~/ 10);
    }

    return -1; // No match
  }

  /// Filter a list of items based on a search query
  /// The [getText] function extracts the searchable text from each item
  static List<T> filter<T>(
    List<T> items,
    String query,
    String Function(T item) getText,
  ) {
    if (query.isEmpty) return items;

    return items.where((item) {
      final text = getText(item);
      return matches(text, query);
    }).toList();
  }

  /// Filter and sort a list of items based on relevance to the search query
  /// The [getText] function extracts the searchable text from each item
  static List<T> filterAndSort<T>(
    List<T> items,
    String query,
    String Function(T item) getText,
  ) {
    if (query.isEmpty) return items;

    // Create list of items with their relevance scores
    final itemsWithScores = items.map((item) {
      final text = getText(item);
      final score = getRelevanceScore(text, query);
      return {'item': item, 'score': score};
    }).where((entry) => (entry['score'] as int) >= 0).toList();

    // Sort by relevance score (highest first)
    itemsWithScores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    // Return just the items
    return itemsWithScores.map((entry) => entry['item'] as T).toList();
  }
}
