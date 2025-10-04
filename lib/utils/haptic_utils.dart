// lib/utils/haptic_utils.dart - Haptic feedback utilities for enhanced UX

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Centralized haptic feedback utilities for consistent user experience
class HapticUtils {
  static const MethodChannel _channel = MethodChannel('com.helal.quran/vibration');

  /// Light haptic feedback for subtle interactions (35ms)
  static Future<void> lightImpact() async {
    await _vibrate(35);
  }

  /// Medium haptic feedback for standard interactions (60ms)
  static Future<void> mediumImpact() async {
    await _vibrate(60);
  }

  /// Heavy haptic feedback for important interactions (100ms)
  static Future<void> heavyImpact() async {
    await _vibrate(100);
  }

  /// Selection click for toggles and selections (50ms)
  static Future<void> selectionClick() async {
    await _vibrate(50);
  }

  /// Vibrate for error states or warnings (600ms)
  static Future<void> vibrate() async {
    await _vibrate(600);
  }

  /// Continuous vibration for Qibla alignment - pulses until stopped
  static Future<void> qiblaAlignmentVibrate() async {
    await _vibrate(200);
  }

  /// Core vibration method using native Android Vibrator service
  static Future<void> _vibrate(int durationMs) async {
    try {
      await _channel.invokeMethod('vibrate', {'duration': durationMs});
    } catch (e) {
      if (kDebugMode) debugPrint('Vibration error: $e');
    }
  }

  // Semantic feedback methods for specific interactions

  /// Button tap feedback
  static Future<void> buttonTap() async {
    await lightImpact();
  }

  /// Toggle switch feedback
  static Future<void> toggleSwitch() async {
    await selectionClick();
  }

  /// Navigation feedback
  static Future<void> navigation() async {
    await lightImpact();
  }

  /// Selection feedback (list items, cards, etc.)
  static Future<void> selection() async {
    await selectionClick();
  }

  /// Success feedback
  static Future<void> success() async {
    await mediumImpact();
  }

  /// Error feedback
  static Future<void> error() async {
    await vibrate();
  }

  /// Long press feedback
  static Future<void> longPress() async {
    await heavyImpact();
  }

  /// Swipe/dismiss feedback
  static Future<void> swipe() async {
    await lightImpact();
  }

  /// Media control feedback (play, pause, etc.)
  static Future<void> mediaControl() async {
    await mediumImpact();
  }

  /// Bookmark action feedback
  static Future<void> bookmark() async {
    await mediumImpact();
  }

  /// Dialog open feedback
  static Future<void> dialogOpen() async {
    await lightImpact();
  }

  /// Page turn feedback
  static Future<void> pageTurn() async {
    await lightImpact();
  }
}