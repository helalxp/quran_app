// lib/constants/app_constants.dart - App-wide constants

import 'package:flutter/material.dart';
import '../theme_manager.dart';

class AppConstants {
  // Quran constants  
  static const int totalPages = 604;
  static const int totalSurahs = 114;
  static const int totalJuz = 30;
  
  // UI constants
  static const double pageVerticalOffset = 50.0;
  static const double jumpButtonSize = 70.0;
  static const double jumpButtonHeight = 40.0;
  
  // Timing constants
  static const Duration saveDebounceTimeout = Duration(milliseconds: 500);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration pulseAnimationDuration = Duration(seconds: 2);
  
  // Error retry constants
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // SVG constants
  static const double svgSourceWidth = 395.0;
  static const double svgSourceHeight = 551.0;
  static const double svgBaseScaleMultiplier = 1.143;
  static const double svgBaseYOffset = -41.0;
  static const double svgReferenceWidth = 400.0;
  static const double svgReferenceHeight = 800.0;
  
  // Color constants  
  static const int warmPaperColorValue = 0xFFFAF8F3;
  
  // Theme constants
  static const AppTheme defaultTheme = AppTheme.islamic;
  static const ThemeMode defaultThemeMode = ThemeMode.system;
  static const bool defaultFollowAyahOnPlayback = true;
}