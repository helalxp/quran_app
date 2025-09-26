// lib/constants/quran_data.dart

import '../audio_download_manager.dart';

/// Static data about Quran structure for download management
class QuranData {
  // Private constructor to prevent instantiation
  QuranData._();
  
  /// Number of ayahs in each surah (index 0 = Surah 1, etc.)
  static const List<int> ayahCounts = [
    7,    // Al-Fatiha
    286,  // Al-Baqarah
    200,  // Ali 'Imran
    176,  // An-Nisa
    120,  // Al-Ma'idah
    165,  // Al-An'am
    206,  // Al-A'raf
    75,   // Al-Anfal
    129,  // At-Tawbah
    109,  // Yunus
    123,  // Hud
    111,  // Yusuf
    43,   // Ar-Ra'd
    52,   // Ibrahim
    99,   // Al-Hijr
    128,  // An-Nahl
    111,  // Al-Isra
    110,  // Al-Kahf
    98,   // Maryam
    135,  // Ta-Ha
    112,  // Al-Anbiya
    78,   // Al-Hajj
    118,  // Al-Mu'minun
    64,   // An-Nur
    77,   // Al-Furqan
    227,  // Ash-Shu'ara
    93,   // An-Naml
    88,   // Al-Qasas
    69,   // Al-'Ankabut
    60,   // Ar-Rum
    34,   // Luqman
    30,   // As-Sajdah
    73,   // Al-Ahzab
    54,   // Saba
    45,   // Fatir
    83,   // Ya-Sin
    182,  // As-Saffat
    88,   // Sad
    75,   // Az-Zumar
    85,   // Ghafir
    54,   // Fussilat
    53,   // Ash-Shura
    89,   // Az-Zukhruf
    59,   // Ad-Dukhan
    37,   // Al-Jathiyah
    35,   // Al-Ahqaf
    38,   // Muhammad
    29,   // Al-Fath
    18,   // Al-Hujurat
    45,   // Qaf
    60,   // Adh-Dhariyat
    49,   // At-Tur
    62,   // An-Najm
    55,   // Al-Qamar
    78,   // Ar-Rahman
    96,   // Al-Waqi'ah
    29,   // Al-Hadid
    22,   // Al-Mujadila
    24,   // Al-Hashr
    13,   // Al-Mumtahanah
    14,   // As-Saff
    11,   // Al-Jumu'ah
    11,   // Al-Munafiqun
    18,   // At-Taghabun
    12,   // At-Talaq
    12,   // At-Tahrim
    30,   // Al-Mulk
    52,   // Al-Qalam
    44,   // Al-Haqqah
    42,   // Al-Ma'arij
    28,   // Nuh
    28,   // Al-Jinn
    20,   // Al-Muzzammil
    56,   // Al-Muddaththir
    40,   // Al-Qiyamah
    31,   // Al-Insan
    50,   // Al-Mursalat
    40,   // An-Naba
    46,   // An-Nazi'at
    42,   // 'Abasa
    29,   // At-Takwir
    19,   // Al-Infitar
    36,   // Al-Mutaffifin
    25,   // Al-Inshiqaq
    22,   // Al-Buruj
    17,   // At-Tariq
    19,   // Al-A'la
    26,   // Al-Ghashiyah
    30,   // Al-Fajr
    20,   // Al-Balad
    15,   // Ash-Shams
    21,   // Al-Layl
    11,   // Ad-Duha
    8,    // Ash-Sharh
    8,    // At-Tin
    19,   // Al-'Alaq
    5,    // Al-Qadr
    8,    // Al-Bayyinah
    8,    // Az-Zalzalah
    11,   // Al-'Adiyat
    11,   // Al-Qari'ah
    8,    // At-Takathur
    3,    // Al-'Asr
    9,    // Al-Humazah
    5,    // Al-Fil
    4,    // Quraysh
    7,    // Al-Ma'un
    3,    // Al-Kawthar
    6,    // Al-Kafirun
    3,    // An-Nasr
    5,    // Al-Masad
    4,    // Al-Ikhlas
    5,    // Al-Falaq
    6,    // An-Nas
  ];

