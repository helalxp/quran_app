// lib/constants/juz_mappings.dart - Correct Juz to page mappings


class JuzMappings {
  
  /// Map of Juz number to starting page number
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
  

  /// Traditional Arabic names for each Juz based on their starting verses
  static const Map<int, String> juzNames = {
    1: 'الم',
    2: 'سيقول',
    3: 'تلك الرسل',
    4: 'لن تنالوا',
    5: 'والمحصنات',
    6: 'لا يحب الله',
    7: 'وإذا سمعوا',
    8: 'ولو أننا',
    9: 'قال الملأ',
    10: 'واعلموا',
    11: 'يعتذرون',
    12: 'وما من دابة',
    13: 'وما أبرئ',
    14: 'ربما',
    15: 'سبحان',
    16: 'قال ألم',
    17: 'اقترب',
    18: 'قد أفلح',
    19: 'وقال الذين',
    20: 'أمّن خلق',
    21: 'اتل ما أوحي',
    22: 'ومن يقنت',
    23: 'ومالي',
    24: 'فمن أظلم',
    25: 'إليه يرد',
    26: 'حم',
    27: 'قال فما خطبكم',
    28: 'قد سمع',
    29: 'تبارك',
    30: 'عم',
  };

  /// Get juz name in Arabic with traditional name
  static String getJuzName(int juzNumber) {
    if (juzNumber < 1 || juzNumber > 30) {
      return 'الجزء غير صحيح';
    }
    return juzNames[juzNumber] ?? 'الجزء $juzNumber';
  }

  /// Get full juz name with number (e.g., "الجزء 1 - الم")
  static String getJuzFullName(int juzNumber) {
    if (juzNumber < 1 || juzNumber > 30) {
      return 'الجزء غير صحيح';
    }
    final name = juzNames[juzNumber];
    return name != null ? 'الجزء $juzNumber - $name' : 'الجزء $juzNumber';
  }
  
  /// Validate if a juz number is valid
  static bool isValidJuzNumber(int juzNumber) {
    return juzNumber >= 1 && juzNumber <= 30;
  }
}