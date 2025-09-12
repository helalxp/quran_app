// lib/constants/juz_mappings.dart - Correct Juz to page mappings

/// Standard Juz (Para) to page mappings for Quran
/// These are the traditional starting pages for each Juz in most Mushaf layouts
class JuzMappings {
  
  /// Map of Juz number to starting page number
  /// Based on standard 604-page Mushaf layout
  static const Map<int, int> juzToPage = {
    1: 1,     // Al-Fatiha 1:1
    2: 22,    // Al-Baqarah 2:142  
    3: 42,    // Al-Baqarah 2:253
    4: 62,    // Aal-e-Imran 3:93
    5: 82,    // An-Nisa 4:24
    6: 102,   // An-Nisa 4:148
    7: 122,   // Al-Ma'idah 5:82
    8: 142,   // Al-An'am 6:111
    9: 162,   // Al-A'raf 7:88
    10: 182,  // Al-Anfal 8:41
    11: 202,  // At-Taubah 9:93
    12: 222,  // Hud 11:6
    13: 242,  // Yusuf 12:53
    14: 262,  // Ibrahim 14:6
    15: 282,  // Al-Hijr 15:1
    16: 302,  // An-Nahl 16:51
    17: 322,  // Al-Isra 17:1
    18: 342,  // Al-Kahf 18:75
    19: 362,  // Maryam 19:59
    20: 382,  // Ta-Ha 20:136
    21: 402,  // Al-Anbiya 21:1
    22: 422,  // Al-Hajj 22:1
    23: 442,  // Al-Mu'minun 23:1
    24: 462,  // An-Nur 24:21
    25: 482,  // Al-Furqan 25:21
    26: 502,  // Ash-Shu'ara 26:111
    27: 522,  // An-Naml 27:56
    28: 542,  // Al-Qasas 28:51
    29: 562,  // Al-Ankabut 29:46
    30: 582,  // Ar-Rum 30:54
  };
  
  /// Get the starting page for a specific Juz
  /// Returns null if juz number is invalid
  static int? getJuzStartPage(int juzNumber) {
    if (juzNumber < 1 || juzNumber > 30) {
      return null;
    }
    return juzToPage[juzNumber];
  }
  
  /// Get the Juz number for a specific page
  /// Returns the Juz that contains the given page
  static int getJuzForPage(int pageNumber) {
    if (pageNumber < 1) return 1;
    if (pageNumber > 604) return 30;
    
    // Find the juz that contains this page
    for (int juz = 30; juz >= 1; juz--) {
      final startPage = juzToPage[juz];
      if (startPage != null && pageNumber >= startPage) {
        return juz;
      }
    }
    return 1; // Fallback to first juz
  }
  
  /// Get all juz start pages as a list for easy iteration
  static List<int> getAllJuzStartPages() {
    return List.generate(30, (index) => juzToPage[index + 1]!);
  }
  
  /// Get juz name in Arabic
  static String getJuzName(int juzNumber) {
    if (juzNumber < 1 || juzNumber > 30) {
      return 'الجزء غير صحيح';
    }
    return 'الجزء $juzNumber';
  }
  
  /// Validate if a juz number is valid
  static bool isValidJuzNumber(int juzNumber) {
    return juzNumber >= 1 && juzNumber <= 30;
  }
}