  /// Juz (Para) boundaries - mapping of Juz number to starting surah and ayah
  static const Map<int, JuzInfo> juzBoundaries = {
    1: JuzInfo(startSurah: 1, startAyah: 1, endSurah: 2, endAyah: 141),
    2: JuzInfo(startSurah: 2, startAyah: 142, endSurah: 2, endAyah: 252),
    3: JuzInfo(startSurah: 2, startAyah: 253, endSurah: 3, endAyah: 92),
    4: JuzInfo(startSurah: 3, startAyah: 93, endSurah: 4, endAyah: 23),
    5: JuzInfo(startSurah: 4, startAyah: 24, endSurah: 4, endAyah: 147),
    6: JuzInfo(startSurah: 4, startAyah: 148, endSurah: 5, endAyah: 81),
    7: JuzInfo(startSurah: 5, startAyah: 82, endSurah: 6, endAyah: 110),
    8: JuzInfo(startSurah: 6, startAyah: 111, endSurah: 7, endAyah: 87),
    9: JuzInfo(startSurah: 7, startAyah: 88, endSurah: 8, endAyah: 40),
    10: JuzInfo(startSurah: 8, startAyah: 41, endSurah: 9, endAyah: 92),
    11: JuzInfo(startSurah: 9, startAyah: 93, endSurah: 11, endAyah: 5),
    12: JuzInfo(startSurah: 11, startAyah: 6, endSurah: 12, endAyah: 52),
    13: JuzInfo(startSurah: 12, startAyah: 53, endSurah: 14, endAyah: 52),
    14: JuzInfo(startSurah: 15, startAyah: 1, endSurah: 16, endAyah: 128),
    15: JuzInfo(startSurah: 17, startAyah: 1, endSurah: 18, endAyah: 74),
    16: JuzInfo(startSurah: 18, startAyah: 75, endSurah: 20, endAyah: 135),
    17: JuzInfo(startSurah: 21, startAyah: 1, endSurah: 22, endAyah: 78),
    18: JuzInfo(startSurah: 23, startAyah: 1, endSurah: 25, endAyah: 20),
    19: JuzInfo(startSurah: 25, startAyah: 21, endSurah: 27, endAyah: 55),
    20: JuzInfo(startSurah: 27, startAyah: 56, endSurah: 29, endAyah: 45),
    21: JuzInfo(startSurah: 29, startAyah: 46, endSurah: 33, endAyah: 30),
    22: JuzInfo(startSurah: 33, startAyah: 31, endSurah: 36, endAyah: 27),
    23: JuzInfo(startSurah: 36, startAyah: 28, endSurah: 39, endAyah: 31),
    24: JuzInfo(startSurah: 39, startAyah: 32, endSurah: 41, endAyah: 46),
    25: JuzInfo(startSurah: 41, startAyah: 47, endSurah: 45, endAyah: 37),
    26: JuzInfo(startSurah: 46, startAyah: 1, endSurah: 51, endAyah: 30),
    27: JuzInfo(startSurah: 51, startAyah: 31, endSurah: 57, endAyah: 29),
    28: JuzInfo(startSurah: 58, startAyah: 1, endSurah: 66, endAyah: 12),
    29: JuzInfo(startSurah: 67, startAyah: 1, endSurah: 77, endAyah: 50),
    30: JuzInfo(startSurah: 78, startAyah: 1, endSurah: 114, endAyah: 6),
  };

  /// Get number of ayahs in a surah
  static int getAyahCountForSurah(int surahNumber) {
    if (surahNumber < 1 || surahNumber > ayahCounts.length) {
      throw ArgumentError('Invalid surah number: $surahNumber');
    }
    return ayahCounts[surahNumber - 1];
  }

  /// Get all ayahs for a specific juz
  static List<AyahInfo> getAyahsForJuz(int juzNumber) {
    if (juzNumber < 1 || juzNumber > 30) {
      throw ArgumentError('Invalid juz number: $juzNumber');
    }

    final juzInfo = juzBoundaries[juzNumber]!;
    final List<AyahInfo> ayahs = [];

    for (int surah = juzInfo.startSurah; surah <= juzInfo.endSurah; surah++) {
      final startAyah = (surah == juzInfo.startSurah) ? juzInfo.startAyah : 1;
      final endAyah = (surah == juzInfo.endSurah) ? juzInfo.endAyah : getAyahCountForSurah(surah);

      for (int ayah = startAyah; ayah <= endAyah; ayah++) {
        ayahs.add(AyahInfo(surah: surah, ayah: ayah));
      }
    }

    return ayahs;
  }

  /// Get total number of ayahs in the Quran
  static int get totalAyahs => ayahCounts.fold(0, (sum, count) => sum + count);

  /// Get juz number for a specific ayah
  static int getJuzForAyah(int surah, int ayah) {
    for (final entry in juzBoundaries.entries) {
      final juzNumber = entry.key;
      final juzInfo = entry.value;
      
      // Check if ayah falls within this juz
      if ((surah > juzInfo.startSurah || (surah == juzInfo.startSurah && ayah >= juzInfo.startAyah)) &&
          (surah < juzInfo.endSurah || (surah == juzInfo.endSurah && ayah <= juzInfo.endAyah))) {
        return juzNumber;
      }
    }
    
    throw ArgumentError('Invalid surah:ayah combination: $surah:$ayah');
  }

  /// Check if surah number is valid
  static bool isValidSurah(int surahNumber) {
    return surahNumber >= 1 && surahNumber <= ayahCounts.length;
  }

  /// Check if ayah number is valid for a surah
  static bool isValidAyah(int surahNumber, int ayahNumber) {
    if (!isValidSurah(surahNumber)) return false;
    return ayahNumber >= 1 && ayahNumber <= getAyahCountForSurah(surahNumber);
  }

  /// Check if juz number is valid
  static bool isValidJuz(int juzNumber) {
    return juzNumber >= 1 && juzNumber <= 30;
  }

  /// Get surah name in Arabic (you can expand this)
  static String getSurahNameArabic(int surahNumber) {
    const surahNames = [
      'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة', 'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
      // Add all 114 surah names...
      // This is a simplified version - you should add all surah names
      // remove this since we going to make a new file
    ];

    if (surahNumber < 1 || surahNumber > surahNames.length) {
      return 'سورة $surahNumber'; // Fallback
    }

    return surahNames[surahNumber - 1];
  }
}

/// Information about a Juz (Para)
class JuzInfo {
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;

  const JuzInfo({
    required this.startSurah,
    required this.startAyah,
    required this.endSurah,
    required this.endAyah,
  });
}