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

  // Media player UI constants
  static const double mediaPlayerIconSize = 24.0;
  static const double mediaPlayerPlayIconSize = 28.0;
  static const double mediaPlayerBottomOffset = 80.0;
  static const double mediaPlayerLeftOffset = 16.0;
  static const double mediaPlayerBottomButtonOffset = 37.0;
  static const double mediaPlayerBorderRadius = 24.0;
  static const double mediaPlayerBlurRadius = 20.0;
  static const double mediaPlayerMargin = 16.0;

  // Action sheet UI constants
  static const double actionSheetHandleWidth = 40.0;
  static const double actionSheetHandleHeight = 4.0;
  static const double actionSheetHandleBorderRadius = 2.0;
  static const double actionSheetSpacing = 12.0;
  static const double actionSheetTitleFontSize = 18.0;
  static const double actionSheetDividerHeight = 1.0;
  static const double actionSheetPadding = 16.0;
  static const double actionSheetInnerPadding = 12.0;

  // Timing constants
  static const Duration saveDebounceTimeout = Duration(milliseconds: 500);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration longAnimationDuration = Duration(milliseconds: 350);
  static const Duration pulseAnimationDuration = Duration(seconds: 2);

  // Network timeout constants
  static const Duration apiTimeout = Duration(seconds: 8);
  static const Duration tafsirTimeout = Duration(seconds: 10);
  static const Duration snackBarShortDuration = Duration(seconds: 1);
  static const Duration snackBarLongDuration = Duration(seconds: 2);

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