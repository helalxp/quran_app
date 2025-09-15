// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_manager.dart';
import 'continuous_audio_manager.dart';
import 'memorization_manager.dart';
import 'audio_download_manager.dart';
import 'constants/api_constants.dart';
import 'utils/animation_utils.dart';
import 'utils/haptic_utils.dart';

class SettingsScreen extends StatefulWidget {
  final MemorizationManager? memorizationManager;
  
  const SettingsScreen({
    super.key,
    this.memorizationManager,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late List<AnimationController> _sectionControllers;
  String _selectedReciter = 'عبد الباسط عبد الصمد';
  String _selectedTafsir = 'تفسير ابن كثير';
  double _playbackSpeed = 1.0;
  bool _autoPlayNext = true;
  bool _repeatSurah = false;
  bool _isLoading = true;
  
  // Memorization settings
  int _memorationRepetitions = 3;
  bool _pauseBetweenRepetitions = true;
  int _pauseDurationSeconds = 2;
  MemorizationMode _memorationMode = MemorizationMode.singleAyah;

  // Download manager
  late AudioDownloadManager _downloadManager;

  // Enhanced reciter list with more options
  // SYNCHRONIZED: This is now the single source of truth for reciters.
  final Map<String, ReciterInfo> _reciters = {
    'مشاري العفاسي': ReciterInfo('Mishary Alafasy', 'Alafasy_128kbps'),
    'عبد الباسط عبد الصمد': ReciterInfo('Abdul Basit', 'Abdul_Basit_Murattal_192kbps'),
    'عبد الرحمن السديس': ReciterInfo('Abdur-Rahman as-Sudais', 'Sudais_128kbps'),
    'ماهر المعيقلي': ReciterInfo('Maher Al Muaiqly', 'MaherAlMuaiqly128kbps'),
    'محمد صديق المنشاوي': ReciterInfo('Minshawi', 'Minshawi_Murattal_128kbps'),
    'سعود الشريم': ReciterInfo('Saud Al-Shuraim', 'Shatri_128kbps'),
    'أحمد العجمي': ReciterInfo('Ahmad Al-Ajmi', 'Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net'),
    'سعد الغامدي': ReciterInfo('Saad Al-Ghamdi', 'Ghamadi_40kbps'),
    'ياسر الدوسري': ReciterInfo('Yasser Al Dosari', 'Yasser_Ad-Dussary_128kbps'),
    'محمود خليل الحصري': ReciterInfo('Mahmoud Khalil Al-Hussary', 'Husary_128kbps'),
    'ناصر القطامي': ReciterInfo('Nasser Al-Qatami', 'Nasser_Alqatami_128kbps'),
    'خالد القحطاني': ReciterInfo('Khalid Al-Qahtani', 'Khalid_Al-Qahtani_192kbps'),
    'محمد أيوب': ReciterInfo('Muhammad Ayyub', 'Muhammad_Ayyoub_128kbps'),
    'عبد الله المطرود': ReciterInfo('Abdullah Al-Matroud', 'Abdullah_Matroud_128kbps'),
  };

  // CORRECTED: Replace the _tafsirSources map with this complete version.
  final Map<String, TafsirInfo> _tafsirSources = {
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

  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: AnimationUtils.normal,
      vsync: this,
    );
    
    _sectionControllers = AnimationUtils.createStaggeredControllers(
      vsync: this,
      count: 5, // Number of sections (added memorization section)
      duration: AnimationUtils.normal,
    );

    // Initialize download manager
    _downloadManager = AudioDownloadManager();

    _loadSettings();
    
    // Start animations after loading
    _fadeController.forward();
    AnimationUtils.startStaggeredAnimations(
      controllers: _sectionControllers,
      staggerDelay: const Duration(milliseconds: 150),
    );
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    AnimationUtils.disposeStaggeredControllers(_sectionControllers);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedReciter = prefs.getString('selected_reciter') ?? _reciters.keys.first;
        _selectedTafsir = prefs.getString('default_tafsir') ?? _tafsirSources.keys.first;
        _playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;
        _autoPlayNext = prefs.getBool('auto_play_next') ?? true;
        _repeatSurah = prefs.getBool('repeat_surah') ?? false;
        
        // Load memorization settings
        _memorationRepetitions = prefs.getInt('memorization_repetitions') ?? 3;
        _pauseBetweenRepetitions = prefs.getBool('pause_between_repetitions') ?? true;
        _pauseDurationSeconds = prefs.getInt('pause_duration_seconds') ?? 2;
        final modeIndex = prefs.getInt('memorization_mode') ?? 0;
        _memorationMode = MemorizationMode.values[modeIndex];
        
        _isLoading = false;
      });
      
