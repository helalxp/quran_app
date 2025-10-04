import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/haptic_utils.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  int _count = 0;
  int _currentWordIndex = 0;
  Timer? _inactivityTimer;
  DateTime? _lastTapTime;

  static const int _inactivityDurationSeconds = 30;
  static const String _countKey = 'tasbih_count';
  static const String _wordIndexKey = 'tasbih_word_index';
  static const String _lastTapKey = 'tasbih_last_tap';

  final List<String> _words = [
    'سبحان الله',
    'الحمد لله',
    'الله أكبر',
  ];

  final String _completion100 =
      'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، وهو على كل شيء قدير';

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _startInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = prefs.getInt(_countKey) ?? 0;
      _currentWordIndex = prefs.getInt(_wordIndexKey) ?? 0;
      final lastTapMillis = prefs.getInt(_lastTapKey);
      if (lastTapMillis != null) {
        _lastTapTime = DateTime.fromMillisecondsSinceEpoch(lastTapMillis);
      }
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, _count);
    await prefs.setInt(_wordIndexKey, _currentWordIndex);
    await prefs.setInt(_lastTapKey, DateTime.now().millisecondsSinceEpoch);
  }

  void _onTap() {
    HapticUtils.selectionClick();

    setState(() {
      _count++;
      _lastTapTime = DateTime.now();

      if (_count == 100) {
        // Show 100th completion phrase, then reset
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _count = 0;
              _currentWordIndex = 0;
            });
            _saveProgress();
          }
        });
      } else {
        // Cycle through words
        _currentWordIndex = (_currentWordIndex + 1) % _words.length;
      }
    });

    _saveProgress();
    _resetInactivityTimer();
  }

  void _startInactivityTimer() {
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastTapTime != null) {
        final inactiveDuration = DateTime.now().difference(_lastTapTime!);
        if (inactiveDuration.inSeconds >= _inactivityDurationSeconds) {
          _showInactivityReminder();
          _lastTapTime = DateTime.now(); // Reset to avoid continuous reminders
        }
      }
    });
  }

  void _resetInactivityTimer() {
    _lastTapTime = DateTime.now();
  }

  void _showInactivityReminder() {
    if (!mounted) return;

    HapticUtils.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'واصل التسبيح 🤲',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Uthmanic', fontSize: 18),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getCurrentWord() {
    if (_count == 100) {
      return _completion100;
    }
    return _words[_currentWordIndex];
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
      ),
      body: GestureDetector(
        onTap: _count == 100 ? null : _onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Counter at top
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    '$_count / 100',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                // Centered word
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          _getCurrentWord(),
                          key: ValueKey<String>('$_count-$_currentWordIndex'),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: _count == 100 ? 32 : 48,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Uthmanic',
                            color: Theme.of(context).colorScheme.primary,
                            height: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Instruction text
                Padding(
                  padding: const EdgeInsets.only(bottom: 40.0),
                  child: Text(
                    _count == 100
                        ? 'تم إكمال التسبيح ✨'
                        : 'اضغط في أي مكان للتسبيح',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      fontFamily: 'Uthmanic',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
