// lib/services/native_azan_service.dart

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to communicate with native Android azan player
/// Handles stopping azan when user interacts with the app
class NativeAzanService {
  static const MethodChannel _channel = MethodChannel('com.helal.quran/azan');
  static bool _isPlaying = false;

  /// Check if azan is currently playing
  static Future<bool> isAzanPlaying() async {
    try {
      final result = await _channel.invokeMethod('isPlaying');
      _isPlaying = result as bool? ?? false;
      return _isPlaying;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error checking azan status: $e');
      return false;
    }
  }

  /// Stop azan from Flutter side (called when user taps in app)
  /// Only calls native stop method if azan is actually playing
  static Future<void> stopAzanFromFlutter() async {
    try {
      // Check if azan is currently playing (one native call to check status)
      final isPlaying = await _channel.invokeMethod('isPlaying') as bool? ?? false;

      if (!isPlaying) {
        return; // Silently return if not playing (no log spam)
      }

      // Azan is playing, stop it
      await _channel.invokeMethod('stopAzanFromFlutter');
      _isPlaying = false;
      if (kDebugMode) debugPrint('🛑 Azan stopped from Flutter');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error stopping azan: $e');
    }
  }
}