      // Load current settings from memorization manager if available
      if (widget.memorizationManager != null) {
        final currentSettings = widget.memorizationManager!.settings;
        setState(() {
          _memorationRepetitions = currentSettings.repetitionCount;
          _pauseBetweenRepetitions = currentSettings.pauseBetweenRepetitions;
          _pauseDurationSeconds = currentSettings.pauseDuration.inSeconds;
          _memorationMode = currentSettings.mode;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveReciter(String reciter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_reciter', reciter);
      setState(() {
        _selectedReciter = reciter;
      });
      
      // Update audio manager with new reciter
      final audioManager = ContinuousAudioManager();
      await audioManager.updateReciter(reciter);

    } catch (e) {
      debugPrint('Error saving reciter: $e');
    }
  }

  Future<void> _saveTafsir(String tafsir) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('default_tafsir', tafsir);
      setState(() {
        _selectedTafsir = tafsir;
      });

    } catch (e) {
      debugPrint('Error saving tafsir: $e');
    }
  }

  Future<void> _savePlaybackSpeed(double speed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('playback_speed', speed);
      setState(() {
        _playbackSpeed = speed;
      });
      
      // Update audio manager with new speed
      final audioManager = ContinuousAudioManager();
      await audioManager.updatePlaybackSpeed(speed);
    } catch (e) {
      debugPrint('Error saving playback speed: $e');
    }
  }

  Future<void> _saveAutoPlayNext(bool value) async {
    try {
      HapticUtils.toggleSwitch(); // Haptic feedback for toggle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_play_next', value);
      setState(() {
        _autoPlayNext = value;
      });
      
      // Update audio manager with new auto-play setting
      final audioManager = ContinuousAudioManager();
      await audioManager.updateAutoPlayNext(value);
    } catch (e) {
      debugPrint('Error saving auto play setting: $e');
    }
  }

  Future<void> _saveRepeatSurah(bool value) async {
    try {
      HapticUtils.toggleSwitch(); // Haptic feedback for toggle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('repeat_surah', value);
      setState(() {
        _repeatSurah = value;
      });
      
      // Update audio manager with new repeat setting
      final audioManager = ContinuousAudioManager();
      await audioManager.updateRepeatSurah(value);
    } catch (e) {
      debugPrint('Error saving repeat surah setting: $e');
    }
  }

  // Memorization settings save methods
  Future<void> _saveMemorizationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save to SharedPreferences
      await prefs.setInt('memorization_repetitions', _memorationRepetitions);
      await prefs.setBool('pause_between_repetitions', _pauseBetweenRepetitions);
      await prefs.setInt('pause_duration_seconds', _pauseDurationSeconds);
      await prefs.setInt('memorization_mode', _memorationMode.index);
      
      debugPrint('💾 Memorization settings saved: repetitions=$_memorationRepetitions, speed=$_playbackSpeed (universal), pause=$_pauseBetweenRepetitions, duration=$_pauseDurationSeconds, mode=$_memorationMode');
      
      // Update memorization manager if available
      if (widget.memorizationManager != null) {
        final newSettings = MemorizationSettings(
          repetitionCount: _memorationRepetitions,
          playbackSpeed: _playbackSpeed, // Use universal playback speed
          pauseBetweenRepetitions: _pauseBetweenRepetitions,
          pauseDuration: Duration(seconds: _pauseDurationSeconds),
          mode: _memorationMode,
        );
        await widget.memorizationManager!.updateSettings(newSettings);
        debugPrint('🧠 Memorization manager updated with new settings');
      }
      
    } catch (e) {
      debugPrint('Error saving memorization settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              title: const Text(
                'الإعدادات',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
            body: FadeTransition(
              opacity: _fadeController,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Audio/Recitation Section - Animated
                  AnimationUtils.fadeSlideTransition(
                    animation: _sectionControllers[0],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('إعدادات التلاوة'),
                        const SizedBox(height: 12),
                        _buildAudioSettings(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Memorization Section - Animated
                  if (widget.memorizationManager != null)
                    AnimationUtils.fadeSlideTransition(
                      animation: _sectionControllers[1],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('إعدادات الحفظ'),
                          const SizedBox(height: 12),
                          _buildMemorizationSettings(),
                        ],
                      ),
                    ),

                  if (widget.memorizationManager != null) const SizedBox(height: 32),

                  // Tafsir Section - Animated
                  AnimationUtils.fadeSlideTransition(
                    animation: _sectionControllers[widget.memorizationManager != null ? 2 : 1],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('إعدادات التفسير'),
                        const SizedBox(height: 12),
                        _buildTafsirSettings(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Theme Section - Animated
                  AnimationUtils.fadeSlideTransition(
                    animation: _sectionControllers[widget.memorizationManager != null ? 3 : 2],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('المظهر'),
                        const SizedBox(height: 12),
                        _buildThemeColorSelector(themeManager),
                        const SizedBox(height: 16),
                        _buildThemeModeSelector(themeManager),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // About Section - Animated
                  AnimationUtils.fadeSlideTransition(
                    animation: _sectionControllers[widget.memorizationManager != null ? 4 : 3],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('حول التطبيق'),
                        const SizedBox(height: 12),
                        _buildAboutSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildAudioSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Current Reciter
          ListTile(
            leading: Icon(
              Icons.record_voice_over,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('القارئ الحالي'),
            subtitle: Text(_selectedReciter),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: _showReciterSelection,
          ),
          const Divider(height: 1),

          // Playback Speed
          ListTile(
            leading: Icon(
              Icons.speed,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('سرعة التشغيل'),
            subtitle: Text('${_playbackSpeed}x'),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: _showSpeedSelection,
          ),
          const Divider(height: 1),

          // Auto Play Next
          SwitchListTile(
            secondary: Icon(
              Icons.skip_next,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('التشغيل التلقائي للآية التالية'),
            subtitle: const Text('تشغيل الآيات تلقائياً حتى نهاية السورة'),
            value: _autoPlayNext,
            onChanged: _saveAutoPlayNext,
          ),
          const Divider(height: 1),

          // Repeat Surah
          SwitchListTile(
            secondary: Icon(
              Icons.repeat,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('تكرار السورة'),
            subtitle: const Text('إعادة تشغيل السورة عند انتهائها'),
            value: _repeatSurah,
            onChanged: _saveRepeatSurah,
          ),
          const Divider(height: 1),

          // Follow the Ayah on Playback
          Consumer<ThemeManager>(
            builder: (context, themeManager, child) => SwitchListTile(
              secondary: Icon(
                Icons.my_location_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('متابعة الآية أثناء التشغيل'),
              subtitle: const Text('الانتقال تلقائياً للصفحة التي تحتوي على الآية المُشغلة'),
              value: themeManager.followAyahOnPlayback,
              onChanged: (value) => themeManager.toggleFollowAyahOnPlayback(),
            ),
          ),
          const Divider(height: 1),

          // Download Section (Future Feature)
          ListTile(
            leading: Icon(
              Icons.download,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('تحميل التلاوة'),
            subtitle: const Text('تحميل تلاوة السور للاستماع بدون إنترنت'),
            trailing: const Icon(Icons.keyboard_arrow_left),
            onTap: _showDownloadDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildTafsirSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Current Tafsir Source
          ListTile(
            leading: Icon(
              Icons.book,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('مصدر التفسير الافتراضي'),
            subtitle: Text(_selectedTafsir),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: _showTafsirSelection,
          ),
          const Divider(height: 1),

          // Tafsir Info - Enhanced
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('معلومات التفسير المختار'),
            subtitle: Text(_tafsirSources[_selectedTafsir]?.author ?? 'غير محدد'),
            onTap: () => _showDetailedTafsirInfo(_selectedTafsir),
          ),
          const Divider(height: 1),

          // Browse All Tafsir Sources
          ListTile(
            leading: Icon(
              Icons.library_books,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('استعراض جميع مصادر التفسير'),
            subtitle: const Text('معلومات مفصلة عن كل مصدر تفسير'),
            trailing: const Icon(Icons.keyboard_arrow_left),
            onTap: _showAllTafsirSources,
          ),
        ],
      ),
    );
  }

  Widget _buildMemorizationSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Repetition Count
          ListTile(
            leading: Icon(
              Icons.repeat,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('عدد التكرارات'),
            subtitle: Text('$_memorationRepetitions مرات'),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: _showRepetitionSelection,
          ),
          const Divider(height: 1),


          // Pause Between Repetitions
          SwitchListTile(
            secondary: Icon(
              Icons.pause,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('توقف بين التكرارات'),
            subtitle: Text(_pauseBetweenRepetitions 
                ? 'توقف لمدة $_pauseDurationSeconds ثانية' 
                : 'تشغيل متواصل'),
            value: _pauseBetweenRepetitions,
            onChanged: (value) {
              setState(() {
                _pauseBetweenRepetitions = value;
              });
              _saveMemorizationSettings();
            },
          ),

          // Pause Duration (if pause is enabled)
          if (_pauseBetweenRepetitions) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.timer,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('مدة التوقف'),
              subtitle: Text('$_pauseDurationSeconds ثانية'),
              trailing: const Icon(Icons.keyboard_arrow_down),
              onTap: _showPauseDurationSelection,
            ),
          ],

          const Divider(height: 1),

          // Memorization Mode
          ListTile(
            leading: Icon(
              Icons.playlist_play,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('نوع الحفظ'),
            subtitle: Text(_getMemorizationModeDescription(_memorationMode)),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: _showMemorizationModeSelection,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeColorSelector(ThemeManager themeManager) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'لون التطبيق',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          ...AppTheme.values.map((theme) => ListTile(
            title: Text(themeManager.getThemeName(theme)),
            leading: Radio<AppTheme>(
              value: theme,
              // ignore: deprecated_member_use
              groupValue: themeManager.currentTheme,
              // ignore: deprecated_member_use
              onChanged: (value) => themeManager.setTheme(value!),
            ),
            trailing: CircleAvatar(
              backgroundColor: _getThemeColor(theme),
              radius: 12,
            ),
            onTap: () => themeManager.setTheme(theme),
          )),
        ],
      ),
    );
  }

  Widget _buildThemeModeSelector(ThemeManager themeManager) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            title: const Text('فاتح'),
            subtitle: const Text('المظهر الفاتح'),
            leading: Radio<ThemeMode>(
              value: ThemeMode.light,
              // ignore: deprecated_member_use
              groupValue: themeManager.themeMode,
              // ignore: deprecated_member_use
              onChanged: (value) => themeManager.setThemeMode(value!),
            ),
            trailing: const Icon(Icons.light_mode),
            onTap: () => themeManager.setThemeMode(ThemeMode.light),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('داكن'),
            subtitle: const Text('المظهر الداكن'),
            leading: Radio<ThemeMode>(
              value: ThemeMode.dark,
              // ignore: deprecated_member_use
              groupValue: themeManager.themeMode,
              // ignore: deprecated_member_use
              onChanged: (value) => themeManager.setThemeMode(value!),
            ),
            trailing: const Icon(Icons.dark_mode),
            onTap: () => themeManager.setThemeMode(ThemeMode.dark),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('تلقائي'),
            subtitle: const Text('يتبع إعدادات النظام'),
            leading: Radio<ThemeMode>(
              value: ThemeMode.system,
              // ignore: deprecated_member_use
              groupValue: themeManager.themeMode,
              // ignore: deprecated_member_use
              onChanged: (value) => themeManager.setThemeMode(value!),
            ),
            trailing: const Icon(Icons.auto_mode),
            onTap: () => themeManager.setThemeMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('معلومات التطبيق'),
            subtitle: const Text('الإصدار 1.0.0'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.star_rate,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('تقييم التطبيق'),
            subtitle: const Text('ساعدنا بتقييم التطبيق'),
            onTap: () {
              // TODO: Implement app rating
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.help_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('المساعدة والدعم'),
            subtitle: const Text('طريقة استخدام التطبيق'),
            onTap: _showHelpDialog,
          ),
        ],
      ),
    );
  }

  Color _getThemeColor(AppTheme theme) {
    switch (theme) {
      case AppTheme.brown:
        return const Color(0xFF6D4C41);
      case AppTheme.green:
        return const Color(0xFF2E7D32);
      case AppTheme.blue:
        return const Color(0xFF1976D2);
      case AppTheme.islamic:
        return const Color(0xFFD4AF37); // Islamic gold color
    }
  }

  void _showReciterSelection() {
    HapticUtils.dialogOpen(); // Haptic feedback for dialog open
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'اختر القارئ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _reciters.length,
                itemBuilder: (context, index) {
                  final reciterName = _reciters.keys.elementAt(index);
                  final reciterInfo = _reciters[reciterName]!;
                  final isSelected = reciterName == _selectedReciter;

                  return ListTile(
                    title: Text(reciterName),
                    subtitle: Text(reciterInfo.englishName),
                    trailing: isSelected
                        ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _saveReciter(reciterName);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTafsirSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'اختر مصدر التفسير',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _tafsirSources.length,
                itemBuilder: (context, index) {
                  final tafsirName = _tafsirSources.keys.elementAt(index);
                  final tafsirInfo = _tafsirSources[tafsirName]!;
                  final isSelected = tafsirName == _selectedTafsir;

                  return ListTile(
                    title: Text(tafsirName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tafsirInfo.author),
                        Text(
                          'الصعوبة: ${tafsirInfo.difficulty}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          onPressed: () {
                            Navigator.pop(context);
                            _showDetailedTafsirInfo(tafsirName);
                          },
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _saveTafsir(tafsirName);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailedTafsirInfo(String tafsirName) {
    final tafsirInfo = _tafsirSources[tafsirName];
    if (tafsirInfo == null) return;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(tafsirName),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('الاسم الكامل:', tafsirInfo.fullArabicName),
                const SizedBox(height: 8),
                _buildInfoRow('المؤلف:', tafsirInfo.author),
                const SizedBox(height: 8),
                _buildInfoRow('فترة الحياة:', tafsirInfo.authorLifespan),
                const SizedBox(height: 8),
                _buildInfoRow('الوصف:', tafsirInfo.description),
                const SizedBox(height: 8),
                _buildInfoRow('المنهج:', tafsirInfo.methodology),
                const SizedBox(height: 8),
                _buildInfoRow('مستوى الصعوبة:', tafsirInfo.difficulty),
                const SizedBox(height: 8),
                _buildInfoRow('عدد المجلدات:', tafsirInfo.volumes),
                const SizedBox(height: 12),

                const Text(
                  'الميزات الرئيسية:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...tafsirInfo.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
            if (tafsirName != _selectedTafsir)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveTafsir(tafsirName);
                },
                child: const Text('اختيار هذا التفسير'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  void _showAllTafsirSources() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TafsirSourcesScreen(
          tafsirSources: _tafsirSources,
          currentSelection: _selectedTafsir,
          onTafsirSelected: _saveTafsir,
        ),
      ),
    );
  }

  void _showSpeedSelection() {
    HapticUtils.dialogOpen(); // Haptic feedback for dialog open
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'اختر سرعة التشغيل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const Divider(height: 1),
              ..._speedOptions.map((speed) {
                final isSelected = speed == _playbackSpeed;
                return ListTile(
                  title: Text('${speed}x'),
                  subtitle: Text(_getSpeedDescription(speed)),
                  trailing: isSelected
                      ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _savePlaybackSpeed(speed);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _getSpeedDescription(double speed) {
    if (speed < 1.0) return 'أبطأ';
    if (speed == 1.0) return 'طبيعي';
    if (speed <= 1.5) return 'أسرع قليلاً';
    return 'سريع';
  }

  void _showDownloadDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DownloadManagerBottomSheet(
        downloadManager: _downloadManager,
        selectedReciter: _selectedReciter,
        reciters: _reciters,
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('المساعدة والدعم'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('طريقة استخدام التطبيق:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('1. اضغط على أي آية لعرض خيارات الآية'),
                Text('2. اختر "تشغيل الآية" لبدء التشغيل المتواصل'),
                Text('3. استخدم مشغل الصوت في الأسفل للتحكم في التشغيل'),
                Text('4. يمكنك تغيير القارئ من الإعدادات'),
                Text('5. اضغط طويلاً على زر الإشارة المرجعية لعرض جميع الإشارات'),
                SizedBox(height: 16),
                Text('للدعم الفني أو الاستفسارات، يرجى التواصل معنا.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }

  // Memorization helper methods
  String _getMemorizationModeDescription(MemorizationMode mode) {
    switch (mode) {
      case MemorizationMode.singleAyah:
        return 'آية واحدة';
      case MemorizationMode.ayahRange:
        return 'نطاق من الآيات';
      case MemorizationMode.fullSurah:
        return 'السورة كاملة';
    }
  }

  void _showRepetitionSelection() {
    HapticUtils.dialogOpen();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر عدد التكرارات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(10, (index) {
                final count = index + 1;
                return ListTile(
                  title: Text('$count ${count == 1 ? 'مرة' : 'مرات'}'),
                  trailing: _memorationRepetitions == count 
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _memorationRepetitions = count;
                    });
                    _saveMemorizationSettings();
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }


  void _showPauseDurationSelection() {
    HapticUtils.dialogOpen();
    final durations = [1, 2, 3, 5, 10];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر مدة التوقف',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...durations.map((duration) => ListTile(
              title: Text('$duration ${duration == 1 ? 'ثانية' : 'ثوانِ'}'),
              trailing: _pauseDurationSeconds == duration 
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                setState(() {
                  _pauseDurationSeconds = duration;
                });
                _saveMemorizationSettings();
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showMemorizationModeSelection() {
    HapticUtils.dialogOpen();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر نوع الحفظ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...MemorizationMode.values.map((mode) => ListTile(
              leading: Icon(_getMemorizationModeIcon(mode)),
              title: Text(_getMemorizationModeDescription(mode)),
              subtitle: Text(_getMemorizationModeDetails(mode)),
              trailing: _memorationMode == mode 
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                setState(() {
                  _memorationMode = mode;
                });
                _saveMemorizationSettings();
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  IconData _getMemorizationModeIcon(MemorizationMode mode) {
    switch (mode) {
      case MemorizationMode.singleAyah:
        return Icons.looks_one;
      case MemorizationMode.ayahRange:
        return Icons.format_list_numbered;
      case MemorizationMode.fullSurah:
        return Icons.menu_book;
    }
  }

  String _getMemorizationModeDetails(MemorizationMode mode) {
    switch (mode) {
      case MemorizationMode.singleAyah:
        return 'تكرار آية واحدة فقط';
      case MemorizationMode.ayahRange:
        return 'تكرار مجموعة من الآيات';
      case MemorizationMode.fullSurah:
        return 'تكرار السورة بالكامل';
    }
  }
}

// Helper classes for better organization
class ReciterInfo {
  final String englishName;
  final String apiCode;

  ReciterInfo(this.englishName, this.apiCode);
}

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

  TafsirInfo({
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

// New screen for detailed tafsir sources
class TafsirSourcesScreen extends StatelessWidget {
  final Map<String, TafsirInfo> tafsirSources;
  final String currentSelection;
  final Function(String) onTafsirSelected;

  const TafsirSourcesScreen({
    super.key,
    required this.tafsirSources,
    required this.currentSelection,
    required this.onTafsirSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme
            .of(context)
            .scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme
              .of(context)
              .scaffoldBackgroundColor,
          elevation: 0,
          title: const Text(
            'مصادر التفسير',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tafsirSources.length,
          itemBuilder: (context, index) {
            final tafsirName = tafsirSources.keys.elementAt(index);
            final tafsirInfo = tafsirSources[tafsirName]!;
            final isSelected = tafsirName == currentSelection;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tafsirName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme
                                  .of(context)
                                  .colorScheme
                                  .primary
                                  : Theme
                                  .of(context)
                                  .colorScheme
                                  .onSurface,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme
                                .of(context)
                                .colorScheme
                                .primary,
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Author and timespan
                    Text(
                      '${tafsirInfo.author} ${tafsirInfo.authorLifespan}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme
                            .of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      tafsirInfo.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme
                            .of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Info chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildInfoChip(
                          context,
                          Icons.school,
                          tafsirInfo.difficulty,
                        ),
                        _buildInfoChip(
                          context,
                          Icons.library_books,
                          tafsirInfo.volumes,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _showDetailedInfo(
                                  context, tafsirName, tafsirInfo),
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('تفاصيل أكثر'),
                        ),
                        const SizedBox(width: 8),
                        if (!isSelected)
                          ElevatedButton(
                            onPressed: () {
                              onTafsirSelected(tafsirName);
                              Navigator.pop(context);
                            },
                            child: const Text('اختيار'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme
              .of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme
                .of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme
                  .of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailedInfo(BuildContext context, String tafsirName,
      TafsirInfo tafsirInfo) {
    showDialog(
      context: context,
      builder: (context) =>
          Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(tafsirName),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDetailRow('الاسم الكامل:', tafsirInfo.fullArabicName),
                    const SizedBox(height: 8),
                    _buildDetailRow('المؤلف:', tafsirInfo.author),
                    const SizedBox(height: 8),
                    _buildDetailRow('فترة الحياة:', tafsirInfo.authorLifespan),
                    const SizedBox(height: 8),
                    _buildDetailRow('الوصف:', tafsirInfo.description),
                    const SizedBox(height: 8),
                    _buildDetailRow('المنهج:', tafsirInfo.methodology),
                    const SizedBox(height: 8),
                    _buildDetailRow('مستوى الصعوبة:', tafsirInfo.difficulty),
                    const SizedBox(height: 8),
                    _buildDetailRow('عدد المجلدات:', tafsirInfo.volumes),
                    const SizedBox(height: 12),

                    const Text(
                      'الميزات الرئيسية:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ...tafsirInfo.features.map((feature) =>
                        Padding(
                          padding: const EdgeInsets.only(right: 16, bottom: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(child: Text(feature)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
                if (tafsirName != currentSelection)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      onTafsirSelected(tafsirName);
                      Navigator.pop(context); // Close sources screen
                    },
                    child: const Text('اختيار هذا التفسير'),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
}

class DownloadManagerBottomSheet extends StatefulWidget {
  final AudioDownloadManager downloadManager;
  final String selectedReciter;
  final Map<String, ReciterInfo> reciters;

  const DownloadManagerBottomSheet({
    super.key,
    required this.downloadManager,
    required this.selectedReciter,
    required this.reciters,
  });

  @override
  State<DownloadManagerBottomSheet> createState() => _DownloadManagerBottomSheetState();
}

class _DownloadManagerBottomSheetState extends State<DownloadManagerBottomSheet> {
  int _selectedTab = 0;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إدارة التحميلات',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تحميل ومتابعة تلاوة القرآن الكريم',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                      // Tabs
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTab('السور', 0, Icons.book),
                            ),
                            Expanded(
                              child: _buildTab('الأجزاء', 1, Icons.menu_book),
                            ),
                            Expanded(
                              child: _buildTab('التحميلات', 2, Icons.download_done),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Content
                      Expanded(
                        child: _selectedTab == 0
                            ? _buildSurahsList()
                            : _selectedTab == 1
                                ? _buildJuzsList()
                                : _buildDownloadsManagerList(),
                      ),
                    ],
                  ),
                ),
              ),

            // Download status
            if (_isDownloading) ...[
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _downloadStatus,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Bottom safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 114, // Total Surahs
      itemBuilder: (context, index) {
        final surahNumber = index + 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$surahNumber',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(
              'سورة ${getSurahName(surahNumber)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              widget.reciters[widget.selectedReciter]?.englishName ?? widget.selectedReciter,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: _isDownloading
                    ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.download_rounded,
                  color: _isDownloading
                      ? Theme.of(context).colorScheme.outline
                      : Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: _isDownloading ? null : () => _downloadSurah(surahNumber),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJuzsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 30, // Total Juz
      itemBuilder: (context, index) {
        final juzNumber = index + 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$juzNumber',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(
              'الجزء $juzNumber',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              widget.reciters[widget.selectedReciter]?.englishName ?? widget.selectedReciter,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: _isDownloading
                    ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.download_rounded,
                  color: _isDownloading
                      ? Theme.of(context).colorScheme.outline
                      : Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: _isDownloading ? null : () => _downloadJuz(juzNumber),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadsManagerList() {
    final completedDownloads = widget.downloadManager.getCompletedDownloads();

    if (completedDownloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_done,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد تحميلات',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ستظهر هنا التحميلات المكتملة',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: completedDownloads.length,
      itemBuilder: (context, index) {
        final download = completedDownloads[index];
        final isJuz = download.type == DownloadType.juz;
        final title = isJuz
            ? 'الجزء ${download.number}'
            : 'سورة ${getSurahName(download.number)}';
        final subtitle = '${widget.reciters.values.firstWhere((r) => r.apiCode == download.reciter, orElse: () => ReciterInfo('غير معروف', download.reciter)).englishName} • ${download.ayahs.length} آية';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                isJuz ? Icons.menu_book : Icons.book,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            title: Text(title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'مكتمل',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (download.completionTime != null)
                      Text(
                        _formatDate(download.completionTime!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirm = await _showDeleteConfirmation(title);
                  if (confirm) {
                    await _deleteDownload(download.id, title);
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('حذف', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final downloadDate = DateTime(date.year, date.month, date.day);

    if (downloadDate == today) {
      return 'اليوم';
    } else if (downloadDate == today.subtract(const Duration(days: 1))) {
      return 'أمس';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<bool> _showDeleteConfirmation(String title) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف $title؟\nسيتم حذف جميع الملفات المحملة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  Future<void> _deleteDownload(String taskId, String title) async {
    try {
      await widget.downloadManager.deleteDownload(taskId);
      setState(() {}); // Refresh the list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف $title بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حذف $title: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadSurah(int surahNumber) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'تحميل سورة ${getSurahName(surahNumber)}...';
    });

    try {
      final reciterCode = widget.reciters[widget.selectedReciter]?.apiCode ?? 'Abdul_Basit_Murattal_192kbps';
      final arabicName = ApiConstants.apiCodeToArabicName[reciterCode] ?? 'عبد الباسط عبد الصمد';

      debugPrint('📥 Starting download for Surah $surahNumber with reciter: $arabicName (API: $reciterCode)');

      await widget.downloadManager.downloadSurah(surahNumber, arabicName);

      setState(() {
        _downloadStatus = 'تم تحميل سورة ${getSurahName(surahNumber)} بنجاح';
        _downloadProgress = 1.0;
      });

      // Show success message briefly
      await Future.delayed(const Duration(seconds: 2));

    } catch (e) {
      setState(() {
        _downloadStatus = 'فشل تحميل سورة ${getSurahName(surahNumber)}: $e';
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _downloadJuz(int juzNumber) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'تحميل الجزء $juzNumber...';
    });

    try {
      final reciterCode = widget.reciters[widget.selectedReciter]?.apiCode ?? 'Abdul_Basit_Murattal_192kbps';
      final arabicName = ApiConstants.apiCodeToArabicName[reciterCode] ?? 'عبد الباسط عبد الصمد';

      debugPrint('📥 Starting download for Juz $juzNumber with reciter: $arabicName (API: $reciterCode)');

      await widget.downloadManager.downloadJuz(juzNumber, arabicName);

      setState(() {
        _downloadStatus = 'تم تحميل الجزء $juzNumber بنجاح';
        _downloadProgress = 1.0;
      });

      // Show success message briefly
      await Future.delayed(const Duration(seconds: 2));

    } catch (e) {
      setState(() {
        _downloadStatus = 'فشل تحميل الجزء $juzNumber: $e';
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }


  String getSurahName(int surahNumber) {
    // Basic surah names mapping - would normally come from a constants file
    const surahNames = [
      'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة', 'الأنعام', 'الأعراف', 'الأنفال',
      'التوبة', 'يونس', 'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر', 'النحل', 'الإسراء',
      'الكهف', 'مريم', 'طه', 'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان', 'الشعراء',
      'النمل', 'القصص', 'العنكبوت', 'الروم', 'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
      'يس', 'الصافات', 'ص', 'الزمر', 'غافر', 'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية',
      'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق', 'الذاريات', 'الطور', 'النجم', 'القمر',
      'الرحمن', 'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة', 'الصف', 'الجمعة',
      'المنافقون', 'التغابن', 'الطلاق', 'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
      'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة', 'الإنسان', 'المرسلات', 'النبأ', 'النازعات',
      'عبس', 'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج', 'الطارق', 'الأعلى',
      'الغاشية', 'الفجر', 'البلد', 'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين', 'العلق',
      'القدر', 'البينة', 'الزلزلة', 'العاديات', 'القارعة', 'التكاثر', 'العصر', 'الهمزة',
      'الفيل', 'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر', 'المسد', 'الإخلاص',
      'الفلق', 'الناس'
    ];

    if (surahNumber >= 1 && surahNumber <= surahNames.length) {
      return surahNames[surahNumber - 1];
    }
    return 'سورة $surahNumber';
  }
}