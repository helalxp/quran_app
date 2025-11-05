// lib/widgets/quick_memorization_settings_sheet.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../memorization_manager.dart';
import '../utils/haptic_utils.dart';

/// Quick memorization settings bottom sheet
/// Provides contextual access to memorization settings from the media player
class QuickMemorizationSettingsSheet extends StatefulWidget {
  final MemorizationManager? memorizationManager;

  const QuickMemorizationSettingsSheet({
    super.key,
    this.memorizationManager,
  });

  @override
  State<QuickMemorizationSettingsSheet> createState() => _QuickMemorizationSettingsSheetState();
}

class _QuickMemorizationSettingsSheetState extends State<QuickMemorizationSettingsSheet> {
  int _repetitionCount = MemorizationConstants.defaultRepetitionCount;
  double _playbackSpeed = 1.0;
  bool _pauseBetweenRepetitions = true;
  int _pauseDurationSeconds = MemorizationConstants.defaultPauseDuration.inSeconds;
  MemorizationMode _mode = MemorizationMode.singleAyah;
  bool _showProgress = true;
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
        _repetitionCount = prefs.getInt('memorization_repetition_count') ?? MemorizationConstants.defaultRepetitionCount;
        _playbackSpeed = prefs.getDouble('memorization_playback_speed') ?? 1.0;
        _pauseBetweenRepetitions = prefs.getBool('memorization_pause_between') ?? true;
        _pauseDurationSeconds = prefs.getInt('memorization_pause_duration') ?? MemorizationConstants.defaultPauseDuration.inSeconds;
        final modeIndex = prefs.getInt('memorization_mode') ?? 0;
        _mode = MemorizationMode.values[modeIndex.clamp(0, MemorizationMode.values.length - 1)];
        _showProgress = prefs.getBool('memorization_show_progress') ?? true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading memorization settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveRepetitionCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('memorization_repetition_count', count);
      setState(() => _repetitionCount = count);
      HapticUtils.success();
    } catch (e) {
      debugPrint('Error saving repetition count: $e');
    }
  }

  Future<void> _savePlaybackSpeed(double speed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('memorization_playback_speed', speed);
      setState(() => _playbackSpeed = speed);
      HapticUtils.success();
    } catch (e) {
      debugPrint('Error saving playback speed: $e');
    }
  }

  Future<void> _savePauseBetween(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('memorization_pause_between', value);
      setState(() => _pauseBetweenRepetitions = value);
      HapticUtils.selection();
    } catch (e) {
      debugPrint('Error saving pause between setting: $e');
    }
  }

  Future<void> _savePauseDuration(int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('memorization_pause_duration', seconds);
      setState(() => _pauseDurationSeconds = seconds);
      HapticUtils.success();
    } catch (e) {
      debugPrint('Error saving pause duration: $e');
    }
  }

  Future<void> _saveMode(MemorizationMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('memorization_mode', mode.index);
      setState(() => _mode = mode);
      HapticUtils.success();
    } catch (e) {
      debugPrint('Error saving memorization mode: $e');
    }
  }

  Future<void> _saveShowProgress(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('memorization_show_progress', value);
      setState(() => _showProgress = value);
      HapticUtils.selection();
    } catch (e) {
      debugPrint('Error saving show progress setting: $e');
    }
  }

  void _showRepetitionCountDialog() {
    HapticUtils.lightImpact();
    final counts = [1, 2, 3, 5, 7, 10, 15, 20];

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('عدد مرات التكرار', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: counts.map((count) {
              final isSelected = count == _repetitionCount;
              return ListTile(
                title: Text(
                  '$count مرة',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  _saveRepetitionCount(count);
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

  void _showPauseDurationDialog() {
    HapticUtils.lightImpact();
    final durations = [1, 2, 3, 5, 10, 15, 30];

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مدة التوقف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: durations.map((duration) {
              final isSelected = duration == _pauseDurationSeconds;
              return ListTile(
                title: Text(
                  duration == 1 ? 'ثانية واحدة' : '$duration ثوان',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  _savePauseDuration(duration);
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

  void _showModeDialog() {
    HapticUtils.lightImpact();

    final modes = {
      MemorizationMode.singleAyah: 'آية واحدة',
      MemorizationMode.ayahRange: 'مجموعة آيات',
      MemorizationMode.fullSurah: 'السورة كاملة',
    };

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نمط الحفظ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: modes.entries.map((entry) {
              final isSelected = entry.key == _mode;
              return ListTile(
                title: Text(
                  entry.value,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  _saveMode(entry.key);
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

  String _getModeName(MemorizationMode mode) {
    switch (mode) {
      case MemorizationMode.singleAyah:
        return 'آية واحدة';
      case MemorizationMode.ayahRange:
        return 'مجموعة آيات';
      case MemorizationMode.fullSurah:
        return 'السورة كاملة';
    }
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
                Icon(Icons.school, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'إعدادات الحفظ السريعة',
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
                  // Memorization Mode
                  ListTile(
                    leading: Icon(Icons.category, color: Theme.of(context).colorScheme.primary),
                    title: const Text('نمط الحفظ'),
                    subtitle: Text(_getModeName(_mode)),
                    trailing: const Icon(Icons.keyboard_arrow_down),
                    onTap: _showModeDialog,
                  ),
                  const Divider(height: 1),

                  // Repetition Count
                  ListTile(
                    leading: Icon(Icons.repeat, color: Theme.of(context).colorScheme.primary),
                    title: const Text('عدد مرات التكرار'),
                    subtitle: Text('$_repetitionCount مرة'),
                    trailing: const Icon(Icons.keyboard_arrow_down),
                    onTap: _showRepetitionCountDialog,
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

                  // Pause Between Repetitions
                  SwitchListTile(
                    secondary: Icon(Icons.pause_circle, color: Theme.of(context).colorScheme.primary),
                    title: const Text('توقف بين التكرارات'),
                    subtitle: const Text('إضافة وقفة بين كل تكرار'),
                    value: _pauseBetweenRepetitions,
                    onChanged: _savePauseBetween,
                  ),
                  const Divider(height: 1),

                  // Pause Duration (only if pause is enabled)
                  if (_pauseBetweenRepetitions)
                    ListTile(
                      leading: Icon(Icons.timer, color: Theme.of(context).colorScheme.primary),
                      title: const Text('مدة التوقف'),
                      subtitle: Text(_pauseDurationSeconds == 1 ? 'ثانية واحدة' : '$_pauseDurationSeconds ثوان'),
                      trailing: const Icon(Icons.keyboard_arrow_down),
                      onTap: _showPauseDurationDialog,
                    ),
                  if (_pauseBetweenRepetitions)
                    const Divider(height: 1),

                  // Show Progress
                  SwitchListTile(
                    secondary: Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary),
                    title: const Text('إظهار التقدم'),
                    subtitle: const Text('عرض عداد التكرار الحالي'),
                    value: _showProgress,
                    onChanged: _saveShowProgress,
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

/// Show quick memorization settings sheet
void showQuickMemorizationSettings(BuildContext context, MemorizationManager? memorizationManager) {
  HapticUtils.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => QuickMemorizationSettingsSheet(
      memorizationManager: memorizationManager,
    ),
  );
}
