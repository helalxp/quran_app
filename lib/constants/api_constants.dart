// lib/constants/api_constants.dart - API endpoints and configuration

/// API endpoints and configuration for external services
class ApiConstants {
  
  // Private constructor to prevent instantiation
  ApiConstants._();
  
  /// Base URLs for different API services
  static const String alquranCloudBase = 'https://api.alquran.cloud/v1';
  static const String quranComBase = 'https://api.quran.com/api/v4';
  static const String everyAyahBase = 'https://www.everyayah.com/data';
  
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
    return '$quranComBase/verses/by_key/$surah:$ayah?translations=$translationId';
  }
  
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
      baseUrl: '$everyAyahBase/Minshawi_Murattal_128kbps',
      format: 'mp3',
    ),
    'أبو بكر الشاطري': ReciterConfig(
      baseUrl: '$everyAyahBase/Shatri_128kbps',
      format: 'mp3',
    ),
    'عبد الرحمن السديس': ReciterConfig(
      baseUrl: '$everyAyahBase/Sudais_128kbps',
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
      baseUrl: '$everyAyahBase/Khalid_Al-Qahtani_192kbps',
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
    'التفسير الميسر': 171,
  };
  
  /// Request timeout configurations
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration audioTimeout = Duration(seconds: 30);
  static const Duration tafsirTimeout = Duration(seconds: 15);
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