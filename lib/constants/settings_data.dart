// lib/constants/settings_data.dart - Settings-specific data models and constants

import 'api_constants.dart';

/// Simple reciter info wrapper
class ReciterInfo {
  final String englishName;
  final String apiCode;

  ReciterInfo(this.englishName, this.apiCode);
}

/// Detailed tafsir information for settings UI
class TafsirInfo {
  final String englishName;
  final String fullArabicName;
  final String author;
  final String authorLifespan;
  final String description;
  final String methodology;
  final List<String> features;
  final String difficulty;
  final String volumes;

  const TafsirInfo({
    required this.englishName,
    required this.fullArabicName,
    required this.author,
    required this.authorLifespan,
    required this.description,
    required this.methodology,
    required this.features,
    required this.difficulty,
    required this.volumes,
  });
}

/// Detailed tafsir sources with comprehensive information
class SettingsData {
  // Private constructor to prevent instantiation
  SettingsData._();

  /// Comprehensive tafsir information for settings UI
  static const Map<String, TafsirInfo> tafsirInfo = {
    'تفسير ابن كثير': TafsirInfo(
      englishName: 'Ibn Kathir',
      fullArabicName: 'تفسير القرآن العظيم',
      author: 'الحافظ ابن كثير الدمشقي',
      authorLifespan: '(701-774 هـ)',
      description: 'تفسير شامل ومفصل يعتمد على القرآن والسنة والأثر.',
      methodology: 'منهج السلف في التفسير بالمأثور',
      features: ['تفسير بالقرآن والسنة', 'أسباب النزول', 'الأحاديث الصحيحة'],
      difficulty: 'متوسط إلى متقدم',
      volumes: '8 مجلدات',
    ),
    'التفسير الميسر': TafsirInfo(
      englishName: 'Al-Muyassar',
      fullArabicName: 'التفسير الميسر',
      author: 'نخبة من علماء التفسير',
      authorLifespan: 'معاصر',
      description: 'تفسير مبسط ومعاصر بلغة سهلة.',
      methodology: 'منهج تبسيطي يركز على المعنى العام',
      features: ['البساطة والوضوح', 'اللغة المعاصرة', 'التركيز على المعاني العملية'],
      difficulty: 'مبتدئ',
      volumes: 'مجلد واحد',
    ),
    'تفسير الجلالين': TafsirInfo(
      englishName: 'Jalalayn',
      fullArabicName: 'تفسير الجلالين',
      author: 'الجلال المحلي والجلال السيوطي',
      authorLifespan: '(791-864 هـ) و (849-911 هـ)',
      description: 'تفسير مختصر وواضح مناسب للمبتدئين.',
      methodology: 'تفسير مختصر بأسلوب سهل ومباشر',
      features: ['الإيجاز والوضوح', 'تفسير المفردات', 'المعاني الأساسية'],
      difficulty: 'مبتدئ إلى متوسط',
      volumes: 'مجلد واحد',
    ),
    'تفسير السعدي': TafsirInfo(
      englishName: 'As-Sa\'di',
      fullArabicName: 'تيسير الكريم الرحمن في تفسير كلام المنان',
      author: 'الشيخ عبد الرحمن السعدي',
      authorLifespan: '(1307-1376 هـ)',
      description: 'تفسير متوسط الطول يجمع بين الوضوح والعمق.',
      methodology: 'منهج سلفي معتدل مع التركيز على الهداية العملية',
      features: ['الوضوح والاعتدال', 'الفوائد العملية', 'التطبيق المعاصر'],
      difficulty: 'متوسط',
      volumes: 'مجلد واحد',
    ),
    'تفسير الطبري': TafsirInfo(
      englishName: 'At-Tabari',
      fullArabicName: 'جامع البيان عن تأويل آي القرآن',
      author: 'الإمام أبو جعفر الطبري',
      authorLifespan: '(224-310 هـ)',
      description: 'أول تفسير تاريخي مفصل وأكثرها شمولية.',
      methodology: 'التفسير بالمأثور مع ذكر الأقوال المختلفة',
      features: ['الشمولية التاريخية', 'الأسانيد المفصلة', 'الأقوال المتنوعة'],
      difficulty: 'متقدم',
      volumes: '24 مجلد',
    ),
    'تفسير القرطبي': TafsirInfo(
      englishName: 'Al-Qurtubi',
      fullArabicName: 'الجامع لأحكام القرآن',
      author: 'الإمام القرطبي المالكي',
      authorLifespan: '(600-671 هـ)',
      description: 'تفسير فقهي وتاريخي يركز على الأحكام الشرعية.',
      methodology: 'استنباط الأحكام الفقهية من الآيات',
      features: ['الأحكام الفقهية', 'المذاهب الأربعة', 'القضايا الاجتماعية'],
      difficulty: 'متوسط إلى متقدم',
      volumes: '20 مجلد',
    ),
  };

  /// Get reciter Arabic name from API constants
  static String? getReciterName(String apiCode) {
    return ApiConstants.apiCodeToArabicName[apiCode];
  }

  /// Get all available reciters from API constants
  static Map<String, String> get availableReciters => ApiConstants.apiCodeToArabicName;

  /// Playback speed options
  static const List<double> speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  /// Repetition count options
  static const List<int> repetitionOptions = [1, 2, 3, 5, 10];

  /// Pause duration options (in seconds)
  static const List<int> pauseDurationOptions = [0, 1, 2, 3, 5, 10];

  /// Memorization mode options
  // TODO: Either remove it or implement it
  static const List<String> memorizationModes = [
    'الحفظ التقليدي',
    'الحفظ بالتكرار',
    'الحفظ التفاعلي',
    'الحفظ بالمراجعة',
  ];
}