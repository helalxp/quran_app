import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/haptic_utils.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _afterPrayerPageController;
  late PageController _customPageController;
  late AudioPlayer _audioPlayer;

  // After Prayer Tasbih state
  int _afterPrayerCount = 0;
  int _afterPrayerWordIndex = 0;

  // Custom counter state
  int _customCount = 0;
  int _customWordIndex = 0;
  List<String> _customWords = [
    'سبحان الله',
    'الحمد لله',
    'الله أكبر',
    'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير',
  ];

  // After Prayer words
  final List<String> _afterPrayerWords = [
    'سبحان الله',
    'الحمد لله',
    'الله أكبر',
    'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير',
  ];

  static const String _afterPrayerCountKey = 'tasbih_after_prayer_count';
  static const String _afterPrayerWordIndexKey = 'tasbih_after_prayer_word_index';
  static const String _customCountKey = 'tasbih_custom_count';
  static const String _customWordIndexKey = 'tasbih_custom_word_index';
  static const String _customWordsKey = 'tasbih_custom_words';
  static const String _currentTabKey = 'tasbih_current_tab';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _tabController = TabController(length: 2, vsync: this);
    _afterPrayerPageController = PageController();
    _customPageController = PageController();
    _tabController.addListener(_onTabChanged);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();

    final afterPrayerCount = prefs.getInt(_afterPrayerCountKey) ?? 0;
    final afterPrayerWordIndex = prefs.getInt(_afterPrayerWordIndexKey) ?? 0;
    final customCount = prefs.getInt(_customCountKey) ?? 0;
    final customWordIndex = prefs.getInt(_customWordIndexKey) ?? 0;
    final savedWords = prefs.getStringList(_customWordsKey);
    final currentTab = prefs.getInt(_currentTabKey) ?? 0;

    if (mounted) {
      setState(() {
        _afterPrayerCount = afterPrayerCount;
        _afterPrayerWordIndex = afterPrayerWordIndex;
        _customCount = customCount;
        _customWordIndex = customWordIndex;

        if (savedWords != null && savedWords.isNotEmpty) {
          _customWords = savedWords;
        }

        _tabController.index = currentTab;
      });

      // Jump to correct pages after setState
      if (_afterPrayerWordIndex > 0) {
        _afterPrayerPageController.jumpToPage(_afterPrayerWordIndex);
      }
      if (_customWordIndex > 0 && _customWords.isNotEmpty) {
        _customPageController.jumpToPage(_customWordIndex);
      }
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_afterPrayerCountKey, _afterPrayerCount);
    await prefs.setInt(_afterPrayerWordIndexKey, _afterPrayerWordIndex);
    await prefs.setInt(_customCountKey, _customCount);
    await prefs.setInt(_customWordIndexKey, _customWordIndex);
    await prefs.setStringList(_customWordsKey, _customWords);
    await prefs.setInt(_currentTabKey, _tabController.index);
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {}); // Rebuild to show/hide Add button
      _saveProgress();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _afterPrayerPageController.dispose();
    _customPageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.setAsset('assets/azan.mp3');
      await _audioPlayer.setVolume(0.3);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _onAfterPrayerTap() {
    HapticUtils.selectionClick();

    final previousCount = _afterPrayerCount;

    setState(() {
      _afterPrayerCount++;

      // Determine word index based on count
      final countMod100 = _afterPrayerCount % 100;
      final previousCountMod100 = previousCount % 100;
      int targetWordIndex;

      if (countMod100 == 0) {
        // At 100, 200, 300, etc. - show big word and play sound
        targetWordIndex = 3;
        _playSound();
        if (_afterPrayerWordIndex != 3) {
          _afterPrayerPageController.animateToPage(
            3,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      } else if (previousCountMod100 == 0) {
        // Just passed 100 - quick slide back to first word
        targetWordIndex = 0;
        _afterPrayerPageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else if (countMod100 >= 1 && countMod100 <= 33) {
        targetWordIndex = 0;
      } else if (countMod100 >= 34 && countMod100 <= 66) {
        targetWordIndex = 1;
        if (_afterPrayerWordIndex != 1 && previousCountMod100 == 33) {
          _afterPrayerPageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      } else if (countMod100 >= 67 && countMod100 <= 99) {
        targetWordIndex = 2;
        if (_afterPrayerWordIndex != 2 && previousCountMod100 == 66) {
          _afterPrayerPageController.animateToPage(
            2,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      } else {
        // This shouldn't happen, but default to first word
        targetWordIndex = 0;
      }

      _afterPrayerWordIndex = targetWordIndex;
    });

    _saveProgress();
  }

  void _onCustomTap() {
    HapticUtils.selectionClick();

    setState(() {
      _customCount++;

      // Play sound at every 100
      if (_customCount % 100 == 0) {
        _playSound();
      }
    });

    _saveProgress();
  }

  void _resetCounter() {
    HapticUtils.mediumImpact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'إعادة تعيين العداد',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Uthmanic', fontWeight: FontWeight.bold),
        ),
        content: Text(
          _tabController.index == 0
              ? 'هل تريد إعادة تعيين عداد التسبيح بعد الصلاة؟'
              : 'هل تريد إعادة تعيين العداد الحر؟',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Uthmanic'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (_tabController.index == 0) {
                  _afterPrayerCount = 0;
                  _afterPrayerWordIndex = 0;
                  _afterPrayerPageController.jumpToPage(0);
                } else {
                  _customCount = 0;
                }
              });
              _saveProgress();
              Navigator.pop(context);
            },
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
  }

  void _showManageDuasSheet() {
    HapticUtils.selectionClick();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'إدارة الأدعية والأذكار',
                              style: TextStyle(
                                fontFamily: 'Uthmanic',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Add new dua button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddDuaDialog();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'إضافة دعاء أو ذكر جديد',
                            style: TextStyle(fontFamily: 'Uthmanic', fontSize: 16),
                          ),
                        ),
                      ),
                    ),

                    // List of duas
                    Flexible(
                    child: _customWords.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.book_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد أدعية',
                                  style: TextStyle(
                                    fontFamily: 'Uthmanic',
                                    fontSize: 18,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'اضغط على الزر أعلاه لإضافة دعاء',
                                  style: TextStyle(
                                    fontFamily: 'Uthmanic',
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _customWords.length,
                            itemBuilder: (context, index) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  title: Text(
                                    _customWords[index],
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Uthmanic',
                                      fontSize: 18,
                                      height: 1.8,
                                    ),
                                  ),
                                  trailing: SizedBox(
                                    width: 48,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                      onPressed: () {
                                        HapticUtils.mediumImpact();
                                        setModalState(() {
                                          setState(() {
                                            _customWords.removeAt(index);
                                            if (_customWordIndex >= _customWords.length && _customWords.isNotEmpty) {
                                              _customWordIndex = _customWords.length - 1;
                                            } else if (_customWords.isEmpty) {
                                              _customWordIndex = 0;
                                            }
                                          });
                                          _saveProgress();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    ),

                    // Bottom padding
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddDuaDialog() {
    HapticUtils.selectionClick();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'إضافة دعاء أو ذكر جديد',
                style: TextStyle(fontFamily: 'Uthmanic', fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Uthmanic', fontSize: 18),
              decoration: InputDecoration(
                hintText: 'أدخل الدعاء أو الذكر',
                hintStyle: TextStyle(
                  fontFamily: 'Uthmanic',
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _customWords.add(controller.text.trim());
                });
                _saveProgress();
                Navigator.pop(context);
                HapticUtils.success();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularCounter(int count, int maxForRing) {
    final progress = (count % maxForRing) / maxForRing;

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 250,
            height: 250,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 16,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: 250,
            height: 250,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 16,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          // Counter text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '/ ${count ~/ maxForRing * maxForRing + maxForRing}',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAfterPrayerTab() {
    return GestureDetector(
      onTap: _onAfterPrayerTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Word display (swipeable RTL)
              SizedBox(
                height: 150,
              child: PageView.builder(
                controller: _afterPrayerPageController,
                reverse: true, // RTL support
                itemCount: _afterPrayerWords.length,
                onPageChanged: (index) {
                  setState(() {
                    _afterPrayerWordIndex = index;
                  });
                  _saveProgress();
                },
                itemBuilder: (context, index) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 64,
                          ),
                          child: Text(
                            _afterPrayerWords[index],
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: index == 3 ? 24 : 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Uthmanic',
                              color: Theme.of(context).colorScheme.primary,
                              height: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Page indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _afterPrayerWords.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _afterPrayerWordIndex == index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
              ).reversed.toList(),
            ),

            const SizedBox(height: 40),

            // Circular counter
            _buildCircularCounter(_afterPrayerCount, 100),

            SizedBox(height: MediaQuery.of(context).size.height * 0.1),

            // Instruction
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Text(
                'اضغط في أي مكان للتسبيح • اسحب لتغيير الذكر',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Uthmanic',
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTab() {
    return GestureDetector(
      onTap: _onCustomTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Word display (swipeable RTL)
              SizedBox(
                height: 150,
              child: _customWords.isEmpty
                  ? Center(
                      child: Text(
                        'اضغط + لإضافة دعاء أو ذكر',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Uthmanic',
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : PageView.builder(
                      controller: _customPageController,
                      reverse: true, // RTL support
                      itemCount: _customWords.length,
                      onPageChanged: (index) {
                        setState(() {
                          _customWordIndex = index;
                        });
                        _saveProgress();
                      },
                      itemBuilder: (context, index) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width - 64,
                                ),
                                child: Text(
                                  _customWords[index],
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Uthmanic',
                                    color: Theme.of(context).colorScheme.secondary,
                                    height: 1.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Page indicator dots
            if (_customWords.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _customWords.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _customWordIndex == index
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                ).reversed.toList(),
              ),

            const SizedBox(height: 40),

            // Circular counter
            _buildCircularCounter(_customCount, 100),

            SizedBox(height: MediaQuery.of(context).size.height * 0.1),

            // Instruction
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Text(
                'اضغط في أي مكان للعد • اسحب لتغيير الدعاء',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Uthmanic',
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            HapticUtils.navigation();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_outlined),
          tooltip: 'رجوع',
        ),
        title: const Text(
          'التسبيح',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Uthmanic'),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _resetCounter,
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تعيين',
          ),
          if (_tabController.index == 1)
            IconButton(
              onPressed: _showManageDuasSheet,
              icon: const Icon(Icons.edit_note),
              tooltip: 'إدارة الأدعية',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Text(
                'التسبيح بعد الصلاة',
                style: TextStyle(fontFamily: 'Uthmanic', fontSize: 14),
              ),
            ),
            Tab(
              child: Text(
                'العداد الحر',
                style: TextStyle(fontFamily: 'Uthmanic', fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAfterPrayerTab(),
          _buildCustomTab(),
        ],
      ),
    );
  }
}
