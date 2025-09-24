// lib/constants/api_constants.dart - API endpoints and configuration

/// API endpoints and configuration for external services
class ApiConstants {
  
  // Private constructor to prevent instantiation
  ApiConstants._();
  
  /// Base URLs for different API services
  static const String alquranCloudBase = 'https://api.alquran.cloud/v1';
  static const String quranComBase = 'http://api.quran-tafseer.com/tafseer/';
  static const String everyAyahBase = 'https://everyayah.com/data';
  
  /// Al-Quran Cloud API endpoints
  static String getAyahTranslation(int surah, int ayah, String edition) {
    return '$alquranCloudBase/ayah/$surah:$ayah/$edition';
  }
  
  static String getAyahSimple(int surah, int ayah) {
    return '$alquranCloudBase/ayah/$surah:$ayah';
  }
  
  /// Quran.com API endpoints  
  static String getVerseUthmani(int surah, int ayah) {
    return '$quranComBase/verses/by_key/$surah:$ayah?fields=text_uthmani';
  }
  
  static String getVerseTranslation(int surah, int ayah, int translationId) {
    return '$quranComBase$translationId/$surah/$ayah';
  }
  
  /// Mapping from API codes to Arabic reciter names
  static const Map<String, String> apiCodeToArabicName = {
    'Abdul_Basit_Murattal_192kbps': 'عبد الباسط عبد الصمد',
    'AbdulSamad_64kbps_QuranCentral.com': 'عبد الباسط عبد الصمد',
    'Alafasy_128kbps': 'مشاري راشد العفاسي',
    'Alafasy_64kbps': 'مشاري راشد العفاسي',
    'Minshawi_Murattal_128kbps': 'محمد صديق المنشاوي',
    'Shatri_128kbps': 'أبو بكر الشاطري',
    'Sudais_128kbps': 'عبد الرحمن السديس',
    'MaherAlMuaiqly128kbps': 'ماهر المعيقلي',
    'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net': 'أحمد العجمي',
    'Muhammad_Ayyoub_128kbps': 'محمد أيوب',
    'Muhammad_Ayyoub_64kbps': 'محمد أيوب',
    'Abdullah_Matroud_128kbps': 'عبد الله المطرود',
    'Khalid_Al-Qahtani_192kbps': 'خالد القحطاني',
    'Nasser_Alqatami_128kbps': 'ناصر القطامي',
    'Ghamadi_40kbps': 'سعد الغامدي',
    'Husary_128kbps': 'محمود خليل الحصري',
    'Husary_64kbps': 'محمود خليل الحصري',
    'Yasser_Ad-Dussary_128kbps': 'ياسر الدوسري',
    'Ahmed_Neana_128kbps': 'أحمد نعينع',
  };

