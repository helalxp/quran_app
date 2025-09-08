// lib/data/app_data.dart - Centralized App Configuration Data

class ReciterConfig {
  final String baseUrl;
  final bool hasIndividualAyahs;
  final String? fallbackUrl;

  const ReciterConfig({
    required this.baseUrl,
    this.hasIndividualAyahs = true,
    this.fallbackUrl,
  });
}

class TafsirSource {
  final String id;
  final String nameArabic;
  final String nameEnglish;
  final String apiEndpoint;

  const TafsirSource({
    required this.id,
    required this.nameArabic,
    required this.nameEnglish,
    required this.apiEndpoint,
  });
}

class AppData {
  // Audio Reciters Configuration
  static const Map<String, ReciterConfig> reciters = {
    // Abdul Basit Abdul Samad
    'عبد الباسط عبد الصمد': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Abdul_Basit_Murattal_192kbps',
      hasIndividualAyahs: true,
      fallbackUrl: 'https://www.everyayah.com/data/AbdulSamad_64kbps_QuranCentral.com',
    ),

    // Mishary Rashid Alafasy
    'مشاري العفاسي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Alafasy_128kbps',
      hasIndividualAyahs: true,
      fallbackUrl: 'https://www.everyayah.com/data/Alafasy_64kbps',
    ),

    // Muhammad Siddiq Al-Minshawi
    'محمد صديق المنشاوي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Minshawi_Murattal_128kbps',
      hasIndividualAyahs: true,
    ),

    // Saud Ash-Shuraim
    'سعود الشريم': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Shatri_128kbps',
      hasIndividualAyahs: true,
    ),

    // Abdul Rahman As-Sudais
    'عبد الرحمن السديس': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Sudais_128kbps',
      hasIndividualAyahs: true,
    ),

    // Maher Al Muaiqly
    'ماهر المعيقلي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/MaherAlMuaiqly128kbps',
      hasIndividualAyahs: true,
    ),

    // Ahmad Al Ajmi
    'أحمد العجمي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      hasIndividualAyahs: true,
    ),

    // Muhammad Ayyub
    'محمد أيوب': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Muhammad_Ayyoub_128kbps',
      hasIndividualAyahs: true,
      fallbackUrl: 'https://www.everyayah.com/data/Muhammad_Ayyoub_64kbps',
    ),

    // Abdullah Al Matroud
    'عبد الله المطرود': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Abdullah_Matroud_128kbps',
      hasIndividualAyahs: true,
    ),

    // Khalid Al Qahtani
    'خالد القحطاني': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Khalid_Al-Qahtani_192kbps',
      hasIndividualAyahs: true,
    ),

    // Nasser Al Qatami
    'ناصر القطامي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Nasser_Alqatami_128kbps',
      hasIndividualAyahs: true,
    ),

    // Saad Al Ghamdi
    'سعد الغامدي': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Ghamadi_40kbps',
      hasIndividualAyahs: true,
    ),

    // Mahmoud Khalil Al-Hussary
    'محمود خليل الحصري': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Husary_128kbps',
      hasIndividualAyahs: true,
      fallbackUrl: 'https://www.everyayah.com/data/Husary_64kbps',
    ),

    // Yasser Al Dosari
    'ياسر الدوسري': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Yasser_Ad-Dussary_128kbps',
      hasIndividualAyahs: true,
    ),

    // Ahmed Neana
    'أحمد نعينع': ReciterConfig(
      baseUrl: 'https://www.everyayah.com/data/Ahmed_Neana_128kbps',
      hasIndividualAyahs: true,
    ),
  };

  // Tafsir Sources Configuration
  static const List<TafsirSource> tafsirSources = [
    TafsirSource(
      id: 'jalalayn',
      nameArabic: 'تفسير الجلالين',
      nameEnglish: 'Tafsir al-Jalalayn',
      apiEndpoint: 'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/ar.jalalayn',
    ),
    TafsirSource(
      id: 'tabari',
      nameArabic: 'تفسير الطبري',
      nameEnglish: 'Tafsir at-Tabari',
      apiEndpoint: 'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/ar.tabari',
    ),
    TafsirSource(
      id: 'kathir',
      nameArabic: 'تفسير ابن كثير',
      nameEnglish: 'Tafsir Ibn Kathir',
      apiEndpoint: 'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/ar.kathir',
    ),
    TafsirSource(
      id: 'baghawi',
      nameArabic: 'تفسير البغوي',
      nameEnglish: 'Tafsir al-Baghawi',
      apiEndpoint: 'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/ar.baghawi',
    ),
    TafsirSource(
      id: 'qurtubi',
      nameArabic: 'تفسير القرطبي',
      nameEnglish: 'Tafsir al-Qurtubi',
      apiEndpoint: 'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/ar.qurtubi',
    ),
    TafsirSource(
      id: 'saadi',
      nameArabic: 'تفسير السعدي',
      nameEnglish: 'Tafsir as-Saadi',
      apiEndpoint: 'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/ar.saadi',
    ),
  ];

  // Translation Sources Configuration
  static const Map<String, Map<String, String>> translationSources = {
    'english': {
      'name': 'English Translation',
      'nameArabic': 'الترجمة الإنجليزية',
      'endpoint': 'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/en.sahih',
    },
    'french': {
      'name': 'French Translation',
      'nameArabic': 'الترجمة الفرنسية',
      'endpoint': 'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/fr.hamidullah',
    },
    'urdu': {
      'name': 'Urdu Translation',
      'nameArabic': 'الترجمة الأردية',
      'endpoint': 'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/ur.ahmedali',
    },
  };

  // App Configuration
  static const Map<String, dynamic> appConfig = {
    'version': '1.0.0',
    'totalPages': 604,
    'totalSurahs': 114,
    'totalJuz': 30,
    'cacheExpiryHours': 24,
    'maxCacheSize': 100, // MB
    'defaultReciter': 'عبد الباسط عبد الصمد',
    'defaultTafsirSource': 'jalalayn',
    'playbackSpeeds': [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    'maxConsecutiveErrors': 5,
    'audioTimeoutSeconds': 15,
  };

  // Helper methods
  static List<String> getReciterNames() {
    return reciters.keys.toList();
  }

  static ReciterConfig? getReciterConfig(String name) {
    return reciters[name];
  }

  static String getDefaultReciter() {
    return appConfig['defaultReciter'] as String;
  }

  static List<TafsirSource> getTafsirSources() {
    return tafsirSources;
  }

  static TafsirSource? getTafsirSource(String id) {
    try {
      return tafsirSources.firstWhere((source) => source.id == id);
    } catch (e) {
      return null;
    }
  }

  static TafsirSource getDefaultTafsirSource() {
    final defaultId = appConfig['defaultTafsirSource'] as String;
    return getTafsirSource(defaultId) ?? tafsirSources.first;
  }

  static List getPlaybackSpeeds() {
    return (appConfig['playbackSpeeds'] as List<dynamic>)
        .map((speed) => speed.toDouble())
        .toList();
  }

  static int getTotalPages() {
    return appConfig['totalPages'] as int;
  }

  static int getCacheExpiryHours() {
    return appConfig['cacheExpiryHours'] as int;
  }

  static int getMaxCacheSize() {
    return appConfig['maxCacheSize'] as int;
  }

  static int getMaxConsecutiveErrors() {
    return appConfig['maxConsecutiveErrors'] as int;
  }

  static int getAudioTimeoutSeconds() {
    return appConfig['audioTimeoutSeconds'] as int;
  }

  // Validation helpers
  static bool isValidReciter(String name) {
    return reciters.containsKey(name);
  }

  static bool isValidTafsirSource(String id) {
    return tafsirSources.any((source) => source.id == id);
  }
}