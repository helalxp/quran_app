// lib/constants/khatma_constants.dart

/// Constants for Khatma system
class KhatmaConstants {
  // Timing constants
  static const int pageTrackingCooldownSeconds = 2;
  static const int saveDebounceDurationSeconds = 3;
  static const int progressReminderDelayHours = 2;

  // Alarm ID offsets
  static const int progressReminderIdOffset = 1000;

  // UI constants
  static const double cardBorderRadius = 16.0;
  static const double cardElevation = 4.0;
  static const double progressBarHeight = 8.0;

  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingLarge = 16.0;
  static const double spacingXLarge = 20.0;
  static const double spacingXXLarge = 24.0;

  // Font sizes
  static const double fontSizeCaption = 12.0;
  static const double fontSizeBody = 13.0;
  static const double fontSizeSubheading = 15.0;
  static const double fontSizeTitle = 18.0;
  static const double fontSizeHeading = 20.0;
  static const double fontSizeLarge = 24.0;
  static const double fontSizeDisplay = 32.0;

  // Animation durations
  static const Duration animationDurationFast = Duration(milliseconds: 200);
  static const Duration animationDurationNormal = Duration(milliseconds: 300);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);

  // Accessibility
  static const double minTouchTarget = 48.0;
}