  /// Audio reciter configurations
  static const Map<String, ReciterConfig> reciterConfigs = {
    'عبد الباسط عبد الصمد': ReciterConfig(
      baseUrl: '$everyAyahBase/Abdul_Basit_Murattal_192kbps',
      fallbackUrl: '$everyAyahBase/AbdulSamad_64kbps_QuranCentral.com',
      format: 'mp3',
    ),
    'مشاري راشد العفاسي': ReciterConfig(
      baseUrl: '$everyAyahBase/Alafasy_128kbps',
      fallbackUrl: '$everyAyahBase/Alafasy_64kbps',
      format: 'mp3',
    ),
    'محمد صديق المنشاوي': ReciterConfig(
      baseUrl: '$everyAyahBase/Minshawy_Murattal_128kbps/',
      format: 'mp3',
    ),
    'أبو بكر الشاطري': ReciterConfig(
      baseUrl: '$everyAyahBase/Abu Bakr Ash-Shaatree_128kbps/',
      format: 'mp3',
    ),
    'عبد الرحمن السديس': ReciterConfig(
      baseUrl: '$everyAyahBase/Abdurrahmaan_As-Sudais_192kbps',
      format: 'mp3',
    ),
    'ماهر المعيقلي': ReciterConfig(
      baseUrl: '$everyAyahBase/MaherAlMuaiqly128kbps',
      format: 'mp3',
    ),
    'أحمد العجمي': ReciterConfig(
      baseUrl: '$everyAyahBase/Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
      format: 'mp3',
    ),
    'محمد أيوب': ReciterConfig(
      baseUrl: '$everyAyahBase/Muhammad_Ayyoub_128kbps',
      fallbackUrl: '$everyAyahBase/Muhammad_Ayyoub_64kbps',
      format: 'mp3',
    ),
    'عبد الله المطرود': ReciterConfig(
      baseUrl: '$everyAyahBase/Abdullah_Matroud_128kbps',
      format: 'mp3',
    ),
    'خالد القحطاني': ReciterConfig(
      baseUrl: '$everyAyahBase/Khaalid_Abdullaah_al-Qahtaanee_192kbps',
      format: 'mp3',
    ),
    'ناصر القطامي': ReciterConfig(
      baseUrl: '$everyAyahBase/Nasser_Alqatami_128kbps',
      format: 'mp3',
    ),
    'سعد الغامدي': ReciterConfig(
      baseUrl: '$everyAyahBase/Ghamadi_40kbps',
      format: 'mp3',
    ),
    'محمود خليل الحصري': ReciterConfig(
      baseUrl: '$everyAyahBase/Husary_128kbps',
      fallbackUrl: '$everyAyahBase/Husary_64kbps',
      format: 'mp3',
    ),
    'ياسر الدوسري': ReciterConfig(
      baseUrl: '$everyAyahBase/Yasser_Ad-Dussary_128kbps',
      format: 'mp3',
    ),
    'أحمد نعينع': ReciterConfig(
      baseUrl: '$everyAyahBase/Ahmed_Neana_128kbps',
      format: 'mp3',
    ),
    'سعود الشريم': ReciterConfig(
        baseUrl: '$everyAyahBase/Saood_ash-Shuraym_128kbps',
        format: 'mp3',
    ),
  };
  
  /// Tafsir source identifiers
  static const Map<String, String> tafsirSources = {
    'ابن كثير': 'ar.katheer',
    'الجلالين': 'ar.jalalayn', 
    'الميسر': 'ar.muyassar',
    'الطبري': 'ar.tabary',
    'القرطبي': 'ar.qurtubi',
    'محمد أسد': 'ar.asad',
  };
  
  /// Translation IDs for Quran.com API
  static const Map<String, int> translationIds = {
    'التفسير الميسر': 1,
    'تفسير الجلالين': 2,
    'تفسير السعدي': 3,
    'تفسير ابن كثير': 4,
    'تفسير الطبري': 8,
    'تفسير القرطبي': 7,

  };
  
  /// Request timeout configurations
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration audioTimeout = Duration(seconds: 30);
  static const Duration tafsirTimeout = Duration(seconds: 15);

  /// Get reciter configuration by API code
  static ReciterConfig? getReciterConfigByApiCode(String apiCode) {
    final arabicName = apiCodeToArabicName[apiCode];
    if (arabicName == null) return null;
    return reciterConfigs[arabicName];
  }
}

/// Configuration for audio reciter
class ReciterConfig {
  final String baseUrl;
  final String? fallbackUrl;
  final String format;
  
  const ReciterConfig({
    required this.baseUrl,
    this.fallbackUrl,
    required this.format,
  });
  
  /// Generate audio URL for specific ayah
  String getAyahUrl(int surah, int ayah) {
    final surahStr = surah.toString().padLeft(3, '0');
    final ayahStr = ayah.toString().padLeft(3, '0');
    return '$baseUrl/$surahStr$ayahStr.$format';
  }
  
  /// Generate fallback audio URL for specific ayah
  String? getFallbackAyahUrl(int surah, int ayah) {
    if (fallbackUrl == null) return null;
    final surahStr = surah.toString().padLeft(3, '0');
    final ayahStr = ayah.toString().padLeft(3, '0');
    return '$fallbackUrl/$surahStr$ayahStr.$format';
  }
}