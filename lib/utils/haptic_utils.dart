// lib/utils/haptic_utils.dart - Haptic feedback utilities for enhanced UX

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Centralized haptic feedback utilities for consistent user experience
class HapticUtils {
  /// Light haptic feedback for subtle interactions
  static Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      if (kDebugMode) {
        print('Haptic feedback not available: $e');
      }
    }
  }

  /// Medium haptic feedback for standard interactions
  static Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      if (kDebugMode) {
        print('Haptic feedback not available: $e');
      }
    }
  }

  /// Heavy haptic feedback for important interactions
  static Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      if (kDebugMode) {
        print('Haptic feedback not available: $e');
      }
    }
  }

  /// Selection click for toggles and selections
  static Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      if (kDebugMode) {
        print('Haptic feedback not available: $e');
      }
    }
  }

  /// Vibrate for error states or warnings
  static Future<void> vibrate() async {
    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      if (kDebugMode) {
        print('Haptic feedback not available: $e');
      }
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