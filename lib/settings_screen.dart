// lib/settings_screen.dart - IMPROVED VERSION with detailed tafsir information

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedReciter = 'عبد الباسط عبد الصمد';
  String _selectedTafsir = 'تفسير ابن كثير';
  double _playbackSpeed = 1.0;
  bool _autoPlayNext = true;
  bool _repeatSurah = false;
  bool _isLoading = true;

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
    _loadSettings();
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
        _isLoading = false;
      });
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('تم تغيير القارئ إلى $reciter'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('تم تغيير مصدر التفسير إلى $tafsir'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
    } catch (e) {
      debugPrint('Error saving playback speed: $e');
    }
  }

  Future<void> _saveAutoPlayNext(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_play_next', value);
      setState(() {
        _autoPlayNext = value;
      });
    } catch (e) {
      debugPrint('Error saving auto play setting: $e');
    }
  }

  Future<void> _saveRepeatSurah(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('repeat_surah', value);
      setState(() {
        _repeatSurah = value;
      });
    } catch (e) {
      debugPrint('Error saving repeat surah setting: $e');
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
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Audio/Recitation Section - Enhanced
                _buildSectionHeader('إعدادات التلاوة'),
                const SizedBox(height: 12),
                _buildAudioSettings(),

                const SizedBox(height: 32),

                // Tafsir Section - Enhanced with detailed info
                _buildSectionHeader('إعدادات التفسير'),
                const SizedBox(height: 12),
                _buildTafsirSettings(),

                const SizedBox(height: 32),

                // Theme Section
                _buildSectionHeader('المظهر'),
                const SizedBox(height: 12),
                _buildThemeColorSelector(themeManager),
                const SizedBox(height: 16),
                _buildThemeModeSelector(themeManager),

                const SizedBox(height: 32),

                // About Section
                _buildSectionHeader('حول التطبيق'),
                const SizedBox(height: 12),
                _buildAboutSection(),
              ],
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
          ...AppTheme.values.map((theme) => RadioListTile<AppTheme>(
            title: Text(themeManager.getThemeName(theme)),
            value: theme,
            groupValue: themeManager.currentTheme,
            onChanged: (value) => themeManager.setTheme(value!),
            secondary: CircleAvatar(
              backgroundColor: _getThemeColor(theme),
              radius: 12,
            ),
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
          RadioListTile<ThemeMode>(
            title: const Text('فاتح'),
            subtitle: const Text('المظهر الفاتح'),
            value: ThemeMode.light,
            groupValue: themeManager.themeMode,
            onChanged: (value) => themeManager.setThemeMode(value!),
            secondary: const Icon(Icons.light_mode),
          ),
          const Divider(height: 1),
          RadioListTile<ThemeMode>(
            title: const Text('داكن'),
            subtitle: const Text('المظهر الداكن'),
            value: ThemeMode.dark,
            groupValue: themeManager.themeMode,
            onChanged: (value) => themeManager.setThemeMode(value!),
            secondary: const Icon(Icons.dark_mode),
          ),
          const Divider(height: 1),
          RadioListTile<ThemeMode>(
            title: const Text('تلقائي'),
            subtitle: const Text('يتبع إعدادات النظام'),
            value: ThemeMode.system,
            groupValue: themeManager.themeMode,
            onChanged: (value) => themeManager.setThemeMode(value!),
            secondary: const Icon(Icons.auto_mode),
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
    }
  }

  void _showReciterSelection() {
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
    );
  }

  String _getSpeedDescription(double speed) {
    if (speed < 1.0) return 'أبطأ';
    if (speed == 1.0) return 'طبيعي';
    if (speed <= 1.5) return 'أسرع قليلاً';
    return 'سريع';
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تحميل التلاوة'),
          content: const Text(
            'هذه الميزة ستكون متاحة قريباً.\nستتمكن من تحميل تلاوة السور للاستماع بدون إنترنت.',
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