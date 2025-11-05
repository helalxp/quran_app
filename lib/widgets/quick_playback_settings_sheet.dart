// lib/widgets/quick_playback_settings_sheet.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../continuous_audio_manager.dart';
import '../theme_manager.dart';
import '../constants/api_constants.dart';
import '../utils/haptic_utils.dart';

/// Quick playback settings bottom sheet
/// Provides contextual access to playback settings from the media player
class QuickPlaybackSettingsSheet extends StatefulWidget {
  const QuickPlaybackSettingsSheet({super.key});

  @override
  State<QuickPlaybackSettingsSheet> createState() => _QuickPlaybackSettingsSheetState();
}

class _QuickPlaybackSettingsSheetState extends State<QuickPlaybackSettingsSheet> {
  String _selectedReciter = 'محمود خليل الحصري';
  double _playbackSpeed = 1.0;
  bool _autoPlayNext = true;
  bool _repeatSurah = false;
  bool _continueToNextSurah = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedReciter = prefs.getString('selected_reciter') ?? 'محمود خليل الحصري';
        _playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;
        _autoPlayNext = prefs.getBool('auto_play_next') ?? true;
        _repeatSurah = prefs.getBool('repeat_surah') ?? false;
        _continueToNextSurah = prefs.getBool('continue_to_next_surah') ?? false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading playback settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveReciter(String reciter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_reciter', reciter);
      setState(() => _selectedReciter = reciter);

      // Update audio manager
      final audioManager = ContinuousAudioManager();
      await audioManager.updateReciter(reciter);

      HapticUtils.success();
    } catch (e) {
      debugPrint('Error saving reciter: $e');
    }
  }

  Future<void> _savePlaybackSpeed(double speed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('playback_speed', speed);
      setState(() => _playbackSpeed = speed);

      // Update audio manager
      final audioManager = ContinuousAudioManager();
      await audioManager.updatePlaybackSpeed(speed);

      HapticUtils.success();
    } catch (e) {
      debugPrint('Error saving playback speed: $e');
    }
  }

  Future<void> _saveAutoPlayNext(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_play_next', value);
      setState(() => _autoPlayNext = value);

      // Update audio manager
      final audioManager = ContinuousAudioManager();
      await audioManager.updateAutoPlayNext(value);

      HapticUtils.selection();
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
        // Mutual exclusivity: Turn off continue to next surah
        if (value && _continueToNextSurah) {
          _continueToNextSurah = false;
          prefs.setBool('continue_to_next_surah', false);
        }
      });

      // Update audio manager
      final audioManager = ContinuousAudioManager();
      await audioManager.updateRepeatSurah(value);

      HapticUtils.selection();
    } catch (e) {
      debugPrint('Error saving repeat surah setting: $e');
    }
  }

  Future<void> _saveContinueToNextSurah(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('continue_to_next_surah', value);

      setState(() {
        _continueToNextSurah = value;
        // Mutual exclusivity: Turn off repeat surah
        if (value && _repeatSurah) {
          _repeatSurah = false;
          prefs.setBool('repeat_surah', false);
          // Update audio manager
          final audioManager = ContinuousAudioManager();
          audioManager.updateRepeatSurah(false);
        }
      });

      // Update audio manager
      final audioManager = ContinuousAudioManager();
      await audioManager.updateContinueToNextSurah(value);

      HapticUtils.selection();
    } catch (e) {
      debugPrint('Error saving continue to next surah setting: $e');
    }
  }

  Future<void> _saveFollowAyahOnPlayback(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('follow_ayah_on_playback', value);

      HapticUtils.selection();
    } catch (e) {
      debugPrint('Error saving follow ayah setting: $e');
    }
  }

  void _showReciterDialog() {
    HapticUtils.lightImpact();
    final sortedReciters = ApiConstants.reciterConfigs.keys.toList()..sort();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر القارئ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sortedReciters.length,
              itemBuilder: (context, index) {
                final reciterName = sortedReciters[index];
                final isSelected = reciterName == _selectedReciter;

                return ListTile(
                  title: Text(
                    reciterName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    _saveReciter(reciterName);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    HapticUtils.lightImpact();
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0];

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('سرعة التشغيل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: speeds.map((speed) {
              final isSelected = speed == _playbackSpeed;
              return ListTile(
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  _savePlaybackSpeed(speed);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 400,
        padding: const EdgeInsets.all(20),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إعدادات التشغيل السريعة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Settings list
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Current Reciter
                  ListTile(
                    leading: Icon(Icons.record_voice_over, color: Theme.of(context).colorScheme.primary),
                    title: const Text('القارئ الحالي'),
                    subtitle: Text(_selectedReciter),
                    trailing: const Icon(Icons.keyboard_arrow_down),
                    onTap: _showReciterDialog,
                  ),
                  const Divider(height: 1),

                  // Playback Speed
                  ListTile(
                    leading: Icon(Icons.speed, color: Theme.of(context).colorScheme.primary),
                    title: const Text('سرعة التشغيل'),
                    subtitle: Text('${_playbackSpeed}x'),
                    trailing: const Icon(Icons.keyboard_arrow_down),
                    onTap: _showSpeedDialog,
                  ),
                  const Divider(height: 1),

                  // Auto Play Next
                  SwitchListTile(
                    secondary: Icon(Icons.skip_next, color: Theme.of(context).colorScheme.primary),
                    title: const Text('التشغيل التلقائي'),
                    subtitle: const Text('تشغيل الآيات تلقائياً'),
                    value: _autoPlayNext,
                    onChanged: _saveAutoPlayNext,
                  ),
                  const Divider(height: 1),

                  // Repeat Surah
                  SwitchListTile(
                    secondary: Icon(Icons.repeat, color: Theme.of(context).colorScheme.primary),
                    title: const Text('تكرار السورة'),
                    subtitle: const Text('إعادة تشغيل السورة عند انتهائها'),
                    value: _repeatSurah,
                    onChanged: _saveRepeatSurah,
                  ),
                  const Divider(height: 1),

                  // Continue to Next Surah
                  SwitchListTile(
                    secondary: Icon(Icons.fast_forward, color: Theme.of(context).colorScheme.primary),
                    title: const Text('الانتقال للسورة التالية'),
                    subtitle: const Text('متابعة التشغيل بالسور التالية'),
                    value: _continueToNextSurah,
                    onChanged: _saveContinueToNextSurah,
                  ),
                  const Divider(height: 1),

                  // Follow Ayah on Playback
                  Consumer<ThemeManager>(
                    builder: (context, themeManager, _) => SwitchListTile(
                      secondary: Icon(Icons.my_location_rounded, color: Theme.of(context).colorScheme.primary),
                      title: const Text('متابعة الآية'),
                      subtitle: const Text('الانتقال للصفحة أثناء التشغيل'),
                      value: themeManager.followAyahOnPlayback,
                      onChanged: (value) {
                        themeManager.toggleFollowAyahOnPlayback();
                        _saveFollowAyahOnPlayback(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom padding
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Show quick playback settings sheet
void showQuickPlaybackSettings(BuildContext context) {
  HapticUtils.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const QuickPlaybackSettingsSheet(),
  );
}
