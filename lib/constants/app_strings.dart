// lib/constants/app_strings.dart - Centralized string constants

/// Centralized string constants for better maintainability and localization support
class AppStrings {
  
  // Private constructor to prevent instantiation
  AppStrings._();
  
  // Error Messages
  static const String errorNetworkOffline = 'تعذر الاتصال بالإنترنت. تأكد من اتصال الشبكة وحاول مرة أخرى.';
  static const String errorNetworkDns = 'مشكلة في الاتصال بالخادم. حاول مرة أخرى خلال دقائق قليلة.';
  static const String errorNetworkTimeout = 'انتهت مهلة التحميل. تأكد من سرعة الاتصال وحاول مرة أخرى.';
  static const String errorNetworkServer = 'الخادم غير متاح حاليا. حاول مرة أخرى لاحقا.';
  static const String errorNetworkSlow = 'الاتصال بطيء. جاري المحاولة مع مصدر آخر...';
  static const String errorTimeout = 'انتهت مهلة التحميل. حاول مرة أخرى.';
  static const String errorCodec = 'مشكلة في ملف الصوت. جاري المحاولة مع قارئ آخر...';
  static const String errorPermission = 'تعذر الوصول لتشغيل الصوت. تحقق من أذونات التطبيق.';
  static const String errorUnknown = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  static const String errorAudioGeneral = 'تعذر تشغيل الملف الصوتي. تحقق من اتصال الإنترنت وحاول مرة أخرى.';
  static const String errorPlaybackFailed = 'فشل في تشغيل التلاوة. حاول مع قارئ آخر أو تحقق من الاتصال.';
  static const String errorReciterNotFound = 'القارئ المطلوب غير متاح. اختر قارئ آخر من الإعدادات.';
  static const String errorNoAyahs = 'لا توجد آيات محددة للتشغيل. حدد آية أو مجموعة آيات أولا.';
  
  // Bookmarks
  static const String bookmarkAdded = 'تم إضافة الإشارة المرجعية';
  static const String bookmarkRemoved = 'تم إزالة الإشارة المرجعية';
  static const String bookmarkDeleted = 'تم حذف الإشارة المرجعية';
  static const String bookmarkNoBookmarks = 'لا توجد إشارات مرجعية محفوظة';
  
  // Navigation and UI
  static const String dataNotLoaded = 'البيانات لم يتم تحميلها بعد';
  static const String surah = 'السورة';
  static const String juz = 'الجزء';
  static const String page = 'الصفحة';
  static const String ayah = 'الآية';
  
  // Memorization
  static const String memorizationMarked = 'تم وضع علامة الحفظ';
  static const String memorizationUnmarked = 'تم إزالة علامة الحفظ';
  static const String memorizationAlreadyMarked = 'هذه الآية محفوظة مسبقا';
  
  // Audio Player
  static const String audioPlaying = 'جاري التشغيل';
  static const String audioPaused = 'متوقف مؤقتا';
  static const String audioStopped = 'متوقف';
  static const String audioBuffering = 'جاري التحميل...';
  static const String audioLoading = 'جاري تحضير الملف...';
  static const String loading = 'جاري التحميل...';
  
  // Dialog Actions
  static const String cancel = 'إلغاء';
  static const String ok = 'موافق';
  static const String save = 'حفظ';
  static const String delete = 'حذف';
  static const String confirm = 'تأكيد';
  
  // Settings
  static const String settings = 'الإعدادات';
  static const String darkMode = 'الوضع الداكن';
  static const String lightMode = 'الوضع الفاتح';
  static const String autoMode = 'تلقائي';
  static const String fontSize = 'حجم الخط';
  static const String playbackSpeed = 'سرعة التشغيل';
  static const String reciter = 'القارئ';
  
  // Jump to dialogs
  static const String jumpToSurah = 'انتقل إلى السورة';
  static const String jumpToJuz = 'انتقل إلى الجزء';
  static const String jumpToPage = 'انتقل إلى الصفحة';
  static const String jumpToAyah = 'انتقل إلى الآية';
  
  // Range selection
  static const String ayahRange = 'مجال الآيات';
  static const String fromAyah = 'من الآية';
  static const String toAyah = 'إلى الآية';
  static const String startPlayback = 'بدء التشغيل';
  
  // Validation messages
  static const String invalidRange = 'المجال المحدد غير صحيح';
  static const String invalidInput = 'المدخل غير صحيح';
  
  // Actions
  static const String play = 'تشغيل';
  static const String pause = 'إيقاف مؤقت';
  static const String stop = 'إيقاف';
  static const String next = 'التالي';
  static const String previous = 'السابق';
  static const String bookmark = 'إشارة مرجعية';
  static const String memorize = 'حفظ';
  static const String share = 'مشاركة';
  static const String retry = 'إعادة المحاولة';
  static const String startMemorization = 'ابدأ الحفظ';
}